# Engineering Agent Team

This directory defines a canonical multi-agent model with implementation roles plus function-based reviewer overlays.

## Core Documents

- `00-team-charter.md`: Team-wide mission, workflow, and governance.
- `role-topology.md`: Canonical role map and capability ownership.
- `skills-matrix.md`: Capability-tiered skill policy and role bindings.
- `review-checklist.md`: Shared review checklist and severity policy.

## Canonical Contracts

- `role-architect.md`
- `role-product-manager.md`
- `role-project-manager.md`
- `role-frontend-engineer.md`
- `role-backend-engineer.md`
- `role-qa-engineer.md`
- `role-ui-ux-designer.md`
- `role-devops.md`
- `role-technical-writer.md`
- `role-git-orchestrator.md`
- `role-frontend-reviewer.md`
- `role-backend-reviewer.md`
- `role-devops-reviewer.md`
- `role-qa-reviewer.md`
- `role-database-reviewer.md`
- `role-design-reviewer.md`

## Operating Defaults

- Product context: Web SaaS first, with extensions for mobile and standalone apps.
- Workflow of record: GitHub Issues/PRs/Actions.
- Secondary systems: Jira+Confluence and Linear+Notion as optional sync layers.
- Governance: `architect` + domain reviewers are final blocker gates.
- Git operations: `git-orchestrator` executes commit/branch/PR/release-note workflows.

## Validation

- `config.base.toml` defines the tracked agent catalog; onboarding regenerates runtime `config.toml` from base + machine-local `config.local.toml`.
- Do not edit `config.toml` directly.
- Run `scripts/test-onboarding.sh` when changing onboarding/config scripts.
- Run `scripts/validate-role-skill-topology.py` after role/skills changes.
