# Note

## Purpose
Use this when you already know something belongs in durable notes and want Codex to draft or update the right note file.

## Body
Turn the important knowledge from the current task or session into a durable technical note.

Rules:
1. Write for teammates who were not present in the session.
2. Capture useful technical knowledge, not chat residue.
3. Prefer `docs/notes/` over `AGENTS.md` unless this is clearly a stable repo-wide rule.
4. Do not create an ADR unless this is a meaningful design or architecture decision.
5. Keep the note concise, structured, and easy to scan.

Tasks:
1. Inspect the most likely target note files under `docs/notes/` before drafting anything.
2. Determine the most appropriate target file under `docs/notes/`.
   Examples:
   - `docs/notes/debugging-gotchas.md`
   - `docs/notes/platform-quirks.md`
   - `docs/notes/test-infra.md`
   - `docs/notes/technical-discussions.md`
3. If a matching topic already exists, merge into that note instead of drafting a parallel note.
4. If the best file does not exist, propose a sensible new file name.
5. Draft the note content or patch.
6. Prefer one durable note update over multiple overlapping notes unless there is a concrete reason to split them.

Preferred structure:
## Topic
### Context
### What we learned
### Practical implication
### Follow-up or caution

## Output Format
## Recommended file
`path/to/file.md`

## Reason
Why this file is the best destination.

## Draft update
Provide the exact markdown to add or revise.
