# Troubleshooting claude-dev tmux sessions

## Quick checks

Verify `claude-dev` created the session:

```bash
tmux list-sessions
```

Expected: a `claude-work` session (or the name set via `CLAUDE_DEV_TMUX_SESSION`).

Verify agent team panes exist while a team is active:

```bash
tmux list-panes -t claude-work
```

If only 1 pane is listed, agents are running in-process, not as split panes.

## Common issues

### No tmux session created

**Symptom:** `tmux list-sessions` shows no `claude-work` session after running `claude-dev`.

**Cause:** Prior to the switch-client fix, running `claude-dev` from inside an existing tmux session (`$TMUX` set) skipped session creation entirely and exec'd Claude directly.

**Fix:** The launcher now handles three in-tmux cases:

| Scenario | Behavior |
|---|---|
| In tmux, already in `claude-work` | Exec Claude directly in the current session |
| In tmux, different session | Create `claude-work` detached, then `tmux switch-client` to it |
| Not in tmux | `tmux new-session -A -s claude-work` |

If you're still not seeing a session, check that `claude-dev` was regenerated after the fix (rerun onboarding or inspect the launcher):

```bash
which claude-dev
cat "$(which claude-dev)" | grep 'switch-client'
```

### Agent panes not appearing

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

Standard tmux bindings apply inside the `claude-work` session:

- `Ctrl+B` then arrow keys -- move between panes
- `Ctrl+B` then `q` -- show pane numbers
- `Ctrl+B` then `z` -- zoom/unzoom current pane
- `Ctrl+B` then `s` -- switch between sessions (to return to your original session)

### Stale session from previous run

If `claude-work` exists from a prior run, `claude-dev` reuses it (via `-A` flag outside tmux, or `has-session` check inside tmux). To force a fresh session:

```bash
tmux kill-session -t claude-work
claude-dev
```

## Bypassing tmux

```bash
claude-dev --no-tmux                             # direct exec, no tmux
CLAUDE_DEV_TMUX_SESSION=alt claude-dev           # different session name
```
