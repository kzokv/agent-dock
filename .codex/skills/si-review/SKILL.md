---
name: "si-review"
description: "Analyze auto-memory for promotion candidates, stale entries, and consolidation opportunities. Use when: reviewing what Claude has learned, identifying patterns to promote to rules, finding outdated entries."
---

# /si:review — Analyze Auto-Memory

Performs a comprehensive audit of Claude Code's auto-memory and produces actionable recommendations for promotion candidates, stale entries, and health metrics.

## Usage

```
/si:review                    # Full review
/si:review --quick            # Summary only (counts + top 3 candidates)
/si:review --stale            # Focus on stale/outdated entries
/si:review --candidates       # Show only promotion candidates
```

## What It Does

Invokes the memory-analyst agent to:
1. Locate all memory files (MEMORY.md and topic files)
2. Analyze each entry for recurrence, staleness, and consolidation opportunities
3. Cross-reference with CLAUDE.md and .claude/rules/ for duplicates
4. Generate a prioritized report with promotion candidates
5. Flag conflicts and stale references

## Tips

- Run `/si:review --quick` frequently (low overhead)
- Full review is most valuable when MEMORY.md is getting crowded (>150 lines)
- Act on promotion candidates promptly — they're proven patterns
- Delete stale entries to free up space; auto-memory will re-learn if needed
