---
name: aaa
description: AAA (Arrange-Act-Assert) test framework for Playwright-based monorepos. Bootstrap, add triplets, audit compliance, or migrate legacy tests.
---

# /aaa — AAA Test Framework Skill

Bootstraps, extends, audits, and migrates AAA (Arrange-Act-Assert) test frameworks for **Playwright-based monorepos**. The framework separates test infrastructure into three layers: `test-framework` (generic), `test-e2e` (web-specific), and `test-api` (API-specific).

## Hard Boundaries

- **Playwright-based monorepos only** — Playwright is a prerequisite; monorepo workspace structure is assumed.
- **Thin endpoint pattern** — `BaseEndpoint` returns raw `APIResponse`, not pre-parsed typed bodies.
- **Per-test sessions** — no shared auth setup projects; each test mints its own session.
- **2-worker parallel-by-file** — no same-file `fullyParallel`.
- **No AAA for trivial unit tests** — 2-6 line pure function tests stay flat in vitest/jest.

## Reference & Templates

- Architecture references: `references/` (7 topic files — see below)
- Templates: `templates/` (7 scaffold files + ESLint plugin)

### Reference Files

| File | Topics |
|---|---|
| `architecture-overview.md` | Three-layer arch, dependency direction, locked decisions |
| `test-user.md` | TestUser lifecycle, caching, notes, extension recipes |
| `mixin-composition.md` | Core class hierarchy, mixin pattern, extension recipes |
| `triplet-pattern.md` | Triplet anatomy, @Step(), boundary rules, accepted variants, extension recipes |
| `pom-layer.md` | BasePage, BaseEndpoint, sub-components, extension recipes |
| `fixture-chain.md` | Fixture chain, Playwright config, test data builders, extension recipes |
| `migration-classification.md` | Category A/B/C, multi-assistant patterns |

---

## Subcommands

### /aaa:guide — Extend Existing AAA Components

**Purpose:** Guide agents and users through modifying existing framework pieces — POMs, triplets, mixins, fixtures, TestUser.

**Workflow:**

1. **Detection** — Classify the extension type by file-target detection (primary) or natural language (fallback). Load the relevant reference file(s) with checklist recipes.
2. **Verification** — After implementation, run prescriptive checks (typecheck, lint, test suite) based on the extension type and blast radius.

**When to use:** An agent is building a feature and needs to add a test method, locator, fixture, or other capability to the existing AAA framework. Or the user wants guided scaffolding for framework extensions.

**Not for:** Creating entirely new triplets (use `/aaa:add`) or bootstrapping a new framework (use `/aaa:init`).

---

### /aaa:init — Bootstrap AAA Framework

**Purpose:** Scaffold a complete AAA test framework in a new project.

**Workflow:**

1. **Discovery Phase**
   - Scan codebase for: test runner (must be Playwright), monorepo layout (workspace detection), existing test files, framework/API stack
   - Read `package.json` workspaces, `tsconfig.json` paths, existing `playwright.config.*`
   - Identify: web app directories, API server directories, existing test helpers

2. **Interview Phase**
   - Present auto-detected findings first
   - Ask always-ask questions (not auto-detectable):
     - **displayName format** — how test users should be named in reports
     - **Auth patterns** — which of the 4 auth modes apply (no auth, header token, session cookie, intentionally missing for 401 tests)
     - **Test classification criteria** — what constitutes Category A/B/C tests
     - **Per-test session strategy** — how to mint fresh sessions per test
     - **Parallel execution configuration** — worker count, parallel-by-file vs fullyParallel
   - For each architectural question, present a recommendation with rationale
   - User can: accept, override, or trigger a `/debate` for structured resolution

3. **Scope Lock**
   - Summarize all decisions
   - User confirms before scaffold begins

4. **Scaffold Phase**
   - Read the architecture references (see Reference Files table above) for structural patterns
   - Generate from templates:
     - `libs/test-framework/` — core classes, mixins, decorators, config, shared utilities
     - `libs/test-e2e/` (if web app detected) — pages, assistants, fixtures
     - `libs/test-api/` (if API detected) — endpoints, assistants, fixtures
   - Generate fixture chain: `base.ts` → app-specific extensions
   - Generate first triplet against a real page/endpoint discovered in codebase (not synthetic)
   - Generate `createPlaywrightConfig()` factory
   - Update `package.json` workspaces and `tsconfig.json` paths
   - Place `aaa-testing.md` rules in `.claude/rules/` (from `templates/aaa-testing.md.tmpl`)
   - Scaffold ESLint plugin (from `templates/eslint-plugin-aaa/`)

