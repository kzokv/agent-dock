---
name: "si-remember"
description: "Explicitly save knowledge to auto-memory. Use when: capturing an important insight, logging a debugging breakthrough, documenting project context that should persist."
---

# /si:remember — Save to Auto-Memory

Explicitly capture important knowledge into MEMORY.md or a topic-specific memory file, bypassing auto-capture and ensuring it's preserved.

## Usage

```
/si:remember "insight about the project"         # Save to MEMORY.md
/si:remember "debugging trick" --topic debugging  # Save to topic file
/si:remember "architecture decision" --type project  # Specify type
```

## Types

- **user**: Information about your role, preferences, domain knowledge
- **feedback**: Rules or guidance you've given Claude
- **project**: Active work, goals, initiatives, deadlines (convert dates to absolute)
- **reference**: Pointers to external resources (Linear projects, dashboards, docs)

## Tips

- Use `/si:remember` when you notice a pattern Claude should know about
- Topic-specific memories keep related entries organized
- Auto-memory already captures a lot — use this for things that won't be auto-detected
- Absolute dates survive across sessions better than relative ones ("2026-03-20" vs "Thursday")

## Related

- `/si:review` — audit memory and find promotion candidates
- `/si:status` — check memory health before saving more
