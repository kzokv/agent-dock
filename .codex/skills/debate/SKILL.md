---
name: debate
description: Structured multi-role debate on a contested technical question. Spawns a team of domain-expert agents that argue via SendMessage, coordinated by a Moderator agent. Produces a debate note with conclusions, defense statements, and visual diagrams. Usable standalone or delegated from other skills (e.g. /scope-grill).
---

# Debate

A structured, adversarial debate session with domain-expert agents. Resolves contested technical questions through evidence-based argumentation. Each debater runs as a real agent in a team, communicating via `SendMessage`.

---

## Invocation Syntax

```
/debate [--rounds N] "contested question or topic"
/debate end | close
```

- **Question** — the contested question or topic to debate
- **`--rounds N`** — optional: force N rounds of debate before seeking consensus (default: consensus at 2-of-N convergence, escalate to user after one full round)
- **`end` / `close`** — terminate a multi-question session and dismiss the team

Examples:
- `/debate "Should we use Redis or Memcached for the session cache?"`
- `/debate --rounds 3 "Monolith vs microservices for the billing domain"`
- `/debate end` — dismiss the team and end the session

---

## Entry Modes

### Direct mode (standalone)

The user invokes `/debate` directly. The skill runs its own context gathering before assembling the team.

### Delegated mode (from another skill)

A parent skill (e.g. `/scope-grill`) writes a **debate brief** to `.worklog/{slug}-debate-brief.md` and spawns `/debate` as a subagent. The skill reads the brief file as its starting context instead of gathering its own.

---

## Phase 0 — Context Gathering

### Direct mode

Before assembling the team:

1. **Explore the codebase** — read files relevant to the contested question, check established patterns, identify constraints
2. **Read session context** — check `.worklog/` for prior session context relevant to the topic
3. **Summarize findings** — output 3-5 bullets: what the codebase shows, relevant constraints, and initial tension points

### Delegated mode

Read the debate brief from the path provided in the spawn prompt. The brief contains:

```markdown
# Debate Brief: {topic}
Date: {date}

## Contested Question
{the specific question}

## Context
{codebase findings, ticket data}

## Positions
- **User:** {their position and reasoning}
- **Interviewer:** {the caller's position and reasoning}

## Evidence
{file paths, patterns, prior decisions cited}

## Visual Diagrams
{mermaid or plain-text diagrams if applicable}
```

The Moderator reads this brief to frame the debate — no additional context gathering needed.

---

## Phase 1 — Team Composition

Infer the team size from the topic signals before proposing. Apply in order:

| Signal in question or topic | Action |
|---|---|
| Auth, permissions, data privacy, security | Add `/senior-security` to squad |
| Acceptance criteria, CI, test coverage, QA gates | Add `/senior-qa` to squad |
| Deep specialization (database, infra, ML, etc.) | Add the matching specialist skill |
| No special signals | Minimal Trio only |

**Sizes:**
- **Minimal Trio** (default): Architect (`/senior-architect`) + Backend (`/senior-backend`) + Frontend (`/senior-frontend`)
- **Full Squad**: Minimal Trio + Security (`/senior-security`) + QA (`/senior-qa`)
- **Custom**: any combination the user specifies

Each engineering role **loads their corresponding skill** to inform their position. The Moderator is a **non-voting plain role** — their job is process management and diagram synthesis only.

**At debate proposal time**, present:
- The contested question
- The inferred team size and roles with rationale
- Option to override roles before spawning

Wait for user confirmation before spawning.

---

## Phase 2 — Team Spawn

### Step 1 — Create the team

```
TeamCreate({
  team_name: "debate-{slug}",
  description: "Debate team for: {contested question summary}"
})
```

### Step 2 — Initialize state

1. Create `.worklog/debate/` directory if it doesn't exist
2. Write `.worklog/debate/state.json` with:
   - Contested question(s)
   - Team composition (roles and skills)
   - `round: 1`, `phase: "init"`
   - `max_rounds`: value of `--rounds N` or `null` (default consensus mode)
   - `debaters`: empty object (populated as agents are spawned)
3. If a debate brief exists, copy its path into `state.json` as `brief_path`

### Step 3 — Spawn the Moderator

The Moderator is the ONLY agent spawned by the main session directly. All debaters are spawned via `[SPAWN]` relay from the Moderator.

```
Agent({
  name: "moderator",
  team_name: "debate-{slug}",
  model: "opus",
  mode: "bypassPermissions",
  prompt: "... full Moderator prompt ..."
})
```

