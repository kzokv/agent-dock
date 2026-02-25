# Review Checklist

This checklist is used by the Code Review Architect and supports all reviewers.

## Severity Levels

- `Blocker`: Must be fixed before merge.
- `Major`: Fix before merge unless a written exception is approved.
- `Minor`: Should be fixed soon and tracked.
- `Nit`: Non-blocking improvement.

## Security Checks

- Authentication and authorization are correct for all new paths.
- Input validation and output encoding are applied where needed.
- Secret handling avoids plaintext exposure and unsafe logging.
- Dependency and configuration changes do not reduce baseline security.
- Threat surface changes are called out in PR description.

## DRY and Reuse

- No unnecessary duplication of business logic.
- Shared utilities are extracted when repeated patterns emerge.
- Duplicate tests are reduced using fixtures and helper functions.

## SOLID and Design

- Single responsibility for modules and services.
- Open/closed principle respected through extension points, not forks.
- Liskov substitution and interface compatibility maintained.
- Interface segregation keeps APIs focused and minimal.
- Dependency inversion is used for pluggable infrastructure concerns.

## Structure and Decoupling

- Module boundaries are explicit and respected.
- Dependency direction is one-way and avoids cycles.
- Composition is favored over inheritance for feature behavior.
- Public interfaces are stable, minimal, and documented.

## Test Quality

- Unit, integration, and end-to-end coverage match change risk.
- Negative paths and error handling are exercised.
- Flaky tests are quarantined with issue tracking and owner.
- CI gates prevent silent regression.

## Performance and Reliability

- New hot paths have basic cost and latency awareness.
- Idempotency, retries, and timeout behavior are explicit.
- Failure modes and rollback paths are documented for risky changes.

## Documentation and Operability

- Architecture and API docs are updated for public behavior changes.
- Runbook changes are included for operationally relevant updates.
- Release notes include user-impacting behavior changes.

## Merge Rules

- Any unresolved `Blocker` blocks merge.
- Security `Major` findings default to block unless approved exception exists.
- Exception record must include owner, risk, mitigation, and expiration date.
