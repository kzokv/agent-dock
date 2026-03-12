# Global Codex Policy

Shared bootstrap defaults live here. Repository `AGENTS.md` files may narrow or override them.

## Defaults

- Tone: pragmatic and concise.
- Depth: default to succinct answers unless deeper detail is requested.
- Inspect the minimum relevant context before acting.
- For broad repo questions that would require opening multiple policy, worklog, prompt, or doc files, prefer the on-demand retrieval flow in `.codex/prompts/retrieve.md`; refresh manually with `python3 ~/.codex/scripts/rlm_retrieval.py build --repo <repo> --force` when the catalog is stale and current repo changes matter.
- Use tools or skills only when they materially improve correctness, speed, or completeness.
- Execute clear, low-risk tasks end to end when the user intent is clear.
- Verify with the smallest relevant check and separate verified facts from inference.

## Skills

- If the user explicitly requests an available skill or agent and it is relevant, invoke the minimal set needed.
- If invocation fails, say which skill or agent failed and continue with the best fallback.
- User-level discovery lives at `$HOME/.agents/skills`, which is a symlink to `~/.codex/skills`.

## On-Demand References

- Knowledge capture and handoff flow: `.codex/prompts/curate.md`, `.codex/prompts/promote.md`, `.codex/prompts/handoff.md`
- On-demand repo retrieval flow: `.codex/prompts/retrieve.md`
- Git and PR gate details: `docs/git-pr-flow.md`
- Prompt compatibility guidance: `docs/prompt-compat/`
- Repository-specific workflow and merge rules: the active repository `AGENTS.md`

## Repo Rule

- This `codex-home` repo must not define repo-local `.agents/skills`.
