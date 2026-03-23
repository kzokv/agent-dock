# Convergence Loop

The core execution engine for agent teams. All tiers use this loop — teammates present vary by tier. The Architect (persistent teammate) orchestrates phase transitions via `SendMessage` and `TaskCreate`/`TaskUpdate`.

---

## Flow

```
CONVERGENCE LOOP (default max: 3 iterations)
│
│  Phase 1 — Build + Plan (parallel)
│  ├── TDD Implementer    implement / fix / refactor
│  └── Senior QA          plan tests (ALL tiers, NO file writes)
│
│  CHECKPOINT (iteration 1 only, Tier 3 only)
│  └── Architect reviews Implementer's test stubs + QA's test plan
│      ├── Aligned with spec? → proceed
│      └── Drifted? → correct before any code is written
│
│  Phase 2 — QA Automation (after Implementer completes)
│  └── Senior QA          write / update test scripts → iterate until own tests green
│
│  Phase 3 — Review + Validate (parallel)
│  ├── Code Reviewer      reviews changed files → findings report (Tier 2-3)
│  └── Validator          full pipeline → failure report
│
│  Phase 4 — Fix
│  └── Fixer              fixes failures + findings → re-runs affected tests (Tier 2-3)
│  └── TDD Implementer    fixes own failures (Tier 1 only, no Fixer)
│
│  EXIT CHECK
│  ├── All tests green?            ✗ → next iteration
│  ├── All findings addressed?     ✗ → next iteration
│  ├── No new regressions?         ✗ → next iteration
│  └── ALL PASS?                   ✓ → exit loop
│
└── end loop

WRAP-UP (runs once, after loop exits)
├── Architect consolidates memory to .team/memory/consolidated.md (Tier 1-2)
├── Architect sends [SPAWN] for Wave 2 (Tier 3)
├── Technical Writer    updates ALL relevant docs (Tier 3, Wave 2)
├── Code Reviewer       reviews Technical Writer output (Tier 3, Wave 2)
├── Technical Writer    addresses review findings if any (Tier 3, Wave 2)
├── Memory Curator      consolidates staged memory to .team/memory/consolidated.md (Tier 3, Wave 2)
├── Architect sends [SHUTDOWN] to main session
└── Main session prompts user to consolidate .team/memory/ → .claude/memory/
```

---

## Iteration behavior

| Iteration | TDD Implementer | Senior QA | Validator | Fixer |
|-----------|----------------|-----------|-----------|-------|
| 1 | Implements feature/fix | Plans tests (no file writes) | First full run | Fixes initial failures + findings |
| 2+ | Fixes regressions from prior fixes | Updates broken/missing tests | Re-runs full suite, flags new regressions | Fixes remaining failures + findings |

**Note:** QA defers all test writing to Phase 2. Phase 1 is plan-only for QA to prevent concurrent file writes in the same worktree.

---

## Bounded iteration with escape hatch

**Default maximum: 3 iterations.**

After iteration 3, if still not green, the Fixer produces a **failure summary**:
- What's still broken
- What was attempted
- Why it didn't converge

The Architect reviews and makes one of three calls:

1. **Extend:** "These are almost fixed, grant 2 more iterations." Architect can extend up to **5 total iterations**.
2. **Redesign:** "The approach is fundamentally wrong, I'm revising the technical design." Restarts from Phase 1 with a new plan.
3. **Escalate:** "This needs human judgment." Sends `[ESCALATE]` to main session.

**Hard ceiling: 5 iterations.** After 5, the Architect must escalate to the user regardless.

---

## Architect self-check rule

**Trigger:** If Phase 4 failures in 2 consecutive iterations trace back to the same module or architectural decision.

**Action:** Before granting more iterations, the Architect must:
1. Re-evaluate its own technical design
2. Determine if the design itself is the root cause
3. If yes → trigger **Redesign** (restart from Phase 1 with corrected design)
4. If no → proceed with **Extend**

This prevents burning iterations on symptoms of a flawed design.

---

## Cycle detection (Fixer)

- If fixing a file already fixed in a previous iteration → send `[CYCLE]` to Architect
- If the same test has failed in 2+ consecutive iterations with different fixes → STOP and send `[CYCLE]` to Architect
- Do not attempt a third fix on the same test — escalate

---

## Teammate timeout detection

