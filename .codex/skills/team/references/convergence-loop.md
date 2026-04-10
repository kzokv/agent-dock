# Convergence Loop

The core execution engine for agent teams. All tiers use this loop — teammates present vary by tier. At Tier 1, the Architect orchestrates phase transitions. At Tier 2-3, the Dispatcher manages state and routing while the Architect focuses on design decisions.

---

## Flow

```
CONVERGENCE LOOP (default max: 3 iterations)
│
│  Phase 1 — Build + Plan (parallel)
│  ├── Implementer(s)       implement / fix / refactor (TDD red-green-refactor)
│  └── Senior QA            plan tests (ALL tiers, NO file writes)
│
│  CHECKPOINT (iteration 1 only, Tier 3 only)
│  └── Architect reviews Implementers' test stubs + QA's test plan
│      ├── Aligned with spec? → proceed
│      └── Drifted? → correct before any code is written
│
│  Phase 2 — QA Automation (after Implementer(s) complete)
│  └── Senior QA            write / update test scripts → iterate until own tests green
│
│  E2E COVERAGE GATE (before Phase 3)
│  └── Cross-check Architect's design table: every non-N/A E2E Coverage
│      entry must have a corresponding test file with ≥1 passing test.
│      Missing? → QA writes them now. Do NOT enter validation with gaps.
│
│  Phase 3 — Review + Validate (parallel)
│  ├── Architect            architectural review → design alignment findings (All tiers)
│  ├── Code Reviewer        mechanical quality review → code quality findings (Tier 2-3)
│  └── Validator            full pipeline → failure report (All tiers)
│
│  FINDING TRIAGE (Architect)
│  └── Read Validator + Code Reviewer findings → tag each to domain owner
│      ├── Implementation issue → route to Implementer (Tier 1-2) or Frontend/Backend Implementer (Tier 3)
│      ├── Test/fixture issue → route to Senior QA
│      └── Cross-cutting issue → Architect decides which domain owner
│
│  Phase 4 — Self-Fix (domain owners fix their own findings)
│  ├── Implementer(s)       fix implementation findings → run full test suite
│  └── Senior QA            fix test/fixture findings → run full test suite
│
│  EXIT CHECK
│  ├── All tests green?            ✗ → next iteration
│  ├── All findings addressed?     ✗ → next iteration
│  ├── No new regressions?         ✗ → next iteration
│  └── ALL PASS?                   ✓ → exit loop
│
└── end loop

WRAP-UP (runs once, after loop exits)
├── Architect consolidates memory to .worklog/team/memory/consolidated.md (All tiers)
├── Architect decides if docs need updating (Tier 1 — conditional)
├── Architect sends [SPAWN] for Wave 2 (All tiers, if Technical Writer needed)
├── Technical Writer     updates ALL relevant docs
├── Code Reviewer        reviews Technical Writer output (Tier 2-3)
├── Technical Writer     addresses review findings if any (Tier 2-3)
├── Architect sends [SHUTDOWN] to main session
└── Main session prompts user to consolidate .worklog/team/memory/ → .claude/memory/
```

---

## Iteration behavior

| Iteration | Implementer(s) | Senior QA | Validator | Code Reviewer |
|-----------|----------------|-----------|-----------|---------------|
| 1 | Implements feature/fix (TDD) | Plans tests (no file writes) | First full run | First full review |
| 2+ | Self-fixes assigned findings | Self-fixes test/fixture issues, updates tests | Re-runs full suite, flags regressions | Re-reviews delta |

**Phase sequencing:**
- **Phase 1 is parallel:** Implementer(s) write code while QA plans tests — no file-write conflicts because QA is plan-only in Phase 1.
- **Phase 2 starts after Implementer(s) complete Phase 1:** QA needs actual code to write test scripts against. Wait for all Implementer `[DONE:*]` signals before starting Phase 2.
- **Phase 3 starts after both Phase 1 AND Phase 2 complete:** see Phase 3 gate below.

**E2E coverage gate (Phase 2→3, hard):** Before Phase 3 starts, cross-check the Architect's design table. Every non-`N/A` entry in the E2E Coverage column must have a corresponding test file with at least one passing test. If any are missing, QA writes them before the Validator runs. Do NOT enter validation with unwritten E2E cases from the approved design.

---

## Bounded iteration with escape hatch

**Default maximum: 3 iterations.**

After iteration 3, if still not green, the Architect produces a **failure summary**:
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

## Cycle detection (Implementers and QA)

Any domain agent performing self-fix can trigger cycle detection:
- If fixing a file already fixed in a previous iteration → send `[CYCLE]` to Architect
- If the same test has failed in 2+ consecutive iterations with different fixes → STOP and send `[CYCLE]` to Architect
- Do not attempt a third fix on the same test — escalate

---

## Teammate timeout detection

See `message-protocol.md` for the full timeout detection protocol. Summary:
- **Tier 1:** Architect detects via 60s polling — 8-minute threshold on task staleness, 2-minute grace after check-in, then escalation.
- **Tier 2-3:** Dispatcher detects via 30s polling — same thresholds.

---

## Git policy

The team does NOT create commits. All file changes remain uncommitted on disk.

- The Architect records the current branch in `.worklog/team/state.json` at init
- No teammate runs `git add`, `git commit`, or `git push`
- The human handles the final commit process after `[SHUTDOWN]`

---

## Phase transition protocol

### Tier 1 — Architect manages transitions

