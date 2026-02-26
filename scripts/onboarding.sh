#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_home_override=""
skip_gh_auth=0
SCRIPT_PATH="${0##*/}"

log() {
  printf '[onboarding] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit 1
}

die_with_help() {
  log "ERROR: $1"
  print_help
  exit 1
}

ensure_trailing_newline() {
  local file="$1"
  [ -s "$file" ] || return 0
  if [ "$(tail -c 1 "$file" 2>/dev/null || true)" != "" ]; then
    printf '\n' >> "$file"
  fi
}

print_help() {
  cat <<EOF_HELP
Description:
  Link this repo to ~/.codex (or override target), migrate user skills to ~/.codex/agents/skills,
  maintain ~/.agents/skills symlink, regenerate config.toml from config.base.toml + config.local.toml,
  bootstrap GitHub CLI auth, and install a codex-net launcher for network-enabled sessions.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help          Show this help message and exit (optional)
  --codex-home PATH   Override the ~/.codex symlink path (optional, default: ~/.codex)
  --skip-gh-auth      Skip GitHub auth bootstrap and secret-file write (optional, default: off)
EOF_HELP
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
        die_with_help "--codex-home requires a PATH"
      fi
      codex_home_override="$1"
      shift
      ;;
    --codex-home=*)
      codex_home_override="${1#*=}"
      shift
      ;;
    --skip-gh-auth)
      skip_gh_auth=1
      shift
      ;;
    -*)
      die_with_help "Unknown flag $1"
      ;;
    *)
      if [ -n "$codex_home_override" ]; then
        die_with_help "Multiple positional arguments not supported ($1)"
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
agents_home="$HOME/.agents"
agents_skills_link="$agents_home/skills"
codex_skills_dir="$codex_home/agents/skills"
legacy_skills_dir="$codex_home/skills"
launcher_bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
codex_net_launcher="$launcher_bin_dir/codex-net"

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

generate_runtime_config() {
  local tmp_config
  tmp_config="$(mktemp)"
  cat "$config_base" > "$tmp_config"
  ensure_trailing_newline "$tmp_config"
  cat "$config_local" >> "$tmp_config"
  mv "$tmp_config" "$config_file"
}

ensure_dir_mode() {
  local dir="$1"
  local mode="$2"
  mkdir -p "$dir"
  chmod "$mode" "$dir"
}

write_executable_file_atomic() {
  local target_path="$1"
  local content="$2"
  local tmp_file

  tmp_file="$(mktemp)"
  printf '%s\n' "$content" > "$tmp_file"
  chmod 755 "$tmp_file"
  mv "$tmp_file" "$target_path"
  chmod 755 "$target_path"
}

install_codex_net_launcher() {
  local launcher_content
  launcher_content='#!/usr/bin/env bash
set -euo pipefail
exec codex --sandbox danger-full-access -a never --search -c shell_environment_policy.inherit=all'

  mkdir -p "$launcher_bin_dir"
  write_executable_file_atomic "$codex_net_launcher" "$launcher_content"
  log "Installed Codex network-enabled launcher: $codex_net_launcher"

  case ":$PATH:" in
    *":$launcher_bin_dir:"*) ;;
    *)
      log "Launcher directory is not on PATH. Add this to your shell profile:"
      log "  export PATH=\"$launcher_bin_dir:\$PATH\""
      ;;
  esac
}

ensure_gh_token_secret() {
  if ! command -v gh >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
      log "GitHub CLI ('gh') not found but Docker is available."
      if [ -t 0 ]; then
        printf "Do you want to use the Docker-based gh fallback? [y/N] "
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
          local wrapper_script="$repo_root/agents/skills/git-gh-docker-fallback/scripts/enable_wrappers.sh"
          if [ -x "$wrapper_script" ]; then
            local has_native_git=0
            if command -v git >/dev/null 2>&1; then has_native_git=1; fi

            eval "$("$wrapper_script")"

            if [ "$has_native_git" -eq 1 ]; then unset -f git || true; fi
            log "Enabled Docker-based gh wrapper"
          else
            die "Wrapper script not found or not executable: $wrapper_script"
          fi
        else
          die "GitHub CLI ('gh') is required. Install gh or rerun with --skip-gh-auth."
        fi
      else
        die "GitHub CLI ('gh') is required (non-interactive). Install gh or rerun with --skip-gh-auth."
      fi
    else
      die "GitHub CLI ('gh') is required for onboarding auth bootstrap. Install gh or rerun with --skip-gh-auth."
    fi
  fi

  if gh auth status >/dev/null 2>&1; then
    log "GitHub CLI auth is already valid"
  else
    log "GitHub CLI auth is not valid; running: gh auth login -h github.com"
    gh auth login -h github.com
    gh auth status >/dev/null 2>&1 || die "GitHub CLI auth remains invalid after login"
  fi
}

