#!/usr/bin/env bash

onboarding_lib_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

ensure_trailing_newline() {
  local file="$1"
  [ -s "$file" ] || return 0
  if [ "$(tail -c 1 "$file" 2>/dev/null || true)" != "" ]; then
    printf '\n' >> "$file"
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

ensure_path_symlink() {
  local target_path="$1"
  local source_path="$2"
  local label="$3"
  local timestamp="$4"
  local current_target current_target_path current_target_canonical source_canonical backup_path

  mkdir -p "$(dirname "$target_path")"

  if [ -L "$target_path" ]; then
    current_target="$(readlink "$target_path")"
    current_target_path="$(resolve_link_target_path "$target_path")"
    current_target_canonical="$(canonical_path "$current_target_path" 2>/dev/null || true)"
    source_canonical="$(canonical_path "$source_path" 2>/dev/null || true)"
    if [ -n "$source_canonical" ] && [ "$current_target_canonical" = "$source_canonical" ]; then
      log "${label} symlink already correct: $target_path -> $current_target"
      return 0
    fi
    backup_path="${target_path}.symlink.backup.${timestamp}"
    log "${label} symlink points elsewhere; backing it up to: $backup_path"
    mv "$target_path" "$backup_path"
  elif [ -e "$target_path" ]; then
    backup_path="${target_path}.backup.${timestamp}"
    log "${label} path exists; backing it up to: $backup_path"
    mv "$target_path" "$backup_path"
  fi

  log "Creating ${label} symlink: $target_path -> $source_path"
  ln -s "$source_path" "$target_path"
}

ensure_directory_path() {
  local target_path="$1"
  local label="$2"
  local timestamp="$3"
  local backup_path

  if [ -d "$target_path" ] && [ ! -L "$target_path" ]; then
    log "${label} directory already present: $target_path"
    return 0
  fi

  if [ -L "$target_path" ]; then
    backup_path="${target_path}.symlink.backup.${timestamp}"
    log "${label} path is a symlink; backing it up to: $backup_path"
    mv "$target_path" "$backup_path"
  elif [ -e "$target_path" ]; then
    backup_path="${target_path}.backup.${timestamp}"
    log "${label} path exists; backing it up to: $backup_path"
    mv "$target_path" "$backup_path"
  fi

  log "Ensuring ${label} directory: $target_path"
  mkdir -p "$target_path"
}

remove_agents_skills_library() {
  local target_path="$1"
  local timestamp="$2"
  local backup_path

  if [ ! -e "$target_path" ] && [ ! -L "$target_path" ]; then
    return 0
  fi

  if [ -L "$target_path" ]; then
    log "Removing deprecated ~/.agents/skills-library symlink: $target_path"
    rm "$target_path"
    return 0
  fi

  if [ -d "$target_path" ] && [ -f "$target_path/.codex-library-skills" ]; then
    log "Removing deprecated managed ~/.agents/skills-library directory: $target_path"
    rm -rf "$target_path"
    return 0
  fi

  backup_path="${target_path}.backup.${timestamp}"
  log "Backing up deprecated ~/.agents/skills-library path to: $backup_path"
  mv "$target_path" "$backup_path"
}

prompt_agent_selection() {
  if [ "${ONBOARDING_FORCE_INTERACTIVE:-0}" != "1" ] && [ ! -t 0 ]; then
    printf 'all\n'
    return 0
  fi

  printf 'Choose agent home(s) to onboard:\n' >&2
  printf '  1. codex\n' >&2
  printf '  2. cursor\n' >&2
  printf '  3. claude\n' >&2
  printf '  4. all\n' >&2
  printf 'Selection (default: 4): ' >&2
  read -r response || true
  case "${response:-4}" in
    1|codex)
      printf 'codex\n'
      ;;
    2|cursor)
      printf 'cursor\n'
      ;;
    3|claude)
      printf 'claude\n'
      ;;
    4|all)
      printf 'all\n'
      ;;
    *)
      die "Unsupported agent selection: ${response}"
      ;;
  esac
}

