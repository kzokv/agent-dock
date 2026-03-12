#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${0##*/}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
codex_repo_home="${repo_root}/.codex"
cursor_repo_home="${repo_root}/.cursor"
claude_repo_home="${repo_root}/.claude"
source "${repo_root}/scripts/onboarding-lib.sh"

agent_selection=""
codex_home_override=""
cursor_home_override=""
claude_home_override=""
skip_gh_auth=0
codex_bootstrap_mode="auto"
internal_codex_flag="--internal-root-dispatch"
initial_arg_count=$#

print_help() {
  cat <<EOF_HELP
Description:
  Link this repo into ~/.codex and selected agent subpaths, point shared skill views at
  ~/.codex/skills, bootstrap GitHub CLI auth, and optionally generate Codex runtime config,
  generated role configs, plus install the Codex CLI and codex-net launcher.

Usage: ${SCRIPT_PATH} [OPTIONS]

Options:
  -h, --help                    Show this help message and exit (optional)
  --agent AGENT                 Target agent to onboard: codex, cursor, claude, or all (optional, default: prompt or all)
  --codex-home PATH             Override the ~/.codex symlink path (optional, default: ~/.codex)
  --cursor-home PATH            Override the ~/.cursor directory path (optional, default: ~/.cursor)
  --claude-home PATH            Override the ~/.claude symlink path (optional, default: ~/.claude)
  --skip-gh-auth                Skip GitHub auth bootstrap (optional, default: off)
  --with-codex-bootstrap        Force Codex config/CLI/bootstrap steps on (optional, default: auto)
  --without-codex-bootstrap     Force Codex config/CLI/bootstrap steps off (optional, default: auto)
EOF_HELP
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    --agent)
      shift
      [ $# -gt 0 ] || die_with_help "--agent requires a value"
      agent_selection="$1"
      shift
      ;;
    --agent=*)
      agent_selection="${1#*=}"
      shift
      ;;
    --codex-home)
      shift
      [ $# -gt 0 ] || die_with_help "--codex-home requires a path"
      codex_home_override="$1"
      shift
      ;;
    --codex-home=*)
      codex_home_override="${1#*=}"
      shift
      ;;
    --cursor-home)
      shift
      [ $# -gt 0 ] || die_with_help "--cursor-home requires a path"
      cursor_home_override="$1"
      shift
      ;;
    --cursor-home=*)
      cursor_home_override="${1#*=}"
      shift
      ;;
    --claude-home)
      shift
      [ $# -gt 0 ] || die_with_help "--claude-home requires a path"
      claude_home_override="$1"
      shift
      ;;
    --claude-home=*)
      claude_home_override="${1#*=}"
      shift
      ;;
    --skip-gh-auth)
      skip_gh_auth=1
      shift
      ;;
    --with-codex-bootstrap)
      [ "$codex_bootstrap_mode" = "off" ] && die_with_help "Cannot combine --with-codex-bootstrap and --without-codex-bootstrap"
      codex_bootstrap_mode="on"
      shift
      ;;
    --without-codex-bootstrap)
      [ "$codex_bootstrap_mode" = "on" ] && die_with_help "Cannot combine --with-codex-bootstrap and --without-codex-bootstrap"
      codex_bootstrap_mode="off"
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

if [ "$initial_arg_count" -eq 0 ] && { [ -t 0 ] || [ "${ONBOARDING_FORCE_INTERACTIVE:-0}" = "1" ]; }; then
  printf 'codex-home onboarding\n'
  printf 'Running interactive setup with defaults after agent selection.\n\n'
fi

if [ -z "$agent_selection" ]; then
  agent_selection="$(prompt_agent_selection)"
fi

case "$agent_selection" in
  codex|cursor|claude|all) ;;
  *)
    die "Unsupported agent selection: $agent_selection"
    ;;
esac

