# Triplet Pattern — Assistants, @Step(), Boundaries & Variants

The core AAA pattern: each page or endpoint gets three assistant classes (Arrange, Actions, Assert) plus a factory. This reference covers how to write correct triplet code.

→ See also: `architecture-overview.md` (always loaded), `pom-layer.md` (POM classes that triplets wrap)

---

## Assistant Triplet Anatomy

Each page or endpoint gets three assistant classes plus a factory:

```typescript
// Arrange — setup, navigation, data preparation
export class {{Name}}Arrange extends BaseArrange {
  private get el() { return this._instance.elements; }

  @Step()
  async openFeesTab() {
    await this.uiActions.click.perform(this.el.tabs.fees);
  }
}

// Actions — the behavior under test
export class {{Name}}Actions extends BaseActions {
  private get el() { return this._instance.elements; }

  @Step()
  async changeLocale(locale: string) { /* ... */ }
}

// Assert — verification
export class {{Name}}Assert extends BaseAssert {
  private get el() { return this._instance.elements; }

  @Step()
  async drawerIsClosed() {
    await expect(this.el.drawer).not.toBeVisible();
  }
}

// Factory + type export
export const {{name}}AssistantFactory = createAssistantFactory({
  Arrange: {{Name}}Arrange,
  Actions: {{Name}}Actions,
  Assert: {{Name}}Assert,
});
export type T{{Name}}Assistant = ReturnType<typeof {{name}}AssistantFactory>;
```

**Consumption in spec:**
```typescript
test("description", async ({ {{name}} }) => {
  // Arrange
  await {{name}}.arrange.doSetup();
  // Act
  await {{name}}.actions.doSomething();
  // Assert
  await {{name}}.assert.checkResult();
});
```

**Triplet scoping heuristic — when to create new vs extend existing:**
- Same Playwright `Page` instance + same navigation context = same triplet. Add methods to the existing Arrange/Actions/Assert.
- Different navigation context or independent lifecycle = new triplet. Create a new POM + triplet.
- Sub-components (dialogs, drawers, inline forms) within a page = nested POM inside the parent, same triplet.
- If a single triplet exceeds ~30 locators across its POM, consider splitting into sub-POMs composed into the parent (see `pom-layer.md`).

---

## @Step() Decorator Semantics

Dual-context decorator applied to all public AAA class methods:

- **Test context:** Wraps in `test.step()` with `box: true` — appears in Playwright traces, HTML reports, and error messages with human-readable names.
- **Global-setup context:** Falls back to console logger — no Playwright test context available.

DisplayName format: `[ClassName] methodName` (e.g., `[SettingsActions] changeLocale`).

---

## Boundary Rules

- **No `expect()` in Arrange classes** — Arrange sets up state, never verifies it.
- **No direct `page.*` in assistant classes** — All page interactions go through `this.uiActions` or locators from `this.el`. Direct `this.page.click()` bypasses logging and readability.
- **POMs are vocabulary, not behavior** — `BasePage`/`BaseEndpoint` define locators/HTTP bindings only. Business logic (clicking through a workflow, asserting a state) lives in assistant triplets.
- **No raw `expect()` in AAA spec files** — AAA specs (`*-aaa.spec.ts`, `*-aaa.http.spec.ts`) must route all assertions through Assert helpers. Enforced by ESLint `no-restricted-syntax` on `CallExpression[callee.name="expect"]`. Non-AAA specs are not subject to this rule. Actions/Assert classes use `expect()` freely — they ARE the abstraction layer. Actions use `expect()` for synchronization guards (e.g., `await expect(el).toBeVisible()` before clicking).
- **Arrange = setup, Actions = behavior under test** — Navigation to the starting point belongs in Arrange (e.g., `arrange.navigateToLogin()`). Navigation that IS the behavior under test belongs in Actions (e.g., `actions.clickDashboardLink()`). Do not call Arrange methods after Actions have started.
- **Direct `request` fixture is acceptable for transport-layer tests** — Security and transport tests (header injection, rate limiting, CORS) may use Playwright's raw `request` fixture alongside assistants. Heuristic: if the test verifies transport/header behavior, raw `request` is appropriate; if it verifies application behavior, use assistants.

---

## Accepted AAA Variants

### Interleaved act-assert (transactional verification)

Complex tests may interleave actions and assertions to verify prerequisites and atomicity:

