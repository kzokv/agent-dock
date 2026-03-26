---
name: "team-status"
description: "Show current state of a running agent team. Use when: user wants team status, progress, phase, iteration, or teammate roster."
---

# /team-status

## Version detection

1. Read `.worklog/team/state.json`
2. Check `skill_version`:
   - `"2.2.0"` → load and execute `team-v2/skills/status/SKILL.md`
   - `"3.0.0"` or missing field → load and execute `team/skills/status/SKILL.md`
   - No state.json → load and execute `team/skills/status/SKILL.md` (latest; let it handle "no team running")