**The Moderator's spawn prompt MUST include:**
1. The contested question and context (or path to debate brief)
2. The approved team composition (roles, skills, names)
3. Path to `.worklog/debate/state.json`
4. Instructions to send `[SPAWN]` to main session to request debater agents
5. The message prefix convention (see Message Protocol below)
6. The debate rules (round management, consensus detection)
7. Instructions to read the debate brief if in delegated mode
8. Spawn ALL agents with `mode: "bypassPermissions"`

### Step 4 — Enter relay loop

Once the Moderator is spawned, the main session enters its relay loop:

```
1. Receive message from Moderator
2. Classify by prefix:
   [STATUS]      → summarize and display to user
   [ESCALATE]    → display with context, collect user response, relay as [USER]
   [SPAWN]       → parse roster, spawn debaters via Agent tool, confirm back
   [SHUTDOWN]    → display debate summary, exit loop
   [HEARTBEAT]   → reset timeout counter, do not display
3. Receive message from user (unprompted)
   → Relay to Moderator via [USER] prefix
4. If 10 minutes with no Moderator message → alert user
5. Repeat until [SHUTDOWN]
```

### Handling [SPAWN] requests

The Moderator sends a `[SPAWN]` message with:

```
[SPAWN]
debaters:
  - name: "architect"
    model: "opus"
    skill: "/senior-architect"
    role: "Architect"
  - name: "backend"
    model: "opus"
    skill: "/senior-backend"
    role: "Backend Engineer"
  - name: "frontend"
    model: "sonnet"
    skill: "/senior-frontend"
    role: "Frontend Engineer"
```

The main session:
1. Spawns all debaters in a SINGLE message (parallel) using the `Agent` tool with `team_name`, `name`, and `mode: "bypassPermissions"`
2. Each debater's prompt includes:
   - Their role and the skill to load for domain expertise
   - The contested question and context
   - The team name and names of all other debaters + moderator
   - The debate rules (evidence-based arguments, position tracking)
   - The message protocol for communicating with the Moderator and other debaters
3. Confirms back to Moderator: `Spawned: [list of debater names].`

---

## Phase 3 — Debate Rounds

### Message Protocol

Agents communicate via `SendMessage` within the team:

**Moderator → Debater:**
- `[ROUND N] {question or prompt for this round}` — signal a new round, provide the question
- `[RESPOND-TO: {debater-name}] {summary of argument to respond to}` — direct a debater to counter another's argument
- `[FINAL-CALL]` — request final position statement

**Debater → Moderator:**
- `[POSITION] {named position and rationale}` — opening or updated position
- `[DEFENSE] {counter-argument with evidence}` — response to another debater's argument
- `[CONCEDE: {point}] {reason}` — explicitly conceding a point with explanation
- `[UPDATE] {new position} {why changed}` — position update after hearing arguments

**Debater → Debater:**
- `[CHALLENGE: {debater-name}] {counter-argument}` — direct challenge to another debater
- `[AGREE: {debater-name}] {point of agreement}` — signal convergence

**Moderator → Main Session:**
- `[STATUS] Round {N} complete. {summary of positions}`
- `[ESCALATE] No consensus after {N} rounds. Positions: {summary}. User decision needed.`
- `[SHUTDOWN] {final report with conclusions, defense statements, diagrams}`

### Debate flow

1. **Moderator** sends `[ROUND 1]` to all debaters with the contested question
2. Each **debater** reads relevant codebase files informed by their loaded skill, then sends `[POSITION]` to the Moderator
3. **Moderator** shares all positions and directs debaters to respond to each other's arguments
4. **Debaters** exchange `[CHALLENGE]`, `[AGREE]`, `[DEFENSE]` messages with each other, copying the Moderator
5. **Moderator** tracks convergence:
   - If **2 of N debaters** agree → declares consensus
   - If no consensus after a full round → starts next round or escalates to user
6. With `--rounds N`: Moderator forces N full rounds before seeking consensus
7. **Moderator** sends `[STATUS]` to main session after each round

### Participant rules

Each debater **must**:
- Open with a named position and rationale grounded in their loaded skill's domain expertise
- Respond to counter-arguments with evidence, not assertion
- Not concede a point without a counter-argument that addresses the original objection
- Explicitly flag when they update their position via `[UPDATE]` and state why
- Read relevant codebase files to ground arguments in the actual code

### Moderator rules

