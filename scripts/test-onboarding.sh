#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_script="$repo_root/scripts/onboarding.sh"
fixture_roots=()
SCRIPT_PATH="${0##*/}"

print_help() {
  cat <<EOF_HELP
Description:
  Run tests that validate scripts/onboarding.sh is non-destructive, idempotent, enforces user-level skill-link
  policy, bootstraps GitHub auth, installs a codex-net launcher, and installs the Cursor role-loader.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help          Show this help message and exit (optional)
  --keep-fixtures     Keep temporary fixture directories (optional, default: off; also supports KEEP_FIXTURES=1)
EOF_HELP
}

cleanup() {
  local code=$?
  [ "${KEEP_FIXTURES:-0}" = "1" ] && return 0
  set +u
  local fixture_root
  for fixture_root in "${fixture_roots[@]}"; do
    [ -n "$fixture_root" ] && rm -rf "$fixture_root"
  done
  set -u
  return "$code"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --keep-fixtures)
      KEEP_FIXTURES=1
      shift
      ;;
    -*)
      printf 'ERROR: Unknown flag %s\n' "$1" >&2
      print_help
      exit 1
      ;;
    *)
      printf 'ERROR: Unexpected argument %s\n' "$1" >&2
      print_help
      exit 1
      ;;
  esac
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"
  rg -q --fixed-strings -- "$pattern" "$file" || fail "Expected '$pattern' in $file"
}

assert_file_not_contains() {
  local file="$1"
  local pattern="$2"
  if rg -q --fixed-strings -- "$pattern" "$file"; then
    fail "Did not expect '$pattern' in $file"
  fi
}

assert_eq() {
  local got="$1"
  local want="$2"
  local msg="$3"
  [ "$got" = "$want" ] || fail "$msg (got '$got', want '$want')"
}

assert_symlink_target_canonical() {
  local link_path="$1"
  local want_path="$2"
  [ -L "$link_path" ] || fail "Expected symlink at $link_path"
  local got_canonical want_canonical
  got_canonical="$(cd "$(dirname "$link_path")" && cd "$(readlink "$link_path")" && pwd -P)"
  want_canonical="$(cd "$want_path" && pwd -P)"
  assert_eq "$got_canonical" "$want_canonical" "Symlink target mismatch for $link_path"
}

run_onboarding() {
  local fixture_home="$1"
  local fixture_repo="$2"
  local codex_home="$3"
  shift 3
  local has_cursor_home=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --cursor-home|--cursor-home=*) has_cursor_home=1; break ;;
    esac
  done
  if [ "$has_cursor_home" -eq 0 ]; then
    set -- --cursor-home "$fixture_home/.cursor" "$@"
  fi
  HOME="$fixture_home" "$fixture_repo/scripts/onboarding.sh" "$codex_home" "$@"
}

make_fixture() {
  local fixture_root
  fixture_root="$(mktemp -d)"
  fixture_roots+=("$fixture_root")
  local fixture_repo="$fixture_root/repo"
  mkdir -p "$fixture_repo/scripts"
  mkdir -p "$fixture_repo/.platforms/cursor/agents"
  cp "$source_script" "$fixture_repo/scripts/onboarding.sh"
  chmod +x "$fixture_repo/scripts/onboarding.sh"
  cp "$repo_root/.platforms/cursor/agents/codex-role-loader.md" \
    "$fixture_repo/.platforms/cursor/agents/codex-role-loader.md"
  printf '%s\n' "$fixture_root"
}

