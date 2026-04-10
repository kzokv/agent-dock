# Migration Classification — Category A/B/C & Multi-Assistant Patterns

Reference for classifying and migrating legacy tests to the AAA framework.

→ See also: `architecture-overview.md` (always loaded), `triplet-pattern.md` (target pattern for migrated tests)

---

## Category A/B/C Classification

When migrating existing tests to AAA:

| Category | Criteria | Action |
|---|---|---|
| **A** — Clean migration | Test only uses HTTP requests + response assertions. Can be proven from real HTTP responses + follow-up reads. | Migrate to Playwright HTTP with AAA triplets. |
| **B** — Partial migration | Some assertions migrate, others need unit-test capabilities (mocks, module inspection). | Split file: HTTP-contract tests → Playwright, internals → stay in unit runner. |
| **C** — No migration | Requires `vi.mock()`, `vi.stubGlobal()`, persistence inspection, event-bus inspection, or DB-schema assertions. | Stay in unit test runner (vitest/jest). |

**Litmus test:** "Can this assertion be proven only from real HTTP responses plus follow-up HTTP reads?" If not, it's Category B or C.

**Migration order:**
1. Classify all test files (A/B/C)
2. Add `*-aaa.spec.ts` alongside legacy
3. Validate one pair as a tracer bullet
4. Run full pair validator (normalized title comparison)
5. Only then delete legacy spec

---

## Multi-Assistant Tests

Most real-world AAA specs use 2-5 assistants per test. This is the dominant pattern, not the exception.

```typescript
test("logout: clear session → redirect to login", async ({ dashboard, login, session }) => {
  // Arrange — use session assistant to verify logged-in state
  await session.arrange.verifyLoggedIn();
  // Act — use dashboard assistant to trigger logout
  await dashboard.actions.clickLogout();
  // Assert — use login assistant to verify redirect
  await login.assert.isOnLoginPage();
});
```

**Guidelines:**
- 3-4 assistants per test is the sweet spot for readability. If you need 5+, consider whether the test covers too much.
- Cross-assistant state flow: one assistant's action produces state that another assistant asserts. This is intentional — assistants are domain-scoped, tests often cross domains.
- Multi-user scenarios: the fixture provides a "default" user. For additional users, mint sessions explicitly via API assistant methods (e.g., `sessionApi.actions.createOauthSessionForClaims()`), then pass cookies to subsequent assistant calls.
- `createTestUser()` factory spawns additional `TestUser` instances with their own `Page`. Used for tests needing multiple browser contexts. Pages are cleaned up automatically on teardown.
