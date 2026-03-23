# agent-dock

Shared AI agent policy and skills monorepo. For the full agent-readable manifest
(repo structure, skills catalog, policies, onboarding, per-tool notes), read
`~/.codex/MANIFEST.md`. Provenance pointer: `~/.codex/ORIGIN`.

Shared policy source of truth: `.codex/AGENTS.md`.

## Repo Structure

- `.codex/` -- shared policy, roles, prompts, skills, config, and support scripts
- `.cursor/` -- tracked agents and skills symlinks for Cursor
- `.claude/` -- tracked agents, rules, skills symlink, versioned memory, and base settings
- `scripts/` -- onboarding orchestrator and shared helpers
- `docs/` -- onboarding reference, prompt compatibility, git-pr-flow, retrieval

## Key References

- Shared agent policy: `.codex/AGENTS.md`
- Prompt compatibility: `docs/prompt-compat/`
- Git and PR workflow: `docs/git-pr-flow.md`
- On-demand retrieval: `.codex/prompts/retrieve.md`
- Onboarding docs: `docs/onboarding.md`

## Memory and Knowledge Curation

Auto-memory is version-controlled at `.claude/memory/MEMORY.md`.

Use the self-improving-agent skill for knowledge lifecycle:
- `/si:review` -- audit and maintain memory entries
- `/si:promote` -- graduate proven learnings to durable knowledge
- `/si:remember` -- capture a specific insight

Destinations: `.claude/CLAUDE.md`, `.claude/rules/`, `docs/notes/`, `docs/adr/`.

## Clarification Protocol

When a request is vague, ambiguous, or underspecified, use the AskUserQuestion tool to interview the user and build a clear spec before proceeding. Do not guess intent — ask.
