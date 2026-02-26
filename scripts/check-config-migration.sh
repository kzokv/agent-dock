#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
SCRIPT_PATH="${0##*/}"

print_help() {
  cat <<EOF
Description:
  Sanity-check config migration hygiene (tracked base config + ignored runtime files).

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help          Show this help message and exit (optional)
EOF
}

log() {
  # Helper narrates the migration audit, ensuring the script’s intent (tracked base, ignored runtime) is visible for each check.
  printf '[check-config-migration] %s\n' "$1"
}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

die_with_help() {
  printf 'ERROR: %s\n' "$1" >&2
  print_help
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

need_cmd git

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -*|*)
      die_with_help "Unknown flag $1"
      ;;
  esac
done

errors=0

assert_tracked() {
  local file="$1"
  local message="$2"
  if ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    log "ERROR: $message ($file missing)"
    errors=1
  fi
}

assert_untracked() {
  local file="$1"
  local message="$2"
  if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    log "ERROR: $message ($file tracked)"
    errors=1
  fi
}

assert_ignored() {
  local file="$1"
  local message="$2"
  if ! git check-ignore -q "$file"; then
    log "ERROR: $message ($file not ignored)"
    errors=1
  fi
}

assert_tracked config.base.toml "config.base.toml must be tracked"
assert_untracked config.toml "config.toml must not be tracked; keep it generated and ignored"
assert_untracked config.local.toml "config.local.toml must not be tracked; keep it machine-local and ignored"
assert_ignored config.toml "config.toml should be ignored in .gitignore"
assert_ignored config.local.toml "config.local.toml should be ignored in .gitignore"

if [ "$errors" -ne 0 ]; then
  log "FAILED: config migration hygiene checks failed."
  exit 1
fi

log "OK: tracked/ignored config files are in the expected migration-safe state."