The Architect manages all phase transitions directly using Claude Code's team tools and `.worklog/team/state.json`.

#### Starting a phase

1. **MANDATORY:** Update `.worklog/team/state.json` with new phase and iteration — this is a gate, not guidance
2. **MANDATORY:** Create tasks for the phase using `TaskCreate`
3. **MANDATORY:** Assign tasks to the appropriate teammates using `TaskUpdate` with `owner`
4. Send SendMessage hints to teammates with context (non-authoritative — task assignment is the durable signal)
5. Send `[STATUS]` to main session: `[STATUS] Phase 1, iteration 1 starting.`

#### Completing a phase

1. Teammates call `TaskUpdate(status: "completed", result: "...")` when done, plus a `[DONE] check TaskList` hint via SendMessage
2. Architect discovers completions via its 60s polling loop (or immediately via hint)
3. Architect reviews results
4. **MANDATORY:** Architect updates `.worklog/team/state.json`
5. Architect creates tasks for the next phase

### Tier 2-3 — Dispatcher manages transitions

The Dispatcher manages phase transitions, state.json, and task creation. The Architect is consulted for decisions.

#### Starting a phase

1. Dispatcher updates `.worklog/team/state.json` with new phase and iteration
2. Dispatcher creates tasks for the phase using `TaskCreate`
3. Dispatcher assigns tasks to teammates using `TaskUpdate` with `owner`
4. Dispatcher sends SendMessage hints to teammates with context
5. Dispatcher sends `[STATUS]` to main session

#### Completing a phase

1. Teammates call `TaskUpdate(status: "completed", result: "...")` when done, plus `[DONE] check TaskList` hint
2. Dispatcher discovers completions via its 30s polling loop
3. For phases that need Architect decisions (finding triage, exit check), Dispatcher wakes Architect via SendMessage
4. Architect makes decision → communicates back to Dispatcher
5. Dispatcher updates state.json and creates next phase tasks

### Phase 3 gate — explicit [GO] required

**Phase 3 MUST NOT start until both Phase 1 (Implementers) AND Phase 2 (Senior QA) have reported completion via `TaskUpdate`.** Starting Phase 3 before QA finishes wastes a full validation cycle on expected failures.

Protocol:
1. Wait for all Implementer tasks to show `completed` (Phase 1 done)
2. Wait for Senior QA's task to show `completed` (Phase 2 done — test scripts written and passing locally)
3. Only then send `[GO]` to Validator via `TaskUpdate` on the Validator's task (set status to `in_progress`)
4. The Validator MUST NOT self-activate — it waits for the explicit `[GO]`

**Who sends `[GO]`:** Architect (Tier 1), Dispatcher (Tier 2-3).

### Finding triage (Phase 3→4)

After all Phase 3 tasks complete:

1. Architect reads Validator findings report + Code Reviewer findings report
2. Architect classifies each finding by domain:
   - Implementation code issue → Implementer (Tier 1-2) or Frontend/Backend Implementer (Tier 3)
   - Test script / fixture / automation issue → Senior QA
   - Cross-cutting (spans domains) → Architect decides primary owner
3. Architect communicates triage assignments:
   - **Tier 1:** Creates fix tasks directly via TaskCreate with assignments
   - **Tier 2-3:** Sends triage assignments to Dispatcher, who creates fix tasks
4. Each domain owner receives only their assigned findings — not the full report

### Between iterations

1. After all Phase 4 tasks complete, Architect checks exit criteria (all tests green, findings addressed, no regressions)
2. Updates `exit_check` fields in `.worklog/team/state.json`
3. If not green → create new iteration's tasks and message teammates
4. If green → proceed to wrap-up

### Heartbeat

**Tier 1:** If the Architect has not sent `[STATUS]`, `[ESCALATE]`, or `[SPAWN]` to the main session for **10 minutes**, it must send:
```
[HEARTBEAT] Phase N, iteration M. Waiting for: [teammate names].
```

**Tier 2-3:** The Dispatcher sends heartbeats to the main session.

The main session resets its timeout counter on any Architect or Dispatcher message. If 10 minutes pass with no message, the main session alerts the user.

---

## Tier-specific variations

### Tier 1 (Solo)
- Architect manages state and routing (no Dispatcher)
- No checkpoint (QA reviews after implementation, not during)
- No Code Reviewer in Phase 3 (Validator + Architect review only)
- Implementer self-fixes all findings (no domain split)
- Wrap-up: Architect consolidates staged memory. Technical Writer conditional — Architect decides if docs need updating.
- Convergence loop still applies but is typically 1 iteration

### Tier 2 (Squad)
- Dispatcher manages state and routing
- No checkpoint (QA writes scripts but no formal plan to review)
- Full Phase 3 with Code Reviewer + Validator
- Fullstack Implementer self-fixes implementation findings; QA self-fixes test findings
- Architect triages findings by domain (implementation vs test)
- Wrap-up: Architect consolidates staged memory. Technical Writer always spawned in Wave 2.

### Tier 3 (Full Team)
- Dispatcher manages state and routing
- Full checkpoint in iteration 1 (Architect reviews Implementers' stubs + QA test plan)
- Full Phase 3 with Code Reviewer (incl. security analysis) + Validator
- Frontend/Backend Implementers self-fix their domain findings; QA self-fixes test findings
- Architect triages findings by domain (frontend vs backend vs test)
- Wrap-up: Architect consolidates staged memory. Technical Writer always spawned in Wave 2. Code Reviewer reviews Technical Writer output.
