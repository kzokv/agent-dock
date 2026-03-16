---
description: Override default memory path — all agent memory must live in-repo
globs: *
---

# Memory location override

Do NOT write memory files to `~/.claude/projects/*/memory/` (the system default).
All agent memory MUST be written to the in-repo `.claude/memory/` directory so it is version-controlled alongside the codebase.

This applies to MEMORY.md index files and all individual memory topic files.
