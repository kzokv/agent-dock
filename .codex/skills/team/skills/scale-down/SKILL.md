---
name: "team:scale-down"
description: "Remove teammates from a running team by downgrading to a lower tier"
---

# /team scale-down

Remove teammates from a running team mid-execution by downgrading to a lower tier.

---

## Prerequisites

- A team must be running (check `.worklog/team/state.json` exists)
- Current tier must be greater than 1

---

## Workflow

### Step 1 — Read current state

Read `.worklog/team/state.json` to determine:
- Current tier
- Current phase and iteration
- Use `TaskList` to see which teammates are active/idle and what they're working on

### Step 2 — Safety check

Do NOT scale down if:
- A teammate that would be removed is actively working on a task — wait for it to complete or ask the user to confirm termination
- The team is in Phase 4 (Fix) — the Fixer may be mid-repair

If blocked, report why and ask the user how to proceed.

### Step 3 — Determine target tier

If the user specified a tier (e.g., `/team scale-down tier-1`), use that.
Otherwise, scale down by one tier (Tier 3 → 2, Tier 2 → 1).

### Step 4 — Identify removed teammates

| From → To | Teammates removed / not spawned |
|-----------|--------------------------------|
| Tier 3 → 2 | Technical Writer, Memory Curator — if not yet spawned (Wave 2), they are simply skipped; if already running, they are shut down |
| Tier 3 → 1 | Technical Writer, Memory Curator (skipped/shut down), Fixer, Code Reviewer (shut down) |
| Tier 2 → 1 | Fixer (Sonnet), Code Reviewer (Sonnet) |

Note: QA runs on Opus at all tiers — no model swap needed during scale-down.

### Step 5 — Relay to Architect

Send the scale-down information to the Architect via `[USER]`:

```
[USER] Scale-down approved: Tier N → Tier M. Removing: [list]. Please shut down removed teammates and adjust workflow.
```

The Architect:
1. Sends shutdown messages to removed teammates via `SendMessage`
2. Reassigns any open tasks from removed teammates
3. Adjusts the convergence loop (e.g., at Tier 1: skip Code Review in Phase 3, Implementer fixes own failures)
4. Updates `.worklog/team/state.json` with the new tier

### Step 6 — Confirm

Report to the user:
```
Scaled down: Tier N → Tier M
Removed teammates: [list]
Workflow adjusted.
```
