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
5. Retrieval: precise rule lookup
   - Find one exact repo rule through bounded retrieval without loading a full policy file.
6. Retrieval: worklog plus policy
   - Answer with one current worklog file plus one policy file rather than broad repo context.
7. Retrieval: relation expansion
   - Traverse one hop such as `skill -> script -> doc` and return only the needed handles.
8. Creative artifact
   - Produce a constrained design or art implementation from a short brief.
9. Missing auth or missing tool fallback
   - Handle a task where the preferred integration is unavailable.
10. Ambiguous request needing clarification
   - Ask one minimal blocking question or make a safe assumption.
11. Named skill or agent invocation
   - Decide whether to invoke the requested helper based on task relevance.
12. Knowledge promotion to `AGENTS.md`
   - Route repeated repo-wide guidance into `AGENTS.md` after inspecting existing policy and avoid duplicate promotion.
13. Knowledge promotion to `docs/notes/`
   - Route a durable technical learning into `docs/notes/` after inspecting likely note targets and merge with existing notes when appropriate.
14. Knowledge promotion to `docs/adr/`
   - Draft an ADR only when the session includes a decision with rationale and consequences.
15. No durable promotion needed
   - Explicitly return a no-op outcome when nothing clears the promotion threshold.
16. Handoff with verification
   - Produce a concise handoff that includes `Checks run`, `Checks not run`, and `Known gaps`.
17. Minimal or no handoff needed
   - Keep resumability state minimal when the task is complete or no useful handoff remains.
18. Curate with concrete cleanup findings
   - Identify a small number of high-value cleanup actions after inspecting `AGENTS.md`, `.worklog/`, `docs/notes/`, and `docs/adr/`.
19. Curate with no cleanup needed
   - Explicitly return `no cleanup needed` when nothing is stale, duplicated, misplaced, or promotion-worthy.
20. Decision with ADR-worthy outcome
   - Inspect existing ADRs, pick the next number, and draft a record only when the threshold is met.
21. Decision with no ADR needed
   - Return `no ADR needed` and route the item to notes or handoff when ADR criteria are not met.

## Scoring dimensions

- Output contract compliance
- Correctness and grounding
- Unnecessary clarifying questions
- Unnecessary tool calls
- Completion of multi-step tasks
- Verbosity and token discipline
- Retrieval efficiency and slice discipline
- Backward compatibility with simpler prompt forms
- Deterministic routing for durable knowledge
- Appropriate no-op behavior when no capture action is warranted
- Verification-state quality for resumability prompts

## Acceptance bar

- Shared core is acceptable without overlays.
- Overlays improve quality without changing the core semantics.
- Older models still follow workflow and output shape.
- No benchmark depends on provider-specific syntax to succeed.
