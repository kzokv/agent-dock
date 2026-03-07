# codex-home

User-level Codex home shared across machines. This repo packages global agent policy, reusable skills, onboarding automation, and PR hygiene checks.

`AGENTS.md` is the canonical policy source. `README.md` is the operator guide.

## What this repo contains

Tracked:

- `AGENTS.md`
- `agents/`
- `agents/skills/`
- `agents-config/`
- `automations/`
- `.platforms/cursor/agents/` — Cursor IDE agent definitions (e.g., `codex-role-loader.md`), installed to `~/.cursor/agents` by onboarding
- `scripts/`
- `config.base.toml`

Not tracked:

- secrets
- machine-local runtime state
- caches
- generated runtime config (`config.toml`)
- machine-local config (`config.local.toml`)

## Quick start

Link this repo to `~/.codex`:

```bash
./scripts/onboarding.sh
```

Use a custom Codex home target:

```bash
./scripts/onboarding.sh /path/to/codex-home
```

If you want to use `gh` from Codex agent sessions, run onboarding so it validates GitHub CLI auth and installs the
Codex CLI plus the network-enabled helper, then launch the helper instead of typing the full `codex --sandbox …` command:

```bash
./scripts/onboarding.sh
codex-net
```

Onboarding installs `codex-net` in `$XDG_BIN_HOME` when set. Otherwise it defaults to `~/bin` on macOS and
`~/.local/bin` on other platforms, and warns if that directory is not on your `PATH`.

If `codex` is missing, onboarding installs it with `npm install -g @openai/codex` before writing the launcher.

## Onboarding behavior

`./scripts/onboarding.sh` will:

- back up an existing target path (`~/.codex` by default) before creating the symlink
- migrate legacy user skills from `~/.codex/skills` to `~/.codex/agents/skills` (one time)
- maintain `$HOME/.agents/skills -> ~/.codex/agents/skills`
- populate `$HOME/.claude/skills` with per-skill symlinks that reference `$HOME/.agents/skills` so Claude-based helpers can discover the same skills
- upsert machine-local trust for this repo by rewriting only its `[projects."…"]` block in `config.local.toml`
- regenerate `config.toml` from `config.base.toml` + `config.local.toml`
- copy the Codex role-loader agent into `~/.cursor/agents` (or `--cursor-home` override) so Cursor can load role profiles from `~/.codex/agents`
- verify GitHub CLI auth and run `gh auth login -h github.com` when needed so agent sessions can re-use the tracker login state
- install the Codex CLI with `npm install -g @openai/codex` when `codex` is not already available
- install a `codex-net` launcher (in `$XDG_BIN_HOME`, or by default `~/bin` on macOS and `~/.local/bin` elsewhere) so you can start network-enabled sessions without manually typing the sandbox flags
- fail fast with non-zero exit when `config.base.toml` is missing

Re-running onboarding is idempotent and preserves unrelated local config.

Use `--skip-gh-auth` to skip GitHub auth (for CI or non-interactive contexts). Use `--cursor-home PATH` to install the role-loader to a custom Cursor directory (default: `~/.cursor`).
`--cursor-home` accepts any writable path, so run onboarding as the target user and avoid privileged system paths unless explicitly intended.

```bash
./scripts/onboarding.sh --skip-gh-auth
./scripts/onboarding.sh --cursor-home /path/to/cursor
```

## Config model

- `config.base.toml`: tracked shared defaults
- `config.local.toml`: machine-local, ignored
- `config.toml`: generated runtime config, ignored

Do not edit `config.toml` directly. Update `config.base.toml` and/or `config.local.toml`, then rerun onboarding.

## Skills model

- System skills: built-in Codex capabilities
- User-level versioned source: `~/.codex/agents/skills`
- User-level discovery path: `$HOME/.agents/skills`
- This repo must not define `.agents/skills`
- Other repos may define `<repo>/.agents/skills` for project-specific workflows

## Validation and maintenance

Validate onboarding behavior:

```bash
./scripts/test-onboarding.sh
```

Validate role/skill topology and policy hygiene (RACI table, skill metadata checks, and repo-level skill policy):

```bash
./scripts/validate-role-skill-topology.py
```

Check config migration hygiene:

```bash
./scripts/check-config-migration.sh
```

Install required skills:

```bash
./scripts/install-required-skills.sh
```

Enable local commit-msg hook:

```bash
./scripts/setup-git-hooks.sh
```

## Policy and merge gates

Policy source of truth: `AGENTS.md`
Operator source of truth: `docs/git-pr-flow.md`

Key enforced areas:

- agent/skill invocation contract
- required Git/PR gate (`type(scope): subject` for commits and PR titles, required sections, content-matched primary label, assignee, relevant tests)
- governance blockers (`architect` + applicable domain reviewers)

Repo enforcement points:

- PR template: `.github/pull_request_template.md`
- PR gate workflow: `.github/workflows/pr-gate.yml`
- local hook bootstrap: `./scripts/setup-git-hooks.sh`

For day-to-day Git/PR workflow steps, examples, and troubleshooting, use `docs/git-pr-flow.md`.
