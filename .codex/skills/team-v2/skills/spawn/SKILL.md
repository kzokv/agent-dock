---
name: "team-v2:spawn"
description: "Spawn a v2.2.0 agent team (Architect-orchestrated, Fixer at Tier 2-3, Memory Curator at Tier 3)"
---

# /team [tier-N]

Spawn an agent team for a task. If no tier is specified, analyze the task and recommend one for user approval.

---

## Prerequisites

No special permission setup required. Memory staging uses `.worklog/team/memory/` (created alongside `.worklog/team/state.json`), which is outside the protected `.claude/` directory and does not trigger permission prompts in `bypassPermissions` mode.

---

## Workflow

### Step 1 — Gather context

Read the task description from the user. If the user provided a Linear issue ID, fetch it. Understand:
- What is being built/fixed/refactored
- Which files and layers are likely affected
- What the acceptance criteria are

### Step 2 — Determine tier

If the user specified `tier-N`, use that tier. Otherwise:

1. Read `references/tier-heuristics.md`
2. Analyze the task against the heuristic table
3. Present your recommendation with reasoning:

```
Recommended: Tier 2 (Squad)
Reasoning:
- ~5 files across API and web layers
- Moderate risk, known area of codebase
- No new modules

Approve? [y/n]
```

4. Wait for user approval before proceeding.

### Step 3 — Create the team

Use `TeamCreate` to create the team:

```
TeamCreate({
  team_name: "{ticket-id}-{short-slug}",
  description: "Tier N team for: {task summary}"
})
```

**Naming convention:** Use the ticket ID and a short slug, e.g., `kzo-73-auth-session`, `kzo-42-dividend-ledger`.

### Step 3b — Display cost estimate

Before spawning, display the estimated cost from `references/tier-heuristics.md`:

```
Estimated cost: ~$X-Y (Tier N, assuming M iterations)

Cost factors:
- Opus agents: N (Architect, Implementer, QA)
- Sonnet agents: M (Validator, Fixer*, Reviewer*, Writer*, Curator*)
- Each additional iteration adds ~30-50% of base cost

Proceed? [y/n]
```

Wait for user confirmation.

### Step 4 — Initialize state

1. Create `.worklog/team/` directory if it doesn't exist
2. Write `.worklog/team/state.json` from `templates/state.json`, populated with:
   - Task description
   - Selected tier
   - `iteration: 1`, `phase: "init"`
   - `branch`: output of `git branch --show-current`
   - `skill_version: "2.2.0"`
   - `teammates`: empty object (populated by Architect as teammates are spawned)
3. Create `.worklog/team/memory/` subdirectory if it doesn't exist

### Step 5 — Spawn the Architect

The Architect is the ONLY teammate spawned by the main session directly. All other teammates are spawned via `[SPAWN]` relay.

```
Agent({
  name: "architect",
  team_name: "{team-name}",
  model: "opus",
  prompt: "... full Architect prompt ..."
})
```

**The Architect's spawn prompt MUST include:**
1. The full task description and acceptance criteria
2. The technical plan/spec from pre-team scoping
3. The tier and expected teammate roster
4. Path to `.worklog/team/state.json`
5. The message prefix convention (Architect ↔ Main Session and Teammate ↔ Architect)
6. Instructions to create the technical design as its first action
7. Instructions to send `[SPAWN]` to main session when ready for teammates
8. **File paths to read on-demand** (instead of inlining full content):
   - `references/role-definitions.md` — read the Architect section + common teammate instructions
   - `references/convergence-loop.md` — read for phase management and exit criteria
   - `references/escalation-rules.md` — read for decision boundaries
   - `references/memory-categories.md` — read for memory staging guidance
9. Instructions to read `AGENTS.md` and/or `CLAUDE.md` in the target project for project-specific conventions and test commands
10. **Absolute memory staging path** — include the resolved absolute path to the project's `.worklog/team/memory/` directory. This prevents CWD-relative path resolution errors when teammates write staged memory files:
    ```
    Memory staging path: {absolute-path-to-project}/.worklog/team/memory/
    Write staged memory files to: {absolute-path-to-project}/.worklog/team/memory/{teammate-name}.md
    Do NOT use relative paths — always use the absolute path above.
    Do NOT write to .claude/memory/ — it is a protected directory that prompts for permission even in bypassPermissions mode.
    ```
    **Path resolution for worktrees:** `git rev-parse --show-toplevel` returns the worktree root, NOT the main repo. Use the worktree root directly.
11. **Teammate permission mode** — spawn ALL teammates (including the Architect) with `mode: "bypassPermissions"`. Teammates run in tmux panes as separate Claude Code processes. The `mode: "auto"` setting does NOT fully bypass file-creation permission prompts, causing teammates to stall on interactive permission dialogs mid-run. `bypassPermissions` ensures teammates can write memory staging files, test files, and implementation code without prompts.

### Step 6 — Enter relay loop

Once the Architect is spawned, the main session enters its relay loop:

