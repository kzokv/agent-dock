---
name: knowledge-curator
description: Classify durable knowledge from the current repository context, recommend the best destination, and keep handoff state concise.
origin: ECC
---

# Knowledge Curator

## Purpose
Capture durable knowledge from meaningful work and route it to the single best destination: repository policy, durable notes, ADRs, transient handoff state, or a follow-up skill candidate.

## Use This Skill When
- A meaningful implementation, debugging, or refactor session produced durable knowledge.
- The current repository uses `AGENTS.md`, `docs/notes/`, `docs/adr/`, and `.worklog/` as its knowledge stores.
- The user wants a structured recommendation or exact draft for how the knowledge should be captured.
- A cleanup pass is needed to trim stale `.worklog` content or move misplaced knowledge into durable docs.

## Do Not Use This Skill When
- The task is trivial or read-only and produced no durable knowledge.
- The user only wants a code or plan review without changing repository knowledge files.
- The repository does not use the expected knowledge layout and the user has not provided an alternative.
- The request is to archive raw conversation history or dump transcripts.

## Required Inputs
- The active repository root.
- The current session/task context.
- Existing `AGENTS.md`, `.worklog/`, `docs/notes/`, and `docs/adr/` files when present.

If the repository layout is unclear, inspect the local files first and infer the existing structure before writing.

## Default Behavior
- Use repository markdown as the canonical destination for durable knowledge.
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

## Workflow
1. Inspect the active repository's `AGENTS.md`, `.worklog/`, `docs/notes/`, and `docs/adr/` structure before drafting anything.
2. Identify candidate items from the current task or maintenance pass.
3. Filter out noise, transient chatter, and items that do not meet the promotion threshold.
4. Classify each remaining item into exactly one best destination:
   - `AGENTS.md` for repeated repo-wide guidance or corrections likely to recur
   - `docs/notes/...` for durable technical learnings, gotchas, caveats, and discussion outcomes
   - `docs/adr/...` for architecture or design decisions with rationale and consequences
   - `.worklog/latest-handoff.md` for transient resumability state
   - a skill candidate for reusable stepwise workflows that should become a repeatable operating pattern
5. If nothing meets the threshold, say so explicitly and avoid forced promotion.
6. Draft concise updates that fit the destination's purpose.
7. Apply small, targeted file updates when the user invoked the skill for implementation; otherwise provide exact drafts.
8. Summarize what changed, what was intentionally left unpromoted, and any follow-up recommendations.

## Tooling
- Repository files: `AGENTS.md`, `.worklog/`, `docs/notes/`, `docs/adr/`
- Shared convenience wrappers: `~/.codex/prompts/promote.md`, `~/.codex/prompts/note.md`, `~/.codex/prompts/decision.md`, `~/.codex/prompts/handoff.md`, `~/.codex/prompts/curate.md`

## Output Contract
Return:
- The candidate items that qualified for promotion.
- The chosen destination for each promoted item.
- The best next capture action when no file update is requested.
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
- `AGENTS.md` in the active repository for storage and curation policy.
- Shared prompt wrappers under `~/.codex/prompts/` for prompt-specific convenience flows.
