# Engineering Agent Team

This directory defines the shared role and governance model consumed from `~/.codex/agents`.

## Core documents

- `00-team-charter.md`
- `role-topology.md`
- `skills-matrix.md`
- `review-checklist.md`

## Canonical role contracts

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

## Validation

- Shared config lives under `~/.codex/config.base.toml`, `~/.codex/config.local.toml`, and `~/.codex/config.toml`.
- Do not edit `~/.codex/config.toml` directly.
- Run `./.codex/scripts/test-onboarding.sh` when changing onboarding or config behavior.
- Run `./.codex/scripts/validate-role-skill-topology.py` after role or skill changes.
- Canonical role files should point to `~/.codex/agents/skills-matrix.md` instead of duplicating required or optional skill lists.
