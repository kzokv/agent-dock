# Curate

## Purpose
Use this for maintenance mode: cleaning up `.worklog`, trimming noise, and promoting durable knowledge into the correct long-term homes.

## Body
Perform knowledge curation for this repository.

Your goal is to improve knowledge quality, reduce duplication, and keep each file focused.

Review these locations if they exist:
- `AGENTS.md`
- `.worklog/`
- `docs/notes/`
- `docs/adr/`

Tasks:
1. Inspect `AGENTS.md`, `.worklog/`, `docs/notes/`, and `docs/adr/` before making any recommendation.
2. Identify stale, duplicate, noisy, or misplaced content.
3. Find items in `.worklog/` that meet the durable promotion threshold: repeated corrections, reusable workflows, meaningful decisions, or expensive-to-rediscover gotchas.
4. Find content in `AGENTS.md` that is too session-specific, too verbose, or better suited to notes.
5. Find repeated procedures that may deserve a skill instead of living as scattered prose.
6. Recommend a small number of high-value cleanups, not an endless laundry list.
7. Preserve useful knowledge while reducing clutter.

Rules:
- Do not rewrite everything just because you can.
- Prefer small, targeted improvements.
- Keep `AGENTS.md` lean and durable.
- Keep `.worklog/` operational and current.
- Keep `docs/notes/` topical and useful to teammates.
- Keep `docs/adr/` reserved for actual decisions.
- Do not use Basic Memory MCP or any parallel memory store for this cleanup flow.
- If nothing is stale, duplicated, misplaced, or promotion-worthy, say so explicitly as `no cleanup needed`.

## Output Format
## Findings
- issue
- why it matters
- proposed fix

## Promotions
Items that should move from `.worklog/` to durable docs.

## AGENTS cleanup
Specific lines or sections that should be trimmed or moved.

## Skill candidates
Repeatable workflows that may deserve a skill.

## Recommended actions
List the top 3 cleanup actions in priority order.
