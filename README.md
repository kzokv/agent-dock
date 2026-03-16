# codex-home

Personal coding-agent config repo shared across machines.

This repository now manages three tracked agent homes:
- `.codex` for shared policy, roles, prompts, skills, config, and support scripts
- `.cursor` for a tracked `agents` symlink to `.codex/agents` and a tracked `skills` symlink to `.codex/skills`
- `.claude` for tracked agents, rules, skills symlink, versioned memory, and base settings

`README.md` is the operator guide. The shared Codex policy source of truth lives at `.codex/AGENTS.md`.

## Layout

Tracked:
- `.codex/`
- `.cursor/`
- `.claude/`
- `.github/`
- `.githooks/`
- `docs/`
- `notes/`
- `scripts/`

Generated or machine-local:
- `.codex/config.toml`
- `.codex/config.local.toml`
- `.codex/agents/config/*.toml`
- caches
- secrets
- runtime state

## Quick start

Run onboarding:

```bash
./scripts/onboarding.sh
```

The script shows an agent-selection menu when run interactively and defaults to `all`.

For automation:

```bash
./scripts/onboarding.sh --agent codex --skip-gh-auth
./scripts/onboarding.sh --agent all
./scripts/onboarding.sh --agent cursor --without-codex-bootstrap
./scripts/onboarding.sh --agent cursor --with-codex-bootstrap --skip-gh-auth
```

If you want the Codex CLI network-enabled launcher, run onboarding with Codex bootstrap enabled and then use:

```bash
codex-net
```

After Claude onboarding, use the permission-skipping launcher:

```bash
claude-dev                                       # tmux session + claude
claude-dev --no-tmux                             # bypass tmux, run directly
CLAUDE_DEV_TMUX_SESSION=work2 claude-dev         # custom session name
```

Canonical onboarding reference:
- [`docs/onboarding.md`](/Users/lume/repos/codex-home/docs/onboarding.md)

That document is the single source of truth for:
- onboarding behavior and side effects
- config and skills topology
- script/data flow and dependency diagrams
- flag behavior for agent/bootstrap combinations
- validation and rerun semantics

## Validation and maintenance

Use:

```bash
./.codex/scripts/test-onboarding.sh
./.codex/scripts/validate-role-skill-topology.py
./.codex/scripts/check-config-migration.sh
./.codex/scripts/bootstrap-budget.sh --repo /path/to/project
python3 ./.codex/scripts/rlm_retrieval.py build --repo /path/to/project
python3 ./.codex/scripts/run_bootstrap_evals.py --target-repo /path/to/project --json
./.codex/scripts/install-required-skills.sh
./.codex/scripts/setup-git-hooks.sh
```

## Policy and merge gates

Shared policy source: `.codex/AGENTS.md`
Operator runbook: `docs/git-pr-flow.md`

Repo enforcement points:
- `.github/pull_request_template.md`
- `.github/workflows/pr-gate.yml`
- `.githooks/commit-msg`
