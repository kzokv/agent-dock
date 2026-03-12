#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CODEX_ROOT="${REPO_ROOT}/.codex"
INSTALLER="${CODEX_ROOT}/skills/.system/skill-installer/scripts/install-skill-from-github.py"
SOURCE_DEST="${CODEX_ROOT}/skills"
MATRIX_PARSER="${CODEX_ROOT}/scripts/role_skill_matrix.py"

if [[ ! -f "${INSTALLER}" ]]; then
  echo "Installer not found: ${INSTALLER}" >&2
  exit 1
fi

mkdir -p "${SOURCE_DEST}"

if [[ ! -f "${MATRIX_PARSER}" ]]; then
  echo "Matrix parser not found: ${MATRIX_PARSER}" >&2
  exit 1
fi

mapfile -t REQUIRED_SKILLS < <(python3 "${MATRIX_PARSER}" --set required)

MISSING_PATHS=()
for skill in "${REQUIRED_SKILLS[@]}"; do
  if [[ -d "${SOURCE_DEST}/${skill}" ]]; then
    echo "Skip ${skill}: already installed"
    continue
  fi
  MISSING_PATHS+=("skills/.curated/${skill}")
done

if [[ "${#MISSING_PATHS[@]}" -eq 0 ]]; then
  echo "All required skills are already installed."
  exit 0
fi

echo "Installing missing required skills into ${SOURCE_DEST}..."
python3 "${INSTALLER}" \
  --repo openai/skills \
  --dest "${SOURCE_DEST}" \
  --path "${MISSING_PATHS[@]}"

echo "Done. Rerun onboarding to refresh the shared skill symlinks."
