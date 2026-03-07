# Core Prompt Contract

Use this contract when you want the same prompt to work acceptably across OpenAI GPT-5.x, Claude Code, Gemini, and older OpenAI GPT-5.x variants.

## Design goals

- Plain Markdown only.
- Minimal assumptions about provider-specific roles or controls.
- Explicit outputs, verification, and fallback behavior.
- Short examples and short instructions.

## Recommended prompt shape

1. State the job in one sentence.
2. State the workflow in ordered steps.
3. State the required output shape.
4. State verification rules.
5. State fallback behavior when context or tools are missing.

## Required behaviors

- Inspect the minimum relevant context before acting.
- Use tools only when they materially improve correctness or completion.
- Ask for clarification only when a missing detail blocks correct execution.
- Distinguish verified facts from inference.
- Report verification status in the final answer.

## Portable output contract

For most tasks, the final answer should include:

- the direct result
- what was verified
- remaining limits or risks

For code review:

- findings first
- file references
- impact or regression risk

For implementation:

- change summary
- checks run
- known gaps

For research:

- answer
- cited sources
- explicit uncertainty where needed

## Anti-patterns

- Depending on XML-like tags for critical meaning.
- Asking for hidden reasoning or chain-of-thought.
- Embedding long tutorials directly in the main contract.
- Repeating salience words instead of writing precise instructions.
- Requiring provider-specific tool semantics when a plain-language fallback is possible.

