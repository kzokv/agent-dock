---
name: "aaa-guide"
description: "Guide agents and users through extending existing AAA framework components — POMs, triplets, mixins, fixtures, TestUser. Routes by file-target detection, provides checklist recipes, verifies correctness."
---

# /aaa:guide — Extend Existing AAA Components

Guides agents and users through modifying existing AAA framework pieces. Routes by detecting the file being modified, loads the relevant reference with checklist recipes, and verifies correctness after implementation.

**Consumers:** Autonomous agents mid-task (reads recipe, self-implements) and interactive users (guided step-by-step).

## Hard Boundaries

- **Playwright-based monorepos only** — same as all `/aaa` sub-commands.
- **Do not create new triplets here** — use `/aaa:add` for new pages/endpoints. `/aaa:guide` is for extending *existing* framework pieces.
- **Architecture constraints are non-negotiable** — dependency direction, boundary rules, and locked decisions from `architecture-overview.md` always apply.

## Before Starting

Read the architecture reference (always loaded):
- `~/.claude/skills/aaa/references/architecture-overview.md`

Then load the **primary reference** based on the routing table below.

---

## Recipe Index

| Extension type | File pattern being modified | Primary reference | Secondary (if needed) |
|---|---|---|---|
| Add locator to POM | `*Page.ts`, `*Component.ts` | `pom-layer.md` | — |
| Add dynamic function element | `*Page.ts`, `*Component.ts` | `pom-layer.md` | — |
| Add sub-component to composite POM | `*Page.ts` + new `*Component.ts` | `pom-layer.md` | `fixture-chain.md` (if exposing as fixture) |
| Add `@Step()` method to Arrange | `*Arrange.ts` | `triplet-pattern.md` | — |
| Add `@Step()` method to Actions | `*Actions.ts` | `triplet-pattern.md` | — |
| Add `@Step()` method to Assert | `*Assert.ts` | `triplet-pattern.md` | — |
| Add API triplet method | `*Api{Arrange,Actions,Assert}.ts` | `triplet-pattern.md` | — |
| Add HTTP method to endpoint | `*Endpoint.ts` | `pom-layer.md` | — |
| Create new endpoint descriptor | `endpoints/*.ts` | `pom-layer.md` | `triplet-pattern.md`, `fixture-chain.md` |
| Add fixture for existing assistant | `fixtures/*.ts` | `fixture-chain.md` | — |
| Add assistant to composite fixture | `fixtures/appPages.ts` etc. | `fixture-chain.md` | — |
| Register assistant in mapper | `config/mapper.ts` | `fixture-chain.md` | — |
| Create new fixture base variant | `fixtures/*.ts` + `shared.ts` | `fixture-chain.md` | `test-user.md` (if new auth mode) |
| Add test data builder | `test/helpers/*.ts` | `fixture-chain.md` | — |
| Add method to existing mixin | `*Mixin*.ts` | `mixin-composition.md` | — |
| Create new mixin | `mixins/*.ts` + `mixins/index.ts` | `mixin-composition.md` | `triplet-pattern.md` (if adding to base) |
| Add app-specific base override | `bases/*.ts` | `mixin-composition.md` | — |
| Add TestUser property | `TestUser.ts` | `test-user.md` | — |
| Add TestUser method | `TestUser.ts` | `test-user.md` | — |
| Add TestUser state pattern | `TestUser.ts` + potentially `shared.ts` | `test-user.md` | `fixture-chain.md` |

---

## Workflow

### Phase 1: Detection

**For autonomous agents (file-target detection):**

1. Identify the file being modified (or the file the agent intends to modify)
2. Match against the file patterns in the Recipe Index above
3. Load `architecture-overview.md` (always) + the primary reference
4. If a secondary reference is indicated, load it too
5. Navigate to the `## Extension Recipes` section in the primary reference
6. Follow the matching recipe checklist

**For interactive users (natural language fallback):**

1. Ask: "What are you extending?" — present the Recipe Index as a menu
2. If the user describes intent in natural language, classify into one of the extension types
3. Load the relevant references
4. Walk through the recipe checklist step by step, asking for input at decision points

**Classification heuristic for natural language:**
- "add a button/element/locator" → POM locator recipe
- "add a test method/step/assertion" → triplet recipe (ask which role: Arrange/Actions/Assert)
- "add a new component to the page" → sub-component recipe
- "add a fixture/wire up an assistant" → fixture recipe
- "add shared behavior/helper method" → mixin recipe
- "add state to TestUser" → TestUser recipe

### Phase 2: Verification

After the consumer implements the recipe, verify correctness. Run the checks prescribed for the extension type:

| Extension type | Verification commands |
|---|---|
| **POM changes** (locator, component, element) | `npm run typecheck` — verify TElements interface and initializeElements() are consistent |
| **Triplet changes** (@Step method) | `npm run typecheck` + `npx eslint .` — verify no boundary violations (expect in Arrange, direct page.* access) |
| **Endpoint changes** | `npm run typecheck` |
| **Fixture changes** | `npm run typecheck` + run one test that uses the fixture to confirm wiring |
| **Mixin changes** | `npm run typecheck` + run the full test suite for the affected layer (test-e2e or test-api) — blast radius is wide |
| **TestUser changes** | `npm run typecheck` + run the full test suite — core class, blast radius is widest |

**Escape hatch:** If the consumer is confident the change is trivial (e.g., adding one locator to an existing POM), they may skip the full verification and rely on typecheck only. The prescriptive checks above are the recommended minimum.

**Dependency direction check (all extension types):**
After implementation, verify no new imports violate the dependency graph:
- `test-e2e` must not import from `test-api`
- `test-api` must not import from `test-e2e`
- Neither may import from app code (`apps/`)
- Both may only import from `test-framework` and `config/test`

---

## Output

- **For autonomous agents:** Recipe checklist completed, verification passed. Agent continues with its primary task.
- **For interactive users:** Recipe checklist walked through, verification run, summary of changes made.
