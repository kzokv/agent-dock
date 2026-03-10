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

`./scripts/onboarding.sh` validates your `gh` CLI auth, runs `gh auth login -h github.com` when required, installs the Codex CLI with `npm install -g @openai/codex` when `codex` is missing, and installs the `codex-net` helper so you can launch network-enabled sessions without typing long sandbox flags. The helper lives under `$XDG_BIN_HOME` when set; otherwise onboarding defaults to `~/bin` on macOS and `~/.local/bin` on other platforms, and warns if that directory is not on your `PATH`. Onboarding also copies the Codex role-loader agent into `~/.cursor/agents` so Cursor can load role profiles from `~/.codex/agents`; use `--cursor-home PATH` to target a custom Cursor directory.

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

By default, commits use:

`type(scope): subject`

In ticket-driven repositories, commits use:

`type(scope): TICKET-ID: subject`

The concrete `TICKET-ID` format is defined by repository policy, for example `LINEAR-TICKET`, `JIRA-KEY`, or another tracker token.

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
- `feat(api): ABC-123: add settlement posting contract`

## 3. PR title, metadata, and body requirements

### PR title

By default, PR title uses:

`type(scope): subject`

In ticket-driven repositories, PR title uses:

`type(scope): TICKET-ID: subject`

Example:

- `docs(gitflow): consolidate operator runbook`
- `feat(api): ABC-123: add settlement posting contract`

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

### Ticket-driven waiver path

If repository policy requires ticket-gated naming and no related ticket is available in the current working session, the orchestrator should:

- check branch name, recent commit subjects, current commit message draft, and known PR title/body draft context
- ask whether to use the repository-defined waiver path
- block non-compliant commit or PR-title flow if the user declines the waiver

When a repository defines a waiver path, it should be repository-specific and human-controlled:

- use the repository-defined waiver label
- require a PR waiver section with rationale and scope
- require an approver distinct from the PR author
- require write-level access or higher for the approver

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

- scoped Conventional Commit title, or repository-defined ticket-gated title when applicable
- required assignee
- required primary label from allow-list (`bug`, `enhancement`, `documentation`)
- required body sections
- `## Testing` evidence-or-waiver contract

If CI fails, fix the exact reported gate and re-run checks.
