---
name: continuous-learning
description: Automatically extract reusable patterns from agent sessions and save them as learned skills or prompts for future use.
origin: ECC
---

# Continuous Learning

## Purpose
Capture reusable patterns from completed sessions and turn them into durable guidance, skills, or follow-up prompts. Use this skill when the goal is to improve future agent behavior from real work instead of solving the current task directly.

## Use This Skill When
- Setting up or reviewing the end-of-session extraction workflow.
- Tuning pattern-detection thresholds or learned-skill destinations.
- Auditing whether the extraction script is saving useful patterns.
- Adapting the workflow to a different agent runtime or hooks system.

## Do Not Use This Skill When
- The user wants help on the active task rather than on learning from past tasks.
- The session is too short or too noisy to yield stable patterns.
- The environment does not expose a transcript or hook payload.

## Required Inputs
- The runtime being integrated, if it is not the default workflow.
- The desired transcript source or hook mechanism.
- The learned-output location, if it differs from `config.json`.
- Any thresholds or pattern categories the user wants to change.

If the runtime is unclear, inspect the local script and config first and describe the default behavior before proposing changes.

## Default Behavior
- Use `evaluate-session.sh` as the primary integration point.
- Read settings from `config.json` when present.
- Prefer end-of-session extraction to per-message extraction unless the user explicitly needs finer-grained hooks.
- Keep learned outputs in a user-scoped path rather than inside this repository.

## Workflow
1. Inspect `config.json` and `evaluate-session.sh` to confirm the current transcript source, thresholds, and output path behavior.
2. Confirm whether the task is setup, tuning, review, or runtime adaptation.
3. Adjust or describe the hook integration, config values, and learned-output path.
4. Check that the workflow remains user-scoped and does not write learned skills into this repo.
5. Summarize what will be extracted, where it will be written, and any runtime assumptions.

## Tooling
- Primary files: `config.json`, `evaluate-session.sh`.
- Expected input: transcript metadata from a stop hook or equivalent runtime callback.
- Learned output path: user-scoped path configured in `config.json` or resolved by the script.

## Output Contract
Return:
- The configured or proposed learning workflow.
- Any changed thresholds, hook behavior, or output-path assumptions.
- Risks or limitations, such as missing transcript support or runtime-specific dependencies.
- Verification status, including whether the script/config were only inspected or also exercised.

## Guardrails
- Keep learned outputs outside this repository.
- Do not assume one provider-specific runtime if the script can be adapted.
- Prefer deterministic config and script changes over speculative architectural comparisons.
- Avoid embedding machine-specific paths in the skill contract unless they are part of the actual implementation.

## Fallback
- If no hook or transcript source exists, document the missing prerequisite and suggest a manual export-and-review workflow.
- If the runtime is incompatible with the current script, keep the skill focused on the extraction contract and note where an adapter is needed.
- If the user only wants conceptual advice, provide the workflow without claiming the local integration is configured.

## References
- `config.json` for thresholds and learned-output settings.
- `evaluate-session.sh` for the current hook integration behavior.