migrate_legacy_skills() {
  if [ ! -d "$legacy_skills_dir" ]; then
    return 0
  fi

  local legacy_canonical repo_legacy_canonical
  legacy_canonical="$(canonical_path "$legacy_skills_dir" 2>/dev/null || true)"
  repo_legacy_canonical="$(canonical_path "$repo_root/skills" 2>/dev/null || true)"
  if [ -n "$legacy_canonical" ] && [ -n "$repo_legacy_canonical" ] && [ "$legacy_canonical" = "$repo_legacy_canonical" ]; then
    log "Legacy skills path resolves to repo-managed skills; skipping migration: $legacy_skills_dir"
    return 0
  fi

  log "Found legacy skills path: $legacy_skills_dir"
  mkdir -p "$(dirname "$codex_skills_dir")"

  if [ ! -e "$codex_skills_dir" ]; then
    log "Migrating legacy skills to: $codex_skills_dir"
    mv "$legacy_skills_dir" "$codex_skills_dir"
    return 0
  fi

  if [ ! -d "$codex_skills_dir" ]; then
    die "Target skills path exists but is not a directory: $codex_skills_dir"
  fi

  log "Merging legacy skills into existing: $codex_skills_dir"
  shopt -s dotglob nullglob
  local item base
  for item in "$legacy_skills_dir"/*; do
    base="$(basename "$item")"
    if [ -e "$codex_skills_dir/$base" ]; then
      die "Cannot migrate legacy skill '$base': destination already exists"
    fi
    mv "$item" "$codex_skills_dir/"
  done
  shopt -u dotglob nullglob
  rmdir "$legacy_skills_dir"
}

ensure_agents_skills_link() {
  mkdir -p "$agents_home"

  if [ ! -d "$codex_skills_dir" ]; then
    mkdir -p "$codex_skills_dir"
  fi

  local target_canonical
  target_canonical="$(canonical_path "$codex_skills_dir")"

  if [ -L "$agents_skills_link" ]; then
    local current_target current_path current_canonical
    current_target="$(readlink "$agents_skills_link")"
    current_path="$(resolve_link_target_path "$agents_skills_link")"
    current_canonical="$(canonical_path "$current_path" 2>/dev/null || true)"
    if [ -n "$current_canonical" ] && [ "$current_canonical" = "$target_canonical" ]; then
      log "User skills symlink already correct: $agents_skills_link -> $current_target"
      return 0
    fi

    local backup_path
    backup_path="${agents_skills_link}.symlink.backup.$timestamp"
    log "User skills symlink points elsewhere; backing it up to: $backup_path"
    mv "$agents_skills_link" "$backup_path"
  elif [ -e "$agents_skills_link" ]; then
    local backup_path
    backup_path="${agents_skills_link}.backup.$timestamp"
    log "Found existing path at $agents_skills_link; backing it up to: $backup_path"
    mv "$agents_skills_link" "$backup_path"
  fi

  log "Creating user skills symlink: $agents_skills_link -> $codex_skills_dir"
  ln -s "$codex_skills_dir" "$agents_skills_link"
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
  fi
elif [ -e "$codex_home" ]; then
  backup_path="${codex_home}.backup.$timestamp"
  log "Found existing file/directory at $codex_home; backing it up to: $backup_path"
  mv "$codex_home" "$backup_path"
  log "Creating symlink: $codex_home -> $repo_root"
  ln -s "$repo_root" "$codex_home"
else
  log "No existing path at $codex_home; creating symlink"
  ln -s "$repo_root" "$codex_home"
fi

migrate_legacy_skills
ensure_agents_skills_link

log "Upserting machine-local trust settings in: $config_local"
ensure_repo_trust_block
log "Wrote machine-local trust settings to: $config_local"

log "Generating runtime config from base + local: $config_base + $config_local -> $config_file"
generate_runtime_config
log "Generated runtime config: $config_file"

if [ "$skip_gh_auth" = "1" ]; then
  log "Skipping GitHub auth bootstrap (--skip-gh-auth)"
else
  log "Bootstrapping GitHub auth and agent token secret"
  ensure_gh_token_secret
fi

install_codex_net_launcher

log "Onboarding complete"
