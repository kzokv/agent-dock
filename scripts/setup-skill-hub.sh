#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${0##*/}"
SKILLS_PACKAGE="skills"
AGENT_SKILLS_CLI_PACKAGE="agent-skills-cli"
CLAUDE_SKILLS_DOMAINS=(
  "engineering-skills"
  "leadership-skills"
  "learning-skills"
  "marketing-skills"
  "tool-skills"
  "workflow-skills"
)
hub_selection=""
domain_selection=""
npm_global_root=""

print_help() {
  cat <<EOF_HELP
Description:
  Ensure the required global skill hub CLI is installed, then launch the selected
  skill hub command.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help                    Show this help message and exit (optional)
  --hub HUB                     Run a hub non-interactively: skills or claude-skills (optional)
  --domain DOMAIN               Claude-skills domain to add when --hub claude-skills is used (optional)
EOF_HELP
}

log() {
  printf '[setup-skill-hub] %s\n' "$1"
}

die() {
  log "ERROR: $1" >&2
  exit 1
}

die_with_help() {
  log "ERROR: $1" >&2
  print_help >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

is_interactive() {
  [ -t 0 ]
}

package_installed() {
  local package_name="$1"
  [ -n "$npm_global_root" ] || return 1
  [ -d "${npm_global_root}/${package_name}" ]
}

package_version() {
  local package_name="$1"
  [ -n "$npm_global_root" ] || return 1
  node -p "require('${npm_global_root}/${package_name}/package.json').version" 2>/dev/null
}

latest_package_version() {
  local package_name="$1"
  npm view "$package_name" version 2>/dev/null || true
}

prompt_yes_no() {
  local prompt="$1"
  local response=""

  if ! is_interactive; then
    return 1
  fi

  printf '%s [y/N]: ' "$prompt" >&2
  read -r response || true

  case "${response}" in
    y|Y|yes|YES|Yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

install_package() {
  local package_name="$1"
  local install_mode="${2:-normal}"

  if [ "$install_mode" = "force" ]; then
    log "Installing package with overwrite: ${package_name}"
    npm install -g --force "$package_name"
  else
    log "Installing missing skill hub package: ${package_name}"
    npm install -g "$package_name"
  fi
  hash -r
}

maybe_offer_package_update() {
  local package_name="$1"
  local installed_version latest_version

  installed_version="$(package_version "$package_name" || true)"
  [ -n "$installed_version" ] || return 0

  latest_version="$(latest_package_version "$package_name")"
  [ -n "$latest_version" ] || return 0
  [ "$installed_version" != "$latest_version" ] || return 0

  if prompt_yes_no "Package '${package_name}' is installed at ${installed_version}; latest is ${latest_version}. Update it"; then
    install_package "$package_name"
  else
    log "Skipping update for ${package_name}; installed version is ${installed_version}"
  fi
}

ensure_package_state() {
  local package_name="$1"
  shift
  local provided_bins=("$@")
  local bin_name bin_path
  local conflicting_bins=()

  if package_installed "$package_name"; then
    log "Package already installed: ${package_name}"
    maybe_offer_package_update "$package_name"
    return 0
  fi

  for bin_name in "${provided_bins[@]}"; do
    bin_path="$(command -v "$bin_name" 2>/dev/null || true)"
    if [ -n "$bin_path" ]; then
      conflicting_bins+=("${bin_name} (${bin_path})")
    fi
  done

  if [ "${#conflicting_bins[@]}" -gt 0 ]; then
    if prompt_yes_no "Package '${package_name}' is missing, but these binaries already exist: ${conflicting_bins[*]}. Overwrite them by installing ${package_name}"; then
      install_package "$package_name" force
    else
      log "Skipping ${package_name}; existing binaries would be overwritten"
      return 0
    fi
  else
    install_package "$package_name"
  fi

  package_installed "$package_name" || die "Package '${package_name}' is still unavailable after installation"
}

ensure_skill_clis_installed() {
  ensure_package_state "${SKILLS_PACKAGE}" skills
  ensure_package_state "${AGENT_SKILLS_CLI_PACKAGE}" skills agent-skills
}

is_supported_domain() {
  local candidate="$1"
  local domain

  for domain in "${CLAUDE_SKILLS_DOMAINS[@]}"; do
    if [ "$candidate" = "$domain" ]; then
      return 0
    fi
  done

  return 1
}

prompt_hub_selection() {
  [ -t 0 ] || die_with_help "--hub is required when stdin is not interactive"

  printf 'Choose skill hub:\n' >&2
  printf '  1. npx skills\n' >&2
  printf '  2. npx agent-skills-cli add alirezarezvani/claude-skills\n' >&2
  printf 'Selection: ' >&2

  local response
  read -r response || die "Failed to read selection"

  case "$response" in
    1|skills)
      printf 'skills\n'
      ;;
    2|claude-skills|agent-skills-cli)
      printf 'claude-skills\n'
      ;;
    *)
      die "Unsupported selection: ${response}"
      ;;
  esac
}

prompt_domain_selection() {
  [ -t 0 ] || die_with_help "--domain is required when --hub claude-skills is used non-interactively"

  printf 'Choose claude-skills domain:\n' >&2
  printf '  1. engineering-skills\n' >&2
  printf '  2. leadership-skills\n' >&2
  printf '  3. learning-skills\n' >&2
  printf '  4. marketing-skills\n' >&2
  printf '  5. tool-skills\n' >&2
  printf '  6. workflow-skills\n' >&2
  printf 'Selection: ' >&2

  local response
  read -r response || die "Failed to read domain selection"

  case "$response" in
    1|engineering-skills)
      printf 'engineering-skills\n'
      ;;
    2|leadership-skills)
      printf 'leadership-skills\n'
      ;;
    3|learning-skills)
      printf 'learning-skills\n'
      ;;
    4|marketing-skills)
      printf 'marketing-skills\n'
      ;;
    5|tool-skills)
      printf 'tool-skills\n'
      ;;
    6|workflow-skills)
      printf 'workflow-skills\n'
      ;;
    *)
      die "Unsupported domain selection: ${response}"
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --hub)
      shift
      [ $# -gt 0 ] || die_with_help "--hub requires a value"
      hub_selection="$1"
      shift
      ;;
    --hub=*)
      hub_selection="${1#*=}"
      shift
      ;;
    --domain)
      shift
      [ $# -gt 0 ] || die_with_help "--domain requires a value"
      domain_selection="$1"
      shift
      ;;
    --domain=*)
      domain_selection="${1#*=}"
      shift
      ;;
    -*)
      die_with_help "Unknown flag $1"
      ;;
    *)
      die_with_help "Unexpected positional argument: $1"
      ;;
  esac
done

require_command npm
require_command npx
npm_global_root="$(npm root -g 2>/dev/null || true)"
[ -n "$npm_global_root" ] || die "Failed to resolve npm global root"
ensure_skill_clis_installed

if [ -z "$hub_selection" ]; then
  hub_selection="$(prompt_hub_selection)"
fi

case "$hub_selection" in
  skills)
    exec npx skills
    ;;
  claude-skills)
    if [ -z "$domain_selection" ]; then
      domain_selection="$(prompt_domain_selection)"
    fi

    is_supported_domain "$domain_selection" || die_with_help "Unsupported domain: $domain_selection"
    exec npx agent-skills-cli add "alirezarezvani/claude-skills/${domain_selection}"
    ;;
  *)
    die_with_help "Unsupported hub selection: $hub_selection"
    ;;
esac
