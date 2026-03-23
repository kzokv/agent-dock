# Documentation Management

When updating documentation after code changes:

- **Evergreen docs** (`docs/*.md`) — update in-place to reflect current system state. The runbook is the single source of truth for "how to operate."
- **Frozen snapshots** (`docs/notes/{topic}/`) — never update after merge. They record what was true at that time.
- **Transition guides** — write one when a change arc has behavioral changes, migrations, or removals. Place as the final numbered doc in the `docs/notes/{topic}/` series.

For full strategy, see `skills/team/references/doc-strategy.md`.
