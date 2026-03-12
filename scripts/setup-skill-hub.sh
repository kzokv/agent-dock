#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${0##*/}"
CLAUDE_SKILLS_DOMAINS=(
  "engineering-team"
  "engineering"
  "marketing-skill"
  "product-team"
  "project-management"
  "ra-qm-team"
  "business-growth"
)
hub_selection=""
domain_selection=""

print_help() {
  cat <<EOF_HELP
Description:
  Launch the selected skill hub command.

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
  printf '  1. engineering-team\n' >&2
  printf '  2. engineering\n' >&2
  printf '  3. marketing-skill\n' >&2
  printf '  4. product-team\n' >&2
  printf '  5. project-management\n' >&2
  printf '  6. ra-qm-team\n' >&2
  printf '  7. business-growth\n' >&2
  printf 'Selection: ' >&2

  local response
  read -r response || die "Failed to read domain selection"

  case "$response" in
    1|engineering-team)
      printf 'engineering-team\n'
      ;;
    2|engineering)
      printf 'engineering\n'
      ;;
    3|marketing-skill)
      printf 'marketing-skill\n'
      ;;
    4|product-team)
      printf 'product-team\n'
      ;;
    5|project-management)
      printf 'project-management\n'
      ;;
    6|ra-qm-team)
      printf 'ra-qm-team\n'
      ;;
    7|business-growth)
      printf 'business-growth\n'
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
