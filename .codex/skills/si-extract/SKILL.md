---
name: "si-extract"
description: "Extract a proven pattern into a standalone, reusable skill. Use when: you have a debugging solution or workflow that could benefit other projects, you want to publish a skill."
---

# /si:extract — Turn Patterns into Skills

Convert a proven pattern from MEMORY.md into a complete, reusable skill that can be published or installed in other projects.

## Usage

```
/si:extract "pattern name"                # Extract a pattern to a skill
/si:extract "pattern" --name my-skill     # Custom skill name
/si:extract "pattern" --publish           # Generate for publishing
```

## What It Generates

A complete skill package with:
- **SKILL.md** with proper frontmatter
- **README.md** with documentation
- **Reference files** explaining the pattern
- **Examples** and edge cases
- **Ready for `/plugin install`** or `clawhub publish`

## Tips

- Extract after a pattern has recurred 3+ times
- Skills are more general than rules — they work across projects
- Extracted skills can be version-controlled separately
- Use `/skill-tester` to validate a skill before publishing

## Related

- `/si:promote` — graduate patterns to project rules (not skills)
- `/skill-tester` — validate a skill before using it