```typescript
// Create resource → assert success → modify → assert success → delete → assert conflict
const createRes = await api.actions.create(payload);
await api.assert.statusIs(createRes, 200);

const modifyRes = await api.actions.modify(id, changes);
await api.assert.statusIs(modifyRes, 200);

const deleteRes = await api.actions.delete(id);
await api.assert.statusIs(deleteRes, 409);
await api.assert.fieldEquals(deleteRes, "code", "has_dependencies");
```

This is **not** an anti-pattern when:
- Each intermediate assertion is a prerequisite for the next step (the test can't proceed without it)
- The test verifies atomicity (action fails → state unchanged)
- The test verifies multi-step transactions

This **is** an anti-pattern when assertions are scattered randomly without purpose.

### Conditional assertion helpers

Environment-dependent assertions belong in named helper functions, not inline in test bodies:

```typescript
// ✅ Good — conditional logic in named helper
async function assertSecureCookieAttribute(session, response) {
  if (requiresSecure) {
    await session.assert.responseHeaderContains(response, "set-cookie", "; Secure");
    return;
  }
  await session.assert.valueNotIncludes(/* ... */);
}

// ❌ Bad — conditional logic inline in test body
test("cookie test", async ({ session }) => {
  if (requiresSecure) { /* ... */ } else { /* ... */ }
});
```

---

## Extension Recipes

### Recipe: Add a @Step() method to an existing Arrange class
Files: 1 (e.g., `DashboardArrange.ts`)

- [ ] Identify the class — must extend `BaseArrange` (or app-specific `AppBaseArrange`)
- [ ] Add method with `@Step()` decorator and `Promise<void>` return
- [ ] **Boundary:** No `expect()` calls — Arrange sets up state, never verifies
- [ ] Access elements via `this.el` (the `private get el()` getter), not `this.page.getByTestId()`
- [ ] If the method stubs a route, use `this.page.route()` — this is an allowed Arrange pattern

```typescript
@Step()
async seedNewState(): Promise<void> {
  await this.page.route("**/api/resource", (route) =>
    route.fulfill({ status: 200, body: JSON.stringify(data) }));
}
```

### Recipe: Add a @Step() method to an existing Actions class
Files: 1 (e.g., `DashboardActions.ts`)

- [ ] Identify the class — must extend `BaseActions` (or app-specific `AppBaseActions`)
- [ ] Add method with `@Step()` decorator and `Promise<void>` return
- [ ] Use `this.uiActions.click.perform()`, `this.uiActions.fill.perform()` etc. — not `this.page.click()`
- [ ] `expect()` is allowed in Actions for synchronization guards only (e.g., wait for element visible before clicking)
- [ ] Verify `declare protected readonly _instance` narrows to the correct Page type

```typescript
@Step()
async clickNewButton(): Promise<void> {
  await this.uiActions.click.perform(this.el.newButton);
}
```

### Recipe: Add a @Step() method to an existing Assert class
Files: 1 (e.g., `DashboardAssert.ts`)

- [ ] Identify the class — must extend `BaseAssert` (or app-specific equivalent)
- [ ] Add method with `@Step()` decorator and `Promise<void>` return
- [ ] Use `expect()` freely — Assert classes ARE the assertion layer
- [ ] Access elements via `this.el`, not `this.page.getByTestId()`
- [ ] For reusable assertion patterns, consider using `mx*` mixin methods from `AssertMixin` (e.g., `this.mxAssertTruthy()`)

```typescript
@Step()
async newElementIsVisible(): Promise<void> {
  await expect(this.el.newElement).toBeVisible();
}

@Step()
async newElementContainsText(text: string | RegExp): Promise<void> {
  await expect(this.el.newElement).toContainText(text);
}
```

### Recipe: Add a @Step() method to an existing API triplet (Arrange/Actions/Assert)
Files: 1 (e.g., `AccountsApiActions.ts`)

- [ ] Same boundary rules as web triplets, plus:
- [ ] API Actions methods typically call `this._instance.get()`, `.post()`, `.patch()`, `.delete()` and return `Promise<APIResponse>`
- [ ] API Assert methods use `this.mxAssertResponseStatus()`, `this.mxAssertDeepEqual()` etc.
- [ ] API Arrange methods use `this.body(response)` and `this.header(response, name)` for response parsing
- [ ] Pass `this.authHeaders` to endpoint methods for authenticated requests

```typescript
// API Actions:
@Step()
async createResource(data: unknown): Promise<APIResponse> {
  return this._instance.post("/api/resource", data, this.authHeaders);
}

// API Assert:
@Step()
async statusIs(response: APIResponse, expected: number): Promise<void> {
  await this.mxAssertResponseStatus(response, expected);
}
```
