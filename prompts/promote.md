# Promote

## Purpose
Use this when you want Codex to look at the current conversation or task and decide what deserves to be persisted and where it should go.

## Body
Review the current task or session and extract only the durable, useful knowledge.

Your job:
1. Inspect the current durable destinations before drafting anything:
   - `AGENTS.md`
   - likely note destinations under `docs/notes/`
   - likely ADR destinations under `docs/adr/`
   - `.worklog/latest-handoff.md` when it exists
2. Identify lessons, rules, workflows, decisions, caveats, and handoff-worthy outcomes from the current context.
3. Classify each item into exactly one best destination using this routing rubric:
   - `AGENTS.md` only for repeated repo-wide guidance or corrections likely to recur
   - `docs/notes/` for durable technical learnings, gotchas, caveats, and discussion outcomes
   - `docs/adr/` only for architecture or design decisions with rationale and consequences
   - `.worklog/latest-handoff.md` only for transient resumability state
   - a new or existing skill only for reusable stepwise workflows that should become a repeatable operating pattern
4. Prefer promotion over duplication. Do not put the same idea in multiple places unless there is a concrete reason.
5. Keep `AGENTS.md` concise and durable. Do not place session-specific details there.
6. Do not dump raw transcript content into any file.
7. If nothing meets the durability threshold, say so explicitly as `no durable promotion needed`.
8. Draft the exact updates that should be made.

## Output Format
## Candidate items
- item
- why it matters
- best destination

## Proposed updates
For each destination, provide a concise draft.

## Suggested next action
Recommend the single best next action:
- update `AGENTS.md`
- update `docs/notes/...`
- create or update `docs/adr/...`
- refresh `.worklog/latest-handoff.md`
- create a new skill
- no durable promotion needed
