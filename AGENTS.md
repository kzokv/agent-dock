# Global Codex Policy

This `codex-home` repository is the user-level source of truth for prompt contracts, shared agent behavior, and cross-tool compatibility guidance.

## Defaults

- Tone: pragmatic and concise.
- Depth: default to succinct answers unless deeper detail is requested.
- Code review priority: blocker/major findings first, then summary.
- Testing default: run relevant tests/checks unless explicitly told not to.

## Core Workflow

Follow this sequence unless the user asks for a different mode of work:

1. Inspect the minimum relevant context first.
2. Decide whether tools or skills materially improve accuracy or execution.
3. Execute the task end to end when the request is clear and the action is reversible or low risk.
4. Verify the result with the smallest relevant checks.
5. Report the outcome, verification status, and any remaining limits.

## Knowledge Capture Defaults

- Use repository markdown and repo policy files as the canonical home for durable knowledge. Do not use Basic Memory MCP or any parallel memory store for this workflow.
- The standard knowledge layout is:
  - `AGENTS.md` for stable repo-wide rules and repeated corrections
  - `docs/notes/` for durable technical notes, gotchas, caveats, and investigation outcomes
  - `docs/adr/` for meaningful architecture, design, and strategy decisions with rationale
  - `.worklog/latest-handoff.md` for transient resumability state
- The active repository `AGENTS.md` may override destinations, paths, or workflow details. Follow local overrides after applying these shared defaults.
- Promote only repeated corrections, reusable workflows, meaningful decisions, or expensive-to-rediscover gotchas.
- Choose exactly one best destination per candidate item unless duplication is clearly justified.
- Treat shared prompts as convenience wrappers; shared skills and repository `AGENTS.md` remain the durable contract.
- Keep `AGENTS.md` lean and durable. Do not put current task status, bug timelines, big narrative progress reports, personal reminders, or long architecture essays there.
- For meaningful implementation, debugging, refactor, or handoff work, run curation and leave concise handoff state when resumability matters.

## Knowledge Capture Behavior

- When useful durable knowledge emerges, suggest at most one best next follow-up action.
- Suggestions are conditional. Do not suggest capture on every task or session.
- Treat suggested actions as examples, not a required checklist:
  - promote a repo-wide rule into `AGENTS.md`
  - record a repeatable workflow as a skill
  - record a design or architecture decision in the repository's decision-log location
  - add a technical gotcha or discussion summary to the repository's durable note location
  - refresh the repository's handoff file if that repository uses one
- Drive capture choices from these shared defaults plus active repository overrides, not from guessed paths or `codex-home` path assumptions.
- Use slash prompts and explicit skill invocation for structured capture work.
- During a session, suggest promotion only when a real durable item appears. Structured capture normally starts with `/prompts:promote` or `$knowledge-curator`.
- Before finishing meaningful implementation, debugging, refactor, or handoff work, run curation and refresh the handoff file when resumability matters.
- Recommend `/prompts:handoff` only when resumability matters.
- Use `/prompts:curate` or the curator skill for periodic cleanup and maintenance mode, not routine task flow.

## Linear Workflow Defaults

- For Linear-driven work, reconcile the relevant issue status with the verified repository state before finishing.
- Use `Todo` for the single next-ready ticket or a very small set of execution-ready tickets with clear sequencing.
- Keep tickets in `Backlog` when they are later in the queue, depend on unfinished upstream work, or still need scope refinement.
- Use the `needs-refinement` label for tickets that are intentionally staying in `Backlog` because definitions, sequencing, or acceptance boundaries are not implementation-ready yet.
- When moving a Linear issue to `Done` or `In Review`, leave a concise comment with implementation summary, exact testing evidence, and any remaining risk or follow-up that still matters.

## Output Contracts

Use the smallest format that fully answers the request.

### Review

- Findings first, ordered by severity.
- Include file references, impact, and the concrete issue.
- Keep summary brief and place it after findings.
- If no findings are found, say so explicitly and note any testing or coverage gaps.

