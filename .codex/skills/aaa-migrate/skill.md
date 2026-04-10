---
name: "aaa-migrate"
description: "Migrate legacy tests to AAA framework. Full orchestration: classify tests (Category A/B/C), dual-pair migration per file, automated parity validation, cleanup legacy."
---

# /aaa:migrate — Migrate Legacy Tests to AAA

Full orchestration of legacy test migration to the AAA framework. Detects "no legacy tests remain" and reports completion.

## Before Starting

Read the architecture references:
- `~/.claude/skills/aaa/references/architecture-overview.md` — three-layer arch, dependency direction, locked decisions
- `~/.claude/skills/aaa/references/migration-classification.md` — Category A/B/C, multi-assistant patterns
- `~/.claude/skills/aaa/references/triplet-pattern.md` — triplet anatomy, @Step(), boundary rules (target pattern)

## Workflow

### Phase 1: Classification

Scan all test files and classify each as Category A, B, or C:

| Category | Criteria | Action |
|---|---|---|
| **A** — Clean migration | Test only uses HTTP requests + response assertions. Litmus: "Can this be proven from real HTTP responses + follow-up reads?" | Full migration to AAA |
| **B** — Partial migration | Some assertions migrate, others need unit-test capabilities (mocks, module inspection) | Split file: HTTP-contract → AAA, internals → stay |
| **C** — No migration | Requires `vi.mock()`, `vi.stubGlobal()`, persistence/event-bus inspection, DB-schema assertions | Document why, leave in unit runner |

Present classification table for user review. User can reclassify before proceeding.

### Phase 2: Migration Planning

For each file:
- **Category A:** Plan full migration — list all test scenarios
- **Category B:** Plan split — which assertions migrate, which stay. Document the split rationale.
- **Category C:** Document why it stays

User confirms migration plan before execution.

### Phase 3: Dual-Pair Migration (per file)

For each Category A/B file, in order:

1. **Create `*-aaa.spec.ts`** alongside the legacy file
2. **Tracer bullet** — migrate ONE scenario first:
   - Create/reuse POM or Endpoint
   - Create Arrange/Actions/Assert triplet
   - Write the AAA spec for that one scenario
   - Run both legacy and AAA versions — verify same outcome
3. **Pair validate** — run the pair validator:
   - Compare normalized test titles (strip filename prefix)
   - Verify assertion counts match
4. **Migrate remaining scenarios** in the file
5. **Full pair validation** — all scenarios in the file

**Assistant helper contracts must stay backward-compatible** during migration. Do not tighten types until the legacy file is deleted.

### Phase 4: Parity Validation

For each migrated file:
- Run legacy spec → capture results
- Run AAA spec → capture results
- Compare: all test titles match, all pass/fail states match
- If divergence: investigate before proceeding

### Phase 5: Cleanup

Only after parity confirmed for a file:
1. Delete the legacy spec file
2. Remove unused helper imports
3. Remove backward-compatibility shims from assistant helpers (tighten types)
4. Update any test index or config files

### Phase 6: Completion Detection

After each file:
- Check if any legacy test files remain
- When none remain: report "migration complete"
- Run full test suite as final validation (all 7 suites if the project defines them)

## Key Rules

- **Never delete legacy before parity is confirmed**
- **One file at a time** — do not batch migrate
- **Pair validators compare normalized titles**, not raw reporter paths (filename prefix differs)
- **Keep assistant contracts backward-compatible** until legacy is deleted
- **Category B splits must document** which assertions stayed and why

## Output

All Category A tests migrated, Category B split, Category C documented. Full suite green.
