#!/usr/bin/env bash
set -euo pipefail

repo_root="${ONBOARDING_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
claude_repo_home="${repo_root}/.claude"

source "${repo_root}/scripts/onboarding-lib.sh"

require_onboarding_env \
  ONBOARDING_TIMESTAMP \
  ONBOARDING_CLAUDE_HOME

timestamp="${ONBOARDING_TIMESTAMP}"
claude_home="${ONBOARDING_CLAUDE_HOME}"

ensure_path_symlink "$claude_home" "$claude_repo_home" "Claude home" "$timestamp"

# Merge base settings into settings.json
ensure_claude_settings "$claude_repo_home/settings.base.json" "$claude_home/settings.json"

# Register MCP servers into ~/.claude.json (user scope), merging any root-level credentials
ensure_user_mcp_servers "${repo_root}/.codex/config.base.toml" "${HOME}/.claude.json" "${repo_root}/.credentials.json"

# Symlink versioned memory
ensure_claude_memory_symlink "$repo_root" "$claude_home" "$claude_repo_home" "$timestamp"

# Install claude-dev launcher if CLI available
claude_cli_path="$(resolve_claude_cli_path 2>/dev/null || true)"
if [ -n "$claude_cli_path" ]; then
  install_claude_dev_launcher "$claude_cli_path"
else
  log "Claude CLI ('claude') not found; skipping claude-dev launcher."
  log "Install with: npm install -g @anthropic-ai/claude-code"
fi

# Install codex-net launcher if Codex CLI available
codex_cli_path="$(resolve_codex_cli_path 2>/dev/null || true)"
if [ -n "$codex_cli_path" ]; then
  install_codex_net_launcher "$codex_cli_path"
else
  log "Codex CLI ('codex') not found; skipping codex-net launcher."
  log "Install with: npm install -g @openai/codex"
fi
