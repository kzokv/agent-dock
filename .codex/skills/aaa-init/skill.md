---
name: "aaa-init"
description: "Bootstrap AAA (Arrange-Act-Assert) test framework in a new Playwright monorepo. Discovers codebase, interviews user on architecture, scaffolds 3 layers + rules + ESLint plugin."
---

# /aaa:init — Bootstrap AAA Framework

Scaffolds a complete AAA test framework in a Playwright-based monorepo.

## Hard Boundaries

- **Playwright-based monorepos only** — Playwright is a prerequisite; monorepo workspace structure is assumed.
- **Thin endpoint pattern** — `BaseEndpoint` returns raw `APIResponse`, not pre-parsed typed bodies.
- **Per-test sessions** — no shared auth setup projects; each test mints its own session.
- **2-worker parallel-by-file** — no same-file `fullyParallel`.
- **No AAA for trivial unit tests** — 2-6 line pure function tests stay flat in vitest/jest.

## Before Starting

Read the architecture references and templates:
- `~/.claude/skills/aaa/references/architecture-overview.md` — three-layer arch, dependency direction, locked decisions
- `~/.claude/skills/aaa/references/test-user.md` — TestUser lifecycle, caching, notes
- `~/.claude/skills/aaa/references/mixin-composition.md` — core class hierarchy, mixin pattern
- `~/.claude/skills/aaa/references/triplet-pattern.md` — triplet anatomy, @Step(), boundary rules, accepted variants
- `~/.claude/skills/aaa/references/pom-layer.md` — BasePage, BaseEndpoint, sub-components
- `~/.claude/skills/aaa/references/fixture-chain.md` — fixture chain, Playwright config, test data builders
- `~/.claude/skills/aaa/references/migration-classification.md` — Category A/B/C (for classification awareness)
- `~/.claude/skills/aaa/templates/` — all scaffold templates

## Workflow

### Phase 1: Discovery

Scan the codebase for:
- Test runner (must be Playwright — abort if not found)
- Monorepo layout (workspace detection from `package.json`)
- Existing test files and patterns
- Framework/API stack (for POM/endpoint tailoring)
- Existing Playwright configs

Read: `package.json` workspaces, `tsconfig.json` paths, existing `playwright.config.*`

### Phase 2: Interview

Present auto-detected findings first. Then ask always-ask questions (not auto-detectable):

1. **displayName format** — how test users should be named in reports
2. **Auth patterns** — which of the 4 auth modes apply (no auth, header token, session cookie, intentionally missing for 401 tests)
3. **Test classification criteria** — what constitutes Category A/B/C tests for this project
4. **Per-test session strategy** — how to mint fresh sessions per test
5. **Parallel execution configuration** — worker count, parallel-by-file vs fullyParallel

For each architectural question, present a recommendation with rationale. User can:
- Accept the recommendation
- Override with their own choice
- Trigger `/debate` for structured resolution on contested decisions

### Phase 3: Scope Lock

Summarize all decisions in a table. User confirms before scaffold begins.

### Phase 4: Scaffold

Generate from templates (in `~/.claude/skills/aaa/templates/`):

1. **Libs:** `test-framework/` (core, mixins, decorators, config), `test-e2e/` (if web app detected), `test-api/` (if API detected)
2. **Fixture chain:** `base.ts` → app-specific extensions
3. **First triplet:** Scaffolded against a real page/endpoint discovered in the codebase (not synthetic examples)
4. **Playwright config:** `createPlaywrightConfig()` factory
5. **Package.json / tsconfig updates:** Workspace registration, path aliases
6. **Rules:** Single `aaa-testing.md` rule file (8 universal rules) placed in `.claude/rules/`
7. **ESLint plugin:** Custom plugin with AAA-specific rules

### Phase 5: Validation

- Run typecheck on scaffolded code
- Run lint
- Verify first triplet compiles and fixture chain is valid

## Output

Working AAA framework with one real triplet, passing typecheck and lint. Ready for test authoring.
