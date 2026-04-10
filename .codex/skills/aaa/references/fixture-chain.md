# Fixture Chain — Fixtures, Config & Test Data

Fixtures wire assistants into Playwright's test runner. This reference covers the fixture extension chain, config conventions, and test data builders.

→ See also: `architecture-overview.md` (always loaded), `triplet-pattern.md` (assistants that fixtures expose)

---

## Fixture Chain Pattern

```typescript
// base.ts — testUser + createTestUser
const baseTest = test.extend<{ testUser: TestUser; createTestUser: () => Promise<TestUser> }>({
  testUser: async ({ page, request }, use) => { /* ... */ },
  createTestUser: async ({ request }, use) => { /* ... */ },
});

// appShell.ts — extends base → provides appShell assistant
const appShellTest = baseTest.extend<{ appShell: TAppShellAssistant }>({
  appShell: async ({ testUser }, use) => {
    const assistant = await testUser.useWebAssistant(AppShellPage);
    await use(assistant);
  },
});

// settings.ts — extends appShell → provides settings assistant
const settingsTest = appShellTest.extend<{ settings: TSettingsAssistant }>({ /* ... */ });

// One-liner fixture factory
export const test = createWebFixture(settingsTest);
```

For API:
```typescript
const apiBaseTest = test.extend<{ testUser: TestUser }>({ /* no page needed */ });
const settingsApiTest = apiBaseTest.extend<{ settingsApi: TSettingsApiAssistant }>({
  settingsApi: async ({ testUser }, use) => {
    const assistant = await testUser.useApiAssistant(SettingsEndpoint);
    await use(assistant);
  },
});
```

---

## Route Prewarming

Base fixtures can prewarm critical routes during page setup to reduce flakiness from cold Next.js routes. Use a module-level `Set` to cache which routes have been prewarmed per worker, so only the first test in a worker pays the cost. Document which fixture bases prewarm and which don't — tests may behave differently on first vs subsequent runs in the same worker.

---

## ActionLogger Per-Test Reset

`ActionLogger` captures `performance.now()` at construction for elapsed timestamps. When a shared logger instance is reused across tests (e.g., `defaultUIActions`), elapsed times accumulate from module load — not from test start.

The fixture layer creates a **fresh `ActionLogger` per test** via `createTestActionLogger(testInfo)`, so this is normally invisible. If you ever reuse a logger across tests (e.g., for custom tooling), call `logger.resetStartTime()` in fixture setup to re-baseline timestamps.

---

## Fixture Base Decision Tree

Document which base to use for each auth/setup scenario. Every project should have a clear mapping from test type to fixture base. The wrong base is a silent failure — tests may pass but not exercise the intended auth path.

---

## Assistant Factory Registry

Assistants are wired via a registry that maps Page/Endpoint constructors to factory functions:

```typescript
// mapper.ts
export function registerTestE2EAssistants(): void {
  webAssistantRegistry
    .register(LoginPage, loginAssistantFactory)
    .register(DashboardPage, dashboardAssistantFactory)
    // ... etc
}

export function registerTestApiAssistants(): void {
  apiAssistantRegistry
    .register(AccountsEndpoint, accountsApiAssistantFactory)
    // ... etc
}
```

Registrations are idempotent (guarded by a `registered` flag). Each registry exposes `_reset()` for test isolation when overriding factories in unit tests. Normal E2E/API test runs never call `_reset()` — the per-worker singleton registrations are correct by design.

---

## Playwright Config Conventions

Recommended `createPlaywrightConfig()` defaults:

```typescript
{
  retries: process.env.CI ? 2 : 0,       // Flakiness visible locally, tolerated in CI
  trace: "on-first-retry",                // Trace on first retry for debugging
  screenshot: "only-on-failure",          // Minimal storage
  video: { mode: "retain-on-failure" },   // Video kept on failure only
  timeout: 30_000,                        // 30s test timeout
  expectTimeout: 10_000,                  // 10s assertion timeout
  fullyParallel: false,                   // File-level parallelism only
  reuseExistingServer: false,             // Always fresh servers
}
```

