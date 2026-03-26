---
name: Team Skill Versioning
description: Active work to version the team skill so v2.2.0 and v3.0.0 are both invokable by name
type: project
---

The `team` skill is being explicitly versioned so the user can invoke different versions by name.

**Why:** The skill evolved significantly between versions and the user wants to be able to test/compare them without losing the old behavior.

**How to apply:** When resuming this work, the starting question is the naming scheme and whether the old version should be a full file copy or a git-ref pointer. The user hadn't answered yet as of 2026-03-26.

## Version delta (v2.2.0 → v3.0.0)

| Area | v2.2.0 (committed) | v3.0.0 (working tree) |
|------|--------------------|-----------------------|
| Tier 2-3 state routing | Architect manages everything | Dispatcher (Sonnet) handles state/routing |
| Finding fixes | Dedicated Fixer role | Domain agents self-fix their own findings |
| Wave 2 | Tier 3 only (Technical Writer + Memory Curator) | All tiers (Technical Writer; conditional at Tier 1) |
| QA at Tier 3 | Sonnet | Opus |

## Naming options discussed

1. `team` (v3) + `team-v2` (v2.2.0) — forward-compatible default
2. `team-v3` + `team-v2` — both explicitly versioned
3. `team` (v3) + `team-legacy` (v2.2.0) — marks old as deprecated

**Session paused** at 2026-03-26 before user selected a naming scheme.

## Implementation approach (to verify when resuming)

- Skills are discovered by Claude Code via `SKILL.md` frontmatter in `.codex/skills/`
- `.codex/skills/` and `.claude/skills/` share the same inodes (hard links) — changes propagate automatically
- A new versioned skill would be a new directory under `.codex/skills/` (e.g., `team-v2/`) with its own `SKILL.md` and sub-skills
- Sub-skills need their own `SKILL.md` files with updated `name` fields (e.g., `team-v2 scale-up`)
