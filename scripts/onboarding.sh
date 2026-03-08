#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_home_override=""
cursor_home_override=""
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
  maintain ~/.agents/skills symlink, expose tracked shared prompts at ~/.codex/prompts via
  the repo symlink, populate ~/.claude/skills with per-skill symlinks,
  regenerate config.toml from config.base.toml + config.local.toml,
  copy the Cursor role-loader agent into ~/.cursor/agents (or override target),
  bootstrap GitHub CLI auth, install the Codex CLI when missing, and install a codex-net
  launcher for network-enabled sessions.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help             Show this help message and exit (optional)
  --codex-home PATH      Override the ~/.codex symlink path (optional, default: ~/.codex)
  --cursor-home PATH     Override the Cursor home directory for the role-loader installation (optional, default: ~/.cursor; use target-user writable paths)
  --skip-gh-auth         Skip GitHub auth bootstrap and secret-file write (optional, default: off)
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
    --cursor-home)
      shift
      if [ $# -eq 0 ]; then
        die_with_help "--cursor-home requires a PATH"
      fi
      cursor_home_override="$1"
      shift
      ;;
    --cursor-home=*)
      cursor_home_override="${1#*=}"
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
codex_prompts_dir="$codex_home/prompts"
cursor_home="${cursor_home_override:-$HOME/.cursor}"
config_base="$repo_root/config.base.toml"
config_local="$repo_root/config.local.toml"
config_file="$repo_root/config.toml"
timestamp="$(date +%Y%m%d%H%M%S)"
project_header="[projects.\"$repo_root\"]"
agents_home="$HOME/.agents"
agents_skills_link="$agents_home/skills"
codex_skills_dir="$codex_home/agents/skills"
legacy_skills_dir="$codex_home/skills"
claude_home="$HOME/.claude"
claude_skills_dir="$claude_home/skills"
codex_cli_path=""
launcher_bin_dir=""
codex_net_launcher=""
cursor_agents_dir="$cursor_home/agents"
cursor_role_loader_src="$repo_root/.platforms/cursor/agents/codex-role-loader.md"
cursor_role_loader_dst="$cursor_agents_dir/codex-role-loader.md"

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

path_contains_dir() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_launcher_bin_dir() {
  if [ -n "${XDG_BIN_HOME:-}" ]; then
    printf '%s\n' "$XDG_BIN_HOME"
    return 0
  fi

  local platform
  platform="$(uname -s 2>/dev/null || printf 'unknown')"

  if [ "$platform" = "Darwin" ]; then
    local candidate
    for candidate in "$HOME/bin" "$HOME/.local/bin"; do
      if path_contains_dir "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done

    for candidate in /opt/homebrew/bin /usr/local/bin; do
      if path_contains_dir "$candidate" && [ -d "$candidate" ] && [ -w "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done

    printf '%s\n' "$HOME/bin"
    return 0
  fi

  printf '%s\n' "$HOME/.local/bin"
}

resolve_npm_global_bin_dir() {
  local npm_prefix
  npm_prefix="$(npm prefix -g 2>/dev/null || true)"
  [ -n "$npm_prefix" ] || return 1
  printf '%s/bin\n' "$npm_prefix"
}

resolve_codex_cli_path() {
  local resolved_path npm_bin_dir
  resolved_path="$(command -v codex 2>/dev/null || true)"
  if [ -n "$resolved_path" ]; then
    printf '%s\n' "$resolved_path"
    return 0
  fi

  npm_bin_dir="$(resolve_npm_global_bin_dir 2>/dev/null || true)"
  if [ -n "$npm_bin_dir" ] && [ -x "$npm_bin_dir/codex" ]; then
    printf '%s\n' "$npm_bin_dir/codex"
    return 0
  fi

  return 1
}

ensure_codex_cli() {
  codex_cli_path="$(resolve_codex_cli_path 2>/dev/null || true)"
  if [ -n "$codex_cli_path" ]; then
    log "Codex CLI already available: $codex_cli_path"
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    die "Codex CLI ('codex') is required. Install npm and rerun onboarding, or install Codex manually with: npm install -g @openai/codex"
  fi

  log "Codex CLI ('codex') not found; installing with npm install -g @openai/codex"
  npm install -g @openai/codex
  hash -r 2>/dev/null || true

  codex_cli_path="$(resolve_codex_cli_path 2>/dev/null || true)"
  if [ -z "$codex_cli_path" ]; then
    die "Codex CLI install completed but 'codex' is still not resolvable. Ensure your npm global bin directory is available, then rerun onboarding."
  fi

  log "Installed Codex CLI: $codex_cli_path"
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
  launcher_bin_dir="$(resolve_launcher_bin_dir)"
  codex_net_launcher="$launcher_bin_dir/codex-net"
  launcher_content="$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec "$codex_cli_path" --sandbox danger-full-access -a never --search -c shell_environment_policy.inherit=all
EOF
)"

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

ensure_claude_skills_links() {
  mkdir -p "$claude_skills_dir"

  shopt -s nullglob
  local skill_path skill_name link_path rel_target
  for skill_path in "$codex_skills_dir"/*/; do
    skill_name="$(basename "$skill_path")"
    link_path="$claude_skills_dir/$skill_name"
    rel_target="../../.agents/skills/$skill_name"

    if [ -L "$link_path" ]; then
      local current_target
      current_target="$(readlink "$link_path")"
      if [ "$current_target" = "$rel_target" ]; then
        log "Claude skill symlink already correct: $link_path -> $current_target"
        continue
      fi
      log "Claude skill symlink points elsewhere; replacing: $link_path"
      rm "$link_path"
    elif [ -e "$link_path" ]; then
      local backup_path
      backup_path="${link_path}.backup.$timestamp"
      log "Found existing path at $link_path; backing it up to: $backup_path"
      mv "$link_path" "$backup_path"
    fi

    log "Creating Claude skill symlink: $link_path -> $rel_target"
    ln -s "$rel_target" "$link_path"
  done
  shopt -u nullglob
}

install_cursor_role_loader() {
  if [ ! -f "$cursor_role_loader_src" ]; then
    die "Cursor role-loader source not found: $cursor_role_loader_src"
  fi

  mkdir -p "$cursor_agents_dir"

  if [ -d "$cursor_role_loader_dst" ]; then
    die "Cursor role-loader destination exists as a directory; remove or move it: $cursor_role_loader_dst"
  fi

  if [ -L "$cursor_role_loader_dst" ]; then
    log "Removing stale symlink at Cursor role-loader destination: $cursor_role_loader_dst"
    rm "$cursor_role_loader_dst"
  fi

  local tmp_loader
  tmp_loader="$(mktemp "$cursor_agents_dir/.codex-role-loader.XXXXXX")"
  cp "$cursor_role_loader_src" "$tmp_loader"
  chmod 644 "$tmp_loader"
  mv "$tmp_loader" "$cursor_role_loader_dst"
  log "Installed Cursor role-loader: $cursor_role_loader_dst"
}

log "Starting onboarding"
log "Repo root: $repo_root"
log "Target symlink: $codex_home -> $repo_root"
log "Shared prompts path: $codex_prompts_dir"
log "Cursor home: $cursor_home"

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

if [ -d "$codex_prompts_dir" ]; then
  log "Tracked shared prompts available via: $codex_prompts_dir"
fi

migrate_legacy_skills
ensure_agents_skills_link
ensure_claude_skills_links
install_cursor_role_loader

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

ensure_codex_cli
install_codex_net_launcher

log "Onboarding complete"
