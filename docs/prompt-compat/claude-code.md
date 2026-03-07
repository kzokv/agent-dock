# Claude Code Overlay

Apply this overlay only when the runtime is Claude Code or a closely related Claude-based coding agent.

## What this family tends to do well

- Follow concise operational instructions.
- Work effectively with tool-oriented loops and repo-grounded context.
- Benefit from explicit guardrails around scope and verification.

## Preferred prompt choices

- Keep the top-level contract short and executable.
- Separate policy from workflow.
- Use direct instructions for what to inspect, what to change, and how to report results.
- Prefer references and templates over large inlined examples.

## Avoid

- Overloading the skill or policy file with manifesto-style prose.
- Depending on vendor-specific wording in shared prompts.
- Treating style preferences as more important than task completion or verification.

## Compatibility note

- If a prompt already works as plain Markdown with explicit outputs and checks, it should not need Claude-specific syntax to remain effective.

