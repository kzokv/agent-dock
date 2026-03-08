# Prompt Evaluation Harness

Use this directory to evaluate shared prompt changes before treating them as the default contract.

Start with:

- `benchmark-set.md` for representative tasks
- `results-template.md` for scoring runs across model families

Evaluation rule:

- Tune the shared core first.
- Add or change overlays only when the benchmark shows a clear, repeatable benefit for a model family.
- When capture or workflow prompts change, extend the benchmark with scenario-specific pass/fail checks before adopting the revision.
