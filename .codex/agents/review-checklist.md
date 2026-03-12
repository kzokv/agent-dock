# Review Checklist

This checklist is used by domain reviewers and architect governance.

## Severity Levels

- `Blocker`: Must be fixed before merge.
- `Major`: Fix before merge unless a written exception is approved.
- `Minor`: Should be fixed soon and tracked.
- `Nit`: Non-blocking improvement.

## Review Workflow

1. Assess change risk and affected boundaries.
2. Apply this checklist with domain-specific depth.
3. Classify findings by severity and confidence.
4. Issue a merge decision with explicit remediation guidance.

## Security Checks

- Authentication and authorization are correct for all new paths.
- Input validation and output encoding are applied where needed.
- Secret handling avoids plaintext exposure and unsafe logging.
- Dependency and configuration changes do not reduce baseline security.
- Threat surface changes are called out in PR description.

## Architecture and Design Checks

- Module boundaries are explicit and respected.
- Dependency direction is one-way and avoids cycles.
- Public interfaces are stable, minimal, and documented.
- UI/UX changes preserve interaction consistency and accessibility intent.
- Schema and migration changes preserve compatibility and rollback safety.

## Test and Operability Checks

- Unit, integration, and end-to-end coverage match change risk.
- Negative paths and error handling are exercised.
- CI gates prevent silent regression.
- Rollback and recovery expectations are documented for risky releases.

## Merge Rules

- Any unresolved `Blocker` blocks merge.
- Security `Major` findings default to block unless approved exception exists.
- Final blocker gate is held by architect + relevant domain reviewers.

## Exception Policy

- Exceptions are allowed only for `Major` findings, never for `Blocker`.
- Every exception must include owner, reason, mitigation, and expiry date.
- Expired exceptions are treated as unresolved findings.

## Escalation Triggers

- Critical security flaw in a release-bound branch.
- Repeated unresolved `Major` findings across the same area.
- High-risk coupling increase without an approved mitigation plan.
