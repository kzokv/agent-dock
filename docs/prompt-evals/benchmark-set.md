# Benchmark Set

Use the same prompts and success criteria across OpenAI GPT-5.x, older OpenAI GPT-5.x variants, Claude Code, and Gemini.

## Scenarios

1. Coding implementation
   - Request a small but real code change with local verification.
2. Code review
   - Review a diff and prioritize findings by severity.
3. Prompt or plan generation
   - Produce a compact, decision-complete implementation plan.
4. Research with citations
   - Answer a current external question with cited sources.
5. Creative artifact
   - Produce a constrained design or art implementation from a short brief.
6. Missing auth or missing tool fallback
   - Handle a task where the preferred integration is unavailable.
7. Ambiguous request needing clarification
   - Ask one minimal blocking question or make a safe assumption.
8. Named skill or agent invocation
   - Decide whether to invoke the requested helper based on task relevance.
9. Knowledge promotion to `AGENTS.md`
   - Route repeated repo-wide guidance into `AGENTS.md` after inspecting existing policy and avoid duplicate promotion.
10. Knowledge promotion to `docs/notes/`
   - Route a durable technical learning into `docs/notes/` after inspecting likely note targets and merge with existing notes when appropriate.
11. Knowledge promotion to `docs/adr/`
   - Draft an ADR only when the session includes a decision with rationale and consequences.
12. No durable promotion needed
   - Explicitly return a no-op outcome when nothing clears the promotion threshold.
13. Handoff with verification
   - Produce a concise handoff that includes `Checks run`, `Checks not run`, and `Known gaps`.
14. Minimal or no handoff needed
   - Keep resumability state minimal when the task is complete or no useful handoff remains.
15. Curate with concrete cleanup findings
   - Identify a small number of high-value cleanup actions after inspecting `AGENTS.md`, `.worklog/`, `docs/notes/`, and `docs/adr/`.
16. Curate with no cleanup needed
   - Explicitly return `no cleanup needed` when nothing is stale, duplicated, misplaced, or promotion-worthy.
17. Decision with ADR-worthy outcome
   - Inspect existing ADRs, pick the next number, and draft a record only when the threshold is met.
18. Decision with no ADR needed
   - Return `no ADR needed` and route the item to notes or handoff when ADR criteria are not met.

## Scoring dimensions

- Output contract compliance
- Correctness and grounding
- Unnecessary clarifying questions
- Unnecessary tool calls
- Completion of multi-step tasks
- Verbosity and token discipline
- Backward compatibility with simpler prompt forms
- Deterministic routing for durable knowledge
- Appropriate no-op behavior when no capture action is warranted
- Verification-state quality for resumability prompts

## Acceptance bar

- Shared core is acceptable without overlays.
- Overlays improve quality without changing the core semantics.
- Older models still follow workflow and output shape.
- No benchmark depends on provider-specific syntax to succeed.
