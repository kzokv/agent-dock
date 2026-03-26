---
name: "team-v2:scale-up"
description: "Add teammates to a running v2.2.0 team by upgrading to a higher tier"
---

# /team scale-up

Add teammates to a running team mid-execution by upgrading to a higher tier.

---

## Prerequisites

- A team must be running (check `.worklog/team/state.json` exists)
- Current tier must be less than 3

---

## Workflow

### Step 1 — Read current state

Read `.worklog/team/state.json` to determine:
- Current tier
- Current phase and iteration
- Use `TaskList` to see which teammates are active/idle

### Step 2 — Determine target tier

If the user specified a tier (e.g., `/team scale-up tier-3`), use that.
Otherwise, scale up by one tier (Tier 1 → 2, Tier 2 → 3).

### Step 3 — Identify new teammates

Compare current roster against the target tier's roster (from `references/role-definitions.md`):

| From → To | New teammates added |
|-----------|---------------------|
| Tier 1 → 2 | Fixer (Sonnet), Code Reviewer (Sonnet) |
| Tier 1 → 3 | Fixer, Code Reviewer, Technical Writer, Memory Curator |
| Tier 2 → 3 | Technical Writer (Sonnet), Memory Curator (Sonnet) |

Note: QA runs on Opus at all tiers — no model swap needed during scale-up.

### Step 4 — Relay spawn request to Architect

Send the scale-up information to the Architect via `[USER]`:

```
[USER] Scale-up approved: Tier N → Tier M. New teammates: [list]. Please send [SPAWN] when ready to incorporate.
```

The Architect decides when to incorporate new teammates:
- If in Phase 1-2: incorporate at the next natural phase boundary
- If in Phase 3-4: incorporate immediately for the next iteration

The Architect sends `[SPAWN]` to the main session with the new teammate roster. The main session spawns them using the standard `[SPAWN]` handling flow.

### Step 5 — Update state

The Architect updates `.worklog/team/state.json` with the new tier.

### Step 6 — Confirm

Report to the user:
```
Scaled up: Tier N → Tier M
New teammates: [list with tmux pane names]
Incorporating at next phase boundary.
```
