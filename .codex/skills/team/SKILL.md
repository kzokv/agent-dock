---
name: "team"
description: "Spawn and manage multi-agent implementation teams with tiered scaling, convergence loops, and state tracking. Use when: user wants to create an agent team, spawn agents for implementation, scale agents up/down, or evaluate task complexity for tier selection."
metadata:
  version: 2.2.0
  category: engineering
  updated: 2026-03-22
---

# Team — Multi-Agent Implementation Teams

Spawn opinionated agent teams that separate **writing** from **validating** from **reviewing**. Each teammate runs in its own tmux pane via Claude Code's Agent Teams feature. Teams run in a bounded convergence loop until all tests pass and all findings are addressed.

---

## Slash Commands

| Command | What it does |
|---------|-------------|
| `/team` | Describe task → recommend tier → approve → spawn team |
| `/team tier-N` | Directly spawn a team at the specified tier (1, 2, or 3) |
| `/team evaluate-tier` | Analyze task and recommend a tier without spawning |
| `/team scale-up` | Add teammates mid-execution (e.g., Tier 1 → Tier 2) |
| `/team scale-down` | Remove teammates mid-execution (e.g., Tier 3 → Tier 2) |
| `/team status` | Show current team state (tier, phase, iteration, teammates, costs) |
| `/team abort` | Gracefully shut down all teammates and preserve work |

---

## When This Skill Activates

Recognize these patterns from the user:

- "Create a team for [task]"
- "Spawn agents for [feature/bug/refactor]"
- "What tier should this be?"
- "Scale up / scale down the team"
- "Start implementation with a team"

---

## Architecture

### Three-layer hierarchy

```
User <-> Main Session (Team Manager) <-> Architect (persistent teammate) <-> Teammates (panes)
```

- **Main Session = Team Manager**: Spawns the Architect, relays escalations to the user, handles spawn requests from the Architect (only the main session can spawn teammates). Filters teammate messages — status updates get summarized, escalations get surfaced with context.
- **Architect = Persistent Teammate**: Runs in its own tmux pane. Creates the technical design, orchestrates the convergence loop, coordinates teammates via `SendMessage` and `TaskCreate`/`TaskUpdate`. Does NOT edit files (prompt-forbidden). Reports to the main session.
- **Teammates = tmux panes**: Each teammate runs in its own tmux pane in the same worktree. They work on assigned tasks, communicate via `SendMessage` with message prefix conventions, and track progress via `TaskUpdate`.

### Pre-team phase (human + Claude)

Clarify → Scope → Plan → Define acceptance criteria → Hand off to team.

The user owns the plan. The team executes it.

### Commit / branch strategy

The team assumes it is running inside a **git worktree** that the user created manually before invoking `/team`. The team does NOT create branches, commit, or push — the human handles the final commit process after the team shuts down.

- The Architect records the branch name in `.team/state.json` at init (reads from `git branch --show-current`)
- Teammates do NOT run `git add`, `git commit`, or `git push`
- All file changes remain uncommitted on disk for human review
- If the user needs to checkpoint mid-run, they do it manually outside the team

This keeps the git history clean and avoids agents fighting over staging.

### Team execution

Uses Claude Code's **Agent Teams** feature (`TeamCreate` + `TaskCreate` + `SendMessage`):

1. Main session creates the team and spawns the Architect only
2. Architect creates the technical design, then requests teammates via `[SPAWN]` message
3. Main session spawns requested teammates
4. Architect orchestrates the convergence loop via `SendMessage` + `TaskCreate`/`TaskUpdate`
5. Main session relays escalations to the user and handles spawn/shutdown requests

See `references/convergence-loop.md` for the full convergence loop flow.

### Tiers

| Tier | Name | When | Teammates (tmux panes) | Est. Cost |
|------|------|------|------------------------|-----------|
| 1 | Solo | 1-2 files, single layer, low risk | 4: Architect, Implementer, QA, Validator | ~$2-5 |
| 2 | Squad | 3-8 files, 2 layers, moderate risk | 6: + Fixer, Code Reviewer | ~$5-15 |
| 3 | Full Team | 9+ files, 3+ layers, high risk | 6 during loop + 2 at wrap-up: + Technical Writer, Memory Curator | ~$15-40 |

