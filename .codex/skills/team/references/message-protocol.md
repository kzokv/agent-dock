# Message Protocol

Inter-agent communication protocol for team execution. Uses a **hybrid model** with two channels: a durable channel (TaskUpdate/TaskCreate/TaskList) for critical-path signals, and a hint channel (SendMessage) for notifications and conversational messages.

---

## Durable channel — TaskUpdate / TaskCreate / TaskList

All phase-transition signals use the task system. These are the messages that, if lost, stall the entire team.

| Signal | Who | How |
|--------|-----|-----|
| Assign work | Architect/Dispatcher → Teammate | `TaskCreate` with description + `TaskUpdate` to set owner |
| `[GO]` (start phase) | Architect (Tier 1) or Dispatcher (Tier 2-3) → Teammate | `TaskUpdate` on the target task (e.g., set status to `in_progress` with a note) |
| `[DONE:CLEAN]` | Teammate → Architect/Dispatcher | `TaskUpdate(status: "completed", result: "CLEAN")` |
| `[DONE:FINDINGS]` | Teammate → Architect/Dispatcher | `TaskUpdate(status: "completed", result: "FINDINGS: ...")` |
| `[BLOCKED]` | Teammate → Architect/Dispatcher | `TaskUpdate(status: "blocked", result: "BLOCKED: ...")` |

**Why durable:** `TaskUpdate` writes to persistent state. `TaskList` reads it back reliably regardless of whether the recipient was busy at write time.

**MANDATORY:** Every teammate MUST call `TaskUpdate` for every status change. This is a gate, not guidance. The team's state machine depends on TaskUpdate to detect phase completions. Do NOT rely on SendMessage alone for critical-path signals.

---

## Hint channel — SendMessage

After any `TaskUpdate`, the sender also fires a minimal SendMessage hint. The hint is **non-authoritative** — the recipient never trusts it alone; it always reads `TaskList` as ground truth.

**Hint format (minimal):**

```
[DONE] check TaskList
[BLOCKED] check TaskList
```

The hint's only purpose is to wake the Architect (Tier 1) or Dispatcher (Tier 2-3) immediately so it doesn't have to wait for the next poll cycle. If the hint gets swallowed, the poll catches it.

**SendMessage-only messages (no TaskUpdate needed):**

| Prefix | Direction | Meaning |
|--------|-----------|---------|
| `[STATUS]` | Architect/Dispatcher → Main | Phase transition, iteration progress |
| `[ESCALATE]` | Architect → Main | Needs user decision |
| `[SPAWN]` | Architect → Main | Needs new teammates spawned |
| `[SHUTDOWN]` | Architect → Main | All green, team done |
| `[HEARTBEAT]` | Architect/Dispatcher → Main | Still alive (every 10 min of silence) |
| `[FORCE_STOP]` | Architect → Main | Auto-force-stopped stuck task |
| `[USER]` | Main → Architect | Relaying user message |
| `[QUESTION]` | Teammate → Architect | Needs clarification |
| `[CYCLE]` | Teammate → Architect | Repeat failure detected (any domain agent during self-fix) |
| `[TRIAGE]` | Architect → Dispatcher | Finding triage assignments for Phase 4 task creation (Tier 2-3) |

These are conversational or informational — loss is annoying but not pipeline-breaking. `[QUESTION]` and `[CYCLE]` are lower severity; the polling loop will detect the underlying stuck state (task not progressing) within one poll cycle regardless.

---

## Polling loop

### Tier 1 — Architect polls (no Dispatcher)

The Architect runs a **60-second polling loop** that ensures no state change is missed.

```
loop:
  1. Call TaskList
  2. For each task with a state change since last poll:
     - "completed" → process result, advance phase if all phase tasks done
     - "blocked"   → read result, decide: unblock, reassign, or escalate
     - stale (no progress for 8 min) → check-in with teammate (see timeout detection)
  3. Listen for SendMessage for up to 60 seconds
     - If hint arrives → immediately call TaskList and process
     - If conversational message arrives ([QUESTION], [CYCLE]) → process directly
  4. Repeat
```

**MANDATORY:** The Architect MUST call TaskList at least once per 60 seconds, regardless of whether it is processing other work. Between polls, the Architect still listens for SendMessage and acts on hints immediately by reading TaskList.

### Tier 2-3 — Dispatcher polls

The Dispatcher runs a **30-second polling loop** — faster than the Architect's because the Dispatcher never gets stuck on deep thinking.

```
loop:
  1. Call TaskList
  2. For each task with a state change since last poll:
     - "completed" → check if all phase tasks done
       - If yes and phase needs Architect decision → wake Architect via SendMessage
       - If yes and phase auto-advances → advance phase (create tasks, update state.json)
     - "blocked"   → notify Architect for decision
     - stale (no progress for 8 min) → check-in with teammate → 2 min grace → escalate to Architect
  3. Listen for SendMessage for up to 30 seconds
     - If hint arrives → immediately call TaskList and process
     - If Architect sends [TRIAGE] → create fix tasks per triage assignments
  4. Repeat
```

The Dispatcher's context stays small (just state.json + task states + routing rules), so it never stalls on processing.

---

## Teammate timeout detection

Detected by the Architect (Tier 1) or Dispatcher (Tier 2-3) via polling:

1. **8-minute threshold:** If a task has been `in_progress` for 8 minutes with no `TaskUpdate`, send a check-in via SendMessage: `Are you still working on [task]? Send a status update.`
2. **2-minute grace:** If no response (no `TaskUpdate` or SendMessage) within 2 minutes after check-in:
   - Update `.worklog/team/state.json`: set teammate status to `unresponsive`
   - Architect sends `[ESCALATE]` to main session: `Teammate {name} unresponsive after check-in. Options: (A) retry with new agent, (B) reassign, (C) abort.`
