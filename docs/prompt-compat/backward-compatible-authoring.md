# Backward-Compatible Authoring

Use this guide when writing prompts, policies, and `SKILL.md` files that must continue to work on older or less capable models.

## Authoring rules

- Prefer plain Markdown headings and bullets.
- Put the task before the nuance.
- Keep sections short enough to scan quickly.
- Put the output contract near the top half of the prompt.
- Use direct verbs such as inspect, verify, cite, update, and report.
- Use one strong emphasis marker only when it changes behavior.

## Template for portable skills

1. Purpose
2. Use This Skill When
3. Do Not Use This Skill When
4. Required Inputs
5. Default Behavior
6. Workflow
7. Tooling
8. Output Contract
9. Guardrails
10. Fallback
11. References

## Keep portable prompts away from these pitfalls

- Repeating `CRITICAL`, `IMPORTANT`, or `ALWAYS`.
- Requiring exact XML or tag parsing.
- Hiding essential behavior in examples.
- Embedding long tutorials in the main contract.
- Requiring provider-specific auth, tool, or sandbox behavior in shared instructions.

## Refactoring checklist

- Can the prompt still be understood if tags are removed?
- Can an older model find the task, workflow, and output shape in the first screenful?
- Are verified facts and inferred statements kept distinct?
- Is the fallback behavior explicit when tools or context are missing?

