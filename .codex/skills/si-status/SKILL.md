---
name: "si-status"
description: "Memory health dashboard showing line counts, capacity, topic files, and recommendations. Use when: checking memory capacity, deciding if it's time to review/promote, monitoring auto-memory health."
---

# /si:status — Memory Health Dashboard

Quick overview of your project's memory state showing capacity utilization, health metrics, and actionable recommendations.

## Usage

```
/si:status                    # Full dashboard
/si:status --brief            # One-line summary
```

## What It Reports

- **MEMORY.md capacity**: Lines used / 200-line limit with visual bar
- **Topic files**: Count and names of overflow files Claude created
- **CLAUDE.md rules**: Line count and .claude/rules/ file inventory
- **Health status**: Capacity level (green/yellow/red), stale entry count, duplicates
- **Recommendations**: What to do next based on current state

## Interpretation

- **Green (< 60%)**: Plenty of room. Auto-memory is working well.
- **Yellow (60-90%)**: Getting full. Consider running `/si:review` to promote or clean up.
- **Red (> 90%)**: Near capacity. Auto-memory may start dropping older entries. Run `/si:review` now.

## Tips

- Run `/si:status --brief` as a quick check anytime
- If capacity is yellow+, run `/si:review` to identify promotion candidates
- Stale entries waste space — delete references to files that no longer exist
