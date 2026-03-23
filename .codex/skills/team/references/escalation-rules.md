# Escalation Rules

Rules for when the Architect decides autonomously vs. escalates to the human. All escalations to the user go through the main session via the `[ESCALATE]` prefix.

---

## Architect decides autonomously when

- The spec clearly covers the scenario — no ambiguity in requirements
- The technical approach follows existing patterns in the codebase
- The change is scoped to files and modules already mentioned in the plan
- There is one obvious correct approach

---

## Architect escalates to human when

- **Spec ambiguity:** The spec is ambiguous or contradictory on a point that affects implementation direction
- **Scope creep:** The implementation requires changing files or modules NOT mentioned in the plan
- **Competing approaches:** Two or more valid technical approaches exist with different tradeoffs and no clear winner
- **Blocking constraint:** A discovered constraint (dependency, API limitation, existing bug) means the plan as written cannot work
- **Convergence failure:** After 5 iterations, still not green (hard ceiling)

### Escalation flow

```
Architect → [ESCALATE] → Main Session → displays to user → user responds → Main Session → [USER] → Architect
```

The Architect does NOT communicate with the user directly. All escalations go through the main session.

---

## QA escalation path

When Senior QA's tests fail due to an implementation bug (not a test bug):

1. **QA diagnoses:** Is this a test bug or an implementation bug?
2. **If implementation bug, matches spec:** QA sends `[DONE:FINDINGS]` to Architect → Architect routes findings to Fixer
3. **If ambiguous (spec unclear):** QA sends `[QUESTION]` to Architect → Architect sends `[ESCALATE]` to main session
4. **QA never fixes implementation code** — QA's job is to detect and classify, not to fix

---

## Fixer escalation path

When the Fixer encounters cycle patterns:

1. **Same file fixed twice:** Send `[CYCLE]` to Architect (informational)
2. **Same test failed 2+ consecutive iterations:** STOP — send `[CYCLE]` to Architect with attempted fixes
3. **Architect then decides:** Extend loop, redesign, or escalate to human via `[ESCALATE]`

---

## Architect self-check escalation

When the same area fails in 2 consecutive iterations:

1. Architect re-evaluates its own technical design
2. **If design is root cause:** Trigger redesign — restart from Phase 1 with corrected design
3. **If design is sound:** Proceed with extending the loop
4. **If uncertain:** Send `[ESCALATE]` to main session with the analysis

---

## Escalation format

When the Architect sends `[ESCALATE]` to the main session, always include:

```
[ESCALATE]
## Escalation

**Reason:** [which rule triggered]
**Context:** [what happened]
**Options:**
  A) [option with tradeoffs]
  B) [option with tradeoffs]
  C) [your recommendation if you have one]

Waiting for your decision.
```

The main session displays this to the user and relays the user's response back as `[USER]`.

Be specific. "I'm stuck" is not an escalation — explain what's ambiguous and what the options are.

---

## Stuck-at-shutdown escalation

When a teammate is still `in_progress` after 10 minutes of waiting at shutdown time:

1. Architect escalates once for all stuck teammates (not per-teammate)
2. Architect sends `[ESCALATE]` to main session:

```
[ESCALATE]
## Escalation

**Reason:** Teammates still busy at shutdown
**Context:** The following teammates still have in_progress tasks after 10 minutes:
  - {teammate-name} ({role}): {task description}
  - {teammate-name} ({role}): {task description}
**Options:**
  A) Wait — specify how many more minutes (extension {N}/3 max)
  B) Force stop — main session calls TaskStop on stuck tasks, team shuts down
  C) Abort — trigger full team abort

**Suggestion:** [Architect's reasoning — e.g., "B: the tasks are non-critical memory writes and all code changes are already complete"]

Waiting for your decision.
```

3. **If user picks A:** Architect restarts the timer with the user-specified duration. Extension count increments. After 3rd extension expires → auto-force-stop (no re-ask).
4. **If user picks B:** Main session calls `TaskStop` on each stuck task, confirms back to Architect via `[USER]`. Architect sets stuck teammates to `"force_stopped"` in `.team/state.json` and sends `[SHUTDOWN]`.
5. **If user picks C:** Main session triggers `/team abort` flow.

---

## Teammate unresponsive escalation

When the Architect detects a teammate has not responded within the timeout window (8 min + 2 min grace after check-in):

1. Architect marks teammate as `unresponsive` in `.team/state.json`
2. Architect sends `[ESCALATE]` to main session:

```
[ESCALATE]
## Escalation

**Reason:** Teammate unresponsive
**Context:** {teammate-name} ({role}) has not responded after check-in. Task: {task description}. Last activity: {timestamp}.
**Options:**
  A) Retry — spawn a replacement teammate with the same role and task
  B) Reassign — give the task to an existing teammate (specify which)
  C) Abort — shut down the team

Waiting for your decision.
```

The main session displays this to the user and handles accordingly.
