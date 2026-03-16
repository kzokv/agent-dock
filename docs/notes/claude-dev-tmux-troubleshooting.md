# Troubleshooting launcher tmux sessions

Applies to both `claude-dev` and `codex-net`. Both launchers share the same tmux and worktree scaffold.

## Quick checks

Verify the launcher created the session:

```bash
tmux list-sessions
```

Expected: a `claude-work` session (or `codex-work`, or the name set via the `--session` flag / env var).

Verify agent team panes exist while a team is active (Claude only):

```bash
tmux list-panes -t claude-work
```

If only 1 pane is listed, agents are running in-process, not as split panes.

## Common issues

### No tmux session created

**Symptom:** `tmux list-sessions` shows no session after running the launcher.

**Cause 1:** Running from a non-interactive context (e.g., a script or non-tty stdin). The launcher detects `[[ -t 0 ]]` to decide whether to show prompts — if stdin is not a terminal the tmux prompt is skipped and tmux is still used, but the session name defaults silently.

**Cause 2:** Prior to the switch-client fix, running from inside an existing tmux session skipped session creation. Now the launcher handles three scenarios:

| Scenario | Behavior |
|---|---|
| Not in tmux | `tmux new-session -A -s <session>` |
| In tmux, different session | Create session detached, `tmux switch-client` to it |
| In tmux, already in target session | Exec CLI directly |

Check that the launcher is current (rerun onboarding or inspect):

```bash
which claude-dev && grep 'switch-client' "$(which claude-dev)"
which codex-net  && grep 'switch-client' "$(which codex-net)"
```

### Stale binary shadowing the installed launcher

**Symptom:** `bash: /opt/homebrew/bin/codex-net: No such file or directory` (or wrong version runs).

**Cause:** An old launcher was installed to `/opt/homebrew/bin` before `~/.local/bin` was in PATH. Bash caches PATH lookups.

**Fix:**

```bash
hash -d codex-net   # or: hash -d claude-dev
which codex-net     # should now show ~/.local/bin/codex-net
```

Both launchers are always installed to `~/.local/bin` (or `~/bin` / `$XDG_BIN_HOME` if in PATH). They are never written to `/opt/homebrew/bin` or `/usr/local/bin`.

### Interactive prompts not appearing

**Symptom:** Launcher goes straight to tmux without showing the session or worktree prompts.

**Cause:** `_interactive()` requires both `[[ -t 0 ]]` (stdin is a tty) and no CLI args passed. When args are present or stdin is piped, prompts are suppressed.

Test without tmux to isolate:

```bash
claude-dev --no-tmux
codex-net  --no-tmux
```

### Agent panes not appearing (Claude only)

**Symptom:** Claude launches inside `claude-work` but agent teammates don't get split panes.

**Check settings:**

```bash
cat ~/.claude/settings.json | grep -E 'teammateMode|tmuxSplitPanes'
```

Expected: `"teammateMode": "auto"` and `"tmuxSplitPanes": true`.

**Check tmux detection from Claude's perspective:** Claude Code reads `$TMUX` at startup. If the variable is set, split-pane mode activates. Confirm:

```bash
tmux show-environment TMUX
```

### Navigating panes

Standard tmux bindings apply inside any launcher session:

- `Ctrl+B` then arrow keys — move between panes
- `Ctrl+B` then `q` — show pane numbers
- `Ctrl+B` then `z` — zoom/unzoom current pane
- `Ctrl+B` then `s` — switch between sessions (to return to your original session)

### Stale session from previous run

If the session exists from a prior run, the launcher reuses it (`-A` flag outside tmux, or `has-session` check inside tmux). To force a fresh session:

```bash
tmux kill-session -t claude-work   # or codex-work
claude-dev
```

## Bypassing tmux

```bash
claude-dev --no-tmux                             # direct exec, no tmux
CLAUDE_DEV_TMUX_SESSION=alt claude-dev           # different session name

codex-net --no-tmux                              # direct exec, no tmux
CODEX_NET_TMUX_SESSION=alt codex-net             # different session name
```

## Worktree selection

Both launchers scan `<git-root>/.worktrees/` for existing worktrees and offer to create new ones. To bypass the picker:

```bash
claude-dev --worktree feature-x                  # use/create .worktrees/feature-x
codex-net  --worktree /absolute/path/to/wt       # use/create at absolute path
```

Post-create hooks run automatically when a new worktree is created (see `docs/onboarding.md` — Post-create hook).
