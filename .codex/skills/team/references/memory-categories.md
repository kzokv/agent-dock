# Memory Categories

What to capture in memory during team execution, and what to skip.

---

## Always capture

| Category | Example | Why it matters |
|----------|---------|----------------|
| **User corrections** | "User said don't mock the DB" | Prevents repeating the same mistake next conversation |
| **Spec deviations** | "Plan said X but we built Y because of constraint Z" | Explains why code doesn't match the original plan |
| **Discovered constraints** | "Google OAuth token expires in 60s, not 300s as docs imply" | Hard-won knowledge not in any documentation |
| **Escalation outcomes** | "Architect escalated ambiguous scope, user decided to exclude feature X" | Records scope decisions that won't appear in code |

---

## Capture if non-obvious

| Category | Example | Why it matters |
|----------|---------|----------------|
| **Recurring failure patterns** | "Vitest alias order matters — `@/` must come before `@app/`" | Saves hours of debugging next time |
| **Test environment gotchas** | "E2e OAuth tests need `AUTH_MODE=oauth` or cookies silently fail" | Environment-specific knowledge not derivable from code |
| **Cross-module dependencies** | "Changing session cookie format breaks both API integration and e2e OAuth suites" | Prevents future agents from making isolated changes to shared concerns |

---

## Never capture

| Category | Why not |
|----------|---------|
| What files were changed | `git log` is authoritative |
| How a bug was fixed | The fix is in the code; the commit message has context |
| Code patterns or conventions | Readable from the codebase directly |
| Anything already in CLAUDE.md or rules/ | Duplication creates conflicts |
| Ephemeral task state | The task list tracks this |

---

## Memory staging model

All teammates (including the Architect) write memory candidates to individual staged files during execution. No teammate modifies `MEMORY.md` directly.

**IMPORTANT:** Do NOT write to `.claude/memory/` — it is a protected directory in Claude Code. `bypassPermissions` mode does NOT bypass write prompts for `.claude/memory/`. Only `.claude/commands/`, `.claude/agents/`, and `.claude/skills/` are exempt. Writing to `.claude/memory/` causes teammates to stall on interactive permission dialogs.

### During execution (all tiers)

Any teammate who encounters something from the "Always capture" or "Capture if non-obvious" categories writes it to:

```
.worklog/team/memory/{teammate-name}.md
```

Each teammate owns their own file — no locks, no coordination needed. The `.worklog/team/` directory is created at team init.

### Consolidation at wrap-up

| Tier | Consolidator | When |
|------|-------------|------|
| Tier 1-2 | **Architect** | After convergence loop exits |
| Tier 3 | **Memory Curator** (Wave 2 teammate) | After convergence loop exits, alongside Technical Writer |

The consolidator:
1. Reads all files in `.worklog/team/memory/`
2. Deduplicates and cleans up entries
3. Writes consolidated entries to `.worklog/team/memory/consolidated.md` (NOT to `.claude/memory/`)
4. **Preserves** the individual staged files (do NOT delete them — they serve as an audit trail)

### Post-shutdown consolidation

After [SHUTDOWN], the main session (which runs interactively and can handle permission prompts):
1. Reads `.worklog/team/memory/consolidated.md`
2. Prompts the user: "Consolidate N memory entries to `.claude/memory/`? [y/n]"
3. On approval, writes proper memory files to `.claude/memory/` and updates `MEMORY.md` index
4. This is a single batch approval — the user sees what's being written

---

## Memory entry format

Follow the project's standard memory format:

```markdown
---
name: {{descriptive_name}}
description: {{one-line description for relevance matching}}
type: {{feedback or project}}
---

{{The fact or rule}}

**Why:** {{reason or context}}

**How to apply:** {{when and where this matters}}
```

---

## Staleness policy

Memory entries are NOT reviewed for staleness during team execution. The user manages staleness manually via `/si:review`.