**Config-per-auth-mode:** Create separate Playwright config files for each auth mode × server topology combination (e.g., `playwright.config.ts` for dev_bypass, `playwright.oauth.config.ts` for OAuth). Each gets its own report directory. Do not use multi-project within a single config for auth separation.

---

## Test Data Builders

Provide stateless factory functions for test payloads:

```typescript
// apps/api/test/helpers/fixtures.ts
export function transactionPayload(): TransactionInput { /* minimal valid payload */ }
export function feeProfilePayload(): FeeProfileInput { /* minimal valid payload */ }
```

**Conventions:**
- Builders return minimal valid payloads — tests override specific fields as needed.
- Stateless (no random data, no side effects). Same function always returns the same shape.
- Shared across both vitest (integration tests) and Playwright (HTTP API specs).
- **Naming:** avoid collision with Playwright's "fixtures" concept. These are test data factories, not Playwright test fixtures.

---

## Extension Recipes

### Recipe: Add a fixture for an existing assistant
Files: 1–2 (fixture file + potentially the composite fixture file)

- [ ] Decide which fixture base to extend (authenticated, unauthenticated, session-based)
- [ ] Add the fixture using `createWebFixture` or `createApiFixture`
- [ ] Export the extended test

```typescript
// For a new web assistant:
import { createWebFixture } from "test-e2e/config";
import { NewPage } from "test-e2e/pages";
import type { TNewAssistant } from "test-e2e/assistants";

export interface TNewFixtures {
  newAssistant: TNewAssistant;
}

export const test = base.extend<TNewFixtures>({
  newAssistant: createWebFixture<TNewAssistant>(NewPage),
});

// For a new API assistant:
import { createApiFixture } from "test-api/config";
import { NewEndpoint } from "test-api/endpoints";
import type { TNewApiAssistant } from "test-api/assistants";

export const test = apiBase.extend<{ newApi: TNewApiAssistant }>({
  newApi: createApiFixture<TNewApiAssistant>(NewEndpoint),
});
```

### Recipe: Add an assistant to an existing composite fixture
Files: 1 (the composite fixture file, e.g., `appPages.ts`)

- [ ] Import the assistant type and Page/Endpoint class
- [ ] Add to the fixture interface
- [ ] Add the `createWebFixture` / `createApiFixture` entry

```typescript
// In appPages.ts:
export interface TAppPagesFixtures {
  // ... existing
  newPage: TNewAssistant;
}

export const test = base.extend<TAppPagesFixtures>({
  // ... existing
  newPage: createWebFixture<TNewAssistant>(NewPage),
});
```

### Recipe: Register an assistant in the mapper
Files: 1 (`mapper.ts` in test-e2e or test-api)

- [ ] Import the Page/Endpoint class and the assistant factory
- [ ] Add `.register()` call in the registration function

```typescript
// test-e2e/src/config/mapper.ts:
import { NewPage } from "../pages";
import { newAssistantFactory } from "../assistants";

export function registerTestE2EAssistants(): void {
  webAssistantRegistry
    // ... existing
    .register(NewPage, newAssistantFactory);
}
```

### Recipe: Create a new fixture base variant
Files: 2–3 (new fixture file + shared.ts if new user setup needed)

- [ ] Determine how this base differs from existing bases (auth mode, session type, prewarm set)
- [ ] If it needs different `TestUser` setup, add a new builder in `shared.ts` or parameterize `buildUserFixtures()`
- [ ] Create the fixture file extending `base` from Playwright
- [ ] Document the fixture base in the decision tree
- [ ] If it needs new `TestUser` capabilities → see `test-user.md`

```typescript
// newBase.ts:
import { test as base } from "@playwright/test";
import { buildUserFixtures, type TBaseFixtures } from "./shared";

export const test = base.extend<TBaseFixtures>({
  ...buildUserFixtures(true), // or false, or a new parameter
  // Add any base-specific fixtures here
});
```

### Recipe: Add a test data builder
Files: 1 (test helpers/fixtures file)

- [ ] Create a stateless factory function returning a minimal valid payload
- [ ] No random data, no side effects — deterministic output
- [ ] Export from the shared test helpers module

```typescript
export function newResourcePayload(): NewResourceInput {
  return {
    name: "Test Resource",
    // minimal valid fields only
  };
}
```