timestamp="$(date +%Y%m%d%H%M%S)"
codex_home="${codex_home_override:-$HOME/.codex}"
cursor_home="${cursor_home_override:-$HOME/.cursor}"
claude_home="${claude_home_override:-$HOME/.claude}"
agents_home="$HOME/.agents"
agents_skills_dir="${agents_home}/skills"
agents_skills_library_dir="${agents_home}/skills-library"
config_base="${codex_repo_home}/config.base.toml"
config_local="${codex_repo_home}/config.local.toml"
config_file="${codex_repo_home}/config.toml"
project_header="[projects.\"$repo_root\"]"
codex_agent_script="${codex_repo_home}/scripts/onboarding.sh"
cursor_agent_script="${cursor_repo_home}/scripts/onboarding.sh"
claude_agent_script="${claude_repo_home}/scripts/onboarding.sh"

should_run_codex_bootstrap=0
case "$agent_selection" in
  codex|all)
    should_run_codex_bootstrap=1
    ;;
  cursor|claude)
    if [ "$codex_bootstrap_mode" = "on" ]; then
      should_run_codex_bootstrap=1
    fi
    ;;
esac

if [ "$codex_bootstrap_mode" = "off" ]; then
  should_run_codex_bootstrap=0
fi

log "Starting onboarding"
log "Repo root: $repo_root"
log "Agent selection: $agent_selection"
log "Codex home target: $codex_home"
log "Cursor home target: $cursor_home"
log "Claude home target: $claude_home"

if [ "$skip_gh_auth" = "1" ]; then
  log "Skipping GitHub auth bootstrap (--skip-gh-auth)"
else
  export ONBOARDING_REPO_ROOT="$repo_root"
  ensure_gh_token_secret
fi

export ONBOARDING_REPO_ROOT="$repo_root"
export ONBOARDING_TIMESTAMP="$timestamp"
export ONBOARDING_CODEX_HOME="$codex_home"
export ONBOARDING_CURSOR_HOME="$cursor_home"
export ONBOARDING_CLAUDE_HOME="$claude_home"
export ONBOARDING_AGENTS_HOME="$agents_home"
export ONBOARDING_AGENTS_SKILLS_DIR="$agents_skills_dir"
export ONBOARDING_AGENTS_SKILLS_LIBRARY_DIR="$agents_skills_library_dir"
export ONBOARDING_CONFIG_BASE="$config_base"
export ONBOARDING_CONFIG_LOCAL="$config_local"
export ONBOARDING_CONFIG_FILE="$config_file"
export ONBOARDING_PROJECT_HEADER="$project_header"

ensure_shared_onboarding_paths "$timestamp" "$codex_home" "$agents_home" "$agents_skills_dir" "$agents_skills_library_dir"

run_codex_bootstrap() {
  [ -x "$codex_agent_script" ] || die "Missing Codex onboarding script: $codex_agent_script"
  "$codex_agent_script" "$internal_codex_flag"
}

case "$agent_selection" in
  codex)
    if [ "$should_run_codex_bootstrap" = "1" ]; then
      run_codex_bootstrap
    else
      log "Skipping Codex bootstrap (--without-codex-bootstrap)"
    fi
    ;;
  cursor)
    if [ "$should_run_codex_bootstrap" = "1" ]; then
      log "Running explicit Codex bootstrap before Cursor onboarding"
      run_codex_bootstrap
    fi
    [ -x "$cursor_agent_script" ] || die "Missing Cursor onboarding script: $cursor_agent_script"
    "$cursor_agent_script"
    ;;
  claude)
    if [ "$should_run_codex_bootstrap" = "1" ]; then
      log "Running explicit Codex bootstrap before Claude onboarding"
      run_codex_bootstrap
    fi
    [ -x "$claude_agent_script" ] || die "Missing Claude onboarding script: $claude_agent_script"
    "$claude_agent_script"
    ;;
  all)
    if [ "$should_run_codex_bootstrap" = "1" ]; then
      run_codex_bootstrap
    else
      log "Skipping Codex bootstrap (--without-codex-bootstrap)"
    fi
    [ -x "$cursor_agent_script" ] || die "Missing Cursor onboarding script: $cursor_agent_script"
    "$cursor_agent_script"
    [ -x "$claude_agent_script" ] || die "Missing Claude onboarding script: $claude_agent_script"
    "$claude_agent_script"
    ;;
esac

log "Onboarding complete"
