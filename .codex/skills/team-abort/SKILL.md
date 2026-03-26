---
name: "team-abort"
description: "Gracefully shut down a running agent team. Use when: user wants to abort, stop, or shut down the team."
---

# /team-abort

## Version detection

1. Read `.worklog/team/state.json`
2. Check `skill_version`:
   - `"2.2.0"` → load and execute `team-v2/skills/abort/SKILL.md`
   - `"3.0.0"` or missing field → load and execute `team/skills/abort/SKILL.md`
   - No state.json → load and execute `team/skills/abort/SKILL.md` (latest; let it handle "no team running")
