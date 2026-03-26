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

  # Prefer user-local directories that are already in PATH
  local candidate
  for candidate in "$HOME/.local/bin" "$HOME/bin"; do
    if path_contains_dir "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  # Default to ~/.local/bin (create + warn if not in PATH)
  local default_dir="$HOME/.local/bin"
  mkdir -p "$default_dir"
  if ! path_contains_dir "$default_dir"; then
    log "WARNING: $default_dir is not in PATH. Add it to your shell profile."
  fi
  printf '%s\n' "$default_dir"
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

# Emit the shared flag-parsing / interactive-prompt / worktree-picker scaffold
# used by both claude-dev and codex-net launchers.
# Args: cli_name env_prefix default_session cli_args_var cli_display_name
_generate_launcher_body() {
  local cli_name="$1"
  local env_prefix="$2"
  local default_session="$3"
  local cli_args_var="$4"
  local cli_display_name="$5"
  cat <<GENEOF

SCRIPT_PATH="\${0##*/}"

print_help() {
  cat <<EOF
Description:
  Interactive launcher for ${cli_display_name} with tmux session management and
  git worktree selection.

Usage: \${SCRIPT_PATH} [OPTIONS] [-- ARGS...]

Options:
  -h, --help              Show this help message and exit (optional)
  --no-tmux               Skip tmux session management (optional, default: off)
  --worktree PATH         Use or create a worktree at PATH (optional)
  --session NAME          Tmux session name (optional, default: ${default_session})
  --                      Forward remaining arguments to ${cli_display_name}

Environment:
  ${env_prefix}_NO_TMUX=1    Equivalent to --no-tmux
  ${env_prefix}_WORKTREE     Equivalent to --worktree
  ${env_prefix}_TMUX_SESSION Equivalent to --session
EOF
}

# ── Section 2: Parse launcher flags ───────────────────────────────────
use_tmux=1
worktree_path="\${${env_prefix}_WORKTREE:-}"
session_name="\${${env_prefix}_TMUX_SESSION:-${default_session}}"
${cli_args_var}=()
[[ "\${${env_prefix}_NO_TMUX:-0}" = "1" ]] && use_tmux=0

while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -h|--help)   print_help; exit 0 ;;
    --no-tmux)   use_tmux=0; shift ;;
    --worktree)  worktree_path="\${2:?${cli_name}: --worktree requires a path}"; shift 2 ;;
    --session)   session_name="\${2:?${cli_name}: --session requires a name}"; shift 2 ;;
    --)          shift; ${cli_args_var}+=("\$@"); break ;;
    *)           ${cli_args_var}+=("\$1"); shift ;;
  esac
done