The Architect tracks responsiveness for all teammates:

1. **Timer starts** when the Architect assigns a task via `SendMessage`
2. **8-minute threshold:** If no `[DONE:*]`, `[BLOCKED]`, `[QUESTION]`, or `[CYCLE]` received within 8 minutes, the Architect sends a check-in: `Are you still working on [task]? Send a status update.`
3. **2-minute grace:** If no response within 2 minutes after check-in, the Architect:
   - Updates `.team/state.json`: sets teammate status to `unresponsive`
   - Sends `[ESCALATE]` to main session: `Teammate {name} unresponsive after check-in. Options: (A) retry the task with a new agent, (B) reassign to another teammate, (C) abort.`

This prevents the team from stalling silently when a teammate crashes or runs out of context.

---

## Git policy

The team does NOT create commits. All file changes remain uncommitted on disk.

- The Architect records the current branch in `.team/state.json` at init
- No teammate runs `git add`, `git commit`, or `git push`
- The human handles the final commit process after `[SHUTDOWN]`

---

## Phase transition protocol

The Architect (persistent teammate) manages all phase transitions using Claude Code's team tools and `.team/state.json`.

### Starting a phase

1. Update `.team/state.json` with new phase and iteration
2. Create tasks for the phase using `TaskCreate`
3. Assign tasks to the appropriate teammates using `TaskUpdate` with `owner`
4. Message teammates with context using `SendMessage`:
   ```
   SendMessage({
     to: "tdd-implementer",
     message: "Phase 1 starting. Your task: [description]. Technical design: [summary]."
   })
   ```
5. Send `[STATUS]` to main session: `[STATUS] Phase 1, iteration 1 starting.`

### Completing a phase

1. Teammates send `[DONE:CLEAN]` or `[DONE:FINDINGS]` when done
2. Architect waits for all phase teammates to report `[DONE:*]`
3. Architect reviews results
4. Architect updates `.team/state.json`
5. Architect creates tasks for the next phase

### Phase 3 gate — explicit [GO] required

**The Architect MUST NOT start Phase 3 until both Phase 1 (TDD Implementer) AND Phase 2 (Senior QA) have reported `[DONE:*]`.** Starting Phase 3 before QA finishes wastes a full validation cycle on expected failures.

Protocol:
1. Wait for `[DONE:*]` from TDD Implementer (Phase 1 complete)
2. Wait for `[DONE:*]` from Senior QA (Phase 2 complete — test scripts written and passing locally)
3. Only then send explicit `[GO]` to Validator: `"Phase 3 starting. Run the full pipeline now."`
4. The Validator must NOT self-activate based on task availability — it waits for the explicit `[GO]`

### Between iterations

1. Architect checks exit criteria (all tests green, findings addressed, no regressions)
2. Updates `exit_check` fields in `.team/state.json`
3. If not green → create new iteration's tasks and message teammates
4. If green → proceed to wrap-up

### Heartbeat

If the Architect has not sent `[STATUS]`, `[ESCALATE]`, or `[SPAWN]` to the main session for **10 minutes**, it must send:
```
[HEARTBEAT] Phase N, iteration M. Waiting for: [teammate names].
```

The main session resets its timeout counter on any Architect message. If 10 minutes pass with no message from the Architect, the main session alerts the user.

---

## Tier-specific variations

### Tier 1 (Solo)
- No checkpoint (QA reviews after implementation, not during)
- No Code Reviewer in Phase 3 (Validator only)
- No Fixer — TDD Implementer fixes its own failures
- Wrap-up: Architect consolidates staged memory to `.team/memory/consolidated.md`
- Convergence loop still applies but is typically 1 iteration

### Tier 2 (Squad)
- No checkpoint (QA writes scripts but no formal plan to review)
- Full Phase 3 with Code Reviewer + Validator
- Fixer handles all fixes
- Wrap-up: Architect consolidates staged memory to `.team/memory/consolidated.md`

### Tier 3 (Full Team)
- Full checkpoint in iteration 1
- Full Phase 3 with Code Reviewer + Validator
- Fixer handles all fixes
- Wrap-up: Architect sends `[SPAWN]` for Wave 2 (Technical Writer + Memory Curator)
- Wave 2 includes a Code Reviewer pass on Technical Writer output before `[SHUTDOWN]`
