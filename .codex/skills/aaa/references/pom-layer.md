# POM Layer — BasePage, BaseEndpoint & Sub-Components

Page Object Models (POMs) and endpoint descriptors are the vocabulary layer. They define locators and HTTP bindings — business logic lives in triplets, not here.

→ See also: `architecture-overview.md` (always loaded), `triplet-pattern.md` (triplets that wrap these POMs)

---

## BasePage

```typescript
abstract class BasePage<TElements> {
  readonly page: Page;
  abstract elements: TElements;
  protected locate(testId: string, description?: string): Locator;
  protected locateByRole(role: string, options?: { description?: string }): Locator;
  protected withDescription(locator: Locator, description?: string): Locator;
  protected abstract initializeElements(): void;
}
```

**`locate()` description convention:** Attach human-readable labels for Playwright traces. Convention: noun phrases in Title Case with container context (e.g., `"Save Settings Button"`, `"Settings Locale Select"`). These appear in HTML reports, trace viewer, and action logs. If omitted, the raw locator string is used.

---

## POM Composition (Sub-Components)

`initializeElements()` may instantiate child POMs alongside locators. Use this for composite pages built from smaller vocabulary pieces:

```typescript
protected initializeElements(): void {
  this._elements = {
    topBar: new TopBarComponent(this.page),      // child POM
    title: this.locate("page-title", "Page title"), // static locator
  };
}
```

Child POMs receive `this.page` — they share the same Page instance. Shared components live in `pages/shared/` and parent POMs give them a contextual slot name.

---

## Dynamic Function Elements

For DOM elements whose testid depends on runtime data, use `(param) => Locator`:

```typescript
this._elements = {
  profileName: (index: number) =>
    this.locate(`fee-profile-name-${index}`, `Fee Profile Name ${index}`),
};
```

Note: function elements don't get `withDescription()` wrapping automatically — call it in the function body.

---

## Nested Locator Chaining

For components inside a specific container, define a `root` locator and chain children from it:

```typescript
const root = this.locate("side-navigation", "Side navigation");
this._elements = {
  root,
  dashboardLink: root.getByTestId("nav-dashboard"),
  portfolioLink: root.getByTestId("nav-portfolio"),
};
```

This scopes element resolution to the container, preventing ambiguity when multiple instances exist on the page.

---

## BaseEndpoint

```typescript
class BaseEndpoint {
  constructor(protected readonly request: APIRequestContext) {}
  // Named HTTP methods returning raw APIResponse
  protected async get(url: string, headers?: Record<string, string>): Promise<APIResponse>;
  protected async post(url: string, data?: unknown, headers?: Record<string, string>): Promise<APIResponse>;
  protected async patch(url: string, data?: unknown, headers?: Record<string, string>): Promise<APIResponse>;
  protected async delete(url: string, headers?: Record<string, string>): Promise<APIResponse>;
}
```

**Key insight:** `BaseEndpoint` returns raw `APIResponse`, not pre-parsed typed bodies. 47% of real-world tests assert on non-2xx responses — typed returns are a type lie for error paths. Header/cookie access also requires raw responses.

---

## Extension Recipes

### Recipe: Add a locator to an existing POM
Files: 1 (e.g., `DashboardPage.ts`)

- [ ] Add the typed property to the `TElements` interface
- [ ] Add the locator binding in `initializeElements()`
- [ ] Use `this.locate("test-id", "Description")` for testid-based elements
- [ ] Use `this.locateByRole("button", { name: "Submit", description: "Submit Button" })` for role-based
- [ ] Use `this.withDescription(this.page.getByText("..."), "Description")` for text-based

```typescript
// TElements interface:
export interface TDashboardElements {
  // ... existing
  newElement: Locator;
}

// initializeElements():
protected initializeElements(): void {
  this._elements = {
    // ... existing
    newElement: this.locate("new-element-testid", "New Element Description"),
  };
}
```

### Recipe: Add a dynamic function element to an existing POM
Files: 1

- [ ] Add the function signature to `TElements` interface
- [ ] Add the function in `initializeElements()`
- [ ] Call `this.locate()` inside the function body for description wrapping

```typescript
// TElements interface:
rowByIndex: (index: number) => Locator;

// initializeElements():
rowByIndex: (index: number) =>
  this.locate(`row-${index}`, `Row ${index}`),
```

### Recipe: Add a sub-component to a composite POM
Files: 2–3

- [ ] **Create the component class** — new file extending `BasePage<TNewElements>`
  - Define `TNewElements` interface with the component's locators
  - Implement `initializeElements()`
  - Place in `pages/shared/` if reusable, or `pages/{domain}/` if domain-specific
- [ ] **Update the parent POM** — add the component to parent's `TElements` interface and `initializeElements()`
- [ ] **Export** from the domain's `index.ts`
- [ ] _(If the component needs its own triplet methods)_ — add methods to the parent's existing Arrange/Actions/Assert, accessing via `this.el.newComponent.elements.someLocator`

```typescript
// NewComponent.ts:
export interface TNewComponentElements {
  root: Locator;
  title: Locator;
  closeButton: Locator;
}

export class NewComponent extends BasePage<TNewComponentElements> {
  protected initializeElements(): void {
    const root = this.locate("new-component", "New Component");
    this._elements = {
      root,
      title: root.getByTestId("component-title"),
      closeButton: root.getByTestId("component-close"),
    };
  }
}

// Parent POM update:
// TParentElements:
newComponent: NewComponent;

// initializeElements():
newComponent: new NewComponent(this.page),
```

### Recipe: Add an HTTP method to an existing endpoint
Files: 1 (e.g., `AccountsEndpoint.ts`)

- [ ] Add the method using the inherited `this.get()`, `this.post()`, etc.
- [ ] Return `Promise<APIResponse>` — never pre-parse the body
- [ ] Accept `headers` parameter for auth header forwarding
- [ ] Use URL helpers from constants, not hardcoded strings

```typescript
async getById(id: string, headers?: Record<string, string>): Promise<APIResponse> {
  return this.get(`${ACCOUNTS_URL}/${id}`, headers);
}
```

### Recipe: Create a new endpoint descriptor
Files: 2–3

- [ ] Create endpoint class extending `BaseEndpoint` in `test-api/src/endpoints/`
- [ ] Define HTTP method bindings (get, post, patch, delete) for the API routes
- [ ] Export from `endpoints/index.ts`
- [ ] Create triplet + factory → see `triplet-pattern.md` recipes
- [ ] Register in mapper → see `fixture-chain.md` recipes

```typescript
export class NewEndpoint extends BaseEndpoint {
  async list(headers?: Record<string, string>): Promise<APIResponse> {
    return this.get(NEW_RESOURCE_URL, headers);
  }

  async create(data: unknown, headers?: Record<string, string>): Promise<APIResponse> {
    return this.post(NEW_RESOURCE_URL, data, headers);
  }
}
```
