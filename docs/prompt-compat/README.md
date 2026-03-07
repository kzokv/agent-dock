# Prompt Compatibility

This directory keeps the shared prompt contract portable across OpenAI GPT-5.x, Claude Code, Gemini, and older OpenAI GPT-5.x variants.

Use these files in this order:

1. `core-contract.md` for the default cross-agent behavior.
2. `backward-compatible-authoring.md` when writing or refactoring prompts and skills.
3. The provider overlay only when a task depends on a specific runtime or tool family:
   - `openai-gpt5.md`
   - `claude-code.md`
   - `gemini.md`

Rules for using overlays:

- The shared contract must stand on its own without any overlay.
- Overlays may optimize wording, tool expectations, and formatting for a family, but they must not change the core semantics.
- If two overlays would conflict, prefer the shared core and simplify the prompt.

Related evaluation materials live in `../prompt-evals/`.
