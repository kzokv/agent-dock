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

## Scoring dimensions

- Output contract compliance
- Correctness and grounding
- Unnecessary clarifying questions
- Unnecessary tool calls
- Completion of multi-step tasks
- Verbosity and token discipline
- Backward compatibility with simpler prompt forms

## Acceptance bar

- Shared core is acceptable without overlays.
- Overlays improve quality without changing the core semantics.
- Older models still follow workflow and output shape.
- No benchmark depends on provider-specific syntax to succeed.