ensure_gh_token_secret() {
  local codex_repo_home wrapper_script has_native_git

  codex_repo_home="${ONBOARDING_REPO_ROOT:-$onboarding_lib_repo_root}/.codex"

  if ! command -v gh >/dev/null 2>&1; then
    if command -v docker >/dev/null 2>&1; then
      log "GitHub CLI ('gh') not found but Docker is available."
      if [ -t 0 ]; then
        printf "Do you want to use the Docker-based gh fallback? [y/N] "
        read -r response || true
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
          wrapper_script="${codex_repo_home}/skills/git-gh-docker-fallback/scripts/enable_wrappers.sh"
          if [ -x "$wrapper_script" ]; then
            has_native_git=0
            if command -v git >/dev/null 2>&1; then
              has_native_git=1
            fi

            eval "$("$wrapper_script")"

            if [ "$has_native_git" -eq 1 ]; then
              unset -f git || true
            fi
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

ensure_codex_cli() {
  local codex_cli_path
  codex_cli_path="$(resolve_codex_cli_path 2>/dev/null || true)"
  if [ -n "$codex_cli_path" ]; then
    log "Codex CLI already available: $codex_cli_path"
    printf '%s\n' "$codex_cli_path"
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
  printf '%s\n' "$codex_cli_path"
}

install_codex_net_launcher() {
  local codex_cli_path="$1"
  local launcher_bin_dir codex_net_launcher launcher_content

  launcher_bin_dir="$(resolve_launcher_bin_dir)"
  codex_net_launcher="$launcher_bin_dir/codex-net"
  launcher_content="$(cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
default_codex_path="$codex_cli_path"
resolved_codex_path="\$(command -v codex 2>/dev/null || true)"

if [ -z "\$resolved_codex_path" ] && [ -x "\$default_codex_path" ]; then
  resolved_codex_path="\$default_codex_path"
fi

if [ -z "\$resolved_codex_path" ]; then
  printf 'codex-net: unable to locate the Codex CLI. Rerun onboarding or install codex.\\n' >&2
  exit 1
fi

exec "\$resolved_codex_path" --sandbox danger-full-access -a never --search -c shell_environment_policy.inherit=all "\$@"
EOF
)"

  mkdir -p "$launcher_bin_dir"
  write_executable_file_atomic "$codex_net_launcher" "$launcher_content"
  log "Installed Codex network-enabled launcher: $codex_net_launcher"

  if ! path_contains_dir "$launcher_bin_dir"; then
    log "Launcher directory is not on PATH. Add this to your shell profile:"
    log "  export PATH=\"$launcher_bin_dir:\$PATH\""
  fi
}

ensure_repo_trust_block() {
  local config_local="$1"
  local project_header="$2"
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
  local config_base="$1"
  local config_local="$2"
  local config_file="$3"
  local tmp_config

  tmp_config="$(mktemp)"
  cat "$config_base" > "$tmp_config"
  if [ -f "$config_local" ]; then
    ensure_trailing_newline "$tmp_config"
    cat "$config_local" >> "$tmp_config"
  fi
  mv "$tmp_config" "$config_file"
}

generate_agent_role_configs() {
  local output_dir="$1"
  local render_agent_configs_script="${ONBOARDING_REPO_ROOT:-$onboarding_lib_repo_root}/.codex/scripts/render-agent-configs.py"

  if ! command -v python3 >/dev/null 2>&1; then
    die "python3 is required to generate role config files"
  fi

  [ -f "$render_agent_configs_script" ] || die "Missing role-config generator: $render_agent_configs_script"

  log "Generating role config files in: $output_dir"
  python3 "$render_agent_configs_script" --output-dir "$output_dir" --default-model "gpt-5.4" --default-reasoning "medium"
}

ensure_shared_onboarding_paths() {
  local timestamp="$1"
  local codex_home="$2"
  local agents_home="$3"
  local agents_skills_dir="$4"
  local agents_skills_library_dir="$5"
  local repo_root="${ONBOARDING_REPO_ROOT:-$onboarding_lib_repo_root}"

  ensure_path_symlink "$codex_home" "${repo_root}/.codex" "Codex home" "$timestamp"
  mkdir -p "$agents_home"
  ensure_path_symlink "$agents_skills_dir" "${codex_home}/skills" "Shared agent skills" "$timestamp"
  remove_agents_skills_library "$agents_skills_library_dir" "$timestamp"
}

require_onboarding_env() {
  local missing_var
  for missing_var in "$@"; do
    if [ -z "${!missing_var:-}" ]; then
      die "Missing required onboarding env: ${missing_var}"
    fi
  done
}
