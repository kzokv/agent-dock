---
name: "team-v2:evaluate-tier"
description: "Analyze a task and recommend a tier without spawning agents (v2.2.0)"
---

# /team evaluate-tier

Analyze the current task and recommend a team tier without spawning any agents.

---

## Workflow

### Step 1 — Gather context

Understand the task from:
- User's description in the current conversation
- Linear issue if referenced
- Git diff or branch changes if work has started
- Existing codebase structure (which files/layers would be affected)

### Step 2 — Evaluate against heuristics

Read `references/tier-heuristics.md` and score the task:

| Signal | Evaluate |
|--------|----------|
| Files likely changed | Count affected files by exploring the codebase |
| Layers touched | Identify which layers (API, UI, DB, config, tests) |
| Spec complexity | Simple fix vs. multi-story feature |
| Risk level | Isolated change vs. cross-cutting concern |

### Step 3 — Present recommendation

Output a structured recommendation:

```
## Tier Recommendation

**Task:** [brief description]

**Recommended tier:** Tier N ([Solo/Squad/Full Team])

### Analysis
| Signal | Assessment | Score |
|--------|-----------|-------|
| Files changed | ~N files (list key ones) | Tier X |
| Layers touched | [API, UI, ...] | Tier X |
| Spec complexity | [simple/moderate/complex] | Tier X |
| Risk | [low/moderate/high] — [reason] | Tier X |

### Teammates that would be spawned
[List teammates for the recommended tier]

### Why not Tier [N-1]?
[Explain why lower tier is insufficient]

### Why not Tier [N+1]?
[Explain why higher tier is unnecessary, or note if it's borderline]

### Cost estimate
- Opus agents: N | Sonnet agents: M
- Estimated cost: ~$X-Y (assuming N iterations)
- Each additional iteration adds ~30-50%
```

### Step 4 — Wait for approval

Do NOT spawn teammates. This is evaluation only. The user can then run `/team tier-N` to spawn.
