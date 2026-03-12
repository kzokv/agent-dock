# Skills Matrix

## Policy

- Source of truth: this file is authoritative for canonical role-to-skill bindings.
- Required skills define the role's domain anchor and a small set of central repo-native tools.
- Optional skills cover narrower helpers, external-context workflows, and situational accelerators.
- Coordination-heavy roles may have zero required skills.
- External-context skills may appear only as optional bindings.
- Default enabled discovery subset = union of all required skills plus all universal optional skills.
- Required install baseline = union of all required skills only.

## Universal Optional Skills

- `openai-docs`

## External-Context Optional Skills

- `figma-implement-design`
- `linear`
- `notion-spec-to-implementation`
- `notion-meeting-intelligence`
- `sentry`
- `git-gh-docker-fallback`

## Canonical Role Skill Bindings

| Role | Required Skills | Optional Skills |
| --- | --- | --- |
| `role-architect` | `api-design-principles`, `security-threat-model` | `platform-infrastructure`, `security-ownership-map` |
| `role-backend-engineer` | `nodejs-backend-patterns`, `api-design-principles`, `database-design` | `spreadsheet`, `jupyter-notebook`, `sentry`, `security-ownership-map` |
| `role-backend-reviewer` | `nodejs-backend-patterns`, `api-design-principles`, `security-best-practices`, `security-threat-model` | `database-design` |
| `role-database-reviewer` | `database-design`, `security-best-practices` | `security-threat-model`, `spreadsheet` |
| `role-design-reviewer` | `frontend-design` | `figma-implement-design`, `screenshot`, `playwright`, `doc` |
| `role-devops` | `senior-devops`, `script-automation`, `gh-fix-ci` | `docker-expert`, `hybrid-cloud-networking`, `platform-infrastructure`, `jupyter-notebook`, `sentry`, `security-ownership-map` |
| `role-devops-reviewer` | `senior-devops`, `script-automation`, `gh-fix-ci` | `docker-expert`, `hybrid-cloud-networking`, `security-ownership-map`, `sentry` |
| `role-frontend-engineer` | `frontend-design`, `playwright` | `webapp-testing`, `screenshot`, `figma-implement-design` |
| `role-frontend-reviewer` | `frontend-design`, `security-best-practices` | `playwright`, `screenshot` |
| `role-git-orchestrator` | `gh-address-comments`, `gh-fix-ci` | `github-workflow-automation`, `linear`, `git-gh-docker-fallback` |
| `role-product-manager` | none | `linear`, `notion-spec-to-implementation`, `notion-meeting-intelligence`, `spreadsheet` |
| `role-project-manager` | none | `linear`, `notion-spec-to-implementation`, `notion-meeting-intelligence`, `spreadsheet` |
| `role-qa-engineer` | `senior-qa`, `webapp-testing`, `playwright`, `gh-fix-ci` | `screenshot`, `spreadsheet`, `jupyter-notebook`, `sentry` |
| `role-qa-reviewer` | `senior-qa`, `gh-fix-ci` | `webapp-testing`, `playwright`, `screenshot` |
| `role-technical-writer` | `doc`, `pdf` | `spreadsheet`, `knowledge-curator`, `notion-meeting-intelligence` |
| `role-ui-ux-designer` | `frontend-design` | `figma-implement-design`, `screenshot`, `doc`, `theme-factory` |

## Install Notes

- Provider-specific placeholders without a local skill directory are not part of the canonical matrix.
- Scripts must parse this file directly rather than rely on duplicated role-local lists or manifests.
