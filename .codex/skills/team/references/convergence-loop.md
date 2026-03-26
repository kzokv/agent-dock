# Convergence Loop

The core execution engine for agent teams. All tiers use this loop — teammates present vary by tier. The Architect (persistent teammate) orchestrates phase transitions via the hybrid message protocol (see `message-protocol.md`).

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
│  ├── Architect          architectural review → design alignment findings (All tiers)
│  ├── Code Reviewer      mechanical quality review → code quality findings (Tier 2-3)
│  └── Validator          full pipeline → failure report (All tiers)
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
├── Architect consolidates memory to .worklog/team/memory/consolidated.md (Tier 1-2)
├── Architect sends [SPAWN] for Wave 2 (Tier 3)
├── Technical Writer    updates ALL relevant docs (Tier 3, Wave 2)
├── Code Reviewer       reviews Technical Writer output (Tier 3, Wave 2)
├── Technical Writer    addresses review findings if any (Tier 3, Wave 2)
├── Memory Curator      consolidates staged memory to .worklog/team/memory/consolidated.md (Tier 3, Wave 2)
├── Architect sends [SHUTDOWN] to main session
└── Main session prompts user to consolidate .worklog/team/memory/ → .claude/memory/
```

---

## Iteration behavior

| Iteration | TDD Implementer | Senior QA | Validator | Fixer |
|-----------|----------------|-----------|-----------|-------|
| 1 | Implements feature/fix | Plans tests (no file writes) | First full run | Fixes initial failures + findings |
| 2+ | Fixes regressions from prior fixes | Updates broken/missing tests | Re-runs full suite, flags new regressions | Fixes remaining failures + findings |

**Phase sequencing:**
- **Phase 1 is parallel:** TDD Implementer writes code while QA plans tests — no file-write conflicts because QA is plan-only in Phase 1.
- **Phase 2 starts after Implementer completes Phase 1:** QA needs actual code to write test scripts against. Architect waits for Implementer's `[DONE:*]` before starting Phase 2.
- **Phase 3 starts after both Phase 1 AND Phase 2 complete:** see Phase 3 gate below.

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

See `message-protocol.md` for the full timeout detection protocol. Summary: 8-minute threshold on task staleness (detected via `TaskList` polling), 2-minute grace after check-in, then escalation.

---

## Git policy

The team does NOT create commits. All file changes remain uncommitted on disk.

- The Architect records the current branch in `.worklog/team/state.json` at init
- No teammate runs `git add`, `git commit`, or `git push`
- The human handles the final commit process after `[SHUTDOWN]`

---

## Phase transition protocol

The Architect (persistent teammate) manages all phase transitions using Claude Code's team tools, the hybrid message protocol (`message-protocol.md`), and `.worklog/team/state.json`.

### Starting a phase

1. Update `.worklog/team/state.json` with new phase and iteration
2. Create tasks for the phase using `TaskCreate`
3. Assign tasks to the appropriate teammates using `TaskUpdate` with `owner`
4. Send SendMessage hints to teammates with context (non-authoritative — task assignment is the durable signal)
5. Send `[STATUS]` to main session: `[STATUS] Phase 1, iteration 1 starting.`

### Completing a phase

1. Teammates call `TaskUpdate(status: "completed", result: "...")` when done, plus a `[DONE] check TaskList` hint via SendMessage
2. Architect discovers completions via its 60s polling loop (or immediately via hint)
3. Architect reviews results
4. Architect updates `.worklog/team/state.json`
5. Architect creates tasks for the next phase

### Phase 3 gate — explicit [GO] required

**The Architect MUST NOT start Phase 3 until both Phase 1 (TDD Implementer) AND Phase 2 (Senior QA) have reported completion via `TaskUpdate`.** Starting Phase 3 before QA finishes wastes a full validation cycle on expected failures.

Protocol:
1. Poll `TaskList` — wait for TDD Implementer's task to show `completed` (Phase 1 done)
2. Poll `TaskList` — wait for Senior QA's task to show `completed` (Phase 2 done — test scripts written and passing locally)
3. Only then send `[GO]` to Validator via `TaskUpdate` on the Validator's task (set status to `in_progress` with note: `Phase 3 starting. Run the full pipeline now.`)
4. The Validator must NOT self-activate based on task availability — it waits for the explicit `[GO]`

### Between iterations

1. Architect checks exit criteria (all tests green, findings addressed, no regressions)
2. Updates `exit_check` fields in `.worklog/team/state.json`
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
- Wrap-up: Architect consolidates staged memory to `.worklog/team/memory/consolidated.md`
- Convergence loop still applies but is typically 1 iteration

### Tier 2 (Squad)
- No checkpoint (QA writes scripts but no formal plan to review)
- Full Phase 3 with Code Reviewer + Validator
- Fixer handles all fixes
- Wrap-up: Architect consolidates staged memory to `.worklog/team/memory/consolidated.md`

### Tier 3 (Full Team)
- Full checkpoint in iteration 1
- Full Phase 3 with Code Reviewer + Validator
- Fixer handles all fixes
- Wrap-up: Architect sends `[SPAWN]` for Wave 2 (Technical Writer + Memory Curator)
- Wave 2 includes a Code Reviewer pass on Technical Writer output before `[SHUTDOWN]`
