# TestUser — Lifecycle & Semantics

TestUser is the shared orchestrator that holds identity, page/request references, and the assistant cache. It is the single class through which all assistants are created and test sessions are managed.

→ See also: `architecture-overview.md` (always loaded)

---

## Class Shape

```typescript
class TestUser {
  readonly userId: string;
  readonly page?: Page;
  readonly request: APIRequestContext;
  sessionCookie?: string;

  async useWebAssistant<TPage, TAAA>(PageClass: Constructor<TPage>): Promise<TAAA>;
  async useApiAssistant<TEndpoint, TAAA>(EndpointClass: Constructor<TEndpoint>): Promise<TAAA>;
  async reset(apiBaseUrl: string): Promise<void>;
  async assignIdentity(appBaseUrl: string): Promise<void>;
  setSessionCookie(value: string): void;
  appendNote<T>(key: string, values: T[]): void;
  getNote<T>(key: string): T[] | undefined;
}
```

---

## Methods and Side Effects

| Method | API call | Clears assistant cache? | Clears notes? | Clears sessionCookie? | Clears cookies? | Sets identity cookie? |
|---|---|---|---|---|---|---|
| `reset(apiBaseUrl)` | POST `/__e2e/reset` | **Yes** | **Yes** | **Yes** | No | No |
| `assignIdentity(appBaseUrl)` | None | No | No | No | **Yes (ALL cookies)** | Yes (`tw_e2e_user`) |
| `setSessionCookie(value)` | None | No | No | No | No | No |

**Critical — `reset()` clears all client-side state:** After `reset()`, calling `useWebAssistant()` or `useApiAssistant()` creates fresh instances (not cached). Notes and sessionCookie are also wiped. This is intentional — `reset()` returns the TestUser to a clean-slate state matching the server reset.

**Critical — `assignIdentity()` nukes all browser cookies:** Calls `page.context().clearCookies()` before setting the identity cookie. Any cookies set during Arrange (OAuth session, feature flags) are wiped. Call this before other cookie-dependent setup, or re-set those cookies after.

---

## Assistant Caching

`TestUser` caches assistants by Constructor in `assistantCache`. `useWebAssistant()` and `useApiAssistant()` return cached instances on repeat calls. The cache **is cleared on `reset()`** — after reset, the next `useWebAssistant()` / `useApiAssistant()` call creates a fresh instance.

---

## Identity Generation

- `buildE2EUserId(testInfo)` — deterministic slug: `"qa-{filename}-{title}-worker{n}"`. Same test always gets the same user ID.
- `buildDisplayName(testInfo)` — short label: `"{acronym}:{worker}:{firstName}"`. Used in `@Step()` labels for trace readability.

---

## Notes System

Cross-triplet state sharing via `appendNote<T>(key, values)` / `getNote<T>(key)`:

```typescript
// In one triplet — capture data
testUser.appendNote("transactionIds", [txId]);

// In another triplet — consume data
const ids = testUser.getNote<string>("transactionIds");
```

Notes are append-only within a test. Use for passing data between assistants that operate on different pages/endpoints within the same test.

---

## Extension Recipes

### Recipe: Add a new property to TestUser
Files: 1 (`TestUser.ts`)

- [ ] Add the property to the class (readonly if state is set once, mutable if updated during test)
- [ ] Initialize in constructor from `TTestUserOptions` (extend the options interface if needed)
- [ ] Document the property's lifecycle: when set, when cleared, who reads it

```typescript
// TTestUserOptions:
export interface TTestUserOptions {
  // ... existing
  newProperty?: string;
}

// TestUser class:
readonly newProperty: string | undefined;

constructor(options: TTestUserOptions) {
  // ... existing
  this.newProperty = options.newProperty;
}
```

### Recipe: Add a new method to TestUser
Files: 1 (`TestUser.ts`)

- [ ] Add the method to the class
- [ ] Document side effects (does it clear cache? clear cookies? make API calls?)
- [ ] Update the "Methods and Side Effects" table in this reference if the method has side effects
- [ ] If the method needs to be called from fixtures, ensure it's public

```typescript
async newLifecycleMethod(baseUrl: string): Promise<void> {
  // Document: API call? Cache effect? Cookie effect?
}
```

### Recipe: Add a new state management pattern (beyond notes)
Files: 1-2 (`TestUser.ts` + potentially fixture shared.ts)

- [ ] Consider if `appendNote`/`getNote` already covers the use case
- [ ] If notes are insufficient (e.g., need typed access, reset semantics, or non-append behavior):
  - Add a private backing field
  - Add public getter/setter or method
  - Add a `_reset*` method if state must be cleared between test phases
- [ ] If the new state affects fixture setup, update the relevant fixture's `buildUserFixtures()` → see `fixture-chain.md`