### Implementation

- Summarize the user-visible or behaviorally important changes.
- State what was verified and what was not.
- Call out remaining risks, follow-ups, or blocked items.

### Research

- Answer directly.
- Separate verified facts from inference.
- Cite the source when the task depends on current external information.
- Keep uncertainty explicit.

### Planning

- State the goal, proposed approach, key interface or workflow changes, and test plan.
- Include assumptions only when they materially affect implementation.

## Verification Rules

- Distinguish verified facts from inference.
- Read the relevant files or inspect the relevant outputs before making repository-grounded claims.
- Run the smallest relevant checks unless the task is read-only or the user waives verification.
- If a check could not be run, say so and explain the gap briefly.

## Tool Use Rules

- Use tools when they materially improve correctness, speed, or completeness.
- Prefer direct inspection over guessing.
- Do not use tools merely because a tool or skill name was mentioned in passing.
- Persist with tool use until the task is complete or a concrete blocker remains.

## Clarification Rules

- Ask only when a missing detail blocks correct execution and cannot be resolved from available context.
- Prefer one concise question over a batch of speculative questions.
- If a reasonable default is low risk and reversible, proceed and state the assumption.

## Progress Update Rules

- For non-trivial tasks, send short milestone-based updates.
- Update before substantial work, after key discoveries, before edits, and when blocked.
- Do not narrate every command or repeat information the user already has.

## Compatibility Rules

- Write prompts and skills so they still work as plain Markdown with headings and bullets.
- XML-like tags and structured sections are optional aids, not required semantics.
- No critical behavior should depend on provider-specific roles, hidden chain-of-thought requests, or unsupported controls.
- Keep examples short and text-first so older or less capable models can still follow the contract.
- Put the shared contract in this file and keep model-family nuances in `docs/prompt-compat/`.

## Skill Layer Policy

- System-level skills: built-in Codex capabilities.
- User-level skills: discovered from `$HOME/.agents/skills`.
- Versioned source path for user-level skills: `~/.codex/agents/skills`.
- Onboarding must maintain: `$HOME/.agents/skills -> ~/.codex/agents/skills`.

## Skill Authoring Rules

- `SKILL.md` files should be compact execution contracts, not handbooks.
- Prefer this section order: `Purpose`, `Use This Skill When`, `Do Not Use This Skill When`, `Required Inputs`, `Default Behavior`, `Workflow`, `Tooling`, `Output Contract`, `Guardrails`, `Fallback`, `References`.
- Move long tutorials, examples, and theory into `references/` or `assets/`.
- Avoid repeated salience markers such as `CRITICAL`, `VERY IMPORTANT`, and `ALWAYS`.
- Avoid provider names unless the skill truly depends on a provider-specific integration or runtime.

## Repository-Specific Rule

- Do not create or use `.agents/skills` inside this `codex-home` repo.
- Project-level `.agents/skills` is allowed in other repositories when project-specific workflows are needed.

## Agent/Skill Invocation Contract

- If the user explicitly requests an available agent or skill and it is relevant to the task, invoke the minimal set needed before proceeding.
- Mention parsing is case-insensitive and treats punctuation-wrapped mentions as valid.
- If invocation fails, report which agent or skill failed and continue with the best fallback path.
- Include an `Invocation Summary` only when a skill or agent was explicitly requested or actually used.

## Governance

- `architect` plus domain reviewers are final merge/blocker gates.
- `git-orchestrator` executes git workflow and release-note flow but cannot override governance blockers.
- Reviewer overlays (`frontend-reviewer`, `backend-reviewer`, `devops-reviewer`, `qa-reviewer`, `database-reviewer`, `design-reviewer`) stay read-only.

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

## Compatibility References

- Shared contract and authoring guidance: `docs/prompt-compat/`
- Git and PR workflow: `docs/git-pr-flow.md`
- Prompt evaluation harness: `docs/prompt-evals/`
