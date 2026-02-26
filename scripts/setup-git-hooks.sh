#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/setup-git-hooks.sh

Configures this repository to use .githooks as core.hooksPath.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks_dir="${repo_root}/.githooks"

if [[ ! -d "${hooks_dir}" ]]; then
  echo "Hooks directory missing: ${hooks_dir}" >&2
  exit 1
fi

if [[ ! -x "${hooks_dir}/commit-msg" ]]; then
  echo "commit-msg hook is missing or not executable: ${hooks_dir}/commit-msg" >&2
  exit 1
fi

git -C "${repo_root}" config core.hooksPath .githooks
echo "Configured git hooks path: .githooks"
echo "commit-msg enforcement is now active for this repository."
