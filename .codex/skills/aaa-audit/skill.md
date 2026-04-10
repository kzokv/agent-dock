---
name: "aaa-audit"
description: "Check AAA compliance across test files. Scans for boundary violations, dependency direction issues, and semantic anti-patterns beyond what ESLint catches."
---

# /aaa:audit — Check AAA Compliance

Scans test files for AAA pattern violations. Deeper than static analysis — includes semantic checks.

## Before Starting

Read the architecture references:
- `~/.claude/skills/aaa/references/architecture-overview.md` — dependency direction, locked decisions
- `~/.claude/skills/aaa/references/triplet-pattern.md` — boundary rules, accepted variants, @Step() semantics

## Workflow

### Phase 1: Framework Detection

- Verify AAA framework exists (`test-framework/`, `test-e2e/`, `test-api/`)
- Locate all assistant classes, spec files, and fixture chains
- Build inventory of files to audit

### Phase 2: Static Checks

These overlap with ESLint but catch patterns the plugin may miss:

| Check | Severity | Description |
|---|---|---|
| `expect()` in Arrange class | Error | AAA boundary violation — Arrange must not verify |
| Direct `this.page.*` in assistant | Warning | Bypasses logging/readability layer |
| Missing `@Step()` on public method | Warning | Method won't appear in Playwright traces |
| Missing `get el()` typed getter | Warning | May lose type safety on element access |

Note: `expect()` in Actions/Assert classes is **allowed** — AAA assistants ARE the abstraction layer. Actions use `expect()` for synchronization guards (e.g., `await expect(el).toBeVisible()` before clicking). The rule is: no raw `expect()` in **AAA spec files** (`*-aaa.spec.ts`, `*-aaa.http.spec.ts`), not in assistant classes. Non-AAA specs are not subject to this rule.

This is enforced by ESLint via `no-restricted-syntax` on `CallExpression[callee.name="expect"]` scoped to AAA spec file globs.

### Phase 3: Semantic Analysis

Deeper checks that require understanding intent:

| Check | Severity | Description |
|---|---|---|
| Direct `expect()` in AAA spec body | Error | Enforced by ESLint `no-restricted-syntax` — only applies to `*-aaa.spec.ts` / `*-aaa.http.spec.ts` |
| Shared mutable state between tests | Error | Fixture isolation violation |
| `test-e2e` importing from `test-api` | Error | Dependency direction violation |
| `test-api` importing from `test-e2e` | Error | Dependency direction violation |
| `fullyParallel: true` on test file | Error | Same-file fan-out prohibited |
| `networkidle` usage | Error | Incompatible with SSE (hangs forever) |
| `page.waitForTimeout()` usage | Warning | Fixed sleeps hide root causes |
| Fixture not resetting module state | Warning | May cause cross-test state leaks |

### Phase 4: Report

Output a structured compliance report:

```
## AAA Compliance Report

### Errors (must fix)
- [file:line] Description — suggested fix

### Warnings (should fix)
- [file:line] Description — suggested fix

### Info
- [file:line] Description — context

### Summary
- X files scanned
- Y errors, Z warnings
- Overall compliance: X%
```

## Output

Compliance report with actionable items, grouped by severity.