# Helper: true when we should show interactive prompts
_interactive() {
  [[ -t 0 && \${#${cli_args_var}[@]} -eq 0 ]]
}

# Resolve worktree base directory (.worktrees/ relative to repo root)
worktree_base=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  worktree_base="\$(git rev-parse --show-toplevel)/.worktrees"
fi

# Resolve relative --worktree values against the worktree base
if [[ -n "\$worktree_path" && "\$worktree_path" != /* && -n "\$worktree_base" ]]; then
  worktree_path="\$worktree_base/\$worktree_path"
fi

_worktree_created=0

# Create worktree if it does not exist yet (auto-create from HEAD)
_ensure_worktree() {
  local wt_dir="\$1"
  if [[ -d "\$wt_dir" ]]; then
    _worktree_created=0
    return 0
  fi
  _worktree_created=1
  local branch_name
  branch_name="\$(basename "\$wt_dir")"
  mkdir -p "\$(dirname "\$wt_dir")"
  if git show-ref --verify "refs/heads/\$branch_name" &>/dev/null; then
    # Branch exists (likely leftover from a removed worktree).
    # Reset it to current HEAD so the worktree gets the latest code.
    git branch -f "\$branch_name" HEAD
    git worktree add "\$wt_dir" "\$branch_name"
  else
    git worktree add -b "\$branch_name" "\$wt_dir" HEAD
  fi
}

# ── Section 3: Interactive tmux prompt ────────────────────────────────
if [[ "\$use_tmux" = "1" ]] && _interactive && [[ -z "\$worktree_path" ]]; then
  read -r -p "Use tmux session? [Y/n] " tmux_ans
  [[ "\$tmux_ans" =~ ^[Nn] ]] && use_tmux=0
  if [[ "\$use_tmux" = "1" ]]; then
    read -r -p "Session name (default: \$session_name): " sn_ans
    [[ -n "\$sn_ans" ]] && session_name="\$sn_ans"
  fi
fi

# ── Section 4: Interactive worktree picker ────────────────────────────
# Shows worktrees under .worktrees/ and offers to create new ones
if [[ -z "\$worktree_path" && -n "\$worktree_base" ]] && _interactive; then
  wt_paths=()
  wt_branches=()
  wt_base_resolved="\$(mkdir -p "\$worktree_base" && cd "\$worktree_base" && pwd -P)"
  while IFS=\$'\\t' read -r wt_p wt_b; do
    resolved_wt="\$(cd "\$wt_p" 2>/dev/null && pwd -P)" || continue
    # Only include worktrees that live under .worktrees/
    [[ "\$resolved_wt" = "\$wt_base_resolved"/* ]] || continue
    wt_paths+=("\$wt_p")
    wt_branches+=("\${wt_b##refs/heads/}")
  done < <(
    git worktree list --porcelain | awk '
      /^worktree / { wt = substr(\$0, 10) }
      /^branch /   { br = substr(\$0, 8); print wt "\t" br }
    '
  )

  echo "Launch in a worktree?"
  echo "  1) current directory (normal)"
  for i in "\${!wt_paths[@]}"; do
    wt_resolved="\$(cd "\${wt_paths[\$i]}" 2>/dev/null && pwd -P)"
    wt_short="\${wt_resolved#"\$wt_base_resolved"/}"
    printf "  %d) %s  [%s]\n" "\$((i + 2))" "\$wt_short" "\${wt_branches[\$i]}"
  done
  new_opt=\$(( \${#wt_paths[@]} + 2 ))
  custom_opt=\$(( new_opt + 1 ))
  printf "  %d) create new worktree\n" "\$new_opt"
  printf "  %d) create new worktree (custom path)\n" "\$custom_opt"
  read -r -p "Pick [1]: " pick
  pick="\${pick:-1}"
  if [[ "\$pick" =~ ^[0-9]+\$ ]]; then
    if [[ "\$pick" -ge 2 && "\$pick" -le \$(( \${#wt_paths[@]} + 1 )) ]]; then
      worktree_path="\${wt_paths[\$(( pick - 2 ))]}"
    elif [[ "\$pick" -eq "\$new_opt" ]]; then
      read -r -p "Worktree name (becomes branch name): " wt_name
      [[ -n "\$wt_name" ]] && worktree_path="\$worktree_base/\$wt_name"
    elif [[ "\$pick" -eq "\$custom_opt" ]]; then
      read -r -p "Worktree name (becomes branch name): " wt_name
      if [[ -n "\$wt_name" ]]; then
        while true; do
          read -r -p "Absolute path: " custom_path
          [[ "\$custom_path" == /* ]] && break
          echo "Path must be absolute (start with /)"
        done
        worktree_path="\$custom_path"
      fi
    fi
  fi
fi
# ── Section 5: Worktree setup and post-create hook ────────────────────
if [[ -n "\$worktree_path" ]]; then
  _ensure_worktree "\$worktree_path"
  cd "\$worktree_path" || { printf '${cli_name}: cannot cd to worktree %s\n' "\$worktree_path" >&2; exit 1; }

  # Run post-create hook if worktree was just created
  # Hook lives at .hooks/ in the project repo
  # Both claude-dev and codex-net trigger the same hook for consistency.
  if [[ "\$_worktree_created" = "1" ]]; then
    main_root="\$(git worktree list --porcelain | head -1 | sed 's/^worktree //')"
    hook_file="\${main_root}/.hooks/post-worktree-create.sh"
    if [[ -f "\$hook_file" ]]; then
      printf '${cli_name}: running post-create hook…\n'
      export WORKTREE_PATH="\$worktree_path"
      export MAIN_ROOT="\$main_root"
      bash "\$hook_file"
    fi
  fi
fi
GENEOF
}

install_codex_net_launcher() {
  local codex_cli_path="$1"
  local launcher_bin_dir codex_net_launcher launcher_content

  launcher_bin_dir="$(resolve_launcher_bin_dir)"
  codex_net_launcher="$launcher_bin_dir/codex-net"
  launcher_content="$(cat <<'LAUNCHER_EOF'
#!/usr/bin/env bash
set -euo pipefail

# ── Section 1: Locate Codex CLI ───────────────────────────────────────
LAUNCHER_EOF
)"
  # Inject the literal codex_cli_path (expanded at install time)
  launcher_content+="
default_codex_path=\"$codex_cli_path\""
  launcher_content+='
resolved_codex_path="$(command -v codex 2>/dev/null || true)"
[[ -z "$resolved_codex_path" && -x "$default_codex_path" ]] && resolved_codex_path="$default_codex_path"
if [[ -z "$resolved_codex_path" ]]; then
  printf '\''codex-net: unable to locate the Codex CLI. Rerun onboarding or install codex.\n'\'' >&2
  exit 1
fi
'
  # Sections 2-4: shared launcher body (flag parsing, tmux prompt, worktree picker)
  launcher_content+="$(_generate_launcher_body "codex-net" "CODEX_NET" "codex-work" "codex_args" "Codex CLI")"

  # Section 6: codex-specific exec (tmux + CLI invocation)
  launcher_content+='
if [[ "$use_tmux" = "0" ]] || ! command -v tmux >/dev/null 2>&1; then
  [[ "$use_tmux" = "1" ]] && printf '\''codex-net: tmux not found; launching directly\n'\'' >&2
  exec "$resolved_codex_path" --sandbox danger-full-access -a never --search \
    -c shell_environment_policy.inherit=all "${codex_args[@]+"${codex_args[@]}"}"
fi

# Already inside tmux: create dedicated session and switch to it
if [[ -n "${TMUX:-}" ]]; then
  current_session="$(tmux display-message -p '\''#S'\'')"
  if [[ "$current_session" = "$session_name" ]]; then
    exec "$resolved_codex_path" --sandbox danger-full-access -a never --search \
      -c shell_environment_policy.inherit=all "${codex_args[@]+"${codex_args[@]}"}"
  fi
  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" \
      "$resolved_codex_path" --sandbox danger-full-access -a never --search \
      -c shell_environment_policy.inherit=all "${codex_args[@]+"${codex_args[@]}"}"
  fi
  exec tmux switch-client -t "$session_name"
fi

# Not in tmux: create/attach session
if ! tmux has-session -t "$session_name" 2>/dev/null; then
  tmux new-session -d -s "$session_name" \
    "$resolved_codex_path" --sandbox danger-full-access -a never --search \
    -c shell_environment_policy.inherit=all "${codex_args[@]+"${codex_args[@]}"}";
fi
exec tmux attach-session -t "$session_name"
'

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

ensure_tmux_config() {
  local repo_root="$1"
  local timestamp="$2"
  local source_conf="${repo_root}/tmux/.tmux.conf"
  local target_conf="$HOME/.tmux.conf"
  local tpm_dir="$HOME/.tmux/plugins/tpm"

  if [ ! -f "$source_conf" ]; then
    log "tmux config source not found: $source_conf; skipping"
    return 0
  fi

  # Copy config (backup if existing differs)
  if [ -f "$target_conf" ]; then
    if ! diff -q "$source_conf" "$target_conf" >/dev/null 2>&1; then
      local backup="${target_conf}.backup.${timestamp}"
      log "Backing up existing ~/.tmux.conf to: $backup"
      cp "$target_conf" "$backup"
    else
      log "~/.tmux.conf already up to date"
      return 0  # skip TPM check too if config unchanged
    fi
  fi

  log "Installing tmux config: $target_conf"
  cp "$source_conf" "$target_conf"

  # Bootstrap TPM
  if [ ! -d "$tpm_dir" ]; then
    log "Cloning TPM..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi

  # Install plugins
  if [ -x "$tpm_dir/bin/install_plugins" ]; then
    log "Installing tmux plugins..."
    "$tpm_dir/bin/install_plugins"
  fi
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

  # Write provenance pointer so agents in other projects know where their config originates
  local origin_file="${codex_home}/ORIGIN"
  printf '%s\n' "$repo_root" > "$origin_file"
  log "Wrote provenance pointer: $origin_file -> $repo_root"
}

resolve_claude_cli_path() {
  local resolved_path npm_bin_dir
  resolved_path="$(command -v claude 2>/dev/null || true)"
  if [ -n "$resolved_path" ]; then
    printf '%s\n' "$resolved_path"
    return 0
  fi

  npm_bin_dir="$(resolve_npm_global_bin_dir 2>/dev/null || true)"
  if [ -n "$npm_bin_dir" ] && [ -x "$npm_bin_dir/claude" ]; then
    printf '%s\n' "$npm_bin_dir/claude"
    return 0
  fi

  return 1
}

install_claude_dev_launcher() {
  local claude_cli_path="$1"
  local launcher_bin_dir claude_dev_launcher launcher_content

  launcher_bin_dir="$(resolve_launcher_bin_dir)"
  claude_dev_launcher="$launcher_bin_dir/claude-dev"
  launcher_content="$(cat <<'LAUNCHER_EOF'
#!/usr/bin/env bash
set -euo pipefail

# ── Section 1: Locate Claude CLI ──────────────────────────────────────
LAUNCHER_EOF
)"
  # Inject the literal claude_cli_path (expanded at install time)
  launcher_content+="
default_claude_path=\"$claude_cli_path\""
  launcher_content+='
resolved_claude_path="$(command -v claude 2>/dev/null || true)"
[[ -z "$resolved_claude_path" && -x "$default_claude_path" ]] && resolved_claude_path="$default_claude_path"
if [[ -z "$resolved_claude_path" ]]; then
  printf '\''claude-dev: unable to locate the Claude CLI. Rerun onboarding or install claude.\n'\'' >&2
  exit 1
fi
'
  # Sections 2-4: shared launcher body (flag parsing, tmux prompt, worktree picker)
  launcher_content+="$(_generate_launcher_body "claude-dev" "CLAUDE_DEV" "claude-work" "claude_args" "Claude Code")"

  # Section 6: claude-specific exec (tmux + CLI invocation)
  launcher_content+='
if [[ "$use_tmux" = "0" ]] || ! command -v tmux >/dev/null 2>&1; then
  [[ "$use_tmux" = "1" ]] && printf '\''claude-dev: tmux not found; launching directly\n'\'' >&2
  exec "$resolved_claude_path" --dangerously-skip-permissions "${claude_args[@]+"${claude_args[@]}"}"
fi

# Already inside tmux: create dedicated session and switch to it
if [[ -n "${TMUX:-}" ]]; then
  current_session="$(tmux display-message -p '\''#S'\'')"
  if [[ "$current_session" = "$session_name" ]]; then
    exec "$resolved_claude_path" --dangerously-skip-permissions "${claude_args[@]+"${claude_args[@]}"}"
  fi
  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" \
      "$resolved_claude_path" --dangerously-skip-permissions "${claude_args[@]+"${claude_args[@]}"}"
  fi
  exec tmux switch-client -t "$session_name"
fi

# Not in tmux: create/attach session
if ! tmux has-session -t "$session_name" 2>/dev/null; then
  tmux new-session -d -s "$session_name" \
    "$resolved_claude_path" --dangerously-skip-permissions "${claude_args[@]+"${claude_args[@]}"}";
fi
exec tmux attach-session -t "$session_name"
'

  mkdir -p "$launcher_bin_dir"
  write_executable_file_atomic "$claude_dev_launcher" "$launcher_content"
  log "Installed Claude interactive launcher: $claude_dev_launcher"

  if ! path_contains_dir "$launcher_bin_dir"; then
    log "Launcher directory is not on PATH. Add this to your shell profile:"
    log "  export PATH=\"$launcher_bin_dir:\$PATH\""
  fi
}

ensure_claude_settings() {
  local settings_base="$1"
  local settings_target="$2"

  if [ ! -f "$settings_base" ]; then
    log "Claude settings base not found: $settings_base; skipping settings merge"
    return 0
  fi

  if [ ! -f "$settings_target" ]; then
    log "Creating Claude settings from base: $settings_target"
    cp "$settings_base" "$settings_target"
    return 0
  fi

  log "Merging Claude base settings into: $settings_target"
  python3 -c "
import json, sys
base = json.load(open(sys.argv[1]))
target = json.load(open(sys.argv[2]))
for k, v in base.items():
    if k not in target:
        target[k] = v
    elif isinstance(v, dict) and isinstance(target[k], dict):
        for sk, sv in v.items():
            if sk not in target[k]:
                target[k][sk] = sv
with open(sys.argv[2], 'w') as f:
    json.dump(target, f, indent=2)
    f.write('\n')
" "$settings_base" "$settings_target"
}

ensure_user_mcp_servers() {
  local config_base_toml="$1"
  local claude_json_target="$2"
  local credentials_path="${3:-}"

  if [ ! -f "$config_base_toml" ]; then
    log "Codex base config not found: $config_base_toml; skipping MCP server registration"
    return 0
  fi

  if [ -n "$credentials_path" ] && [ -f "$credentials_path" ]; then
    log "Registering MCP servers into: $claude_json_target (with credentials from: $credentials_path)"
  else
    log "Registering MCP servers into: $claude_json_target"
    credentials_path=""
  fi

  python3 - "$config_base_toml" "$claude_json_target" "${credentials_path:-}" <<'PY'
import json, re, sys, os

toml_path = sys.argv[1]
out_path = sys.argv[2]
creds_path = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None

with open(toml_path) as f:
    text = f.read()

creds = {}
if creds_path:
    try:
        with open(creds_path) as f:
            raw_creds = json.load(f)
        for key, val in raw_creds.items():
            server_name = key.split('|')[0]
            creds[server_name] = val
    except Exception:
        pass

servers = {}
for m in re.finditer(r'^\[mcp_servers\.("[^"]+"|[^\]\s]+)\]\s*\n((?:(?!\n\[).)*)', text, re.MULTILINE | re.DOTALL):
    name = m.group(1).strip('"')
    block = m.group(2)
    server = {}
    for line in block.strip().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        key, _, val = line.partition('=')
        key = key.strip()
        val = val.strip()
        if key in ('startup_timeout_sec',):
            continue
        if val.startswith('\"'):
            server[key] = val.strip('\"')
        elif val.startswith('['):
            server[key] = json.loads(val)
    if 'url' in server and 'command' not in server:
        server.setdefault('type', 'http')
    if server:
        servers[name] = server

claude_json = {}
if os.path.exists(out_path):
    try:
        with open(out_path) as f:
            claude_json = json.load(f)
    except Exception:
        pass

claude_json.setdefault('mcpServers', {}).update(servers)

with open(out_path, 'w') as f:
    json.dump(claude_json, f, indent=2)
    f.write('\n')
PY
}

ensure_claude_memory_symlink() {
  local repo_root="$1"
  local claude_home="$2"
  local claude_repo_home="$3"
  local timestamp="$4"
  local encoded_path target_dir source_dir

  encoded_path="$(printf '%s' "$repo_root" | tr '/' '-')"
  target_dir="${claude_home}/projects/${encoded_path}/memory"
  source_dir="${claude_repo_home}/memory"

  if [ ! -d "$source_dir" ]; then
    log "Claude versioned memory directory not found: $source_dir; skipping memory symlink"
    return 0
  fi

  ensure_path_symlink "$target_dir" "$source_dir" "Claude versioned memory" "$timestamp"
}

require_onboarding_env() {
  local missing_var
  for missing_var in "$@"; do
    if [ -z "${!missing_var:-}" ]; then
      die "Missing required onboarding env: ${missing_var}"
    fi
  done
}