See `references/tier-heuristics.md` for selection criteria.

### Two-wave spawn

| Wave | When | Teammates |
|------|------|-----------|
| Wave 1 | After Architect creates technical design | Implementer, QA, Validator, Fixer*, Code Reviewer* |
| Wave 2 | After convergence loop exits (Tier 3 only) | Technical Writer, Memory Curator |

*Fixer and Code Reviewer only at Tier 2-3.

### State management

| Concern | Managed by |
|---------|-----------|
| Team creation | `TeamCreate` → creates team + shared task list |
| Work items | `TaskCreate` / `TaskUpdate` / `TaskList` |
| Coordination | `SendMessage` between teammates with prefix conventions |
| Loop control | `.team/state.json` (phase, iteration, exit checks, tier, escalation log) |

The Architect is the sole writer to `.team/state.json` — no lock protocol needed.

### Message conventions

All inter-agent communication uses prefix conventions for reliable routing.

**Architect <-> Main Session:**

| Prefix | Direction | Meaning |
|--------|-----------|---------|
| `[STATUS]` | Architect → Main | Phase transition, iteration progress |
| `[ESCALATE]` | Architect → Main | Needs user decision |
| `[SPAWN]` | Architect → Main | Needs new teammates spawned (structured payload) |
| `[SHUTDOWN]` | Architect → Main | All green, team done |
| `[HEARTBEAT]` | Architect → Main | Still alive, working (every 10 min of silence) |
| `[USER]` | Main → Architect | Relaying user message |

**Teammate <-> Architect:**

| Prefix | Direction | Meaning |
|--------|-----------|---------|
| `[DONE:CLEAN]` | Teammate → Architect | Task complete, no issues |
| `[DONE:FINDINGS]` | Teammate → Architect | Task complete, findings attached |
| `[BLOCKED]` | Teammate → Architect | Can't proceed |
| `[CYCLE]` | Teammate → Architect | Repeat failure detected (Fixer) |
| `[QUESTION]` | Teammate → Architect | Needs clarification |

### Memory staging

All teammates (including Architect) write memory candidates to `.team/memory/{teammate-name}.md` during execution. No locks needed — each teammate owns their own file.

**Why `.team/memory/` and not `.claude/memory/`?** The `.claude/` directory is protected by Claude Code — `bypassPermissions` mode does NOT bypass write prompts for `.claude/memory/`. Only `.claude/commands/`, `.claude/agents/`, and `.claude/skills/` are exempt. Writing to `.claude/memory/` causes teammates to stall on interactive permission dialogs.

Consolidation happens once at wrap-up:
- **Tier 1-2**: Architect writes consolidated entries to `.team/memory/consolidated.md`. Main session prompts user to approve batch write to `.claude/memory/` after [SHUTDOWN].
- **Tier 3**: Memory Curator (Wave 2) writes consolidated entries to `.team/memory/consolidated.md`. Main session prompts user to approve batch write to `.claude/memory/` after [SHUTDOWN].

See `references/memory-categories.md` for what to capture.

---

## Routing

When the user invokes `/team`:

1. If arguments include `tier-N` → delegate to `skills/spawn/SKILL.md` with tier locked
2. If arguments include `evaluate-tier` → delegate to `skills/evaluate-tier/SKILL.md`
3. If arguments include `scale-up` → delegate to `skills/scale-up/SKILL.md`
4. If arguments include `scale-down` → delegate to `skills/scale-down/SKILL.md`
5. If arguments include `status` → delegate to `skills/status/SKILL.md`
6. If arguments include `abort` → delegate to `skills/abort/SKILL.md`
7. Otherwise → delegate to `skills/spawn/SKILL.md` (will recommend tier first)

---

## Key References

- `references/role-definitions.md` — All 8 roles (Main Session + 7 team roles) with per-tier variants
- `references/convergence-loop.md` — Phases, exit criteria, Architect self-check
- `references/tier-heuristics.md` — Tier selection criteria
- `references/escalation-rules.md` — When Architect decides vs. escalates to human
- `references/memory-categories.md` — What to capture in memory, what to skip
- `templates/state.json` — Initial state file template
- `skills/status/SKILL.md` — Read-only team status report
- `skills/abort/SKILL.md` — Graceful team shutdown
