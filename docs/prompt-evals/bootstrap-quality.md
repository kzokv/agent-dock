# Bootstrap Quality Eval

Use this harness when bootstrap prompt changes need proof that lower startup tokens did not degrade output quality.

## RLM-style scaffold

- Keep durable repository knowledge in external state rather than preloading it into the root prompt.
- Expose only small root metadata at session start: document counts, chunk counts, edge counts, FTS backend, and doc-type counts.
- Retrieve recursively with bounded primitives:
  - `status` to inspect freshness before reuse
  - `query` to rank candidate handles
  - `peek` to inspect exact chunk slices
  - `expand` to traverse one-hop explicit reference edges
  - `summarize` to compact only the selected handles
- Persist retrieval steps in a scratch session file under `~/.codex/cache/knowledge/` so intermediate state stays outside the active prompt.
- Use `prompts/retrieve.md` as the shared on-demand trigger rather than an enabled skill or startup hook.

## Runner

```bash
python3 ./scripts/run_bootstrap_evals.py --target-repo /path/to/project --json
```

The runner compares a baseline snapshot from `git archive <ref>` against the current worktree candidate. It records:

- bootstrap and session token budgets from `scripts/bootstrap-budget.sh --json`
- normalized path accounting for skill-path cost comparisons
- 3 paired output-quality scenarios
- 3 retrieval-specific trials
- runtime warnings that could invalidate the comparison

## Required scenarios

- Plan generation
- Code review
- Research with citations
- Retrieval: precise rule lookup
- Retrieval: worklog plus policy
- Retrieval: relation expansion

## Pass criteria

- Candidate quality is the same or better than baseline across the paired scenarios.
- Candidate bootstrap tokens are lower than baseline.
- Retrieval trials load only bounded candidate slices unless the task truly requires more.
- Runtime warnings are recorded and investigated before drawing conclusions from a run.
