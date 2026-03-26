---
name: "team-scale-up"
description: "Add teammates to a running team by upgrading to a higher tier. Use when: user wants to scale up, add agents, or upgrade tier mid-execution."
---

# /team-scale-up

## Version detection

1. Read `.worklog/team/state.json`
2. Check `skill_version`:
   - `"2.2.0"` → load and execute `team-v2/skills/scale-up/SKILL.md`
   - `"3.0.0"` or missing field → load and execute `team/skills/scale-up/SKILL.md`
   - No state.json → load and execute `team/skills/scale-up/SKILL.md` (latest; let it handle "no team running")
