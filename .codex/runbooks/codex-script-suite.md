# Runbook - codex-script-suite

- Service: codex-script-suite
- Owner: codex-home-maintainers
- Environment: local-shared
- Last verified: 2026-03-12

## Overview

The `codex-script-suite` is the operational script surface under `.codex/scripts` plus the root onboarding orchestration in `scripts/`.

Primary purposes:
- bootstrap and maintain shared Codex/Cursor/Claude homes
- validate role-to-skill topology and config migration hygiene
- measure bootstrap/session token cost
- build and query the local retrieval catalog
- run bootstrap-quality evals
- configure local git hooks

Core entrypoints:
- `./scripts/onboarding.sh`
- `./.codex/scripts/test-onboarding.sh`
- `./.codex/scripts/validate-role-skill-topology.py`
- `./.codex/scripts/check-config-migration.sh`
- `./.codex/scripts/bootstrap-budget.sh`
- `python3 ./.codex/scripts/rlm_retrieval.py`
- `python3 ./.codex/scripts/run_bootstrap_evals.py`
- `./.codex/scripts/install-required-skills.sh`
- `./.codex/scripts/setup-git-hooks.sh`

Critical user impact:
- onboarding failures can leave agent homes or generated configs stale
- matrix/skill validation failures can break role loading and bootstrap assumptions
- budget regressions can materially increase bootstrap cost for downstream repos

## Preconditions

- Run commands from the repo root:

```bash
cd /Users/lume/repos/codex-home
```

- Required local tools on PATH:
  - `bash`
  - `python3`
  - `git`
  - `rg`
  - `node`
  - `npm`
- For onboarding with auth/bootstrap enabled:
  - `gh` authenticated, or use `--skip-gh-auth`
  - writable home directory for `~/.codex`, `~/.cursor`, `~/.claude`, and `~/.agents`
- For retrieval/evals:
  - working `codex` CLI for eval execution
  - network access when the eval scenario or CLI requires it

## Start Procedure

1. Confirm the repo is at the intended revision and inspect local changes.
2. Run syntax checks before touching onboarding or validation behavior.
3. Run targeted health checks.
4. If the change affects onboarding paths or generated config, run onboarding in a safe mode.

```bash
git status --short
for f in .codex/scripts/*.sh; do bash -n "$f"; done
for f in .codex/scripts/*.py; do python3 -m py_compile "$f"; done
./.codex/scripts/validate-role-skill-topology.py
./.codex/scripts/check-config-migration.sh
./.codex/scripts/bootstrap-budget.sh --repo . --json
```

When validating shared wiring without GitHub auth bootstrap:

```bash
./scripts/onboarding.sh --agent codex --skip-gh-auth
```

When validating full shared wiring:

```bash
./scripts/onboarding.sh --agent all
```

Expected result:
- no syntax failures
- topology validation passes
- config migration check passes
- onboarding completes with explicit log lines for symlink/config actions

## Stop Procedure

There is no persistent daemon to stop. Safe shutdown means stopping in-flight long-running validations and cleaning temporary artifacts created during local testing.

1. Cancel any active eval or onboarding test process.
2. Remove only disposable artifact directories you created manually.
3. Re-check repo status before leaving the workspace.

```bash
pkill -f 'run_bootstrap_evals.py' || true
pkill -f 'test-onboarding.sh' || true
git status --short
```

If `test-onboarding.sh --keep-fixtures` was used, remove the fixture directory after inspection.

## Health Checks

- Script syntax and import health:

```bash
for f in .codex/scripts/*.sh; do bash -n "$f"; done
for f in .codex/scripts/*.py; do python3 -m py_compile "$f"; done
```

- Agent and skill topology:

```bash
python3 ./.codex/scripts/role_skill_matrix.py --validate-local-skills
./.codex/scripts/validate-role-skill-topology.py
```

- Generated-config hygiene:

```bash
./.codex/scripts/check-config-migration.sh
```

- Onboarding regression suite:

```bash
./.codex/scripts/test-onboarding.sh
```

- Bootstrap cost visibility:

```bash
./.codex/scripts/bootstrap-budget.sh --repo . --json
```

For another repository:

```bash
./.codex/scripts/bootstrap-budget.sh --repo /path/to/target-repo --json
./.codex/scripts/bootstrap-budget.sh --repo /path/to/target-repo --max-bootstrap-tokens 1500 --max-session-tokens 3000
```

- Retrieval catalog status:

```bash
python3 ./.codex/scripts/rlm_retrieval.py status --repo . --json
```

Healthy state:
- all commands exit `0`
- topology validator reports `Validation passed`
- onboarding test reports `ok` for every scenario
- bootstrap budget output is plausible for the current skill catalog and does not exceed any active CI threshold

## Deployment Checklist

Use this before merging changes to `.codex/scripts`, `.codex/agents`, onboarding logic, or `.codex/skills`.

1. Run syntax checks.
2. Run topology validation and config migration checks.
3. Run onboarding regression tests when onboarding/config behavior changed.
4. Re-run bootstrap budget after skill, prompt, or policy changes.
5. Re-run retrieval status/build when retrieval logic changed.
6. If eval logic changed, run bootstrap evals against a target repo.
7. Review docs affected by the script behavior.

