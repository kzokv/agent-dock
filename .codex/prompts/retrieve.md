# Retrieve

## Purpose
Use the shared RLM retrieval scaffold to answer a repository question without loading broad repo context into the active prompt.

## Body
Answer the current repository question with the local retrieval catalog first.

Repository root defaults to the current working directory unless the user explicitly gives another path.

Use `python3 ~/.codex/scripts/rlm_retrieval.py`.

Workflow:
1. Run `status --repo <repo> --json`.
2. If the catalog is missing, run `build --repo <repo> --json`.
3. If `status.stale` is `true` and the question depends on current repo edits, run `build --repo <repo> --force --json` and say that the catalog was refreshed manually.
4. Start a retrieval session with `session-start --repo <repo> --json`.
5. If `session-start` returns `persisted: false`, continue without `--session` and note that scratch-session persistence was unavailable in the current environment.
6. Run `query --repo <repo> --question "<user question>" --limit 6 [--session <session>] --json`.
7. Inspect only the top 1-3 most relevant handles first.
8. Use `peek` for exact chunk slices.
9. Use `expand` only when you need one-hop related files such as `skill -> script`, `doc -> referenced file`, or similar explicit references.
10. Use `summarize` only for the selected handles you actually inspected.
11. Answer from the inspected handles. Do not broaden to whole-repo reads unless the bounded retrieval path is insufficient.

Rules:
- Keep retrieval bounded. Do not open many files just because they were candidates.
- Prefer `peek` before full-file reads.
- Do not auto-refresh on every use. Refresh only when the catalog is missing or stale and the freshness matters to the answer.
- Report which handles were inspected.
- Report whether the catalog was already fresh, was stale but reused, or was manually refreshed.
- If scratch-session persistence is unavailable, say so and continue without it.
- Separate verified facts from inference.

## Output Format
## Catalog
- repo
- fresh/stale status
- whether a manual refresh was performed

## Retrieval
- query used
- handles inspected
- whether any one-hop expansion was used

## Answer
Direct answer grounded in the inspected handles.

## Limits
- anything not verified from the retrieved handles