The **Moderator**:
- Manages round progression and turn order
- Ensures every debater responds to every other debater's key arguments
- Flags when two or more debaters converge via `[AGREE]` messages
- Declares consensus when **2 of N debaters** agree on a position
- If no consensus after a full round → sends `[ESCALATE]` to main session for user decision
- Synthesizes visual diagrams (Mermaid primary, plain-text secondary) when the topic involves flow charts, dependency charts, or architectural decisions
- Updates `.worklog/debate/state.json` after each round (sole writer)

### Multi-question sessions

The **team stays alive** across all contested questions in the session. When one question resolves, the Moderator sends `[STATUS]` with the conclusion and waits for the next question from the user (relayed via `[USER]`).

To end a multi-question session, the user invokes `/debate end` or `/debate close`. The main session relays this as `[USER] end session` to the Moderator, who sends `[SHUTDOWN]`.

---

## Phase 4 — Debate Note

The Moderator writes the debate note before sending `[SHUTDOWN]`. Before writing, the Moderator sends `[ESCALATE] Where should I save the debate note?` to the main session, which presents the location options to the user.

### Location strategy

Present these options, leading with the suggested option:

- **Suggested** (default) — infer the most relevant path from context (e.g. if tickets are involved, `docs/notes/`; if session-scoped, `.worklog/`)
- **Option A** — `docs/notes/{slug}/debate-{YYYYMMDDHHmm}-{short-desc}.md` (version-controlled, visible to the team — **durable:** persists across sessions, frozen after merge)
- **Option B** — `.worklog/debate/{slug}-debate.md` (cross-agent handoff surface — **ephemeral:** may be cleaned up between sessions)
- **Custom** — path the user specifies

Where `{slug}` is derived from ticket IDs (e.g. `kzo-109-110`) or a short kebab-case topic name.

**Tip:** Remind the user of the lifecycle difference: `docs/notes/` is version-controlled and permanent; `.worklog/` is gitignored and ephemeral.

### Note structure

```markdown
---
slug: {slug}
source: debate
created: {today's date}
tickets: [{ticket IDs, if any}]
superseded_by: null
---

# Debate: {topic or ticket IDs}

## Contested Questions
- {list of questions debated}

## Team Composition
| Role | Skill Loaded | Agent Name |
|------|-------------|------------|
| Moderator | (plain role) | moderator |
| Architect | /senior-architect | architect |
| Backend Engineer | /senior-backend | backend |
| ... | ... | ... |

## Exchange
### Round {N}
#### {Agent Name} — {Role}
**Position:** {named position}
**Defense:** {rationale and evidence}
**Updated position (if any):** {new position and why}

{repeat for each debater, each round}

## Visual Diagrams
{Mermaid diagrams (primary) or plain-text diagrams (secondary) synthesized by the Moderator — flow charts, dependency charts, architectural diagrams as applicable}

## Conclusions
{one conclusion per contested question — the agreed position}

## Open Items
{anything escalated to user or still unresolved}
```

Debate notes are **append-only** — if a follow-up session revisits the same topic, create a new dated note rather than overwriting.

**Superseding old debate notes:** If a previous debate note exists for the same slug, write `superseded_by: {new-note-path}` into the old note's frontmatter after writing the new one. This prevents agents from acting on stale decisions.

---

## Phase 5 — Result File (delegated mode only)

When invoked by a parent skill, the Moderator also writes a structured result file to `.worklog/{slug}-debate-result.md` before sending `[SHUTDOWN]`:

```markdown
# Debate Result: {topic}
Date: {today's date}

## Conclusions
{one conclusion per contested question — the agreed position}

## Open Items
{anything escalated to user or still unresolved}

## Defense Statements
### Round {N}
#### {Agent Name} — {Role}
**Position:** {named position}
**Defense:** {rationale and evidence}
{repeat for each debater, each round}

## Visual Diagrams
{Mermaid or plain-text diagrams synthesized by the Moderator}

## Debate Note Path
{path to the debate note written in Phase 4}
```

---

## Guardrails

- **Never skip context gathering** — in direct mode, always explore the codebase first; in delegated mode, always read the brief
- **Never spawn without user confirmation** — always present the proposed team and wait for approval
- **Debaters are real agents** — each runs as a separate agent in the team, communicating via `SendMessage`; never role-play debates in the main session
- **Diagrams are the Moderator's job** — debaters argue with evidence; the Moderator synthesizes visual artifacts
- **Never overwrite existing debate notes** — create a new dated note instead
- **Team dismissal requires explicit signal** — only `/debate end` or `/debate close` shuts down a multi-question session
- **Moderator is sole writer to `.worklog/debate/state.json`** — no lock protocol needed
