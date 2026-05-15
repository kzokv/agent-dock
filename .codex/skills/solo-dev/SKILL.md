---
name: solo-dev
description: "Lightweight single-agent TDD workflow with bounded validation loop. Distills /team into a solo convergence engine: plan → TDD → auto-tests → validate → self-fix → review → docs. Each phase invokes relevant skills. Use when: implementing features, fixing bugs, or refactoring solo with full quality gates."
metadata:
  version: 1.1.0
  category: engineering
  updated: 2026-03-29
  derived-from: team v3.0.0
---

# Solo Dev — Single-Agent TDD Workflow

One agent. Every essential. Distills the multi-agent `/team` skill into a sequential convergence loop that a single Claude Code agent runs end-to-end.

---

## When This Skill Activates

- "Implement [feature] with tests"
- "Fix [bug] using TDD"
- "Build this end-to-end with validation"
- "Solo dev [task]"
- Any implementation task where user wants quality gates without spawning a team

---

## Workflow Overview

```
Phase 0: Plan & Design ─────────── /tdd (planning)
Phase 1: TDD Loop ──────────────── /tdd (red-green-refactor)
Phase 2: Auto Tests ─────────────── /senior-qa, /playwright-pro
Phase 3: Validate ───────────────── run full pipeline
Phase 4: Self-Fix ───────────────── fix findings, re-run
Phase 5: Review ─────────────────── /code-reviewer
  ↑                                    │
  └── iterate (bounded: 3→5 max) ──────┘
Phase 6: Docs ───────────────────── /technical-writing
```

---

## Phase 0: Plan & Design

**Goal:** Align on scope and design before writing code.

1. **Read scope artifacts first** — check for prior scope-grill output (`docs/notes/*/scope-todo-*.md`), locked scope in Linear tickets, or `.worklog/` handoff notes. These contain agreed decisions, out-of-scope boundaries, and implementation notes that override guesswork.
2. Read the task/spec/ticket thoroughly
3. Identify the public interface changes needed
4. Design interfaces for testability (accept dependencies, return results)
5. List behaviors to test — prioritize by criticality
6. Propose vertical slices (tracer bullets, not horizontal layers)
7. **Get user approval** on the plan before proceeding

**Skill:** Invoke `/tdd` planning phase. Read `tdd/interface-design.md` and `tdd/deep-modules.md` for design heuristics.

**Plan format (required):**

Present the plan as a table with an explicit E2E column:

```
| # | Slice | Layers | Key Behaviors | E2E Coverage |
|---|---|---|---|---|
| 1 | Database + types | SQL, TS | migration, union query | N/A — no UI |
| 2 | API routes | Fastify | auth, validation, response | N/A — no UI |
| 3 | Settings tab | React, CSS | tab renders, search, save | "open tab → empty state → browse → select → save" |
| 4 | Full catalog sheet | React, CSS | expand, filter, back | "filter by type → search → back preserves state" |
```

**UI gate:** Any slice whose Layers column includes React, Next.js, CSS, or component files MUST have a non-empty E2E Coverage cell describing the user flow to verify. `N/A` is only valid for slices with zero UI surface. Do NOT present a plan for approval with empty E2E cells on UI slices — fill them first or ask the user which flows matter.

**Output:** Approved plan table with E2E coverage descriptions for all UI slices.

**Escalate if:** Spec is ambiguous, contradictory, or requires out-of-scope changes.

---

## Phase 1: TDD Loop (per vertical slice)

**Goal:** Implement feature using strict RED→GREEN→REFACTOR per behavior.

For each behavior from the plan:

```
RED:      Write ONE failing test → verify it fails for the right reason
GREEN:    Write MINIMAL code to pass → verify test passes
REFACTOR: Clean up → verify all tests still pass
```

**Rules:**
- One test at a time — never write tests in bulk
- Tests verify behavior through public interfaces, not implementation
- Only enough code to pass the current test — no speculation
- Never refactor while RED — get to GREEN first
- Run tests after each step

**Skill:** Follow `/tdd` workflow (tracer bullet → incremental loop → refactor).

**Checklist per cycle:**
- [ ] Test describes behavior, not implementation
- [ ] Test uses public interface only
- [ ] Test would survive internal refactor
- [ ] Code is minimal for this test
- [ ] No speculative features added

**Output:** All unit tests passing. Feature implemented.

---

## Phase 2: Auto Tests (API, Integration, E2E)

**Goal:** Add higher-level test coverage beyond unit tests.

**What to write (in order):**

