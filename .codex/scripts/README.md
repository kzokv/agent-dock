# Codex Script Helpers

This directory contains the canonical support tooling for the shared `.codex` home.

## Entry points

- `onboarding.sh`
  - internal Codex bootstrap implementation invoked by `scripts/onboarding.sh`
  - rejects direct operator use unless called by the root orchestrator with its hidden flag
- `render-agent-configs.py`
  - generates `.codex/agents/config/*.toml` with default model/reasoning plus preserved role execution traits
- `test-onboarding.sh`
  - validates the root-orchestrated onboarding flow and Codex bootstrap conditions
- `validate-role-skill-topology.py`
  - validates `.codex/agents` and `.codex/skills`
- `check-config-migration.sh`
  - verifies tracked vs ignored ownership for `.codex/config.base.toml`, `.codex/config.local.toml`, and `.codex/config.toml`
- `install-required-skills.sh`
  - installs missing required skills into `.codex/skills`
- `bootstrap-budget.sh`
  - estimates bootstrap token cost using `.codex/AGENTS.md`, `.codex/skills`, system skills, repo-local skills, and optional worklog files
- `rlm_retrieval.py`
  - builds and queries the local retrieval catalog under `~/.codex/cache/knowledge/`
- `run_bootstrap_evals.py`
  - runs baseline vs candidate bootstrap-quality evals
- `setup-git-hooks.sh`
  - configures `.githooks` as the local git hooks path

## Path model

- Canonical shared home: `~/.codex`
- Canonical shared skills: `~/.codex/skills`
- Shared Codex discovery path: `~/.agents/skills`
- Cursor skill path: `~/.cursor/skills`
- Claude skill path: `~/.claude/skills`

All runtime skill paths above resolve to the same `.codex/skills` source.

## Guidance

- Keep shared onboarding helpers in the root `scripts/` directory.
- Keep Codex-specific support tooling in `.codex/scripts`.
- Keep `scripts/onboarding.sh` as the only supported operator onboarding entrypoint.
- Keep agent-specific onboarding entrypoints under each tracked agent home.
- Keep helpers flag-driven with `-h/--help` support and deterministic non-interactive behavior.
- Update `test-onboarding.sh` when onboarding symlink or bootstrap behavior changes.
