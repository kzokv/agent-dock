#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALLER="${REPO_ROOT}/skills/.system/skill-installer/scripts/install-skill-from-github.py"
DEST="${REPO_ROOT}/skills"

if [[ ! -f "${INSTALLER}" ]]; then
  echo "Installer not found: ${INSTALLER}" >&2
  exit 1
fi

# Required curated skills across canonical roles.
# External optional accelerators are intentionally excluded.
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
  if [[ -d "${DEST}/${skill}" ]]; then
    echo "Skip ${skill}: already installed"
    continue
  fi
  MISSING_PATHS+=("skills/.curated/${skill}")
done

if [[ "${#MISSING_PATHS[@]}" -eq 0 ]]; then
  echo "All required skills are already installed."
  exit 0
fi

echo "Installing missing required skills into ${DEST}..."
python3 "${INSTALLER}" \
  --repo openai/skills \
  --dest "${DEST}" \
  --path "${MISSING_PATHS[@]}"

echo "Done. Restart Codex to pick up new skills."
