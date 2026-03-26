---
name: "team-v2:status"
description: "Show current state of a running v2.2.0 agent team"
---

# /team status

Display the current state of a running agent team without interrupting execution.

---

## Prerequisites

- A team must be running (check `.worklog/team/state.json` exists)

---

## Workflow

### Step 1 — Read state

Read `.worklog/team/state.json` and extract:
- Current tier, phase, iteration
- Wave (1 or 2)
- Branch name
- Exit check status

### Step 2 — Read teammate status

From `state.json`'s `teammates` object, build a roster table showing each teammate's:
- Name
- Model
- Status (`active`, `idle`, `done`, `unresponsive`)
- Last activity timestamp

Also check `TaskList` for assigned and completed tasks.

### Step 3 — Read recent escalations

Pull the last 3 entries from `state.json`'s `escalations` array (if any).

### Step 4 — Read phase history

Pull the last 5 entries from `state.json`'s `phase_history` array to show recent phase transitions.

### Step 5 — Display report

```
## Team Status

**Task:** [task description]
**Tier:** N ([Solo/Squad/Full Team])
**Branch:** [branch name]
**Phase:** [current phase] | **Iteration:** N / max
**Wave:** [1 or 2]

### Exit Check
- Tests green: [yes/no]
- Findings addressed: [yes/no]
- No regressions: [yes/no]

### Teammates
| Name | Model | Status | Last Activity |
|------|-------|--------|---------------|
| architect | opus | active | 2 min ago |
| tdd-implementer | opus | active | 30s ago |
| ... | ... | ... | ... |

### Tasks
- [N] completed, [M] in progress, [K] pending

### Recent Escalations
- [timestamp] [reason] — [outcome]

### Cost
- Estimated: $X-Y
```

### Step 6 — No side effects

This command is read-only. Do NOT send messages to teammates, modify state, or interrupt the convergence loop.
