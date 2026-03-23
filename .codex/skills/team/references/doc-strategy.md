# Documentation Strategy

Rules for how the team manages documentation during and after implementation.

---

## Two document types

| Type | Location | Updates when? | Purpose |
|------|----------|--------------|---------|
| **Evergreen** | `docs/*.md` (top-level) | Every relevant code change | "How the system works right now" |
| **Frozen snapshot** | `docs/notes/{topic}/` | Written once, never updated after merge | "What changed between version X and Y" |

### Evergreen docs

- `docs/runbook.md` — single source of truth for "how to operate the system"
- `docs/backend-db-api-architecture-dossier.md` — system design reference
- `docs/web-frontend-architecture.md` — frontend architecture reference

**Rule:** When a code change affects operational behavior, the Technical Writer updates the relevant evergreen doc in-place. The evergreen doc always reflects the current state of the code.

### Frozen snapshots

- **Design docs** (`docs/notes/{topic}/01-plan.md`, `02-review.md`, etc.) — decision history
- **Implementation TODOs** (`docs/notes/{topic}/NN-implementation-todo.md`) — task tracking
- **Transition guides** (`docs/notes/{topic}/NN-transition-guide.md`) — "what changed" for humans

**Rule:** Frozen docs are never updated after the PR merges. They record what was true *at that time*. If someone asks "is this still current?", the answer is in the evergreen doc, not the frozen snapshot.

### ADRs

- `docs/adr/` — immutable architecture decision records
- Written when a non-obvious decision is made
- Never updated — if a decision is reversed, write a new ADR that supersedes the old one

---

## Transition guides

Transition guides are the capstone of a design series. They answer: "I was away for 2 weeks, what changed?"

### Structure

```markdown
# Transition Guide — {Arc Name}

> Covers: {ticket IDs}
> Date: {date}
> Status: Frozen — for current behavior, see docs/runbook.md

## What was removed
## What was added
## What's unchanged
## Before/After comparison (tables, side-by-side)
## Migration steps (what you need to do)
```

### Lifecycle

```
1. Code ships
2. Transition guide written (frozen at that point)
3. Evergreen docs updated to reflect current state
4. Future change ships → NEW transition guide in a NEW or existing series
5. Evergreen docs updated again
6. Old transition guide stays as-is (historical record)
```

### Where they live

Transition guides live in `docs/notes/{topic}/` alongside the design docs for that arc:

```
docs/notes/oauth-env-refactor/
├── 01-env-variable-refactor-plan.md
├── 02-env-refactor-team-review.md
├── ...
├── 06-kzo-103-implementation-todo.md
└── 07-transition-guide.md          ← capstone
```

When a new change arc starts, it gets its own `docs/notes/{new-topic}/` directory.

---

## Technical Writer responsibilities (Wave 2)

During wrap-up, the Technical Writer must:

1. **Update evergreen docs** — fix stale references, reflect current behavior
2. **Write transition guide** — if the change arc is significant enough (3+ tickets, behavioral changes, migration steps required)
3. **Grep for stale references** — search docs for old function names, schema names, env vars, file paths that were changed
4. **Do NOT update frozen docs** — design docs and previous transition guides stay as-is

### "Is a transition guide needed?" heuristic

Write one when ANY of these are true:
- Behavioral change: something that worked before now works differently
- Migration required: users/operators need to take action
- Multiple tickets: 3+ tickets in the arc
- Removal: something was deleted that users relied on

Skip when:
- Pure internal refactor with no behavioral change
- Single bug fix
- Test-only changes

---

## Staleness check

If a reader wonders "is this transition guide still accurate?":
1. Check the date in the header
2. Check `docs/runbook.md` for the current state
3. The transition guide is accurate for *its time period* — the runbook is accurate for *now*