**Output:** Working AAA framework with one real triplet, passing typecheck and lint.

---

### /aaa:add — Add New Triplet

**Purpose:** Add a new Arrange/Actions/Assert triplet to an existing AAA framework.

**Workflow:**

1. **Detection**
   - Check for existing AAA framework (`test-framework/`, `test-e2e/`, `test-api/`)
   - If not found → redirect to `/aaa:init`
   - Detect target: is user adding a web page or API endpoint?

2. **Source Analysis**
   - Read the target page component or API route source code
   - Identify: elements/locators (web), HTTP methods/routes (API), data shapes

3. **Generation**
   - From `templates/assistant-triplet.ts.tmpl`:
     - POM class (web) or Endpoint descriptor (API)
     - Arrange class with setup methods
     - Actions class with behavior methods
     - Assert class with verification methods
     - Factory + type export
   - From `templates/fixture-chain.ts.tmpl`:
     - Fixture extending the appropriate base
   - Register in assistant mapper

4. **Validation**
   - Run typecheck on the new triplet
   - Verify fixture chain compiles

**Output:** New triplet registered and type-safe. Ready for spec authoring.

---

### /aaa:audit — Check AAA Compliance

**Purpose:** Scan test files for AAA pattern violations — deeper than static analysis.

**Workflow:**

1. **Framework Detection**
   - Verify AAA framework exists
   - Locate all assistant classes, spec files, and fixture chains

2. **Static Checks** (overlaps with ESLint but catches more)
   - `expect()` in Arrange classes → violation
   - `expect()` in Actions classes → violation
   - Direct `this.page.*` in assistant classes → violation
   - Missing `@Step()` on public assistant methods → warning
   - Assistant class not using `get el()` typed getter → warning

3. **Semantic Analysis**
   - Spec files with direct `expect()` calls (should go through Assert helpers)
   - Fixture isolation: shared mutable state between tests
   - Dependency direction: `test-e2e` importing from `test-api` or vice versa
   - `fullyParallel: true` on any test file → violation
   - `networkidle` usage in any test → violation (incompatible with SSE)

4. **Report**
   - Violations grouped by severity (Error, Warning, Info)
   - File paths + line numbers
   - Suggested fix for each violation

**Output:** Compliance report with actionable items.

---

### /aaa:migrate — Migrate Legacy Tests to AAA

**Purpose:** Full orchestration of legacy test migration to AAA framework.

**Workflow:**

1. **Classification Phase**
   - Scan all test files
   - Classify each as Category A, B, or C:
     - **A** — Clean migration: HTTP-contract assertions only
     - **B** — Partial: some assertions migrate, some stay
     - **C** — No migration: requires unit-test capabilities (mocks, module inspection)
   - Present classification table for user review

2. **Migration Planning**
   - For each Category A file: plan full migration
   - For each Category B file: plan split (which assertions migrate, which stay)
   - Category C files: document why they stay
   - User confirms migration plan

3. **Dual-Pair Migration** (per file)
   - Create `*-aaa.spec.ts` alongside legacy file
   - Migrate one scenario as tracer bullet
   - Run pair validator (normalized title comparison)
   - Migrate remaining scenarios
   - Run full pair validator

4. **Parity Validation**
   - Compare legacy vs AAA spec results
   - Verify all assertions have equivalents
   - Run both specs side-by-side

5. **Cleanup**
   - Only after parity confirmed: delete legacy spec
   - Remove unused helpers/imports
   - Update any test index files

6. **Completion Detection**
   - After each file: check if legacy tests remain
   - When no legacy tests remain: report "migration complete"
   - Run full test suite as final validation

**Output:** All Category A tests migrated, Category B split, Category C documented. Full suite green.

---

## Enforcement Surfaces

| Surface | Scope | When |
|---|---|---|
| `.claude/rules/aaa-testing.md` | Agent-enforced AAA boundaries | Always (generated at scaffold time) |
| ESLint plugin (`eslint-plugin-aaa`) | CI-enforced static analysis | On commit / PR |
| `/aaa:audit` | Semantic compliance check | On-demand (deeper than static analysis) |
