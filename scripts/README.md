# Onboarding Script Helpers

## Scripts

- [`scripts/onboarding.sh`](onboarding.sh)
  - `log` keeps lifecycle messages namespaced and suitable for automation.
  - `canonical_path` and `resolve_link_target_path` normalize symlink targets to compare canonical destinations safely.
  - `ensure_repo_trust_block` rewrites only this repo's project trust block in `config.local.toml`.
  - `generate_runtime_config` merges `config.base.toml` + `config.local.toml` into generated `config.toml`.
  - `migrate_legacy_skills` performs one-time migration from legacy `~/.codex/skills` to `~/.codex/agents/skills`.
  - `ensure_agents_skills_link` maintains `$HOME/.agents/skills -> ~/.codex/agents/skills` with backup-then-replace behavior.

- [`scripts/test-onboarding.sh`](test-onboarding.sh)
  - Validates onboarding idempotency, config generation, skills-link creation, and legacy skills migration.
  - Supports `--keep-fixtures` or `KEEP_FIXTURES=1` to keep fixture directories for debugging.
  - Requires `rg` to be available in PATH.

- [`scripts/validate-role-skill-topology.py`](validate-role-skill-topology.py)
  - Validates role-to-skill bindings and canonical role topology integrity.

- [`scripts/check-config-migration.sh`](check-config-migration.sh)
  - Verifies tracked/ignored config ownership (`config.base.toml` tracked, generated/local files ignored).

- [`scripts/install-required-skills.sh`](install-required-skills.sh)
  - User-level installer that installs required curated skills into `~/.codex/agents/skills` (repo source of truth).

- [`scripts/setup-git-hooks.sh`](setup-git-hooks.sh)
  - Configures local git to use `.githooks` and enables commit message enforcement.

## Skill layering contract

- System-level: built-in Codex capabilities.
- User-level: discovery path is `$HOME/.agents/skills`.
- User-level versioned source: `~/.codex/agents/skills`.
- Repo-level project skills (`<repo>/.agents/skills`) are allowed in other repos.
- This `codex-home` repo must not define its own `.agents/skills`.

## Guidelines for future helpers

Always keep onboarding scripts flag-driven with `-h/--help` support and deterministic non-interactive behavior.
Document helper additions here and add fixture tests in `scripts/test-onboarding.sh` for new migration or symlink logic.