install_stub_gh() {
  local fixture_root="$1"
  local stub_dir="$fixture_root/stubs"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/gh" <<'STUB_GH'
#!/usr/bin/env bash
set -euo pipefail

log_dir="${GH_STUB_LOG_DIR:-}"
status_result="${GH_STUB_STATUS_RESULT:-ok}"
login_result="${GH_STUB_LOGIN_RESULT:-ok}"
token_value="${GH_STUB_TOKEN_VALUE:-}"

if [ $# -lt 2 ]; then
  exit 1
fi

if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
  if [ "$status_result" = "fail-then-ok" ]; then
    if [ -n "$log_dir" ] && [ -f "$log_dir/login-called" ]; then
      exit 0
    fi
    exit 1
  fi
  if [ "$status_result" = "ok" ]; then
    exit 0
  fi
  exit 1
fi

if [ "$1" = "auth" ] && [ "$2" = "login" ]; then
  if [ -n "$log_dir" ]; then
    mkdir -p "$log_dir"
    : > "$log_dir/login-called"
  fi
  if [ "$login_result" = "ok" ]; then
    exit 0
  fi
  exit 1
fi

if [ "$1" = "auth" ] && [ "$2" = "token" ]; then
  printf '%s\n' "$token_value"
  exit 0
fi

exit 1
STUB_GH
  chmod +x "$stub_dir/gh"
  printf '%s\n' "$stub_dir"
}

need_cmd rg
need_cmd mktemp
test_non_destructive_and_idempotent() {
  local fixture_root fixture_repo fixture_home codex_home before_local after_local before_cfg after_cfg block_count loader_dst
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  loader_dst="$fixture_home/.cursor/agents/codex-role-loader.md"
  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  cat > "$fixture_repo/config.local.toml" <<EOF_LOCAL
machine_note = "keep"

[projects."/tmp/keep"]
trust_level = "ask"

[projects."$fixture_repo"]
trust_level = "untrusted"
EOF_LOCAL

  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" --skip-gh-auth >/dev/null

  assert_file_contains "$fixture_repo/config.local.toml" 'machine_note = "keep"'
  assert_file_contains "$fixture_repo/config.local.toml" '[projects."/tmp/keep"]'
  assert_file_contains "$fixture_repo/config.local.toml" "[projects.\"$fixture_repo\"]"
  assert_file_contains "$fixture_repo/config.local.toml" 'trust_level = "trusted"'

  block_count="$(rg -c --fixed-strings "[projects.\"$fixture_repo\"]" "$fixture_repo/config.local.toml")"
  assert_eq "$block_count" "1" "Project trust block should appear exactly once"

  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_repo/agents/skills"
  [ -f "$loader_dst" ] || fail "Expected codex-role-loader.md at $loader_dst after first onboarding run"

  before_local="$(cat "$fixture_repo/config.local.toml")"
  before_cfg="$(cat "$fixture_repo/config.toml")"

  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" --skip-gh-auth >/dev/null

  after_local="$(cat "$fixture_repo/config.local.toml")"
  after_cfg="$(cat "$fixture_repo/config.toml")"

  assert_eq "$after_local" "$before_local" "Second onboarding run should not change config.local.toml"
  assert_eq "$after_cfg" "$before_cfg" "Second onboarding run should not change generated config.toml"
  [ -f "$loader_dst" ] || fail "Expected codex-role-loader.md at $loader_dst after second onboarding run"

  if ls "$codex_home".symlink.backup.* >/dev/null 2>&1; then
    fail "No codex symlink backup should be created on idempotent re-run"
  fi
  if ls "$fixture_home/.agents/skills".symlink.backup.* >/dev/null 2>&1; then
    fail "No user skills backup should be created on idempotent re-run"
  fi
}

test_cursor_role_loader_destination_directory_fails() {
  local fixture_root fixture_repo fixture_home codex_home cursor_home loader_dst output_file
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  cursor_home="$fixture_home/.cursor"
  loader_dst="$cursor_home/agents/codex-role-loader.md"
  output_file="$fixture_root/onboarding-directory-destination.log"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills" "$loader_dst"
  [ -d "$loader_dst" ] || fail "Precondition: expected directory at $loader_dst"

  if run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" --skip-gh-auth >"$output_file" 2>&1; then
    fail "Onboarding should fail when Cursor role-loader destination is a directory"
  fi

  assert_file_contains "$output_file" "Cursor role-loader destination exists as a directory"
}

test_missing_base_fails() {
  local fixture_root fixture_repo fixture_home codex_home output_file
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  output_file="$fixture_root/onboarding.log"
  mkdir -p "$fixture_home"

  if run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" --skip-gh-auth >"$output_file" 2>&1; then
    fail "Onboarding should fail when config.base.toml is missing"
  fi

  assert_file_contains "$output_file" 'ERROR: Missing required base config'
  [ ! -e "$fixture_repo/config.toml" ] || fail "config.toml should not be generated when base config is missing"
}

test_canonical_symlink_equivalence() {
  local fixture_root fixture_repo fixture_home codex_home
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  ln -s "../repo" "$codex_home"

  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" --skip-gh-auth >/dev/null

  if ls "$codex_home".symlink.backup.* >/dev/null 2>&1; then
    fail "Canonical-equivalent symlink should not be relinked"
  fi

  [ -L "$codex_home" ] || fail "Codex symlink should still exist"
  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_repo/agents/skills"
}

test_repo_skills_path_is_not_migrated() {
  local fixture_root fixture_repo fixture_home codex_home
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/skills/legacy-skill"
  cat > "$fixture_repo/skills/legacy-skill/SKILL.md" <<'SKILL'
# Legacy Skill
SKILL

  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" --skip-gh-auth >"$fixture_root/onboarding.log" 2>&1

  [ -d "$fixture_repo/skills" ] || fail "Repo-managed skills path should not be removed"
  [ -f "$fixture_repo/skills/legacy-skill/SKILL.md" ] || fail "Repo-managed skills entries should remain in place"
  [ ! -f "$fixture_repo/agents/skills/legacy-skill/SKILL.md" ] || fail "Repo-managed skills should not be migrated into agents/skills"
  assert_file_contains "$fixture_root/onboarding.log" "Legacy skills path resolves to repo-managed skills; skipping migration"
  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_repo/agents/skills"
}

test_claude_skills_links_created() {
  local fixture_root fixture_repo fixture_home codex_home claude_skill_link
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  claude_skill_link="$fixture_home/.claude/skills/claude-skill"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills/claude-skill"

  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" --skip-gh-auth >/dev/null

  assert_symlink_target_canonical "$claude_skill_link" "$fixture_home/.agents/skills/claude-skill"
}

test_gh_missing_fails_when_default_on() {
  local fixture_root fixture_repo fixture_home codex_home output_file path_without_gh
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  output_file="$fixture_root/onboarding-gh-missing.log"
  path_without_gh="/usr/bin:/bin:/usr/sbin:/sbin"

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  if PATH="$path_without_gh" run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" >"$output_file" 2>&1; then
    fail "Onboarding should fail by default when gh is unavailable"
  fi

  assert_file_contains "$output_file" "GitHub CLI ('gh') is required for onboarding auth bootstrap"
  assert_file_contains "$output_file" "--skip-gh-auth"
}

test_gh_skipped_with_flag() {
  local fixture_root fixture_repo fixture_home codex_home path_without_gh
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  path_without_gh="/usr/bin:/bin:/usr/sbin:/sbin"

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  PATH="$path_without_gh" run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" --skip-gh-auth >/dev/null
}

test_gh_auth_success() {
  local fixture_root fixture_repo fixture_home codex_home stub_dir
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  stub_dir="$(install_stub_gh "$fixture_root")"

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  PATH="$stub_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
    GH_STUB_STATUS_RESULT="ok" \
    run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" >/dev/null
}

test_gh_auth_invalid_triggers_login() {
  local fixture_root fixture_repo fixture_home codex_home stub_dir login_log_dir
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  stub_dir="$(install_stub_gh "$fixture_root")"
  login_log_dir="$fixture_root/gh-stub-log"

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  PATH="$stub_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
    GH_STUB_STATUS_RESULT="fail-then-ok" \
    GH_STUB_LOGIN_RESULT="ok" \
    GH_STUB_LOG_DIR="$login_log_dir" \
    run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" >/dev/null

  [ -f "$login_log_dir/login-called" ] || fail "Expected gh auth login to be called"
}

test_no_token_persistence() {
  local fixture_root fixture_repo fixture_home codex_home stub_dir output_file secret_token
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  stub_dir="$(install_stub_gh "$fixture_root")"
  output_file="$fixture_root/onboarding-gh-output.log"
  secret_token="gho_stub_no_leak_token"

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  PATH="$stub_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
    GH_STUB_STATUS_RESULT="ok" \
    GH_STUB_TOKEN_VALUE="$secret_token" \
    run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" >"$output_file" 2>&1

  assert_file_not_contains "$output_file" "$secret_token"
  [ ! -e "$codex_home/secrets/gh_token" ] || fail "Onboarding should not write GH token secrets"
}

test_codex_net_launcher_installed() {
  local fixture_root fixture_repo fixture_home codex_home stub_dir launcher_path
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  stub_dir="$(install_stub_gh "$fixture_root")"
  launcher_path="$fixture_home/.local/bin/codex-net"

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  PATH="$stub_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
    GH_STUB_STATUS_RESULT="ok" \
    run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" >/dev/null
  [ -x "$launcher_path" ] || fail "Expected codex-net launcher at $launcher_path"
  assert_file_contains "$launcher_path" 'exec codex --sandbox danger-full-access -a never --search -c shell_environment_policy.inherit=all'
}

test_cursor_role_loader_copied() {
  local fixture_root fixture_repo fixture_home codex_home cursor_home loader_dst
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  cursor_home="$fixture_home/.cursor"
  loader_dst="$cursor_home/agents/codex-role-loader.md"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" \
    --cursor-home "$cursor_home" --skip-gh-auth >/dev/null

  [ -f "$loader_dst" ] || fail "Expected codex-role-loader.md at $loader_dst"
  [ ! -L "$loader_dst" ] || fail "codex-role-loader.md must be a regular file, not a symlink"
  assert_file_contains "$loader_dst" 'name: codex-role-loader'
}

test_cursor_role_loader_overwrite() {
  local fixture_root fixture_repo fixture_home codex_home cursor_home loader_dst
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  cursor_home="$fixture_home/.cursor"
  loader_dst="$cursor_home/agents/codex-role-loader.md"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills" "$cursor_home/agents"
  printf 'stale content\n' > "$loader_dst"

  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" \
    --cursor-home "$cursor_home" --skip-gh-auth >/dev/null

  [ -f "$loader_dst" ] || fail "Expected codex-role-loader.md at $loader_dst"
  assert_file_contains "$loader_dst" 'name: codex-role-loader'
  if rg -q --fixed-strings 'stale content' "$loader_dst"; then
    fail "Stale content should have been overwritten"
  fi
}

test_cursor_role_loader_symlink_replaced() {
  local fixture_root fixture_repo fixture_home codex_home cursor_home loader_dst
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  cursor_home="$fixture_home/.cursor"
  loader_dst="$cursor_home/agents/codex-role-loader.md"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills" "$cursor_home/agents"
  ln -s "$fixture_repo/.platforms/cursor/agents/codex-role-loader.md" "$loader_dst"
  [ -L "$loader_dst" ] || fail "Precondition: expected symlink at $loader_dst"

  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" \
    --cursor-home "$cursor_home" --skip-gh-auth >/dev/null

  [ -f "$loader_dst" ] || fail "Expected codex-role-loader.md at $loader_dst"
  [ ! -L "$loader_dst" ] || fail "Symlink should have been replaced with a regular file"
}

test_cursor_role_loader_idempotent() {
  local fixture_root fixture_repo fixture_home codex_home cursor_home loader_dst before after
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  cursor_home="$fixture_home/.cursor"
  loader_dst="$cursor_home/agents/codex-role-loader.md"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" \
    --cursor-home "$cursor_home" --skip-gh-auth >/dev/null
  before="$(cat "$loader_dst")"

  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" \
    --cursor-home "$cursor_home" --skip-gh-auth >/dev/null
  after="$(cat "$loader_dst")"

  assert_eq "$after" "$before" "Second onboarding run should not change loader content"
}

test_cursor_home_override() {
  local fixture_root fixture_repo fixture_home codex_home custom_cursor_home loader_dst
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  custom_cursor_home="$fixture_root/custom-cursor"
  loader_dst="$custom_cursor_home/agents/codex-role-loader.md"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$fixture_home" "$fixture_repo/agents/skills"
  run_onboarding "$fixture_home" "$fixture_repo" "$codex_home" \
    --cursor-home "$custom_cursor_home" --skip-gh-auth >/dev/null

  [ -f "$loader_dst" ] || fail "Expected codex-role-loader.md in overridden cursor home at $loader_dst"
  [ ! -L "$loader_dst" ] || fail "codex-role-loader.md must be a regular file, not a symlink"
  assert_file_contains "$loader_dst" 'name: codex-role-loader'
}

test_non_destructive_and_idempotent
printf 'ok - non-destructive and idempotent\n'

test_missing_base_fails
printf 'ok - missing base fails\n'

test_canonical_symlink_equivalence
printf 'ok - canonical symlink equivalence\n'

test_repo_skills_path_is_not_migrated
printf 'ok - repo skills path is not migrated\n'

test_claude_skills_links_created
printf 'ok - claude skills links created\n'

test_gh_missing_fails_when_default_on
printf 'ok - gh missing fails when default on\n'

test_gh_skipped_with_flag
printf 'ok - gh skipped with flag\n'

test_gh_auth_success
printf 'ok - gh auth success\n'

test_gh_auth_invalid_triggers_login
printf 'ok - gh auth invalid triggers login\n'

test_no_token_persistence
printf 'ok - no token persistence\n'

test_codex_net_launcher_installed
printf 'ok - codex-net launcher installed\n'

test_cursor_role_loader_copied
printf 'ok - cursor role-loader copied as regular file\n'

test_cursor_role_loader_overwrite
printf 'ok - cursor role-loader overwritten when stale\n'

test_cursor_role_loader_symlink_replaced
printf 'ok - cursor role-loader symlink replaced with regular file\n'

test_cursor_role_loader_destination_directory_fails
printf 'ok - cursor role-loader directory destination fails with clear error\n'

test_cursor_role_loader_idempotent
printf 'ok - cursor role-loader copy is idempotent\n'

test_cursor_home_override
printf 'ok - cursor home override respected\n'

printf 'All onboarding tests passed.\n'
