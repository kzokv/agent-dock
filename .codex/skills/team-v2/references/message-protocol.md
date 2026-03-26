# Message Protocol

Inter-agent communication protocol for team execution. Uses a **hybrid model** with two channels: a durable channel (TaskUpdate/TaskCreate/TaskList) for critical-path signals, and a hint channel (SendMessage) for notifications and conversational messages.

---

## Durable channel — TaskUpdate / TaskCreate / TaskList

All phase-transition signals use the task system. These are the messages that, if lost, stall the entire team.

| Signal | Who | How |
|--------|-----|-----|
| Assign work | Architect → Teammate | `TaskCreate` with description + `TaskUpdate` to set owner |
| `[GO]` (start phase) | Architect → Teammate | `TaskUpdate` on the target task (e.g., set status to `in_progress` with a note) |
| `[DONE:CLEAN]` | Teammate → Architect | `TaskUpdate(status: "completed", result: "CLEAN")` |
| `[DONE:FINDINGS]` | Teammate → Architect | `TaskUpdate(status: "completed", result: "FINDINGS: ...")` |
| `[BLOCKED]` | Teammate → Architect | `TaskUpdate(status: "blocked", result: "BLOCKED: ...")` |

**Why durable:** `TaskUpdate` writes to persistent state. `TaskList` reads it back reliably regardless of whether the recipient was busy at write time.

---

## Hint channel — SendMessage

After any `TaskUpdate`, the sender also fires a minimal SendMessage hint. The hint is **non-authoritative** — the recipient never trusts it alone; it always reads `TaskList` as ground truth.

**Hint format (minimal):**

```
[DONE] check TaskList
[BLOCKED] check TaskList
```

The hint's only purpose is to wake the Architect immediately so it doesn't have to wait for the next poll cycle. If the hint gets swallowed, the poll catches it.

**SendMessage-only messages (no TaskUpdate needed):**

| Prefix | Direction | Meaning |
|--------|-----------|---------|
| `[STATUS]` | Architect → Main | Phase transition, iteration progress |
| `[ESCALATE]` | Architect → Main | Needs user decision |
| `[SPAWN]` | Architect → Main | Needs new teammates spawned |
| `[SHUTDOWN]` | Architect → Main | All green, team done |
| `[HEARTBEAT]` | Architect → Main | Still alive (every 10 min of silence) |
| `[FORCE_STOP]` | Architect → Main | Auto-force-stopped stuck task |
| `[USER]` | Main → Architect | Relaying user message |
| `[QUESTION]` | Teammate → Architect | Needs clarification |
| `[CYCLE]` | Teammate → Architect | Repeat failure detected (Fixer) |

These are conversational or informational — loss is annoying but not pipeline-breaking. `[QUESTION]` and `[CYCLE]` are lower severity; the Architect's polling loop will detect the underlying stuck state (task not progressing) within 60 seconds regardless.

---

## Architect polling loop (safety net)

The Architect runs a **60-second polling loop** that ensures no state change is missed, regardless of whether SendMessage hints arrive.

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

**Between polls**, the Architect still listens for SendMessage and acts on hints immediately by reading `TaskList`. The 60-second poll is the fallback — it guarantees that even if every hint gets swallowed, the Architect discovers state changes within one minute.

---

## Teammate timeout detection

The Architect tracks responsiveness for all teammates via `TaskList`:

1. **8-minute threshold:** If a task has been `in_progress` for 8 minutes with no `TaskUpdate`, the Architect sends a check-in via SendMessage: `Are you still working on [task]? Send a status update.`
2. **2-minute grace:** If no response (no `TaskUpdate` or SendMessage) within 2 minutes after check-in, the Architect:
   - Updates `.worklog/team/state.json`: sets teammate status to `unresponsive`
   - Sends `[ESCALATE]` to main session: `Teammate {name} unresponsive after check-in. Options: (A) retry with new agent, (B) reassign, (C) abort.`

---

## What was removed

**3-way handshake (REQUEST/ACK/ACK-OK)** — removed. The durable TaskUpdate channel + 60s polling loop makes acknowledgment-based delivery unnecessary. The handshake was a protocol-level fix on an unreliable transport; the hybrid model fixes the transport itself.
