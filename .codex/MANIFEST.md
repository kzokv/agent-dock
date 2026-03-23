# Agent Dock — Canonical Agent Manifest

You are configured by **agent-dock**, a shared policy and skills monorepo.
Your global policies, skills, prompts, and behavioral rules originate from this repository.

To find where this repo lives on disk, read `~/.codex/ORIGIN`. That file contains the
absolute path to the agent-dock repository root.

---

## Repo Structure

```
.codex/              Shared policy, roles, prompts, skills, config, and scripts
  AGENTS.md          Global policy defaults (tone, depth, skills invocation)
  MANIFEST.md        This file — canonical agent-readable manifest
  config.base.toml   Shared base config (merged during onboarding)
  agents/            Role definitions, TOML configs, team charter
  prompts/           Decision, retrieval, curation, and handoff flows
  scripts/           Onboarding, validation, and maintenance scripts
  skills/            Shared skill library (symlinked to ~/.codex/skills)
  runbooks/          Operational runbooks

.claude/             Claude Code agent home
  CLAUDE.md          Claude-specific instructions (references this manifest)
  rules/             Scoped behavioral rules
  memory/            Version-controlled auto-memory
  settings.base.json Base settings (merged into ~/.claude/settings.json)
  scripts/           Claude-specific onboarding

.cursor/             Cursor agent home
  agents/            Symlink to .codex/agents
  skills/            Symlink to .codex/skills

scripts/             Root onboarding orchestrator and shared helpers
docs/                Onboarding reference, git-pr-flow runbook, prompt compatibility
notes/               Frozen knowledge snapshots
```

---

## Skills Catalog

74 skills organized by domain, available at `~/.codex/skills/` (symlinked from `~/.agents/skills/`):

**Architecture & Design:**
agent-designer, agent-workflow-designer, api-design-reviewer, database-designer,
database-schema-designer, improve-codebase-architecture, senior-architect,
ui-design-system, ux-researcher-designer

**Development & Engineering:**
code-reviewer, pr-review-expert, senior-backend, senior-frontend, senior-fullstack,
tdd, tdd-guide, script-automation, performance-profiler, epic-design

**DevOps & Infrastructure:**
aws-solution-architect, ci-cd-pipeline-builder, docker-development, helm-chart-builder,
senior-devops, terraform-patterns, env-secrets-manager, observability-designer

**Data & AI/ML:**
rag-architect, senior-data-engineer, senior-data-scientist, senior-ml-engineer,
senior-computer-vision, senior-prompt-engineer

**Security:**
senior-security, senior-secops, skill-security-auditor

**QA & Testing:**
senior-qa, api-test-suite-builder, playwright-pro, skill-tester

**Product & Planning:**
grill-me, write-a-prd, prd-to-issues, interview-system-designer, tech-debt-tracker,
tech-stack-evaluator, dependency-auditor

**Documentation & Knowledge:**
doc-coauthoring, technical-writing, knowledge-curator, codebase-onboarding,
changelog-generator, release-manager, runbook-generator

**Integration & Tools:**
linear, stripe-integration-expert, google-workspace-cli, ms365-tenant-manager,
openai-docs, mcp-server-builder, email-template-builder

**Agent Infrastructure:**
team, self-improving-agent, si-extract, si-promote, si-remember, si-review, si-status,
autoresearch-agent, git-worktree-manager, monorepo-navigator, migration-architect,
incident-commander, using-superpowers

---

## Policy Summary

### Behavioral defaults (from `.codex/AGENTS.md`)
- Tone: pragmatic and concise
- Inspect minimum relevant context before acting
- Execute clear, low-risk tasks end to end when user intent is clear
- Use tools or skills only when they materially improve correctness, speed, or completeness
- Verify with the smallest relevant check; separate verified facts from inference

### Git workflow (from `docs/git-pr-flow.md`)
- Commit format: `type(scope): subject` — types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- PR metadata: assignee, primary labels (bug/enhancement/documentation), body with Problem/Solution/Testing/Risk sections
- Testing contract: evidence path (command + outcome) OR waiver path (reason + approver)
- CI gate: `.github/workflows/pr-gate.yml` validates commits, assignee, labels, and testing evidence

### Knowledge curation
- Auto-memory: `.claude/memory/MEMORY.md` (version-controlled)
- Promotion workflow: `/si:review` → `/si:promote` → durable destinations
- Destinations: `.claude/CLAUDE.md`, `.claude/rules/`, `docs/notes/`, `docs/adr/`

---

## Onboarding

The symlink mechanism works as follows:

1. Run `./scripts/onboarding.sh` (supports `--agent codex|cursor|claude|all`)
2. Onboarding creates symlinks:
   - `~/.codex` → `<repo>/.codex`
   - `~/.claude` → `<repo>/.claude`
   - `~/.cursor` agents/skills → `<repo>/.codex/` equivalents
   - `~/.agents/skills` → `~/.codex/skills`
3. Onboarding writes `~/.codex/ORIGIN` with the repo path (provenance pointer)
4. Each agent tool reads its home directory at runtime, inheriting policies and skills

To fork and customize:
1. Fork this repo
2. Edit policies in `.codex/AGENTS.md`, skills in `.codex/skills/`, rules in `.claude/rules/`
3. Run `./scripts/onboarding.sh` to wire your fork as the new source of truth

Full reference: `docs/onboarding.md`

---

## Per-Tool Notes

### Claude Code
- Reads `~/.claude/CLAUDE.md` for global instructions
- Reads `~/.claude/rules/*.md` for scoped behavioral rules
- Reads `~/.claude/settings.json` (merged from `settings.base.json` during onboarding)
- Memory at `~/.claude/memory/MEMORY.md`
- Entry point references this manifest via preamble in `CLAUDE.md`

### Cursor
- Reads `~/.cursor/agents/` for agent definitions (symlinked to `.codex/agents`)
- Reads `~/.cursor/skills/` for skills (symlinked to `.codex/skills`)
- Entry point references this manifest via agent preamble

### Codex (OpenAI)
- Reads `.codex/AGENTS.md` for policy defaults
- Reads `.codex/config.toml` (generated from `config.base.toml` + `config.local.toml`)
- Agent role configs at `.codex/agents/config/*.toml`
- Entry point references this manifest via `AGENTS.md` preamble

### Adding a new agent tool
1. Create `.<tool>/` directory in the repo with tool-specific config
2. Add a `.<tool>/scripts/onboarding.sh` for tool-specific wiring
3. Register it in `scripts/onboarding.sh` (agent selection and dispatch)
4. Add a shim that references `~/.codex/MANIFEST.md` in the tool's entry point
