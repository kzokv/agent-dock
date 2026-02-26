#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_home_override=""
SCRIPT_PATH="${0##*/}"

log() {
  # Helper narrates the onboarding workflow (link creation + config rebuild).
  printf '[onboarding] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit 1
}

ensure_trailing_newline() {
  local file="$1"
  [ -s "$file" ] || return 0
  # Command substitution strips trailing newlines, so an empty string means the
  # file already ends with '\n'.
  if [ "$(tail -c 1 "$file" 2>/dev/null || true)" != "" ]; then
    printf '\n' >> "$file"
  fi
}

print_help() {
  cat <<EOF
Description:
  Link this repo to ~/.codex (or override target) and regenerate config.toml from config.base.toml + config.local.toml.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help          Show this help message and exit (optional)
  --codex-home PATH   Override the ~/.codex symlink path (optional, default: ~/.codex)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --codex-home)
      shift
      if [ $# -eq 0 ]; then
        die "--codex-home requires a PATH"
        print_help
        exit 1
      fi
      codex_home_override="$1"
      shift
      ;;
    --codex-home=*)
      codex_home_override="${1#*=}"
      shift
      ;;
    -*)
      die "Unknown flag $1"
      print_help
      exit 1
      ;;
    *)
      if [ -n "$codex_home_override" ]; then
        die "Multiple positional arguments not supported ($1)"
        print_help
        exit 1
      fi
      codex_home_override="$1"
      shift
      ;;
  esac
done

codex_home="${codex_home_override:-$HOME/.codex}"
config_base="$repo_root/config.base.toml"
config_local="$repo_root/config.local.toml"
config_file="$repo_root/config.toml"
timestamp="$(date +%Y%m%d%H%M%S)"
project_header="[projects.\"$repo_root\"]"

# canonical_path normalizes symlink targets into absolute paths for reliable comparisons.
canonical_path() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
  elif [ -e "$path" ]; then
    local path_dir path_base
    path_dir="$(dirname "$path")"
    path_base="$(basename "$path")"
    (cd "$path_dir" && printf '%s/%s\n' "$(pwd -P)" "$path_base")
  else
    return 1
  fi
}

# resolve_link_target_path converts the symlink's raw link into an absolute path for comparison.
resolve_link_target_path() {
  local link_path="$1"
  local raw_target
  raw_target="$(readlink "$link_path")"
  if [[ "$raw_target" = /* ]]; then
    printf '%s\n' "$raw_target"
  else
    printf '%s/%s\n' "$(dirname "$link_path")" "$raw_target"
  fi
}

# ensure_repo_trust_block centralizes the project trust block upsert, so the config stays consistent.
ensure_repo_trust_block() {
  local tmp_local
  tmp_local="$(mktemp)"
  if [ -f "$config_local" ]; then
    awk -v section_header="$project_header" '
      $0 == section_header { skip = 1; next }
      /^\[.*\]/ && skip == 1 { skip = 0 }
      skip == 0 { print }
    ' "$config_local" > "$tmp_local"
  else
    : > "$tmp_local"
  fi

  ensure_trailing_newline "$tmp_local"
  printf '%s\ntrust_level = "trusted"\n' "$project_header" >> "$tmp_local"
  mv "$tmp_local" "$config_local"
}

# generate_runtime_config merges base/local configs into the runtime file without duplicating sections.
generate_runtime_config() {
  local tmp_config
  tmp_config="$(mktemp)"
  cat "$config_base" > "$tmp_config"
  ensure_trailing_newline "$tmp_config"
  cat "$config_local" >> "$tmp_config"
  mv "$tmp_config" "$config_file"
}

log "Starting onboarding"
log "Repo root: $repo_root"
log "Target symlink: $codex_home -> $repo_root"
if [ ! -f "$config_base" ]; then
  die "Missing required base config: $config_base"
fi

if [ -L "$codex_home" ]; then
  current_target="$(readlink "$codex_home")"
  log "Found existing symlink: $codex_home -> $current_target"
  current_target_path="$(resolve_link_target_path "$codex_home")"
  current_target_canonical="$(canonical_path "$current_target_path" 2>/dev/null || true)"
  repo_root_canonical="$(canonical_path "$repo_root")"
  if [ -n "$current_target_canonical" ] && [ "$current_target_canonical" = "$repo_root_canonical" ]; then
    log "Symlink already points to this repo (canonical match); no symlink update needed"
  elif [ "$current_target" = "$repo_root" ]; then
    log "Symlink already points to this repo; no symlink update needed"
  else
    backup_path="${codex_home}.symlink.backup.$timestamp"
    log "Current symlink points elsewhere; backing it up to: $backup_path"
    mv "$codex_home" "$backup_path"
    log "Creating symlink: $codex_home -> $repo_root"
    ln -s "$repo_root" "$codex_home"
    log "Symlink created"
  fi
elif [ -e "$codex_home" ]; then
  backup_path="${codex_home}.backup.$timestamp"
  log "Found existing file/directory at $codex_home; backing it up to: $backup_path"
  mv "$codex_home" "$backup_path"
  log "Creating symlink: $codex_home -> $repo_root"
  ln -s "$repo_root" "$codex_home"
  log "Symlink created"
else
  log "No existing path at $codex_home; creating symlink"
  ln -s "$repo_root" "$codex_home"
  log "Symlink created"
fi

log "Upserting machine-local trust settings in: $config_local"
ensure_repo_trust_block
log "Wrote machine-local trust settings to: $config_local"

log "Generating runtime config from base + local: $config_base + $config_local -> $config_file"
generate_runtime_config
log "Generated runtime config: $config_file"

log "Onboarding complete"
