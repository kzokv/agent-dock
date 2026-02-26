# Global Codex Policy

This `codex-home` repository is the user-level source of truth for Codex behavior shared across machines.

## Defaults

- Tone: pragmatic and concise.
- Depth: default to succinct answers unless deeper detail is requested.
- Code review priority: blocker/major findings first, then summary.
- Testing default: run relevant tests/checks unless explicitly told not to.

## Skill Layer Policy

- System-level skills: built-in Codex capabilities.
- User-level skills: discovered from `$HOME/.agents/skills`.
- Versioned source path for user-level skills: `~/.codex/agents/skills`.
- Onboarding must maintain: `$HOME/.agents/skills -> ~/.codex/agents/skills`.

## Repository-Specific Rule

- Do not create or use `.agents/skills` inside this `codex-home` repo.
- Project-level `.agents/skills` is allowed in other repositories when project-specific workflows are needed.

## Governance

- `architect` plus domain reviewers are final merge/blocker gates.
- `git-orchestrator` executes git workflow and release-note flow but cannot override governance blockers.
- Reviewer overlays (`frontend-reviewer`, `backend-reviewer`, `qa-reviewer`, `database-reviewer`, `design-reviewer`) stay read-only.

## Agent/Skill Invocation Contract

- If the user explicitly names an available agent or skill (`$name`, `@name`, or plain name), the main agent MUST invoke it in the same turn before proceeding.
- Mention parsing is case-insensitive and treats punctuation-wrapped mentions as valid (for example: `"$qa-reviewer"`, `(@architect)`).
- If multiple named agents/skills are requested, invoke the minimal set that covers the request and state execution order in one short line.
- If invocation fails (tool error, unavailable role, permission block), explicitly report which agent/skill failed and continue with the best fallback path.
- Final response MUST include a short `Invocation Summary` listing requested agents/skills, actually invoked agents/skills, and any skipped items with reason.

## Required Git/PR Gate

Before merge, all of the following are required:

- Commit messages follow `type(scope): subject` (Conventional Commits style).
- PR title follows `type(scope): subject` (Conventional Commits style).
- PR description includes all sections: `Problem`, `Solution`, `Testing`, `Risk/Rollback`.
- PR has an assignee and a primary label that matches PR content (`bug`, `enhancement`, or `documentation`).
- Relevant tests/checks are run for changed scope unless explicitly waived by the requester.
- `## Testing` must include either:
  - `Evidence:` with concrete commands/checks and outcomes, or
  - `Waiver:` with requester-approved reason and approver.
- `architect` plus applicable domain reviewers remain final blocker/merge gates.

Operator runbook (single source of truth): `docs/git-pr-flow.md`.
