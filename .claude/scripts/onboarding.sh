#!/usr/bin/env bash
set -euo pipefail

repo_root="${ONBOARDING_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
claude_repo_home="${repo_root}/.claude"

source "${repo_root}/scripts/onboarding-lib.sh"

require_onboarding_env \
  ONBOARDING_TIMESTAMP \
  ONBOARDING_CLAUDE_HOME

timestamp="${ONBOARDING_TIMESTAMP}"
claude_home="${ONBOARDING_CLAUDE_HOME}"

ensure_path_symlink "$claude_home" "$claude_repo_home" "Claude home" "$timestamp"
