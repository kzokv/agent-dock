# AAA Architecture Overview

Constitutional constraints for the AAA test framework. Always loaded alongside domain-specific references.

---

## Three-Layer Architecture

```
{{PROJECT_PREFIX}}/config/test  (test env config — no test code)
         │
         ▼
test-framework  (generic, app-agnostic base classes + shared utilities)
    ┌────┴────┐
    ▼         ▼
test-e2e   test-api   (sibling app-specific layers — NEVER import each other)
```

- **test-framework** — reusable across projects. Contains base classes, mixins, decorators, fixture helpers, and shared utilities.
- **test-e2e** — app-specific web E2E: page objects (POMs), assistant triplets, fixtures, config.
- **test-api** — app-specific API HTTP: endpoint descriptors, assistant triplets, fixtures, config.

`test-e2e` and `test-api` are parallel siblings. Neither may import from the other. All shared code lives in `test-framework`.

---

## Dependency Direction

```
test-framework ← test-e2e   (imports from framework, never reverse)
test-framework ← test-api   (imports from framework, never reverse)
test-e2e ✗ test-api          (siblings — NEVER import from each other)
```

Why `BaseEndpoint` and `BasePage` stay in test-framework: `TestUser` constructs instances via typed factory methods. Moving base classes to app-specific layers creates circular dependencies.

Shared utilities (URL helpers, cookie parsers, ID generators) live in `test-framework/shared/`:
- `appUrl(path)` — builds web app URL from `TestEnv.appBaseUrl` (e.g., `http://localhost:3333/dashboard`)
- `apiUrl(path)` — builds API server URL from `TestEnv.apiBaseUrl` (e.g., `http://127.0.0.1:4000/settings`)
- `buildE2EUserId(testInfo)` — deterministic user ID per test: `"qa-{filename}-{title}-worker{n}"` (max 72 chars)
- `buildDisplayName(testInfo)` — short label for Playwright traces: `"{acronym}:{worker}:{firstName}"`
- `parseSessionCookie(value)` — splits `{userId}.{hmac}` format
- `UUID_V4_PATTERN` — regex for UUID v4 validation in assertions

Centralize all route paths, endpoint paths, timeouts, and test data constants in a `constants/` module. No hardcoded strings in assistants or specs.

---

## Locked Decisions

| Decision | Rationale |
|---|---|
| **Thin endpoint** — `BaseEndpoint` returns raw `APIResponse` | 47% of tests assert non-2xx; typed returns lie for error paths; header/cookie access needed |
| **Per-test sessions** — no shared auth setup projects | Each test mints its own session. Parallel-safe by design. |
| **2-worker parallel-by-file** — no same-file `fullyParallel` | Stable on resource-constrained hardware. Same-file fan-out caused contention. |
| **No AAA for trivial unit tests** — 2-6 line pure function tests stay flat | AAA ceremony costs more than it helps for `expect(fn(x)).toBe(y)`. |
