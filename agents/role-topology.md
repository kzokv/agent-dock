# Role Topology

This document defines the canonical role model for implementation/coordination and reviewer overlay functions.

## Canonical Roles

- `role-architect`
- `role-product-manager`
- `role-project-manager`
- `role-frontend-engineer`
- `role-backend-engineer`
- `role-qa-engineer`
- `role-ui-ux-designer`
- `role-devops`
- `role-technical-writer`
- `role-git-orchestrator`
- `role-frontend-reviewer`
- `role-backend-reviewer`
- `role-qa-reviewer`
- `role-database-reviewer`
- `role-design-reviewer`

## Capability Ownership (RACI)

Each capability has exactly one primary owner. Supporting roles contribute but do not own final accountability.

| Capability | Primary Owner | Supporting Roles |
| --- | --- | --- |
| Product intent, scope slicing, acceptance framing | `role-product-manager` | `role-project-manager`, `role-architect` |
| Delivery planning, sequencing, execution tracking | `role-project-manager` | `role-product-manager`, `role-devops` |
| Architecture boundaries and compatibility strategy | `role-architect` | `role-backend-engineer`, `role-frontend-engineer` |
| Frontend implementation quality and accessibility | `role-frontend-engineer` | `role-ui-ux-designer`, `role-qa-engineer` |
| Backend domain logic, API contracts, and data workflows | `role-backend-engineer` | `role-architect`, `role-devops` |
| Shift-left testing strategy and validation gates | `role-qa-engineer` | `role-frontend-engineer`, `role-backend-engineer` |
| UI/UX patterns, fidelity, and interaction specifications | `role-ui-ux-designer` | `role-frontend-engineer`, `role-design-reviewer` |
| CI/CD reliability, rollout safety, and infrastructure automation | `role-devops` | `role-qa-engineer`, `role-backend-engineer` |
| Product and engineering documentation quality | `role-technical-writer` | `role-product-manager`, `role-devops` |
| Git workflow execution (branch/commit/PR/release-note) | `role-git-orchestrator` | `role-project-manager`, `role-technical-writer` |
| Frontend code governance and risk review | `role-frontend-reviewer` | `role-architect`, `role-design-reviewer` |
| Backend code governance and risk review | `role-backend-reviewer` | `role-architect`, `role-database-reviewer` |
| Test quality and CI-signal governance review | `role-qa-reviewer` | `role-architect`, `role-qa-engineer` |
| Database schema, migration, and integrity governance review | `role-database-reviewer` | `role-backend-reviewer`, `role-backend-engineer` |
| UI/UX consistency and usability governance review | `role-design-reviewer` | `role-frontend-reviewer`, `role-ui-ux-designer` |

## Policy Notes

- GitHub Issues/PRs/Actions are the source of truth.
- Linear and Notion are optional sync accelerators when explicitly requested.
- `role-git-orchestrator` cannot override blocker decisions from architect/reviewer governance.
