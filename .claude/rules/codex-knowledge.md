---
scope: "**/*"
---

# Knowledge Curation

When capturing durable knowledge that should persist beyond the current conversation,
route it using the `.codex/prompts/promote.md` model:

- Use `/si:promote` to graduate auto-memory entries into permanent project knowledge
- Use `/si:review` to audit and maintain existing memory entries
- Use `/si:remember` to capture a specific insight immediately

Destination targets by content type:
- Project context and repo-wide guidance: `.claude/CLAUDE.md`
- Scoped behavioral rules: `.claude/rules/`
- Technical notes and decisions: `docs/notes/`, `docs/adr/`
- Reusable patterns: `.codex/skills/`

Auto-memory (`MEMORY.md`) is version-controlled at `.claude/memory/`.
