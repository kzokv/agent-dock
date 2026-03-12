#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CODEX_ROOT="${REPO_ROOT}/.codex"
MATRIX_PARSER="${CODEX_ROOT}/scripts/role_skill_matrix.py"
SCRIPT_PATH="${0##*/}"

print_help() {
  cat <<EOF
Description:
  Verify that all required skills from .codex/agents/skills-matrix.md resolve in the local nested skill catalog.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help          Show this help message and exit (optional)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      printf 'ERROR: Unknown flag %s\n' "$1" >&2
      print_help
      exit 1
      ;;
  esac
done

if [[ ! -f "${MATRIX_PARSER}" ]]; then
  echo "Matrix parser not found: ${MATRIX_PARSER}" >&2
  exit 1
fi

mapfile -t REQUIRED_SKILLS < <(python3 "${MATRIX_PARSER}" --set required)

if [[ "${#REQUIRED_SKILLS[@]}" -eq 0 ]]; then
  echo "No required skills are defined in the skills matrix."
  exit 0
fi

set +e
VALIDATION_OUTPUT="$(python3 "${MATRIX_PARSER}" --set required --validate-local-skills 2>&1)"
VALIDATION_STATUS=$?
set -e

if [[ "${VALIDATION_STATUS}" -eq 0 ]]; then
  echo "All required skills are already installed."
  exit 0
fi

echo "Required skill baseline is incomplete." >&2
echo "${VALIDATION_OUTPUT}" >&2
echo >&2
echo "This repo now resolves required skills from the nested .codex/skills catalog." >&2
echo "Add the missing local skills or update .codex/agents/skills-matrix.md so it only references shipped skills." >&2
exit 1
