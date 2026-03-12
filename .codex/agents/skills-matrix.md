# Skills Matrix

## Policy

- Source of truth: this file is authoritative for canonical role-to-skill bindings.
- Skill ids are repo-relative paths under `~/.codex/skills`.
- Required skills define the role's domain anchor and a small set of central repo-native tools.
- Optional skills cover narrower helpers, external-context workflows, and situational accelerators.
- Coordination-heavy roles may have zero required skills.
- External-context skills may appear only as optional bindings.
- Default enabled discovery subset = union of all required skills plus all universal optional skills.
- Required install baseline = union of all required skills only.

## Universal Optional Skills

- `openai-docs`

## External-Context Optional Skills

- `linear`
- `engineering-team/aws-solution-architect`
- `engineering-team/google-workspace-cli`
- `engineering-team/ms365-tenant-manager`
- `engineering-team/playwright-pro/skills/browserstack`
- `engineering-team/playwright-pro/skills/testrail`

## Canonical Role Skill Bindings

| Role | Required Skills | Optional Skills |
| --- | --- | --- |
| `role-architect` | `engineering-team/senior-architect`, `engineering/agent-designer` | `engineering/database-designer`, `engineering/migration-architect`, `engineering/observability-designer`, `engineering/rag-architect` |
| `role-backend-engineer` | `engineering-team/senior-backend`, `engineering/database-designer`, `engineering/api-design-reviewer` | `engineering/api-test-suite-builder`, `engineering/dependency-auditor`, `engineering-team/senior-security` |
| `role-backend-reviewer` | `engineering-team/senior-backend`, `engineering/api-design-reviewer` | `engineering/database-designer`, `engineering/pr-review-expert`, `engineering-team/senior-security` |
| `role-database-reviewer` | `engineering/database-designer`, `engineering/database-schema-designer` | `engineering/migration-architect`, `engineering-team/senior-security` |
| `role-design-reviewer` | `engineering-team/senior-frontend` | `engineering-team/playwright-pro`, `engineering-team/playwright-pro/skills/review`, `engineering-team/playwright-pro/skills/browserstack` |
| `role-devops` | `engineering-team/senior-devops`, `script-automation`, `engineering/ci-cd-pipeline-builder` | `engineering/observability-designer`, `engineering/runbook-generator`, `engineering-team/aws-solution-architect`, `engineering-team/senior-secops` |
| `role-devops-reviewer` | `engineering-team/senior-devops`, `engineering/ci-cd-pipeline-builder` | `engineering/observability-designer`, `engineering/pr-review-expert`, `engineering-team/senior-secops` |
| `role-frontend-engineer` | `engineering-team/senior-frontend`, `engineering-team/playwright-pro` | `engineering-team/playwright-pro/skills/generate`, `engineering-team/playwright-pro/skills/fix`, `engineering-team/playwright-pro/skills/browserstack` |
| `role-frontend-reviewer` | `engineering-team/senior-frontend` | `engineering/pr-review-expert`, `engineering-team/playwright-pro`, `engineering-team/playwright-pro/skills/review` |
| `role-git-orchestrator` | `engineering/release-manager`, `engineering/git-worktree-manager` | `linear`, `knowledge-curator` |
| `role-product-manager` | none | `linear`, `knowledge-curator`, `engineering/tech-debt-tracker` |
| `role-project-manager` | none | `linear`, `knowledge-curator`, `engineering/release-manager` |
| `role-qa-engineer` | `engineering-team/senior-qa`, `engineering-team/playwright-pro` | `engineering-team/playwright-pro/skills/generate`, `engineering-team/playwright-pro/skills/fix`, `engineering-team/playwright-pro/skills/coverage`, `engineering-team/playwright-pro/skills/browserstack` |
| `role-qa-reviewer` | `engineering-team/senior-qa` | `engineering/pr-review-expert`, `engineering-team/playwright-pro/skills/review`, `engineering-team/playwright-pro/skills/coverage` |
| `role-technical-writer` | `knowledge-curator` | `engineering/changelog-generator`, `engineering/runbook-generator`, `linear` |
| `role-ui-ux-designer` | `engineering-team/senior-frontend` | `engineering-team/playwright-pro`, `engineering-team/playwright-pro/skills/browserstack`, `knowledge-curator` |

## Install Notes

- Scripts must parse this file directly rather than rely on duplicated role-local lists or manifests.
- Required skills are expected to resolve inside the local nested `.codex/skills` tree.
