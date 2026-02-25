# Role Topology

This document defines the canonical 9-role model and preserves existing agent IDs as compatibility aliases.

## Canonical Roles

- `role-product-delivery-manager`
- `role-system-architect`
- `role-staff-frontend`
- `role-backend-data-engineer`
- `role-staff-qa`
- `role-platform-automation`
- `role-technical-writer`
- `role-code-review-architect`
- `role-delivery-strategist`

## Alias Map

| Canonical Role | Agent ID Aliases |
| --- | --- |
| `role-product-delivery-manager` | `product-manager`, `project-manager` |
| `role-system-architect` | `architect` |
| `role-staff-frontend` | `staff-frontend` |
| `role-backend-data-engineer` | `staff-backend`, `db-designer` |
| `role-staff-qa` | `staff-qa` |
| `role-platform-automation` | `senior-devops`, `script-developer` |
| `role-technical-writer` | `technical-writer` |
| `role-code-review-architect` | `code-review-architect` |
| `role-delivery-strategist` | `commit-strategist`, `pr-strategist` |

## Capability Ownership (RACI)

Each capability has exactly one primary owner. Supporting roles contribute but do not own final accountability.

| Capability | Primary Owner | Supporting Roles |
| --- | --- | --- |
| Problem framing, scope slicing, release intent | `role-product-delivery-manager` | `role-system-architect`, `role-staff-qa` |
| Architecture boundaries and compatibility strategy | `role-system-architect` | `role-backend-data-engineer`, `role-staff-frontend` |
| Frontend implementation quality and accessibility | `role-staff-frontend` | `role-staff-qa` |
| API, domain logic, schema, and migration implementation | `role-backend-data-engineer` | `role-system-architect`, `role-platform-automation` |
| Shift-left testing strategy and quality gates | `role-staff-qa` | `role-staff-frontend`, `role-backend-data-engineer` |
| CI/CD reliability, rollout safety, and engineering automation | `role-platform-automation` | `role-staff-qa`, `role-backend-data-engineer` |
| Product and engineering documentation quality | `role-technical-writer` | `role-product-delivery-manager`, `role-platform-automation` |
| Cross-cutting security and maintainability governance | `role-code-review-architect` | `role-system-architect`, `role-staff-qa` |
| Commit and PR narrative quality for review readiness | `role-delivery-strategist` | `role-code-review-architect`, `role-product-delivery-manager` |

## Policy Notes

- GitHub Issues/PRs/Actions are the source of truth.
- Linear and Notion are optional sync accelerators when explicitly requested.
- `role-code-review-architect` remains independent and read-only for governance.
