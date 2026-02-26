#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_script="$repo_root/scripts/onboarding.sh"
fixture_roots=()
SCRIPT_PATH="${0##*/}"

print_help() {
  cat <<EOF_HELP
Description:
  Run tests that validate scripts/onboarding.sh is non-destructive, idempotent, and enforces user-level skill-link policy.

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
  rg -q --fixed-strings "$pattern" "$file" || fail "Expected '$pattern' in $file"
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

make_fixture() {
  local fixture_root
  fixture_root="$(mktemp -d)"
  fixture_roots+=("$fixture_root")
  local fixture_repo="$fixture_root/repo"
  mkdir -p "$fixture_repo/scripts"
  cp "$source_script" "$fixture_repo/scripts/onboarding.sh"
  chmod +x "$fixture_repo/scripts/onboarding.sh"
  printf '%s\n' "$fixture_root"
}

need_cmd rg
need_cmd mktemp

test_non_destructive_and_idempotent() {
  local fixture_root fixture_repo fixture_home codex_home before_local after_local before_cfg after_cfg block_count
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
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

  HOME="$fixture_home" "$fixture_repo/scripts/onboarding.sh" "$codex_home" >/dev/null

  assert_file_contains "$fixture_repo/config.local.toml" 'machine_note = "keep"'
  assert_file_contains "$fixture_repo/config.local.toml" '[projects."/tmp/keep"]'
  assert_file_contains "$fixture_repo/config.local.toml" "[projects.\"$fixture_repo\"]"
  assert_file_contains "$fixture_repo/config.local.toml" 'trust_level = "trusted"'

  block_count="$(rg -c --fixed-strings "[projects.\"$fixture_repo\"]" "$fixture_repo/config.local.toml")"
  assert_eq "$block_count" "1" "Project trust block should appear exactly once"

  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_repo/agents/skills"

  before_local="$(cat "$fixture_repo/config.local.toml")"
  before_cfg="$(cat "$fixture_repo/config.toml")"

  HOME="$fixture_home" "$fixture_repo/scripts/onboarding.sh" "$codex_home" >/dev/null

  after_local="$(cat "$fixture_repo/config.local.toml")"
  after_cfg="$(cat "$fixture_repo/config.toml")"

  assert_eq "$after_local" "$before_local" "Second onboarding run should not change config.local.toml"
  assert_eq "$after_cfg" "$before_cfg" "Second onboarding run should not change generated config.toml"

  if ls "$codex_home".symlink.backup.* >/dev/null 2>&1; then
    fail "No codex symlink backup should be created on idempotent re-run"
  fi
  if ls "$fixture_home/.agents/skills".symlink.backup.* >/dev/null 2>&1; then
    fail "No user skills backup should be created on idempotent re-run"
  fi
}

test_missing_base_fails() {
  local fixture_root fixture_repo fixture_home codex_home output_file
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  fixture_home="$fixture_root/home"
  codex_home="$fixture_home/.codex"
  output_file="$fixture_root/onboarding.log"
  mkdir -p "$fixture_home"

  if HOME="$fixture_home" "$fixture_repo/scripts/onboarding.sh" "$codex_home" >"$output_file" 2>&1; then
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

  HOME="$fixture_home" "$fixture_repo/scripts/onboarding.sh" "$codex_home" >/dev/null

  if ls "$codex_home".symlink.backup.* >/dev/null 2>&1; then
    fail "Canonical-equivalent symlink should not be relinked"
  fi

  [ -L "$codex_home" ] || fail "Codex symlink should still exist"
  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_repo/agents/skills"
}

test_legacy_skills_migration() {
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

  HOME="$fixture_home" "$fixture_repo/scripts/onboarding.sh" "$codex_home" >/dev/null

  [ ! -d "$fixture_repo/skills" ] || fail "Legacy skills directory should be removed after migration"
  [ -f "$fixture_repo/agents/skills/legacy-skill/SKILL.md" ] || fail "Legacy skill should move into agents/skills"
  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_repo/agents/skills"
}

test_non_destructive_and_idempotent
printf 'ok - non-destructive and idempotent\n'

test_missing_base_fails
printf 'ok - missing base fails\n'

test_canonical_symlink_equivalence
printf 'ok - canonical symlink equivalence\n'

test_legacy_skills_migration
printf 'ok - legacy skills migration\n'

printf 'All onboarding tests passed.\n'
