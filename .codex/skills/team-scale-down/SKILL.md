---
name: "team-scale-down"
description: "Remove teammates from a running team by downgrading to a lower tier. Use when: user wants to scale down, remove agents, or downgrade tier mid-execution."
---

# /team-scale-down

## Version detection

1. Read `.worklog/team/state.json`
2. Check `skill_version`:
   - `"2.2.0"` → load and execute `team-v2/skills/scale-down/SKILL.md`
   - `"3.0.0"` or missing field → load and execute `team/skills/scale-down/SKILL.md`
   - No state.json → load and execute `team/skills/scale-down/SKILL.md` (latest; let it handle "no team running")