```
1. Receive message from Architect
2. Classify by prefix:
   [STATUS]      → summarize and display to user
   [ESCALATE]    → display with context, collect user response, relay as [USER]
                   Special case — stuck-at-shutdown escalation:
                     User picks A → relay N minutes back as [USER]
                     User picks B → call TaskStop on stuck tasks, relay [USER] "Force-stopped: {names}"
                     User picks C → trigger /team abort
   [SPAWN]       → parse roster, spawn via Agent tool, confirm back to Architect
   [FORCE_STOP]  → call TaskStop on named tasks, confirm back as [USER]
   [SHUTDOWN]    → display final report (including force-stopped teammates if any), exit loop
   [HEARTBEAT]   → reset timeout counter, do not display
3. Receive message from user (unprompted)
   → Relay to Architect via [USER] prefix
4. If 10 minutes with no Architect message → alert user
5. Repeat until [SHUTDOWN]
```

### Handling [SPAWN] requests

When the Architect sends a `[SPAWN]` message, it includes a structured payload:

```
[SPAWN]
teammates:
  - name: "tdd-implementer"
    model: "opus"
    role: "TDD Implementer"
    reason: "Wave 1 — core loop"
  - name: "senior-qa"
    model: "sonnet"
    role: "Senior QA"
    reason: "Wave 1 — core loop"
  - name: "validator"
    model: "sonnet"
    role: "Validator"
    reason: "Wave 1 — core loop"
```

The main session:
1. Spawns all requested teammates in a SINGLE message (parallel) using the `Agent` tool with `team_name`, `name`, and `mode: "bypassPermissions"` parameters
2. Each teammate's prompt includes:
   - Role definition from `references/role-definitions.md` (for the tier variant the Architect specified)
   - The task description and acceptance criteria
   - The Architect's technical design (included in the [SPAWN] payload or retrieved from a shared location)
   - The team name
   - The common teammate instructions (including message prefix convention and memory staging)
   - File paths to read on-demand: `references/convergence-loop.md` (their phases), `references/escalation-rules.md`
   - **Absolute memory staging path** (same value passed to the Architect — prevents CWD-relative path errors):
     ```
     Write your staged memory file to: {absolute-path-to-project}/.worklog/team/memory/{your-name}.md
     Use this exact absolute path — never relative paths.
     Do NOT write to .claude/memory/ — it is protected and will prompt for permission.
     ```
3. Confirms back to Architect: `Spawned: [list of teammate names]. All in tmux panes.`

### Handling [FORCE_STOP]

Before or alongside `[SHUTDOWN]`, the Architect may send `[FORCE_STOP: teammate-name, ...]` when a teammate is auto-force-stopped after 3 failed extensions:

1. Call `TaskStop` on each named teammate's in-progress task
2. Confirm back to Architect: `[USER] Force-stopped: {names}. Proceed with shutdown.`

### Handling [SHUTDOWN]

The Architect only sends `[SHUTDOWN]` after verifying all teammates are idle — no `TaskStop` is needed in the normal case.

When the Architect sends `[SHUTDOWN]`:
1. Display the final report to the user, including any force-stopped teammates noted in the report
2. Display the knowledge hygiene suggestions from the report:

```
## Knowledge hygiene

[Architect's conditional suggestions — one or more of:]
- Run `/si:review` to audit memory entries from this run and identify promotion candidates
- Run `/si:promote` to graduate proven patterns to CLAUDE.md or .claude/rules/
- Run `/si:extract` to turn a reusable pattern into a standalone skill
- Run `/si:status` to check memory health

Periodic reminder: every 3–5 team runs, run `/si:review` + `/si:promote` to prevent
auto-memory from accumulating stale or unpromoted entries.
```

3. Exit the relay loop — the team is complete

---

## Two-wave spawn pattern

The Architect sends `[SPAWN]` requests in two waves:

| Wave | When | Teammates |
|------|------|-----------|
| Wave 1 | After Architect creates technical design | Implementer, QA, Validator, Fixer*, Code Reviewer* |
| Wave 2 | After convergence loop exits (Tier 3 only) | Technical Writer, Memory Curator |

*Fixer and Code Reviewer only at Tier 2-3.

---

## Tier → Teammate mapping

### Tier 1 (Solo) — 4 teammates total
- Architect (Opus) — `name: "architect"` — spawned by main session
- TDD Implementer (Opus) — `name: "tdd-implementer"` — Wave 1
- Senior QA (Opus) — `name: "senior-qa"` — Wave 1
- Validator (Sonnet) — `name: "validator"` — Wave 1

### Tier 2 (Squad) — 6 teammates total
- Architect (Opus) — `name: "architect"` — spawned by main session
- TDD Implementer (Opus) — `name: "tdd-implementer"` — Wave 1
- Senior QA (Opus) — `name: "senior-qa"` — Wave 1
- Fixer (Sonnet) — `name: "fixer"` — Wave 1
- Validator (Sonnet) — `name: "validator"` — Wave 1
- Code Reviewer (Sonnet) — `name: "code-reviewer"` — Wave 1

### Tier 3 (Full Team) — 8 teammates total
- Architect (Opus) — `name: "architect"` — spawned by main session
- TDD Implementer (Opus) — `name: "tdd-implementer"` — Wave 1
- Senior QA (Opus) — `name: "senior-qa"` — Wave 1
- Fixer (Sonnet) — `name: "fixer"` — Wave 1
- Validator (Sonnet) — `name: "validator"` — Wave 1
- Code Reviewer (Sonnet) — `name: "code-reviewer"` — Wave 1
- Technical Writer (Sonnet) — `name: "technical-writer"` — Wave 2
- Memory Curator (Sonnet) — `name: "memory-curator"` — Wave 2
