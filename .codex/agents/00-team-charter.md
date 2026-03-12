# Team Charter

## Mission

Deliver secure, maintainable, and valuable software through explicit ownership boundaries, disciplined handoffs, and measurable quality gates.

## Scope

- Primary context: Web SaaS products.
- Secondary contexts: Mobile apps and standalone applications.
- Lifecycle coverage: Discovery, design, implementation, validation, release, and operations.

## Role Model

- Canonical model: implementation/coordination roles plus reviewer overlays defined in `~/.codex/agents/role-topology.md`.
- Immediate cutover: no legacy alias IDs are part of the operating model.
- Ownership rule: each capability has exactly one primary owner.

## Core Principles

- Security first and secure-by-default.
- DRY and SOLID applied pragmatically.
- Explicit boundaries and reversible change plans.
- Testability, observability, and documentation are part of done.
- Independent governance for merge-risk decisions.

## Shared Workflow

1. Product and project managers define intent, scope, and measurable acceptance.
2. Architect defines boundaries, constraints, and migration intent.
3. Frontend/backend/UI-UX roles implement with clear contracts.
4. QA and DevOps enforce risk-based quality and release gates.
5. Reviewer overlays enforce domain-specific governance.
6. Git Orchestrator executes commit/branch/PR and release-note flow.
7. Technical Writer updates user and engineering docs.

## Merge Policy

- Blockers must be fixed before merge.
- Major findings require resolution or explicit written exception.
- Exceptions require owner, reason, mitigation, and expiry date.
- Architect + domain reviewers are final blocker authorities.

## Skills Baseline

- Canonical role bindings live only in `~/.codex/agents/skills-matrix.md`.
- Matrix skill ids resolve to repo-relative paths under `~/.codex/skills`.
- `openai-docs` is a universal optional skill, not a universal requirement.
- Required skills must reflect role-core capability rather than narrow external-context workflows.
