#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${0##*/}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
codex_repo_home="${repo_root}/.codex"
agent_config_dir="${codex_repo_home}/agents/config"
internal_dispatch=0
source "${repo_root}/scripts/onboarding-lib.sh"

print_help() {
  cat <<EOF_HELP
Description:
  Internal Codex bootstrap implementation used by ./scripts/onboarding.sh.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help                    Show this help message and exit (optional)
EOF_HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --internal-root-dispatch)
      internal_dispatch=1
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

if [ "$internal_dispatch" != "1" ]; then
  log "ERROR: ${SCRIPT_PATH} is an internal helper. Run ./scripts/onboarding.sh instead."
  exit 1
fi

require_onboarding_env \
  ONBOARDING_CONFIG_BASE \
  ONBOARDING_CONFIG_LOCAL \
  ONBOARDING_CONFIG_FILE \
  ONBOARDING_PROJECT_HEADER

config_base="${ONBOARDING_CONFIG_BASE}"
config_local="${ONBOARDING_CONFIG_LOCAL}"
config_file="${ONBOARDING_CONFIG_FILE}"
project_header="${ONBOARDING_PROJECT_HEADER}"

if [ ! -f "$config_base" ]; then
  die "Missing required base config: $config_base"
fi

generate_agent_role_configs "$agent_config_dir"
log "Upserting machine-local trust settings in: $config_local"
ensure_repo_trust_block "$config_local" "$project_header"
log "Generating runtime config: $config_base + $config_local -> $config_file"
generate_runtime_config "$config_base" "$config_local" "$config_file"

codex_cli_path="$(ensure_codex_cli)"
install_codex_net_launcher "$codex_cli_path"
