# Handoff

## Purpose
Use this before wrapping up a task or session so the next Codex session can resume quickly.

## Body
Prepare a concise, high-signal handoff for the next session.

Target file:
`.worklog/latest-handoff.md`

Goals:
1. Capture only what the next session needs in order to resume effectively.
2. Avoid repetition, narration, and transcript-like content.
3. Be explicit about what is done, what remains, and what is uncertain.
4. Make verification status explicit so the next session can distinguish done work from unverified work.

Use this structure:

```md
# Latest Handoff

## Completed
- key completed items

## Decisions
- any decisions made in this session

## Verification
### Checks run
- checks completed in this session

### Checks not run
- checks intentionally skipped or still pending

### Known gaps
- anything implemented but not yet validated

## Next steps
- the most likely next actions

## Risks or blockers
- anything likely to slow or derail progress

## Open questions
- unresolved questions that matter

## Relevant files
- list of paths that the next session should inspect first
```

Tasks:
1. Inspect `.worklog/latest-handoff.md` if it exists before drafting a replacement.
2. Infer the most useful handoff from the current context.
3. If no meaningful resumability value remains, say so explicitly and keep the handoff minimal.
4. Keep it short and operational.
5. If there is already a `.worklog/latest-handoff.md`, produce an update that replaces stale content instead of blindly appending.

## Output Format
## Recommended update
Provide the exact markdown for `.worklog/latest-handoff.md`

## Resume suggestion
One short paragraph telling the next session where to start.
