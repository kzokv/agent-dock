# Onboarding Script Helpers

## Scripts

- [`scripts/onboarding.sh`](onboarding.sh)
  - `log` keeps lifecycle messages namespaced and suitable for automation.
  - `canonical_path` and `resolve_link_target_path` normalize symlink targets to compare canonical destinations safely.
  - `ensure_repo_trust_block` rewrites only this repo's project trust block in `config.local.toml`.
  - `generate_runtime_config` merges `config.base.toml` + `config.local.toml` into generated `config.toml`.
  - `migrate_legacy_skills` performs one-time migration from legacy `~/.codex/skills` to `~/.codex/agents/skills`.
  - `ensure_agents_skill_catalogs` rebuilds `$HOME/.agents/skills` as the enabled discovery subset and `$HOME/.agents/skills-library` as the archived remainder.
  - `ensure_claude_skills_links` populates `$HOME/.claude/skills` with per-skill symlinks for every installed skill.
  - `install_cursor_role_loader` copies `<repo>/.platforms/cursor/agents/codex-role-loader.md` as a regular file into `<cursor_home>/agents/` (default: `~/.cursor/agents/`). Overwrites any existing file and replaces stale symlinks at the destination.
  - `ensure_gh_token_secret` validates `gh` login and runs `gh auth login -h github.com` when needed so spawned sessions share the verified login state.
  - `--skip-gh-auth` disables GH bootstrap for non-interactive or CI-style runs.
  - `--cursor-home PATH` overrides the Cursor home directory used for the role-loader installation (default: `~/.cursor`). This option accepts any writable path; run onboarding as the target user and avoid privileged system paths unless explicitly intended.

- [`scripts/test-onboarding.sh`](test-onboarding.sh)
  - Validates onboarding idempotency, config generation, skills-link creation, legacy skills migration, GH auth bootstrap behavior, secret-file safety constraints, and Cursor role-loader behavior (copy, overwrite, symlink replacement, `--cursor-home` override, idempotency).
  - Supports `--keep-fixtures` or `KEEP_FIXTURES=1` to keep fixture directories for debugging.
  - Requires `rg` to be available in PATH.

- [`scripts/validate-role-skill-topology.py`](validate-role-skill-topology.py)
  - Validates role-to-skill bindings and canonical role topology integrity.

- [`scripts/check-config-migration.sh`](check-config-migration.sh)
  - Verifies tracked/ignored config ownership (`config.base.toml` tracked, generated/local files ignored).

- [`scripts/install-required-skills.sh`](install-required-skills.sh)
  - User-level installer that ensures the curated default skill sources exist in `~/.codex/agents/skills`.

- [`scripts/bootstrap-budget.sh`](bootstrap-budget.sh)
  - Reports approximate startup token usage for shared policy, repo policy, enabled skills, system skills, repo-local skills, and optional worklog files.
  - Supports `--json`, `--max-bootstrap-tokens`, and `--max-session-tokens` for CI-style budget checks and benchmark ingestion.
  - Uses normalized skill paths in estimates and emits `path_mode: normalized` in JSON output.

- [`scripts/rlm_retrieval.py`](rlm_retrieval.py)
  - Builds a local retrieval catalog with file summaries, chunk slices, and explicit reference edges.
  - Exposes bounded retrieval primitives: `status`, `query`, `peek`, `expand`, `summarize`, plus scratch-session logging with root metadata.
  - Stores retrieval artifacts outside the active prompt under `~/.codex/cache/knowledge/`.
  - Keeps refresh manual: rebuild with `build --force` when `status` shows the catalog is stale and current repo changes matter.

- [`scripts/run_bootstrap_evals.py`](run_bootstrap_evals.py)
  - Runs paired baseline-vs-candidate bootstrap evals for plan generation, code review, and research with citations.
  - Records retrieval-efficiency evidence for the RLM-style scaffold, including retrieved handles, retrieval depth, runtime warnings, and token budgets.
  - Uses temporary snapshots so prompt-state comparisons stay stable against the current worktree.

- [`scripts/setup-git-hooks.sh`](setup-git-hooks.sh)
  - Configures local git to use `.githooks` and enables commit message enforcement.

## Skill layering contract

- System-level: built-in Codex capabilities.
- User-level: discovery path is `$HOME/.agents/skills`, populated from an enabled subset of the versioned source.
- User-level versioned source: `~/.codex/agents/skills`.
- User-level archive path: `$HOME/.agents/skills-library`.
- Repo-level project skills (`<repo>/.agents/skills`) are allowed in other repos.
- This `codex-home` repo must not define its own `.agents/skills`.

## Guidelines for future helpers

Always keep onboarding scripts flag-driven with `-h/--help` support and deterministic non-interactive behavior.
Document helper additions here and add fixture tests in `scripts/test-onboarding.sh` for new migration or symlink logic.
