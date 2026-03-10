#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALLER="${REPO_ROOT}/skills/.system/skill-installer/scripts/install-skill-from-github.py"
SOURCE_DEST="${REPO_ROOT}/agents/skills"

if [[ ! -f "${INSTALLER}" ]]; then
  echo "Installer not found: ${INSTALLER}" >&2
  exit 1
fi

mkdir -p "${SOURCE_DEST}"

# Required curated skills across canonical roles.
# Optional external accelerators are intentionally excluded.
REQUIRED_SKILLS=(
  openai-docs
  security-best-practices
  security-threat-model
  security-ownership-map
  gh-fix-ci
  gh-address-comments
  playwright
  screenshot
  figma-implement-design
  sentry
  spreadsheet
  jupyter-notebook
  doc
  pdf
)

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

echo "Done. Rerun onboarding to rebuild \$HOME/.agents/skills and \$HOME/.agents/skills-library."
