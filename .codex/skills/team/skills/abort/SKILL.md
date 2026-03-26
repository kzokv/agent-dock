---
name: "team:abort"
description: "Gracefully shut down a running agent team"
---

# /team abort

Gracefully shut down all teammates in a running team. Preserves work done so far.

---

## Prerequisites

- A team must be running (check `.worklog/team/state.json` exists)

---

## Workflow

### Step 0 — Check if team is already complete

Read `.worklog/team/state.json`. If `phase` is already `"complete"`:

1. Inform the user the team has already finished
2. Run `tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index}: #{pane_title}"` to identify teammate panes (titled with role names)
3. Display the list and ask the user to confirm closing them
4. On confirmation, kill each teammate pane **in reverse index order** (to avoid index shifting), keeping pane index 1 (the main session):
   ```bash
   for pane in <N> ... 2; do tmux kill-pane -t "<session>:<window>.$pane"; done
   ```
5. Do not proceed with the rest of the abort workflow.

Do NOT kill pane index 1 — that is the main session.

### Step 1 — Confirm with user

Display current state summary (tier, phase, iteration, teammates) and ask:

```
Abort team? This will:
- Shut down all teammates
- Preserve all file changes on disk (uncommitted)
- Preserve staged memory files in .worklog/team/memory/
- Update .worklog/team/state.json to phase: "aborted"

Proceed? [y/n]
```

Wait for explicit user confirmation before proceeding.

### Step 2 — Notify Architect

Send message to the Architect:

```
[USER] Team abort requested by user. Please:
1. Send shutdown messages to all active teammates
2. Update .worklog/team/state.json with phase: "aborted"
3. Write a brief summary of progress so far to .worklog/team/abort-summary.md
4. Send [SHUTDOWN] when done
```

### Step 3 — Wait for Architect shutdown

Wait for the Architect's `[SHUTDOWN]` message. If no response within 2 minutes, proceed to Step 4 anyway.

### Step 4 — Force cleanup (if Architect unresponsive)

If the Architect did not respond:
1. Update `.worklog/team/state.json` directly: set `phase: "aborted"`, `updated_at` to now
2. Inform the user that the Architect was unresponsive and teammates may still be running in tmux panes

### Step 5 — Report to user

```
## Team Aborted

**Phase at abort:** [phase]
**Iteration at abort:** [iteration]
**Progress:** [brief summary from abort-summary.md or state.json]

### File changes preserved
All uncommitted changes remain on disk. You can:
- Review with `git diff`
- Continue manually
- Reset with `git checkout .` (destructive)

### Staged memory
Memory candidates in `.worklog/team/memory/` are preserved.
Run consolidation manually if needed.
```
