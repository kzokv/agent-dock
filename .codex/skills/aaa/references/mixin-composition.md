# Mixin Composition — Core Classes & Inheritance

The mixin system composes behavior onto AAABase classes. This reference covers the base class hierarchy and how mixins extend it.

→ See also: `architecture-overview.md` (always loaded), `triplet-pattern.md` (triplet classes extend these bases)

---

## Core Class Hierarchy

### AAABase (shared spine)
```typescript
abstract class AAABase {
  protected readonly _instance: BasePage<unknown> | BaseEndpoint;
  readonly page?: Page;
  readonly request: APIRequestContext;
}
```

### WebAAABase (extends AAABase)
- Requires `Page` — holds `_instance: BasePage<TElements>`
- Provides `uiActions` (fill, click, select, wait with logging)
- **Runtime guard:** Constructor throws if neither `options.page` nor `_instance.page` is available. This catches misconfigured factory options early instead of producing cryptic `undefined` errors downstream.

### ApiAAABase (extends AAABase)
- No `Page` requirement — holds `_instance: BaseEndpoint`
- Provides `authHeaders` getter (self-selecting: cookie if set, else x-user-id header)
- **Priority rule:** `sessionCookie` wins over `userId`. If both are set, a warning is logged and the cookie header is used. This typically indicates confused test setup — a test shouldn't set both.

---

## Mixin Composition Pattern

Mixins extend the AAABase classes to compose behavior:

```
CoreMixin(AAABase)
├── mxWaitForShellClientReady(timeoutMs?)
└── mxWaitForAppReady(timeoutMs?)    (delegates to mxWaitForShellClientReady)

ArrangeMixin(AAABase) ← includes CoreMixin
├── mxWaitForAppReady()     (from Core)
└── mxSeedData()

ActionsMixin(AAABase) ← includes CoreMixin
├── mxWaitForAppReady()
├── mxNavigateToRoute()
├── mxReloadPage()
└── mxWaitForResponse()

AssertMixin(AAABase) ← includes CoreMixin + GenericAssertMixin
├── mxAssertUrlMatches()      (web-specific)
├── mxAssertNoGlobalError()   (web-specific)
├── mxAssertTruthy()          (generic)
├── mxAssertEqual()           (generic)
└── mxAssertContains()        (generic)
```

**Diamond composition is intentional:** `ArrangeMixin` and `ActionsMixin` both include `CoreMixin`, creating a diamond. TypeScript's mixin pattern resolves this correctly — `mxWaitForAppReady()` from `CoreMixin` exists once on the composed class via JS prototype chain. Do not flag this as a design issue.

---

## CoreMixin Soft-Wait Behavior

`mxWaitForShellClientReady(timeoutMs?)` is a **soft-wait** — it waits for `domcontentloaded` (hard), then `load` (soft, with timeout). If the load-state wait times out, a warning is logged and execution continues. It never throws on timeout.

- `timeoutMs` controls the load-state timeout (default: 5000ms)
- `mxWaitForAppReady(timeoutMs?)` delegates to `mxWaitForShellClientReady`
- Override `mxWaitForAppReady()` in app-specific bases to add element-readiness checks (e.g., `expect(getByTestId("app-shell-ready")).toBeVisible()`)

---

## Pre-Composed Exports

```typescript
// Web
const BaseArrange = ArrangeMixin(WebAAABase);
const BaseActions = ActionsMixin(WebAAABase);
const BaseAssert  = AssertMixin(WebAAABase);

// API
const ApiBaseArrange = ApiArrangeMixin(ApiAAABase);
const ApiBaseActions = ApiActionsMixin(ApiAAABase);
const ApiBaseAssert  = ApiAssertMixin(ApiAAABase);
```

Triplet classes extend these pre-composed exports. See `triplet-pattern.md` for how they're used.

---

## Extension Recipes

### Recipe: Add a method to an existing mixin
Files: 1 (the mixin file, e.g., `ActionsMixin.ts`)

- [ ] Add the method inside the mixin's returned class
- [ ] Prefix with `mx` (mixin namespace convention): `mxNewCapability()`
- [ ] Decorate with `@Step()` for trace visibility
- [ ] Verify the method is available on all pre-composed exports that use this mixin

```typescript
// Inside the mixin function:
export function ActionsMixin<TBase extends Constructor<AAABase>>(Base: TBase) {
  return class extends CoreMixin(Base) {
    // ... existing methods

    @Step()
    async mxNewCapability(): Promise<void> {
      // implementation
    }
  };
}
```

### Recipe: Create a new mixin
Files: 3+ (new mixin file + `mixins/index.ts` re-export + pre-composed export update)

- [ ] Create the mixin function following the pattern: `export function MyMixin<TBase extends Constructor<AAABase>>(Base: TBase)`
- [ ] Decide if it wraps `CoreMixin(Base)` (needs core methods) or just `Base` (standalone)
- [ ] Export from `mixins/index.ts`
- [ ] Compose into the appropriate pre-composed export(s) — or document that it's opt-in per triplet
- [ ] If the mixin is web-specific, constrain the generic: `Constructor<WebAAABase>`
- [ ] If the mixin is API-specific, constrain: `Constructor<ApiAAABase>`

```typescript
// New mixin:
export function MyMixin<TBase extends Constructor<WebAAABase>>(Base: TBase) {
  return class extends Base {
    @Step()
    async mxMyMethod(): Promise<void> {
      // implementation
    }
  };
}

// Opt-in composition (per-triplet, not global):
export class SpecialActions extends MyMixin(BaseActions) {
  // ...
}

// OR global composition (affects all triplets using this base):
// Update mixins/index.ts:
export const BaseActions = MyMixin(ActionsMixin(WebAAABase));
```

- [ ] **Blast radius check:** If composing globally, run the full test suite — all existing triplets inherit the new method
- [ ] **Dependency direction:** Mixin must live in the correct layer (test-framework for shared, test-e2e/test-api for app-specific)

### Recipe: Add an app-specific base class override
Files: 1-2 (app base file, e.g., `AppBaseActions.ts` + potentially `bases/index.ts`)

- [ ] Extend the pre-composed base (e.g., `BaseActions`) in the app-specific layer
- [ ] Override the mixin method you want to customize (e.g., `mxWaitForAppReady()`)
- [ ] Update triplets in that layer to extend the app-specific base instead of the generic one

```typescript
// test-e2e/src/bases/AppBaseActions.ts
export class AppBaseActions extends BaseActions {
  @Step()
  override async mxWaitForAppReady(): Promise<void> {
    await expect(this.page.getByTestId("app-shell-ready")).toBeVisible();
  }
}

// Triplets extend AppBaseActions instead of BaseActions:
export class DashboardActions extends AppBaseActions { /* ... */ }
```
