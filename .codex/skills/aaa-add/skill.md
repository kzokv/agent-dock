---
name: "aaa-add"
description: "Add a new Arrange/Actions/Assert triplet to an existing AAA framework. Detects page/endpoint, generates POM/endpoint + triplet + fixture. Redirects to /aaa:init if framework not found."
---

# /aaa:add — Add New Triplet

Adds a new Arrange/Actions/Assert assistant triplet to an existing AAA framework.

## Before Starting

Read the architecture references:
- `~/.claude/skills/aaa/references/architecture-overview.md` — three-layer arch, dependency direction, locked decisions
- `~/.claude/skills/aaa/references/triplet-pattern.md` — triplet anatomy, @Step(), boundary rules
- `~/.claude/skills/aaa/references/pom-layer.md` — BasePage, BaseEndpoint, sub-components
- `~/.claude/skills/aaa/references/fixture-chain.md` — fixture chain, mapper registration

## Workflow

### Phase 1: Detection

- Check for existing AAA framework (`test-framework/`, `test-e2e/`, `test-api/`)
- If not found → tell the user to run `/aaa:init` first
- Detect target: is user adding a web page or API endpoint?
- If ambiguous, ask.

### Phase 2: Source Analysis

Read the target page component or API route source code. Identify:
- **Web:** elements/locators, component structure, data-testid attributes, user interactions
- **API:** HTTP methods, route paths, request/response shapes, auth requirements

### Phase 3: Generation

Using templates from `~/.claude/skills/aaa/templates/`:

**For web (test-e2e):**
1. POM class extending `BasePage<TElements>` — with `locate()` calls for each testid
2. Arrange class extending `BaseArrange` — setup/navigation methods
3. Actions class extending `BaseActions` — user interaction methods
4. Assert class extending `BaseAssert` — verification methods
5. Factory (`createAssistantFactory`) + type export in `index.ts`
6. Fixture extending the appropriate base fixture

**For API (test-api):**
1. Endpoint descriptor extending `BaseEndpoint` — named HTTP method bindings
2. Arrange class extending `ApiBaseArrange` — seed/setup via HTTP
3. Actions class extending `ApiBaseActions` — API call methods
4. Assert class extending `ApiBaseAssert` — status/body/header verification
5. Factory + type export in `index.ts`
6. Fixture extending the API base fixture

**In both cases:**
- All public methods decorated with `@Step()`
- Each assistant has `private get el()` typed getter (by design, not duplication)
- Register in the assistant mapper

### Phase 4: Validation

- Run typecheck on the new triplet
- Verify fixture chain compiles
- Verify mapper registration is correct

## Output

New triplet registered and type-safe. Ready for spec authoring.