```bash
for f in .codex/scripts/*.sh; do bash -n "$f"; done
for f in .codex/scripts/*.py; do python3 -m py_compile "$f"; done
./.codex/scripts/validate-role-skill-topology.py
./.codex/scripts/check-config-migration.sh
./.codex/scripts/test-onboarding.sh
./.codex/scripts/bootstrap-budget.sh --repo . --json
python3 ./.codex/scripts/rlm_retrieval.py status --repo . --json
```

If retrieval logic changed and the local catalog must be refreshed:

```bash
python3 ./.codex/scripts/rlm_retrieval.py build --repo . --force
```

If bootstrap eval behavior changed:

```bash
python3 ./.codex/scripts/run_bootstrap_evals.py --target-repo /path/to/target-repo --json
```

Recommended full invocation:

```bash
rm -rf /tmp/bootstrap-evals
python3 ./.codex/scripts/run_bootstrap_evals.py \
  --target-repo /path/to/target-repo \
  --shared-repo /Users/lume/repos/codex-home \
  --baseline-ref HEAD \
  --output-dir /tmp/bootstrap-evals \
  --timeout-seconds 180 \
  --json
```

Notes:
- the script snapshots baseline and candidate repos into a temporary work area
- it can take several minutes because each Codex scenario may run up to the timeout
- inspect `/tmp/bootstrap-evals/summary.json` and per-scenario stdout files after completion

## Rollback

Rollback triggers:
- onboarding test regressions
- topology or config migration validation newly failing
- bootstrap budget unexpectedly jumping beyond intended threshold
- generated config or symlink behavior becoming non-idempotent

Rollback procedure:
1. Identify the last known good commit.
2. Revert the offending change with a normal `git revert`.
3. Re-run the core validation set.
4. If onboarding state was affected locally, rerun onboarding from the reverted revision.
5. Communicate scope and remaining operator impact.

```bash
git log --oneline -- .codex/scripts .codex/agents scripts
git revert <bad-commit>
./.codex/scripts/validate-role-skill-topology.py
./.codex/scripts/check-config-migration.sh
./.codex/scripts/test-onboarding.sh
./scripts/onboarding.sh --agent codex --skip-gh-auth
```

Do not use destructive reset-based rollback for shared history remediation.

## Incident Response

1. Classify the incident:
   - onboarding breakage
   - role/skill topology breakage
   - bootstrap budget regression
   - retrieval/eval failure
2. Contain impact:
   - stop further onboarding runs from the bad revision
   - avoid regenerating config from a known-bad change set
3. Triage likely failing component:
   - `scripts/onboarding.sh` or `scripts/onboarding-lib.sh`
   - `.codex/scripts/validate-role-skill-topology.py`
   - `.codex/scripts/bootstrap-budget.sh`
   - `.codex/scripts/run_bootstrap_evals.py`
    - `.codex/agents/skills-matrix.md`
    - `.codex/scripts/rlm_retrieval.py`
4. Run focused checks for the affected area.
5. Escalate if the breakage impacts shared onboarding or merge gates.

Focused triage commands:

```bash
git diff -- .codex/scripts .codex/agents scripts
./.codex/scripts/validate-role-skill-topology.py
./.codex/scripts/check-config-migration.sh
./.codex/scripts/bootstrap-budget.sh --repo . --json
./.codex/scripts/test-onboarding.sh
python3 ./.codex/scripts/run_bootstrap_evals.py --target-repo /path/to/target-repo --json
python3 ./.codex/scripts/rlm_retrieval.py status --repo . --json
```

## Escalation

- L1: active repo maintainer making the change
- L2: `codex-home-maintainers`
- L3: platform/engineering owner for shared agent bootstrap and policy

Escalate immediately when:
- onboarding breaks for `all` or `codex`
- generated config files become invalid or non-idempotent
- validator behavior blocks normal development across repos
- CI thresholds or PR gates start failing because of the change

## Post-Incident

1. Capture the exact failing command and stderr output.
2. Record root cause and affected files.
3. Add or update validation coverage:
   - onboarding test fixture
   - topology validation rule
   - budget regression check
   - retrieval/eval coverage
4. Update this runbook if diagnosis or rollback steps were missing.
5. Set a new `Last verified` date after the fix is validated.

## Staleness Detection

Re-review this runbook whenever any of these change:
- `scripts/onboarding.sh`
- `scripts/onboarding-lib.sh`
- `.codex/scripts/*`
- `.codex/agents/skills-matrix.md`
- `.codex/agents/role-*.md`
- `.codex/config.base.toml`
- `docs/onboarding.md`
- `README.md`

## Quarterly Validation Checklist

1. Run onboarding in a disposable environment with `--agent codex --skip-gh-auth`.
2. Run `./.codex/scripts/test-onboarding.sh`.
3. Run topology, config migration, and budget checks.
4. Confirm escalation ownership is still correct.
5. Update `Last verified` after successful validation.
