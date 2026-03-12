#!/usr/bin/env bash
set -euo pipefail

repo_root="${ONBOARDING_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cursor_repo_home="${repo_root}/.cursor"

source "${repo_root}/scripts/onboarding-lib.sh"

require_onboarding_env \
  ONBOARDING_TIMESTAMP \
  ONBOARDING_CURSOR_HOME \
  ONBOARDING_CODEX_HOME

timestamp="${ONBOARDING_TIMESTAMP}"
cursor_home="${ONBOARDING_CURSOR_HOME}"
codex_home="${ONBOARDING_CODEX_HOME}"

ensure_directory_path "$cursor_home" "Cursor home" "$timestamp"
ensure_path_symlink "$cursor_home/agents" "$cursor_repo_home/agents" "Cursor agents" "$timestamp"
ensure_path_symlink "$cursor_home/skills" "${codex_home}/skills" "Cursor skills" "$timestamp"
