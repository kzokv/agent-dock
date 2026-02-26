#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_script="$repo_root/scripts/onboarding.sh"
fixture_roots=()
SCRIPT_PATH="${0##*/}"

print_help() {
  cat <<EOF
Description:
  Run a small test suite that validates scripts/onboarding.sh is non-destructive and idempotent.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help          Show this help message and exit (optional)
  --keep-fixtures     Keep temporary fixture directories (optional, default: off; also supports KEEP_FIXTURES=1)
EOF
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

# fail helper centralizes fatal test exits so downstream assertions can depend on clear messaging and describe what the test harness is guarding.
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

# assert_file_contains is a helper for checking that helper-driven edits land in config files so the onboarding script’s intent is verified.
assert_file_contains() {
  local file="$1"
  local pattern="$2"
  rg -q --fixed-strings "$pattern" "$file" || fail "Expected '$pattern' in $file"
}

# assert_eq ensures helper outputs remain stable across reruns and protects the script’s idempotent behavior.
assert_eq() {
  local got="$1"
  local want="$2"
  local msg="$3"
  [ "$got" = "$want" ] || fail "$msg (got '$got', want '$want')"
}

# make_fixture builds an isolated repo (and folders) so helper-run tests can pass the optional codex_home flag safely and ensures each helper verification stays scoped.
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
  local fixture_root fixture_repo codex_home before_local after_local before_cfg after_cfg block_count
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  codex_home="$fixture_root/home/.codex"
  mkdir -p "$(dirname "$codex_home")"

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

  "$fixture_repo/scripts/onboarding.sh" "$codex_home" >/dev/null

  assert_file_contains "$fixture_repo/config.local.toml" 'machine_note = "keep"'
  assert_file_contains "$fixture_repo/config.local.toml" '[projects."/tmp/keep"]'
  assert_file_contains "$fixture_repo/config.local.toml" "[projects.\"$fixture_repo\"]"
  assert_file_contains "$fixture_repo/config.local.toml" 'trust_level = "trusted"'

  block_count="$(rg -c --fixed-strings "[projects.\"$fixture_repo\"]" "$fixture_repo/config.local.toml")"
  assert_eq "$block_count" "1" "Project trust block should appear exactly once"

  before_local="$(cat "$fixture_repo/config.local.toml")"
  before_cfg="$(cat "$fixture_repo/config.toml")"

  "$fixture_repo/scripts/onboarding.sh" "$codex_home" >/dev/null

  after_local="$(cat "$fixture_repo/config.local.toml")"
  after_cfg="$(cat "$fixture_repo/config.toml")"

  assert_eq "$after_local" "$before_local" "Second onboarding run should not change config.local.toml"
  assert_eq "$after_cfg" "$before_cfg" "Second onboarding run should not change generated config.toml"

  if ls "$codex_home".symlink.backup.* >/dev/null 2>&1; then
    fail "No symlink backup should be created on idempotent re-run"
  fi
}

test_missing_base_fails() {
  local fixture_root fixture_repo codex_home output_file
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  codex_home="$fixture_root/home/.codex"
  output_file="$fixture_root/onboarding.log"
  mkdir -p "$(dirname "$codex_home")"

  if "$fixture_repo/scripts/onboarding.sh" "$codex_home" >"$output_file" 2>&1; then
    fail "Onboarding should fail when config.base.toml is missing"
  fi

  assert_file_contains "$output_file" 'ERROR: Missing required base config'
  [ ! -e "$fixture_repo/config.toml" ] || fail "config.toml should not be generated when base config is missing"
}

test_canonical_symlink_equivalence() {
  local fixture_root fixture_repo codex_home
  fixture_root="$(make_fixture)"
  fixture_repo="$fixture_root/repo"
  codex_home="$fixture_root/home/.codex"

  cat > "$fixture_repo/config.base.toml" <<'BASE'
model = "gpt-5"
BASE

  mkdir -p "$(dirname "$codex_home")"
  ln -s "../repo" "$codex_home"

  "$fixture_repo/scripts/onboarding.sh" "$codex_home" >/dev/null

  if ls "$codex_home".symlink.backup.* >/dev/null 2>&1; then
    fail "Canonical-equivalent symlink should not be relinked"
  fi

  [ -L "$codex_home" ] || fail "Symlink should still exist"
}

test_non_destructive_and_idempotent
printf 'ok - non-destructive and idempotent\n'

test_missing_base_fails
printf 'ok - missing base fails\n'

test_canonical_symlink_equivalence
printf 'ok - canonical symlink equivalence\n'

printf 'All onboarding tests passed.\n'
