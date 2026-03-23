#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${0##*/}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
keep_fixtures=0

print_help() {
  cat <<EOF
Description:
  Run focused fixture tests for the multi-agent onboarding flow.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help              Show this help message and exit (optional)
  --keep-fixtures         Keep temporary fixture directories for debugging (optional, default: off)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --keep-fixtures)
      keep_fixtures=1
      shift
      ;;
    *)
      printf 'ERROR: Unknown flag %s\n' "$1" >&2
      print_help
      exit 1
      ;;
  esac
done

if [ "${KEEP_FIXTURES:-0}" = "1" ]; then
  keep_fixtures=1
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'ERROR: Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

need_cmd rg

fixtures_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-dock-onboarding-tests.XXXXXX")"

cleanup() {
  if [ "$keep_fixtures" = "1" ]; then
    printf 'Fixtures kept at %s\n' "$fixtures_root"
    return
  fi
  rm -rf "$fixtures_root"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  rg -F --quiet -- "$pattern" "$path" || fail "Expected $path to contain: $pattern"
}

assert_not_exists() {
  local path="$1"
  [ ! -e "$path" ] && [ ! -L "$path" ] || fail "Expected path to be absent: $path"
}

assert_command_fails_with() {
  local output_file="$1"
  shift
  if "$@" >"$output_file" 2>&1; then
    fail "Expected command to fail: $*"
  fi
}

canonical_path() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
  else
    local dir base
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    (cd "$dir" && printf '%s/%s\n' "$(pwd -P)" "$base")
  fi
}

