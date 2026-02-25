#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_home="${1:-$HOME/.codex}"

if [ -L "$codex_home" ]; then
  current_target="$(readlink "$codex_home")"
  if [ "$current_target" = "$repo_root" ]; then
    echo "Already linked: $codex_home -> $repo_root"
    exit 0
  fi
  backup_path="${codex_home}.symlink.backup.$(date +%Y%m%d%H%M%S)"
  mv "$codex_home" "$backup_path"
  echo "Moved existing symlink to: $backup_path"
elif [ -e "$codex_home" ]; then
  backup_path="${codex_home}.backup.$(date +%Y%m%d%H%M%S)"
  mv "$codex_home" "$backup_path"
  echo "Backed up existing directory/file to: $backup_path"
fi

ln -s "$repo_root" "$codex_home"
echo "Linked: $codex_home -> $repo_root"
