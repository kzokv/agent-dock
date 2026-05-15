# Documentation Management

## Document locations and lifecycles

| Location | Lifecycle | Version-controlled? | Purpose |
|---|---|---|---|
| `docs/*.md` | **Evergreen** — update in-place | Yes | Single source of truth for "how to operate" |
| `docs/notes/{slug}/` (or project variant) | **Frozen** — never update after merge | Yes | Durable records: debate notes, scope todos, decision snapshots |
| `.worklog/` | **Ephemeral** — may be cleaned up | No (gitignored) | Runtime state, handoff artifacts, session-scoped notes |
| `.claude/memory/` | **Curated** — maintained via `/si:*` skills | Yes | Durable agent memory |

## Rules

- **Evergreen docs** (`docs/*.md`) — update in-place to reflect current system state.
- **Frozen snapshots** — never update after merge. They record what was true at that time. The default location is `docs/notes/{slug}/`, but projects may use variants (e.g. `docs/004-notes/`, `docs/0-notes/`). Before writing, scan for existing notes directories matching patterns like `docs/*notes*/`, `docs/*-notes/`, or numbered variants. Use `{slug}` subdirectories (e.g. `kzo-109-110/`) to co-locate related artifacts for the same ticket or topic. **All** new files under the notes directory must use datetime naming for chronological ordering: `{type}-{YYYYMMDDHHmm}-{short-desc}.md` (e.g. `debate-202603241430-initial-schema.md`, `scope-todo-202603241445-initial.md`, `adr-202603251600-cache-strategy.md`). This applies to any frozen snapshot type — debates, todos, ADRs, troubleshooting notes, etc.
- **Transition guides** — write one when a change arc has behavioral changes, migrations, or removals. Place as the final numbered doc in the `docs/notes/{slug}/` series.
- **Ephemeral artifacts** (`.worklog/`) — runtime state, debate briefs/results, session-scoped notes. Not version-controlled. Skills should remind the user of this lifecycle when offering `.worklog/` as a save location.

For full strategy, see `skills/team/references/doc-strategy.md`.

## Pre-merge correction window for frozen snapshots

**"Frozen — never update after merge"** refers to the post-merge state. Pre-merge corrections to transition notes and scope-todos are encouraged — precisely because they prevent the historical record from inheriting known inaccuracies.

The rule is: once a frozen snapshot is merged to the main branch, it is immutable. Until then, prose corrections, factual fixes, and property-name typos should be addressed in the same PR before it lands.

**Practical guidance:**
- Transition note has a typo caught in Wave 2 docs review → fix it in the same PR, no new file needed.
- Scope-todo checkbox was missed → flip it in the same PR.
- An ADR has a wrong table value discovered before merge → correct it in place.

Do NOT create a follow-up "errata" snapshot for pre-merge corrections — that would violate the single-source principle without the protection of true historical immutability.

**Why:** KZO-188 Wave 2 — Code Reviewer flagged a `liveLoadingMessage` vs `liveSearchingMessage` property-name mismatch in the transition note. The Architect ruled it a pre-merge correction (1-word fix) without routing to a new review cycle. The rule clarification was promoted to prevent future uncertainty about whether pre-merge edits violate the frozen-snapshot contract.
