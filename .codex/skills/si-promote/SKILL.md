---
name: "si-promote"
description: "Graduate a pattern from auto-memory to CLAUDE.md or .claude/rules/. Use when: you want to convert a learned pattern into an enforced rule, move a memory entry to permanent project knowledge."
---

# /si:promote — Graduate Pattern to Rules

Move a proven pattern from MEMORY.md into your project's permanent rule system (CLAUDE.md or .claude/rules/).

## Usage

```
/si:promote "pattern name"               # Promote a specific pattern
/si:promote "pattern" --to rules         # Promote to .claude/rules/
/si:promote "pattern" --to CLAUDE.md     # Promote to CLAUDE.md
```

## What It Does

1. Identifies the pattern in MEMORY.md
2. Generates a properly formatted rule entry
3. Determines best destination (CLAUDE.md vs. scoped rule file)
4. Adds the rule to permanent project knowledge
5. Removes the entry from MEMORY.md to free space

## Pattern Destinations

- **CLAUDE.md**: Project-wide patterns that apply everywhere
- **.claude/rules/topic.md**: Scoped rules for specific file types or areas

## Tips

- Promotion candidates appear in `/si:review` output
- Promoted rules get full context loaded (not truncated at 200 lines)
- Once promoted, the rule is enforced in all future Claude sessions
- You can manually edit promoted rules at any time
