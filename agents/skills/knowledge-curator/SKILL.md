---
name: knowledge-curator
description: Classify durable knowledge from the current repository context, recommend the best destination, and keep handoff state concise.
origin: ECC
---

# Knowledge Curator

## Purpose
Capture durable knowledge from meaningful work using the shared knowledge-capture contract, route it to the single best destination, and keep handoff and Linear workflow state coherent.

## Use This Skill When
- A meaningful implementation, debugging, or refactor session produced durable knowledge.
- The current repository uses the standard knowledge layout or a close variant defined by its local `AGENTS.md`.
- The user wants a structured recommendation or exact draft for how the knowledge should be captured.
- A cleanup pass is needed to trim stale `.worklog` content or move misplaced knowledge into durable docs.
- The task is Linear-driven and the issue state, handoff state, or testing evidence needs to be reconciled with verified repository state.

## Do Not Use This Skill When
- The task is trivial or read-only and produced no durable knowledge.
- The user only wants a code or plan review without changing repository knowledge files.
- The request is to archive raw conversation history or dump transcripts.

## Required Inputs
- The shared user-level `AGENTS.md` contract.
- The active repository root.
- The current session/task context.
- Existing `AGENTS.md`, `.worklog/`, `docs/notes/`, and `docs/adr/` files when present.

If the repository layout is unclear, inspect the local files first and infer the existing structure before writing.

## Default Behavior
- Read the shared user-level `AGENTS.md` first, then apply active repository `AGENTS.md` overrides.
- Use repository markdown as the canonical destination for durable knowledge.
- Prefer the standard layout unless the active repository defines a different durable destination.
- Promote only repeated corrections, reusable workflows, meaningful decisions, or expensive-to-rediscover gotchas.
- Choose exactly one best destination per candidate item unless duplication is clearly justified.
- Use this routing model consistently:
  - `AGENTS.md` for repeated repo-wide guidance or corrections likely to recur
  - `docs/notes/` for durable technical learnings, gotchas, caveats, and discussion outcomes
  - `docs/adr/` for architecture or design decisions with rationale and consequences
  - `.worklog/latest-handoff.md` for transient resumability state
  - a skill for reusable stepwise workflows that should become a repeatable operating pattern
- Default to recommending the best destination and drafting a concise update.
- Write small, targeted updates when explicitly invoked for implementation work.
- Refresh `.worklog/latest-handoff.md` only when resumability matters.
- For Linear-driven work, reconcile issue state with verified repository state and call out the required `Done` or `In Review` comment evidence when relevant.

## Workflow
1. Inspect the shared user-level `AGENTS.md`, then the active repository's `AGENTS.md`, `.worklog/`, `docs/notes/`, and `docs/adr/` structure before drafting anything.
2. Identify candidate items from the current task or maintenance pass.
3. Filter out noise, transient chatter, and items that do not meet the promotion threshold.
4. Classify each remaining item into exactly one best destination:
   - `AGENTS.md` for repeated repo-wide guidance or corrections likely to recur
   - `docs/notes/...` for durable technical learnings, gotchas, caveats, and discussion outcomes
   - `docs/adr/...` for architecture or design decisions with rationale and consequences
   - `.worklog/latest-handoff.md` for transient resumability state
   - a skill candidate for reusable stepwise workflows that should become a repeatable operating pattern
5. If the task is Linear-driven, check for issue-state, evidence, or close-out mismatches against the verified repository state.
6. If nothing meets the threshold, say so explicitly and avoid forced promotion.
7. Draft concise updates that fit the destination's purpose.
8. Apply small, targeted file updates when the user invoked the skill for implementation; otherwise provide exact drafts.
9. Summarize what changed, what was intentionally left unpromoted, and any follow-up recommendations.

## Tooling
- Repository files: `AGENTS.md`, `.worklog/`, `docs/notes/`, `docs/adr/`
- Shared convenience wrappers: `~/.codex/prompts/promote.md`, `~/.codex/prompts/note.md`, `~/.codex/prompts/decision.md`, `~/.codex/prompts/handoff.md`, `~/.codex/prompts/curate.md`

## Output Contract
Return:
- The verified context that was inspected.
- The candidate items that qualified for promotion.
- The chosen destination for each promoted item.
- The best next capture action when no file update is requested.
- Any Linear workflow mismatch or confirmation that no mismatch remains.
- The exact files updated or the exact drafts proposed.
- Any important item intentionally left out because it did not meet the threshold.
- Verification status for the changes made.

## Guardrails
- Do not dump raw transcript content into repository files.
- Do not perform broad rewrites of docs or policy files without a concrete need.
- Do not create ADRs for routine fixes or transient task status.
- Do not introduce Basic Memory MCP or any parallel memory store for this workflow.
- Keep `AGENTS.md` lean and durable.
- Keep `.worklog/` operational and current.

## Fallback
- If nothing meets the promotion threshold, say so explicitly and avoid forced updates.
- If the best destination is unclear, propose the strongest candidate and explain why.
- If the repository layout differs from the expected model, adapt to the nearest equivalent structure and record the assumption.

## References
- The shared user-level `AGENTS.md` for knowledge-capture and Linear workflow defaults.
- `AGENTS.md` in the active repository for storage and curation policy.
- Shared prompt wrappers under `~/.codex/prompts/` for prompt-specific convenience flows.
