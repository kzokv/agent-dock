# agent-dock

A shared, forkable policy and skills monorepo for AI coding agents. Agent-dock is the
canonical source of truth for global settings, behavioral policies, skills, prompts, and
role definitions consumed by multiple agent tools (Claude Code, Cursor, Codex, and more).

Agents dock here, load their config, and go work in other projects.

## How it works

1. Clone or fork this repo
2. Run `./scripts/onboarding.sh` to wire agent-dock into your system
3. Onboarding creates symlinks so each agent tool reads from this repo at runtime:
   - `~/.codex` → `.codex/` (shared policy, skills, roles, prompts)
   - `~/.claude` → `.claude/` (Claude Code config, rules, memory)
   - `~/.cursor` agents/skills → `.codex/` equivalents
   - `~/.agents/skills` → `~/.codex/skills`
4. A provenance pointer (`~/.codex/ORIGIN`) tells agents where their config comes from
5. The agent-readable manifest (`~/.codex/MANIFEST.md`) gives any agent full context

## Layout

Tracked:

| Directory | Purpose |
|---|---|
| `.codex/` | Shared policy, roles, prompts, 74+ skills, config, scripts |
| `.claude/` | Claude Code agent home (rules, memory, settings) |
| `.cursor/` | Cursor agent home (agents/skills symlinks) |
| `scripts/` | Onboarding orchestrator and shared helpers |
| `docs/` | Onboarding reference, git-pr-flow runbook, prompt compatibility |

Generated or machine-local: `.codex/config.toml`, `.codex/agents/config/*.toml`, caches, secrets, runtime state.

## Quick start

```bash
# Interactive (shows agent-selection menu)
./scripts/onboarding.sh

# Target a specific agent
./scripts/onboarding.sh --agent claude
./scripts/onboarding.sh --agent cursor
./scripts/onboarding.sh --agent codex
./scripts/onboarding.sh --agent all

# Automation mode
./scripts/onboarding.sh --agent all --skip-gh-auth
./scripts/onboarding.sh --agent cursor --with-codex-bootstrap
./scripts/onboarding.sh --agent codex --upgrade-codex
```

After onboarding, use the launchers:

```bash
claude-dev                              # tmux session + Claude Code
claude-dev --no-tmux                    # bypass tmux, run directly
codex-net                               # Codex with network-enabled sandbox
```

## For agents

If you are an AI agent reading this, your full context is at `~/.codex/MANIFEST.md`.
That document contains: repo structure, skills catalog, policy summary, onboarding
mechanics, and per-tool integration notes.

The repo path is stored in `~/.codex/ORIGIN`.

## Customizing your fork

1. **Policies** — edit `.codex/AGENTS.md` for global defaults
2. **Skills** — add or modify skills in `.codex/skills/`
3. **Rules** — add Claude-specific rules in `.claude/rules/`
4. **Roles** — define team roles in `.codex/agents/role-*.md`
5. **Prompts** — customize decision/retrieval flows in `.codex/prompts/`

Re-run `./scripts/onboarding.sh` after changes to re-wire symlinks. Codex bootstrap
validates an existing CLI with `codex --version` and automatically reinstalls the
latest npm package when the CLI is missing or unhealthy. Pass `--upgrade-codex` to
force an upgrade even when the current CLI is healthy.

## Validation and maintenance

```bash
./.codex/scripts/test-onboarding.sh                          # onboarding regression tests
./.codex/scripts/validate-role-skill-topology.py              # topology validation
./.codex/scripts/check-config-migration.sh                    # config migration check
./.codex/scripts/bootstrap-budget.sh --repo /path/to/project  # bootstrap cost report
./.codex/scripts/install-required-skills.sh                   # install required skills
./.codex/scripts/setup-git-hooks.sh                           # enable commit-msg hooks
```

## Policy and merge gates

- Shared policy: `.codex/AGENTS.md`
- Agent manifest: `.codex/MANIFEST.md`
- Operator runbook: `docs/git-pr-flow.md`
- Onboarding reference: `docs/onboarding.md`
- CI enforcement: `.github/workflows/pr-gate.yml`, `.githooks/commit-msg`