assert_symlink_target_canonical() {
  local link_path="$1"
  local expected_target="$2"
  [ -L "$link_path" ] || fail "Expected symlink: $link_path"
  local actual_target actual_canonical expected_canonical
  actual_target="$(readlink "$link_path")"
  if [[ "$actual_target" = /* ]]; then
    actual_canonical="$(canonical_path "$actual_target")"
  else
    actual_canonical="$(canonical_path "$(dirname "$link_path")/$actual_target")"
  fi
  expected_canonical="$(canonical_path "$expected_target")"
  [ "$actual_canonical" = "$expected_canonical" ] || fail "Expected $link_path -> $expected_target, got $actual_target"
}

create_fake_codex() {
  local bin_dir="$1"
  cat > "${bin_dir}/codex" <<'EOF'
#!/usr/bin/env bash
printf 'fake-codex %s\n' "$*" >/dev/null
EOF
  chmod +x "${bin_dir}/codex"
}

create_fake_gh() {
  local bin_dir="$1"
  local state_file="$2"
  local log_file="$3"
  cat > "${bin_dir}/gh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >> "$log_file"
if [ "\${1:-}" = "auth" ] && [ "\${2:-}" = "status" ]; then
  [ -f "$state_file" ]
  exit \$?
fi
if [ "\${1:-}" = "auth" ] && [ "\${2:-}" = "login" ]; then
  : > "$state_file"
  exit 0
fi
printf 'unexpected gh call: %s\n' "\$*" >&2
exit 1
EOF
  chmod +x "${bin_dir}/gh"
}

prepare_fixture_repo() {
  local fixture_repo="$1"
  mkdir -p \
    "$fixture_repo/scripts" \
    "$fixture_repo/.codex/scripts" \
    "$fixture_repo/.codex/agents/config" \
    "$fixture_repo/.codex/skills/sample-skill" \
    "$fixture_repo/.cursor" \
    "$fixture_repo/.cursor/scripts" \
    "$fixture_repo/.claude/scripts"

  cp "$repo_root/scripts/onboarding.sh" "$fixture_repo/scripts/onboarding.sh"
  cp "$repo_root/scripts/onboarding-lib.sh" "$fixture_repo/scripts/onboarding-lib.sh"
  cp "$repo_root/.codex/scripts/onboarding.sh" "$fixture_repo/.codex/scripts/onboarding.sh"
  cp "$repo_root/.codex/scripts/render-agent-configs.py" "$fixture_repo/.codex/scripts/render-agent-configs.py"
  cp "$repo_root/.cursor/scripts/onboarding.sh" "$fixture_repo/.cursor/scripts/onboarding.sh"
  cp "$repo_root/.claude/scripts/onboarding.sh" "$fixture_repo/.claude/scripts/onboarding.sh"
  chmod +x \
    "$fixture_repo/scripts/onboarding.sh" \
    "$fixture_repo/.codex/scripts/onboarding.sh" \
    "$fixture_repo/.cursor/scripts/onboarding.sh" \
    "$fixture_repo/.claude/scripts/onboarding.sh"
  chmod +x "$fixture_repo/.codex/scripts/render-agent-configs.py"
  ln -s ../.codex/agents "$fixture_repo/.cursor/agents"
  ln -s ../.codex/skills "$fixture_repo/.cursor/skills"
  ln -s ../.codex/skills "$fixture_repo/.claude/skills"

  cat > "$fixture_repo/.codex/config.base.toml" <<'EOF'
model = "gpt-5.4"
model_reasoning_effort = "medium"

[agents.architect]
description = "fixture"
config_file = "agents/config/architect.toml"
EOF

  cat > "$fixture_repo/.codex/config.local.toml" <<'EOF'
machine_note = "keep"
[projects."/tmp/keep"]
trust_level = "untrusted"
EOF

  cat > "$fixture_repo/.codex/skills/sample-skill/SKILL.md" <<'EOF'
---
name: sample-skill
description: Fixture skill
---
EOF
}

run_onboarding() {
  local fixture_repo="$1"
  local fixture_home="$2"
  local xdg_bin="$3"
  shift 3
  HOME="$fixture_home" XDG_BIN_HOME="$xdg_bin" PATH="${PATH_OVERRIDE}:${PATH}" "$fixture_repo/scripts/onboarding.sh" "$@"
}

test_default_codex_selection_bootstraps_codex() {
  local fixture_repo="$fixtures_root/repo-default"
  local fixture_home="$fixtures_root/home-default"
  local bin_dir="$fixtures_root/bin-default"
  local xdg_bin="$fixtures_root/xdg-default"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  create_fake_codex "$bin_dir"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent codex --skip-gh-auth

  assert_symlink_target_canonical "$fixture_home/.codex" "$fixture_repo/.codex"
  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_home/.codex/skills"
  assert_file_contains "$fixture_repo/.codex/agents/config/architect.toml" 'model = "gpt-5.4"'
  assert_file_contains "$fixture_repo/.codex/agents/config/architect.toml" 'reasoning_effort = "medium"'
  assert_file_contains "$fixture_repo/.codex/agents/config/architect.toml" 'sandbox_mode = "read-only"'
  assert_file_contains "$fixture_repo/.codex/config.local.toml" '[projects."'
  assert_file_contains "$fixture_repo/.codex/config.local.toml" 'trust_level = "trusted"'
  assert_file_contains "$fixture_repo/.codex/config.toml" 'machine_note = "keep"'
  [ -x "$xdg_bin/codex-net" ] || fail "Expected codex-net launcher at $xdg_bin/codex-net"
  assert_not_exists "$fixture_home/.cursor"
  assert_not_exists "$fixture_home/.claude"
}

test_codex_without_bootstrap_only_wires_shared_paths() {
  local fixture_repo="$fixtures_root/repo-codex-no-bootstrap"
  local fixture_home="$fixtures_root/home-codex-no-bootstrap"
  local bin_dir="$fixtures_root/bin-codex-no-bootstrap"
  local xdg_bin="$fixtures_root/xdg-codex-no-bootstrap"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent codex --without-codex-bootstrap --skip-gh-auth

  assert_symlink_target_canonical "$fixture_home/.codex" "$fixture_repo/.codex"
  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_home/.codex/skills"
  assert_not_exists "$fixture_repo/.codex/config.toml"
  assert_not_exists "$fixture_repo/.codex/agents/config/architect.toml"
  assert_not_exists "$xdg_bin/codex-net"
}

test_cursor_only_skips_codex_bootstrap_when_forced_off() {
  local fixture_repo="$fixtures_root/repo-cursor-only"
  local fixture_home="$fixtures_root/home-cursor-only"
  local bin_dir="$fixtures_root/bin-cursor-only"
  local xdg_bin="$fixtures_root/xdg-cursor-only"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  rm "$fixture_repo/.codex/config.base.toml"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent cursor --without-codex-bootstrap --skip-gh-auth

  assert_symlink_target_canonical "$fixture_home/.codex" "$fixture_repo/.codex"
  [ -d "$fixture_home/.cursor" ] || fail "Expected Cursor home directory: $fixture_home/.cursor"
  assert_symlink_target_canonical "$fixture_home/.agents/skills" "$fixture_home/.codex/skills"
  assert_symlink_target_canonical "$fixture_home/.cursor/skills" "$fixture_home/.codex/skills"
  assert_symlink_target_canonical "$fixture_home/.cursor/agents" "$fixture_repo/.cursor/agents"
  assert_not_exists "$fixture_repo/.codex/config.toml"
  assert_not_exists "$xdg_bin/codex-net"
}

test_cursor_with_explicit_codex_bootstrap_runs_both() {
  local fixture_repo="$fixtures_root/repo-cursor-with-bootstrap"
  local fixture_home="$fixtures_root/home-cursor-with-bootstrap"
  local bin_dir="$fixtures_root/bin-cursor-with-bootstrap"
  local xdg_bin="$fixtures_root/xdg-cursor-with-bootstrap"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  create_fake_codex "$bin_dir"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent cursor --with-codex-bootstrap --skip-gh-auth

  assert_symlink_target_canonical "$fixture_home/.codex" "$fixture_repo/.codex"
  [ -d "$fixture_home/.cursor" ] || fail "Expected Cursor home directory: $fixture_home/.cursor"
  assert_file_contains "$fixture_repo/.codex/config.toml" 'machine_note = "keep"'
  [ -x "$xdg_bin/codex-net" ] || fail "Expected codex-net launcher at $xdg_bin/codex-net"
}

test_all_selection_links_all_homes() {
  local fixture_repo="$fixtures_root/repo-all"
  local fixture_home="$fixtures_root/home-all"
  local bin_dir="$fixtures_root/bin-all"
  local xdg_bin="$fixtures_root/xdg-all"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  create_fake_codex "$bin_dir"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent all --skip-gh-auth

  assert_symlink_target_canonical "$fixture_home/.codex" "$fixture_repo/.codex"
  [ -d "$fixture_home/.cursor" ] || fail "Expected Cursor home directory: $fixture_home/.cursor"
  assert_symlink_target_canonical "$fixture_home/.claude" "$fixture_repo/.claude"
  assert_symlink_target_canonical "$fixture_home/.cursor/agents" "$fixture_repo/.cursor/agents"
  assert_symlink_target_canonical "$fixture_home/.cursor/skills" "$fixture_home/.codex/skills"
  assert_symlink_target_canonical "$fixture_home/.claude/skills" "$fixture_home/.codex/skills"
  [ -x "$xdg_bin/codex-net" ] || fail "Expected codex-net launcher at $xdg_bin/codex-net"
}

test_all_without_codex_bootstrap_skips_only_bootstrap() {
  local fixture_repo="$fixtures_root/repo-all-no-bootstrap"
  local fixture_home="$fixtures_root/home-all-no-bootstrap"
  local bin_dir="$fixtures_root/bin-all-no-bootstrap"
  local xdg_bin="$fixtures_root/xdg-all-no-bootstrap"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent all --without-codex-bootstrap --skip-gh-auth

  assert_symlink_target_canonical "$fixture_home/.codex" "$fixture_repo/.codex"
  [ -d "$fixture_home/.cursor" ] || fail "Expected Cursor home directory: $fixture_home/.cursor"
  assert_symlink_target_canonical "$fixture_home/.claude" "$fixture_repo/.claude"
  assert_not_exists "$fixture_repo/.codex/config.toml"
  assert_not_exists "$xdg_bin/codex-net"
}

test_interactive_menu_shows_and_accepts_selection() {
  local fixture_repo="$fixtures_root/repo-interactive"
  local fixture_home="$fixtures_root/home-interactive"
  local bin_dir="$fixtures_root/bin-interactive"
  local xdg_bin="$fixtures_root/xdg-interactive"
  local output_file="$fixtures_root/interactive.out"
  local gh_state="$fixtures_root/interactive-gh.state"
  local gh_log="$fixtures_root/interactive-gh.log"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  create_fake_gh "$bin_dir" "$gh_state" "$gh_log"
  printf '2\n' | HOME="$fixture_home" XDG_BIN_HOME="$xdg_bin" PATH="${bin_dir}:${PATH}" ONBOARDING_FORCE_INTERACTIVE=1 "$fixture_repo/scripts/onboarding.sh" >"$output_file" 2>&1

  assert_file_contains "$output_file" 'agent-dock onboarding'
  assert_file_contains "$output_file" 'Choose agent home(s) to onboard:'
  [ -d "$fixture_home/.cursor" ] || fail "Expected Cursor home directory: $fixture_home/.cursor"
  assert_symlink_target_canonical "$fixture_home/.cursor/agents" "$fixture_repo/.cursor/agents"
  assert_symlink_target_canonical "$fixture_home/.cursor/skills" "$fixture_home/.codex/skills"
  assert_not_exists "$fixture_repo/.codex/config.toml"
  assert_file_contains "$gh_log" 'auth status'
}

test_cursor_subpath_mode_preserves_existing_cursor_state() {
  local fixture_repo="$fixtures_root/repo-cursor-preserve"
  local fixture_home="$fixtures_root/home-cursor-preserve"
  local bin_dir="$fixtures_root/bin-cursor-preserve"
  local xdg_bin="$fixtures_root/xdg-cursor-preserve"
  mkdir -p "$fixture_home/.cursor/projects/existing" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  printf 'keep\n' > "$fixture_home/.cursor/projects/existing/state.json"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent cursor --without-codex-bootstrap --skip-gh-auth

  assert_file_contains "$fixture_home/.cursor/projects/existing/state.json" 'keep'
  assert_symlink_target_canonical "$fixture_home/.cursor/agents" "$fixture_repo/.cursor/agents"
  assert_symlink_target_canonical "$fixture_home/.cursor/skills" "$fixture_home/.codex/skills"
}

test_cursor_subpath_mode_replaces_legacy_cursor_symlink() {
  local fixture_repo="$fixtures_root/repo-cursor-legacy"
  local fixture_home="$fixtures_root/home-cursor-legacy"
  local legacy_target="$fixtures_root/legacy-cursor"
  local bin_dir="$fixtures_root/bin-cursor-legacy"
  local xdg_bin="$fixtures_root/xdg-cursor-legacy"
  mkdir -p "$fixture_home" "$legacy_target" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  ln -s "$legacy_target" "$fixture_home/.cursor"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent cursor --without-codex-bootstrap --skip-gh-auth

  [ -d "$fixture_home/.cursor" ] || fail "Expected Cursor home directory after migration: $fixture_home/.cursor"
  assert_symlink_target_canonical "$fixture_home/.cursor/agents" "$fixture_repo/.cursor/agents"
  assert_symlink_target_canonical "$fixture_home/.cursor/skills" "$fixture_home/.codex/skills"
  compgen -G "$fixture_home/.cursor.symlink.backup.*" >/dev/null || fail "Expected legacy Cursor symlink backup"
}

test_gh_auth_runs_for_cursor_only() {
  local fixture_repo="$fixtures_root/repo-gh"
  local fixture_home="$fixtures_root/home-gh"
  local bin_dir="$fixtures_root/bin-gh"
  local xdg_bin="$fixtures_root/xdg-gh"
  local gh_state="$fixtures_root/gh.state"
  local gh_log="$fixtures_root/gh.log"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  create_fake_gh "$bin_dir" "$gh_state" "$gh_log"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent cursor --without-codex-bootstrap

  assert_file_contains "$gh_log" 'auth status'
  assert_file_contains "$gh_log" 'auth login -h github.com'
}

test_skills_library_removed() {
  local fixture_repo="$fixtures_root/repo-library"
  local fixture_home="$fixtures_root/home-library"
  local bin_dir="$fixtures_root/bin-library"
  local xdg_bin="$fixtures_root/xdg-library"
  mkdir -p "$fixture_home/.agents/skills-library" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  : > "$fixture_home/.agents/skills-library/.codex-library-skills"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --without-codex-bootstrap --skip-gh-auth

  assert_not_exists "$fixture_home/.agents/skills-library"
}

test_direct_codex_script_is_blocked() {
  local fixture_repo="$fixtures_root/repo-direct-codex"
  local output_file="$fixtures_root/direct-codex.out"
  mkdir -p "$fixtures_root/direct-agent-dock"
  prepare_fixture_repo "$fixture_repo"

  assert_command_fails_with "$output_file" "$fixture_repo/.codex/scripts/onboarding.sh"
  assert_file_contains "$output_file" 'Run ./scripts/onboarding.sh instead.'
}

test_conflicting_bootstrap_flags_fail() {
  local fixture_repo="$fixtures_root/repo-conflict"
  local fixture_home="$fixtures_root/home-conflict"
  local bin_dir="$fixtures_root/bin-conflict"
  local xdg_bin="$fixtures_root/xdg-conflict"
  local output_file="$fixtures_root/conflict.out"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"

  assert_command_fails_with "$output_file" env HOME="$fixture_home" XDG_BIN_HOME="$xdg_bin" PATH="${bin_dir}:${PATH}" "$fixture_repo/scripts/onboarding.sh" --agent codex --with-codex-bootstrap --without-codex-bootstrap
  assert_file_contains "$output_file" 'Cannot combine --with-codex-bootstrap and --without-codex-bootstrap'
}

create_fake_claude() {
  local bin_dir="$1"
  cat > "${bin_dir}/claude" <<'EOF'
#!/usr/bin/env bash
printf 'fake-claude %s\n' "$*" >/dev/null
EOF
  chmod +x "${bin_dir}/claude"
}

test_claude_dev_launcher_includes_tmux_integration() {
  local fixture_repo="$fixtures_root/repo-tmux"
  local fixture_home="$fixtures_root/home-tmux"
  local bin_dir="$fixtures_root/bin-tmux"
  local xdg_bin="$fixtures_root/xdg-tmux"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  create_fake_codex "$bin_dir"
  create_fake_claude "$bin_dir"

  cat > "$fixture_repo/.claude/settings.base.json" <<'EOF'
{ "model": "sonnet" }
EOF

  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --agent claude --skip-gh-auth

  [ -x "$xdg_bin/claude-dev" ] || fail "Expected claude-dev launcher at $xdg_bin/claude-dev"
  assert_file_contains "$xdg_bin/claude-dev" 'tmux new-session'
  assert_file_contains "$xdg_bin/claude-dev" 'tmux has-session'
  assert_file_contains "$xdg_bin/claude-dev" 'tmux switch-client'
  assert_file_contains "$xdg_bin/claude-dev" 'tmux display-message'
  assert_file_contains "$xdg_bin/claude-dev" 'TMUX'
  assert_file_contains "$xdg_bin/claude-dev" '--no-tmux'
  assert_file_contains "$xdg_bin/claude-dev" 'claude-work'
  assert_file_contains "$xdg_bin/claude-dev" '--dangerously-skip-permissions'
  assert_file_contains "$xdg_bin/claude-dev" 'CLAUDE_DEV_TMUX_SESSION'
}

test_idempotent_rerun_keeps_config_stable() {
  local fixture_repo="$fixtures_root/repo-idempotent"
  local fixture_home="$fixtures_root/home-idempotent"
  local bin_dir="$fixtures_root/bin-idempotent"
  local xdg_bin="$fixtures_root/xdg-idempotent"
  mkdir -p "$fixture_home" "$bin_dir" "$xdg_bin"
  prepare_fixture_repo "$fixture_repo"
  create_fake_codex "$bin_dir"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --skip-gh-auth
  local first_local first_config
  first_local="$(cat "$fixture_repo/.codex/config.local.toml")"
  first_config="$(cat "$fixture_repo/.codex/config.toml")"
  PATH_OVERRIDE="$bin_dir" run_onboarding "$fixture_repo" "$fixture_home" "$xdg_bin" --skip-gh-auth
  [ "$first_local" = "$(cat "$fixture_repo/.codex/config.local.toml")" ] || fail "config.local.toml changed on rerun"
  [ "$first_config" = "$(cat "$fixture_repo/.codex/config.toml")" ] || fail "config.toml changed on rerun"
}

test_default_codex_selection_bootstraps_codex
printf 'ok - default codex selection bootstraps codex\n'
test_codex_without_bootstrap_only_wires_shared_paths
printf 'ok - codex selection can skip bootstrap and keep shared wiring only\n'
test_interactive_menu_shows_and_accepts_selection
printf 'ok - interactive menu is shown and accepts a selection\n'
test_cursor_only_skips_codex_bootstrap_when_forced_off
printf 'ok - cursor-only selection can skip codex bootstrap\n'
test_cursor_with_explicit_codex_bootstrap_runs_both
printf 'ok - cursor selection can explicitly add codex bootstrap\n'
test_all_selection_links_all_homes
printf 'ok - all selection links all homes\n'
test_all_without_codex_bootstrap_skips_only_bootstrap
printf 'ok - all selection can skip codex bootstrap while keeping other agents\n'
test_gh_auth_runs_for_cursor_only
printf 'ok - gh auth runs for cursor-only onboarding\n'
test_skills_library_removed
printf 'ok - deprecated skills-library is removed\n'
test_cursor_subpath_mode_preserves_existing_cursor_state
printf 'ok - cursor onboarding preserves existing cursor state while wiring subpaths\n'
test_cursor_subpath_mode_replaces_legacy_cursor_symlink
printf 'ok - cursor onboarding migrates legacy cursor home symlinks\n'
test_direct_codex_script_is_blocked
printf 'ok - direct codex onboarding entry is blocked\n'
test_conflicting_bootstrap_flags_fail
printf 'ok - conflicting bootstrap flags fail cleanly\n'
test_claude_dev_launcher_includes_tmux_integration
printf 'ok - claude-dev launcher includes tmux integration\n'
test_idempotent_rerun_keeps_config_stable
printf 'ok - onboarding rerun is idempotent\n'