1. **Integration tests** — Component interactions, API request/response cycles, database queries through the service layer. Mock only at system boundaries (external APIs, third-party services).

2. **API tests** — If the feature has API endpoints: test request validation, response shape, error codes, auth flows. Use real middleware stack where possible.

3. **E2E tests (REQUIRED when UI changes are in scope)** — Critical user flows only (not exhaustive). Happy path + most important error path. Use Page Object Model for UI interactions. Extend existing POMs and triplets rather than creating new ones when the UI lives on an existing page surface.

**Skill:** Invoke `/senior-qa` for test scaffolding and strategy. Use `/playwright-pro` for E2E if Playwright is the test runner. If the project has an AAA (Arrange-Act-Assert) framework, use `/aaa-guide` for extending POMs, triplets, and fixtures, and `/aaa-add` for scaffolding new triplets.

**Rules:**
- Follow the test pyramid: most tests are unit (Phase 1), fewer integration, fewest E2E
- E2E tests should be independent and not depend on test execution order
- Use factories/fixtures for test data — no hardcoded values
- Iterate each test file until green before moving to the next

**Phase 2→3 gate (hard):** Before proceeding to Phase 3, cross-check the Phase 0 plan table. Every non-`N/A` entry in the E2E Coverage column must have a corresponding test file with at least one passing test. If any are missing — write them now. Do NOT enter validation with unwritten E2E cases from the approved plan.

**Output:** Integration, API, and E2E tests passing. All E2E Coverage entries from the plan table are covered.

---

## Phase 3: Validate (Full Pipeline)

**Goal:** Run the complete validation pipeline and classify results.

**Read AGENTS.md first** — the project's `AGENTS.md` (root or nearest subtree) defines the authoritative test suite list and exact commands. Use those commands verbatim. Do NOT substitute approximate commands (e.g., bare `vitest run` is not the same as `npm run test:integration:full:host` — the latter spins up a managed Postgres + Redis stack with a different test population).

**If the feature has UI changes, include visual verification:**
Use browser automation (Playwright MCP, Chrome DevTools MCP) to navigate the UI, inspect rendered state, and screenshot key flows. This catches CSS/layout issues (overlap, clipping, responsive breakage) that no test suite covers.

**Run in order:**
1. **Build** — compile/transpile
2. **Lint** — code style and static analysis
3. **Typecheck** — type safety (if applicable)
4. **Unit tests** — all unit tests
5. **Integration tests** — all integration tests (including DB-backed suites)
6. **E2E tests** — all end-to-end tests
7. **Visual verification** — browser inspection of UI changes (if applicable)

**Classify each failure:**
- **New** — introduced by current changes
- **Pre-existing** — failed before your changes (verify with `git stash` + run if uncertain)
- **Flaky** — passes on re-run without changes

**Only fix New failures.** Flag pre-existing and flaky for user awareness.

**Output:** Full pipeline report with all suites from AGENTS.md. Either CLEAN or FINDINGS with classified failures.

---

## Phase 4: Self-Fix

**Goal:** Fix all New failures found in Phase 3.

**Protocol:**
1. Read the failure (exact file, line, error message)
2. Reproduce — run the specific failing test in isolation
3. Apply fix
4. Run the specific test — confirm it passes
5. Run the **full test suite** — confirm no regressions
6. If full suite introduces new failures, fix those too (still within this phase)

**Cycle detection:**
- If you fix the same file a second time for the same root cause → **STOP**
- If the same test fails across 2 consecutive iterations → **STOP**
- Do NOT attempt a third fix. Escalate to user with diagnosis.

**Self-check rule:** If failures in 2 consecutive iterations trace to the same module or architectural decision, re-evaluate your Phase 0 design. The problem may be in the approach, not the code.

**Output:** All tests passing, or escalation with diagnosis.

---

## Phase 5: Review (Self-Review)

**Goal:** Quality and security gate on all changed code.

**Skill:** Apply `/code-reviewer` checks on your own changes.

**Review checklist:**
- [ ] No hardcoded secrets, API keys, or credentials
- [ ] No SQL injection, XSS, or command injection vectors
- [ ] No `any` types (TypeScript) or equivalent type escapes
- [ ] No debug statements (`console.log`, `debugger`, `print`)
- [ ] Functions under 50 lines, files under 500 lines
- [ ] No deep nesting (>4 levels)
- [ ] Error handling at system boundaries
- [ ] SOLID principles where natural (not forced)

**Fix any findings immediately**, then re-run the full test suite (loop back to Phase 3 if fixes are non-trivial).

