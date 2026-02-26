# Git/PR Flow Runbook

This is the canonical operator runbook for Git/PR workflow in this repository.

Policy source of truth remains `AGENTS.md`.

## 1. Local setup

Enable local commit-message enforcement immediately after cloning:

```bash
./scripts/setup-git-hooks.sh
```

This configures `core.hooksPath=.githooks` so local commits are validated by `.githooks/commit-msg`.

## 1.1 GitHub CLI auth for agent workflows

`./scripts/onboarding.sh` validates your `gh` CLI auth, runs `gh auth login -h github.com` when required, and installs the `codex-net` helper so you can launch network-enabled sessions without typing long sandbox flags. The helper lives under `$XDG_BIN_HOME` (default `~/.local/bin`) and onboarding will warn if that directory is not on your `PATH`.

Once onboarding succeeds, use:

```bash
codex-net
```

instead of manually invoking `codex --sandbox …`.

For automated or CI-style environments where you cannot complete GitHub auth interactively, rerun onboarding with:

```bash
./scripts/onboarding.sh --skip-gh-auth
```

Verify auth state with:

```bash
gh auth status
```

Security rules:

- never print/paste raw tokens into logs, PRs, or chat
- if a token is exposed, revoke and rotate immediately
- keep token scopes minimal for required automation tasks

## 2. Commit message rules

Commits must use:

`type(scope): subject`

Allowed types:

- `feat`
- `fix`
- `docs`
- `style`
- `refactor`
- `perf`
- `test`
- `build`
- `ci`
- `chore`
- `revert`

Examples:

- `feat(onboarding): add config regeneration guard`
- `fix(pr-gate): enforce testing evidence format`
- `docs(runbook): add label selection guidance`

## 3. PR title, metadata, and body requirements

### PR title

PR title must use:

`type(scope): subject`

Example:

- `docs(gitflow): consolidate operator runbook`

### Required metadata

Before handoff, PR must have:

- assignee
- primary label matching PR content (`bug`, `enhancement`, or `documentation`)

Additional labels are allowed.

### Label-to-content mapping

- `bug`: behavior defect fixes
- `enhancement`: non-bug improvements (feature/config/refactor/maintainability)
- `documentation`: docs-only or docs-dominant PRs

When in doubt, choose the label that best matches the dominant intent of the change.

### Required PR sections

PR body must include all sections:

- `## Problem`
- `## Solution`
- `## Testing`
- `## Risk/Rollback`

Use `.github/pull_request_template.md`.

## 4. Testing section contract

`## Testing` must include one of these formats:

1. Evidence path:

```md
Evidence:
- Command/check: <exact command or check>
- Outcome: <pass/fail + key result>
```

2. Waiver path (only when requester approved):

```md
Waiver:
- Reason: <why testing/checks are waived>
- Approver: <requester>
```

Checklist-only entries without evidence or waiver are non-compliant.

## 5. Governance and merge gates

Before merge:

- relevant tests/checks are run for changed scope unless waived by requester
- PR metadata and required sections are complete
- architect and applicable domain reviewers are final blocker/merge gates

## 6. GitHub CLI verification steps

Use these commands to verify metadata and title quickly:

```bash
gh pr view <number> --json assignees,labels,title,url
```

If metadata is missing:

```bash
gh pr edit <number> --add-assignee @me --add-label <label>
```

## 7. CI gate behavior

`.github/workflows/pr-gate.yml` enforces:

- scoped Conventional Commit title
- required assignee
- required primary label from allow-list (`bug`, `enhancement`, `documentation`)
- required body sections
- `## Testing` evidence-or-waiver contract

If CI fails, fix the exact reported gate and re-run checks.
