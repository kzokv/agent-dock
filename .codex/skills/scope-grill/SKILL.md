---
name: scope-grill
description: Relentlessly grill a scope — from a custom request, Linear tickets, or both — through a 3-phase structured session: interrogate, debate, lock. Use when the user wants to stress-test ticket scope, challenge a design proposal, or lock down implementation scope before starting work.
---

# Scope Grill

A structured, adversarial scope session in three phases: interrogate → debate (if needed) → lock.

---

## Invocation Syntax

```
/scope-grill [TICKET_IDS...] [optional context]
```

- **Ticket IDs** — any token matching `[A-Z]+-\d+` (e.g. `KZO-109 KZO-110`) → fetch from Linear before the session
- **Remaining text** — the custom request or topic focus for the grill session

Examples:
- `/scope-grill KZO-109 KZO-110` — grill the scope of two tickets
- `/scope-grill KZO-109 focus on the database schema decisions` — ticket + scoped topic
- `/scope-grill We are considering adding a caching layer` — no tickets, topic only

---

## Phase 0 — Context Gathering

Before asking the first question:

1. **Fetch tickets** — if ticket IDs were provided, fetch each with `mcp__linear__get_issue`. Read the full description, acceptance criteria, and linked issues.
2. **Explore the codebase** — verify claims in the ticket or request against the current code. Read relevant files, check established patterns, identify contradictions.
3. **Read session context** — check `.worklog/` for prior session context relevant to the topic.
4. **Summarize findings** — output 3–5 bullets: what the tickets/request claim, what the codebase confirms, and where you already see contradictions or gaps.

---

## Phase 1 — Scope Interrogation

Interview the user relentlessly. One question at a time. Walk each branch of the decision tree to resolution before moving on.

**You MUST:**
- Challenge anything that contradicts the current codebase design or established patterns — cite file paths or prior decisions as evidence
- Challenge scope not justified by the stated goals
- Press for specifics on vague acceptance criteria ("the user can manage X" → ask: create? edit? delete? all three?)
- State your position and evidence clearly before accepting the user's answer

**Phase 2 triggers — either of:**
1. You and the user disagree after **two full exchange rounds** on the same question → auto-propose a debate team (user must confirm before spawn)
2. The user says "let's debate this", "call the team", or equivalent → immediately propose a debate team

---

## Phase 2 — Debate (delegated to `/debate`)

When a debate is triggered, scope-grill delegates to the standalone `/debate` skill.

### 2a — Write the debate brief

Write a handoff file to `.worklog/scopes/{slug}/debate-brief.md`:

```markdown
# Debate Brief: {topic}
Date: {today's date}

## Contested Question
{the specific question that triggered the debate}

## Context
{codebase findings from Phase 0, ticket data, relevant constraints}

## Positions
- **User:** {their position and reasoning from Phase 1}
- **Interviewer:** {scope-grill's position and reasoning from Phase 1}

## Evidence
{file paths, patterns, prior decisions cited during Phase 1}

## Visual Diagrams
{mermaid or plain-text diagrams if applicable}
```

Where `{slug}` is derived from ticket IDs (e.g. `kzo-109-110`) or a short kebab-case topic name.

### 2b — Spawn the debate

Spawn `/debate` as a subagent via the `Agent` tool, passing the path to the debate brief. The debate skill handles team composition, debate rounds, and note writing.

### 2c — Read the result

After the debate completes, read the result file at `.worklog/scopes/{slug}/debate-result.md`. Extract:
- **Conclusions** — agreed positions per contested question
- **Open items** — anything unresolved
- **Defense statements** — per-round arguments from each participant
- **Visual diagrams** — flow charts, dependency charts if produced
- **Debate note path** — where the full debate note was saved

Carry these forward into Phase 3.

---

## Phase 3 — Scope Lock

When the user says **"scope locked"** (or equivalent):

### 3a — Final scope summary
Print the agreed scope as a numbered checklist — one item per decision made in Phases 1 and 2.

### 3b — Open items
For each open item from the debate note, ask the user:
> "Should I create a Linear ticket for this, or leave it as a note?"

Create linked tickets for any the user confirms.

### 3c — Todo List

Generate a prioritized, actionable todo list from the locked scope. Each item should be a concrete implementation step derived from the agreed decisions.

The todo list serves two use cases:
- **Same-session** (primary): user invokes `/team` immediately — the agent already has full context, the todo is a summary
- **Fresh-start** (fallback): user clears the session and a new agent reads the todo as the sole handoff artifact — the frontmatter and `required_reading` field tell the agent where to find deep context

Structure the todo list as:

```markdown
---
slug: {slug}
source: scope-grill
created: {today's date}
tickets: [{ticket IDs, if any}]
required_reading: [{path to debate note, if one was written}]
superseded_by: null
---

# Todo: {topic or ticket IDs}

> **For agents starting a fresh session:** read all files listed in `required_reading` above before starting implementation.

## Implementation Steps
- [ ] {step 1 — derived from decision N}
- [ ] {step 2 — derived from decision N}
...

## Open Items
- [ ] {any unresolved items carried forward}

## References
- Scope debate note: {path, if one was written}
- Linear tickets: {ticket IDs, if any}
```

**Superseding old todos:** If a previous todo exists at the same path for the same slug, write `superseded_by: {new-todo-path}` into the old todo's frontmatter after writing the new one. This prevents fresh-start agents from acting on stale decisions.

Ask the user where to save the todo list. Present these options, leading with the suggested option:

- **Suggested** (default) — infer the most relevant path from context (e.g. if tickets are involved, `docs/notes/`; if session-scoped, `.worklog/`)
- **Option A** — `docs/notes/{slug}/scope-todo-{YYYYMMDDHHmm}-{short-desc}.md` (version-controlled, visible to the team — **durable:** persists across sessions, frozen after merge)
- **Option B** — `.worklog/scopes/{slug}/scope-todo.md` (cross-agent handoff surface — **ephemeral:** may be cleaned up between sessions)
- **Custom** — path the user specifies

Where `{slug}` is derived from ticket IDs (e.g. `kzo-109-110`) or a short kebab-case topic name — matching the slug used for the debate note if one was written.

**Tip:** Remind the user of the lifecycle difference: `docs/notes/` is version-controlled and permanent; `.worklog/` is gitignored and ephemeral.

### 3d — Linear write-back
For each ticket ID provided at invocation:

1. **Append** a `## Locked Scope` section to the ticket description with:
   - Agreed decisions as bullet points
   - Explicit out-of-scope items
   - Link to the debate note if one was written
   - Link to the todo list

2. **Add a comment** on the ticket summarising the session outcome (decisions reached, questions debated, open items created).

Confirm to the user: *"Scope locked and written back to [TICKET-IDs]."*

---

## Guardrails

- **Never skip Phase 0** — grilling without codebase context produces shallow challenges
- **One question at a time** in Phase 1 — sequential resolution builds shared understanding; do not batch questions
- **Never lock scope unilaterally** — wait for the explicit user signal
- **Debate is never mandatory** — many sessions resolve entirely in Phase 1; Phase 2 only triggers when genuinely needed
- **Never overwrite existing `## Locked Scope` sections** — append a dated revision block instead
