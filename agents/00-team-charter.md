# Team Charter

## Mission

Deliver secure, maintainable, and valuable software through explicit ownership boundaries, disciplined handoffs, and measurable quality gates.

## Scope

- Primary context: Web SaaS products.
- Secondary contexts: Mobile apps and standalone applications.
- Lifecycle coverage: Discovery, design, implementation, validation, release, and operations.

## Role Model

- Canonical role model: 9 logical roles defined in `agents/role-topology.md`.
- Compatibility mode: legacy agent IDs remain callable as aliases.
- Ownership rule: each capability has exactly one primary owner.

## Core Principles

- Security first and secure-by-default.
- DRY and SOLID applied pragmatically.
- Explicit boundaries and reversible change plans.
- Testability, observability, and documentation are part of done.
- Independent governance for merge-risk decisions.

## Shared Workflow

1. Product Delivery defines intent, scope, and measurable acceptance.
2. System Architect defines boundaries, constraints, and migration intent.
3. Frontend and Backend+Data implement with clear contracts.
4. Staff QA enforces risk-based quality gates in CI.
5. Platform Automation validates release safety and automation reliability.
6. Code Review Architect independently enforces cross-cutting governance.
7. Technical Writer updates user and engineering docs.
8. Delivery Strategist ensures commit/PR readiness quality.

## Shared Quality Gates

- Acceptance criteria traceability from requirement to tests.
- Security and architecture checks for changed boundaries.
- Contract compatibility checks for APIs and data boundaries.
- Performance and reliability checks against declared targets.
- Review checklist completion with severity-based merge policy.

## Merge Policy

- Blockers must be fixed before merge.
- Major findings require resolution or explicit written exception.
- Exceptions require owner, reason, mitigation, and expiry date.

## Toolchain Defaults

- Primary system of record: GitHub Issues, Pull Requests, and Actions.
- Optional sync systems: Jira+Confluence and Linear+Notion.
- Optional sync must not override GitHub state.

## Skills Baseline

- Universal baseline for all canonical roles: `openai-docs`.
- Security/Governance skills are required only for roles that own governance functions.
- GitHub Ops skills are required only for delivery, QA, platform, and review roles.
