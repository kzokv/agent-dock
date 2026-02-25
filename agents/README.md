# Engineering Agent Team

This directory defines a consolidated multi-agent engineering model with 9 canonical roles and compatibility aliases for legacy agent IDs.

## Core Documents

- `00-team-charter.md`: Team-wide mission, workflow, and guardrails.
- `role-topology.md`: Canonical role map, alias map, and capability ownership.
- `skills-matrix.md`: Capability-tiered skill policy and role bindings.
- `review-checklist.md`: Shared review checklist and severity policy.

## Canonical Contracts

- `role-product-delivery-manager.md`
- `role-system-architect.md`
- `role-staff-frontend.md`
- `role-backend-data-engineer.md`
- `role-staff-qa.md`
- `role-platform-automation.md`
- `role-technical-writer.md`
- `role-code-review-architect.md`
- `role-delivery-strategist.md`

## Compatibility Alias Files

- `01-product-manager.md` and `09-project-manager.md` -> `role-product-delivery-manager.md`
- `02-system-architect.md` -> `role-system-architect.md`
- `03-staff-frontend-developer.md` -> `role-staff-frontend.md`
- `04-staff-backend-developer.md` and `05-db-designer.md` -> `role-backend-data-engineer.md`
- `06-staff-quality-assurance.md` -> `role-staff-qa.md`
- `07-senior-devops.md` and `10-script-developer.md` -> `role-platform-automation.md`
- `08-technical-writer.md` -> `role-technical-writer.md`
- `11-code-review-architect.md` -> `role-code-review-architect.md`
- `12-commit-strategist.md` and `13-pr-strategist.md` -> `role-delivery-strategist.md`

## Operating Defaults

- Product context: Web SaaS first, with extensions for mobile and standalone apps.
- Workflow of record: GitHub Issues/PRs/Actions.
- Secondary systems: Jira+Confluence and Linear+Notion as optional sync layers.
- Governance: Security and architecture checks are independently enforced by Code Review Architect.

## Validation

- `config.toml` keeps legacy agent IDs callable and maps each to a logical role.
- Canonical role contracts own skills and boundaries; alias files stay short.
- `scripts/validate-role-skill-topology.py` verifies skills, capability ownership, and skill metadata hygiene.
