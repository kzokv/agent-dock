# Skills Matrix

## Policy

- Install strategy: curated-first in phase 1, custom in phase 2 after gap analysis.
- Workflow of record: GitHub-first; other systems are optional sync layers.
- Ownership source: canonical role contracts (`agents/role-*.md`) and `agents/role-topology.md`.

## Capability Tiers

### Universal

- `openai-docs`

### Security/Governance

- `security-best-practices`
- `security-threat-model`
- `security-ownership-map`

### GitHub Ops

- `gh-address-comments`
- `gh-fix-ci`
- `git-gh-docker-fallback`

## Canonical Role Skill Bindings

- `role-architect`
- Required: `openai-docs`, `security-threat-model`
- Optional: `security-ownership-map`, `sentry`

- `role-product-manager`
- Required: `openai-docs`
- Optional: `linear`, `notion-spec-to-implementation`, `notion-meeting-intelligence`

- `role-project-manager`
- Required: `openai-docs`
- Optional: `linear`, `notion-spec-to-implementation`, `notion-meeting-intelligence`

- `role-frontend-engineer`
- Required: `openai-docs`, `figma-implement-design`, `playwright`
- Optional: `screenshot`

- `role-backend-engineer`
- Required: `openai-docs`, `sentry`, `spreadsheet`
- Optional: `jupyter-notebook`, `security-ownership-map`

- `role-qa-engineer`
- Required: `openai-docs`, `playwright`, `screenshot`, `gh-fix-ci`
- Optional: `spreadsheet`, `sentry`, `jupyter-notebook`

- `role-ui-ux-designer`
- Required: `openai-docs`, `figma-implement-design`, `screenshot`
- Optional: `playwright`, `doc`

- `role-devops`
- Required: `openai-docs`, `gh-fix-ci`, `sentry`, `jupyter-notebook`
- Optional: `script-automation`, `security-ownership-map`, `render-deploy` (external), `vercel-deploy` (external)

- `role-technical-writer`
- Required: `openai-docs`, `doc`, `pdf`
- Optional: `spreadsheet`, `notion-meeting-intelligence`

- `role-git-orchestrator`
- Required: `openai-docs`, `gh-address-comments`, `gh-fix-ci`
- Optional: `linear`, `git-gh-docker-fallback`

- `role-frontend-reviewer`
- Required: `openai-docs`, `security-best-practices`, `gh-address-comments`
- Optional: `security-threat-model`, `playwright`

- `role-backend-reviewer`
- Required: `openai-docs`, `security-best-practices`, `security-threat-model`, `gh-address-comments`
- Optional: `security-ownership-map`, `sentry`

- `role-qa-reviewer`
- Required: `openai-docs`, `gh-fix-ci`
- Optional: `playwright`, `screenshot`

- `role-database-reviewer`
- Required: `openai-docs`, `security-best-practices`, `spreadsheet`
- Optional: `security-ownership-map`, `sentry`

- `role-design-reviewer`
- Required: `openai-docs`, `figma-implement-design`, `screenshot`
- Optional: `playwright`, `doc`

## Install Notes

- Phase 1 installs required curated skills used by canonical roles.
- Optional skills marked `(external)` are intentionally not required to be installed.
- Optional sync skills should be enabled only when a user asks for that workflow.