**Output:** Code passes quality review. All tests still green.

---

## Convergence Loop

Phases 3→4→5 form a **bounded convergence loop**.

```
┌─────────────────────────────────────────────┐
│  Iteration 1: Validate → Self-Fix → Review  │
│  Iteration 2: Validate → Self-Fix → Review  │  ← delta only
│  Iteration 3: Validate → Self-Fix → Review  │  ← delta only
├─────────────────────────────────────────────┤
│  EXIT CHECK after iteration 3:              │
│    Tests green? Findings fixed? No regressions? │
│    YES → proceed to Phase 6                 │
│    NO  → choose one:                        │
│      EXTEND — 2 more iterations (5 max)     │
│      REDESIGN — back to Phase 0             │
│      ESCALATE — ask user for direction      │
├─────────────────────────────────────────────┤
│  HARD CEILING: 5 iterations                 │
│    After 5 → must escalate regardless       │
└─────────────────────────────────────────────┘
```

**Iteration 2+ behavior:**
- Only validate and fix delta from previous iteration
- Don't re-review code that already passed review
- Track what changed between iterations

---

## Phase 7: Delivery Checklist

**Goal:** Confirm every item in the user's original todo list was delivered.

**When:** Only when the user provided a todo list (checklist, numbered list, or bullet list) as the implementation brief.

**Steps:**
1. Re-read the user's original todo list
2. For each item, verify it was implemented (or explicitly scoped out in Phase 0)
3. Output a ticked checklist:

```
- [x] Item 1 — implemented in `path/to/file.ts`
- [x] Item 2 — implemented in `path/to/other.ts`
- [ ] Item 3 — SKIPPED: out of scope per Phase 0 plan (see escalation note)
```

4. If any items are unticked and were not scoped out in Phase 0 — implement them now or escalate.

**Output:** Ticked delivery checklist shared with user. All items accounted for.

---

## Phase 6: Docs

**Goal:** Update all documentation affected by code changes.

**Skill:** Use `/technical-writing` patterns.

**Steps:**
1. Identify all docs that reference changed functions, APIs, schemas, env vars, or file paths
2. **Grep for stale references** — search docs for old names that were renamed or removed
3. Update evergreen docs (`docs/*.md`) in-place to reflect current state
4. Write a transition guide if the change has behavioral differences, migrations, or removals
5. Do NOT update frozen snapshot docs (`docs/notes/`)

**Skip docs if:** Pure internal refactor with no behavioral change, test-only changes, or single bug fix with no user-facing impact.

**Output:** Documentation accurate and current.

---

## Escalation Rules

**Proceed autonomously when:**
- Spec clearly covers the scenario
- Approach follows existing codebase patterns
- Changes scoped to files in the plan
- One obvious correct approach exists

**Escalate to user when:**
- Spec is ambiguous or contradictory
- Implementation requires out-of-plan files (scope creep)
- Two valid approaches with different tradeoffs, no clear winner
- Blocking constraint discovered (dependency conflict, API limitation, existing bug)
- Convergence fails after 5 iterations (hard ceiling)
- Cycle detection triggered (same failure twice)

**Escalation format:**
```
## Blocked

**Reason:** [what triggered escalation]
**Context:** [what happened]
**Options:**
  A) [option + tradeoffs]
  B) [option + tradeoffs]
  C) [recommendation if any]
```

---

## Git Policy

- Do NOT create commits, branches, or push — leave for user
- All file changes remain uncommitted on disk for human review
- This keeps git history clean and lets the user control commit granularity

---

## Quick Reference: Skill Routing

| Phase | Primary Skill | References |
|-------|--------------|------------|
| 0 — Plan | `/tdd` | `tdd/interface-design.md`, `tdd/deep-modules.md`, scope artifacts |
| 1 — TDD | `/tdd` | `tdd/tests.md`, `tdd/mocking.md`, `tdd/refactoring.md` |
| 2 — Auto Tests | `/senior-qa`, `/playwright-pro`, `/aaa-guide`, `/aaa-add` | QA strategies, POM, triplets, E2E for UI |
| 3 — Validate | (built-in) | AGENTS.md test suite definition, browser MCP for visual |
| 4 — Self-Fix | (built-in) | Cycle detection, self-check |
| 5 — Review | `/code-reviewer` | Checklist, antipatterns, standards |
| 6 — Docs | `/technical-writing` | Evergreen docs, stale reference grep |
| 7 — Delivery Checklist | (built-in) | Tick off original todo list; flag or implement any gaps |
