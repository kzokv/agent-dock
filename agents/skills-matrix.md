# Skills Matrix

## Policy

- Install strategy: curated-first in phase 1, custom in phase 2 after gap analysis.
- Workflow of record: GitHub-first; other systems are optional sync layers.
- Ownership source: canonical role contracts (`agents/role-*.md`) and `agents/role-topology.md`.

## Capability Tiers

### Universal

- `openai-docs`

### Security/Governance (roles that own governance)

- `security-best-practices`
- `security-threat-model`
- `security-ownership-map`

### GitHub Ops (delivery, QA, platform, review)

- `gh-address-comments`
- `gh-fix-ci`

## Canonical Role Skill Bindings

- `role-product-delivery-manager`
- Required: `openai-docs`
- Optional: `linear`, `notion-spec-to-implementation`, `notion-meeting-intelligence`, `notion-research-documentation` (external), `notion-knowledge-capture` (external)

- `role-system-architect`
- Required: `openai-docs`, `security-threat-model`
- Optional: `security-ownership-map`, `sentry`

- `role-staff-frontend`
- Required: `openai-docs`, `figma-implement-design`, `playwright`
- Optional: `screenshot`, `figma` (external)

- `role-backend-data-engineer`
- Required: `openai-docs`, `sentry`, `spreadsheet`
- Optional: `jupyter-notebook`, `security-ownership-map`

- `role-staff-qa`
- Required: `openai-docs`, `playwright`, `screenshot`, `gh-fix-ci`
- Optional: `spreadsheet`, `sentry`, `jupyter-notebook`

- `role-platform-automation`
- Required: `openai-docs`, `gh-fix-ci`, `sentry`, `jupyter-notebook`
- Optional: `security-ownership-map`, `render-deploy` (external), `vercel-deploy` (external)

- `role-technical-writer`
- Required: `openai-docs`, `doc`, `pdf`
- Optional: `spreadsheet`, `transcribe` (external), `notion-knowledge-capture` (external)

- `role-code-review-architect`
- Required: `openai-docs`, `security-best-practices`, `security-threat-model`, `security-ownership-map`, `gh-address-comments`, `gh-fix-ci`
- Optional: `sentry`

- `role-delivery-strategist`
- Required: `openai-docs`, `gh-address-comments`, `gh-fix-ci`
- Optional: `linear`, `yeet` (external), `notion-knowledge-capture` (external)

## Install Notes

- Phase 1 installs required curated skills used by canonical roles.
- Optional skills marked `(external)` are intentionally not required to be installed.
- Optional sync skills should be enabled only when a user asks for that workflow.
