# Worktree Post-Create Hook

Before `EnterWorktree`, pull the development branch to latest. After `EnterWorktree` succeeds and a new worktree is created, rebase to the project's development branch, then run the post-create hook.

**Steps:**

0. **Pull the development branch to latest (before worktree creation).** From the main repo root, run `git pull` on the development branch (e.g. `dev`) so the worktree starts from the most recent remote state. Stale local branches cause merge conflicts and missing code later.

1. **Rebase to development branch.** `EnterWorktree` creates from HEAD which may resolve to `main` instead of the active development branch. Check if the worktree landed on the wrong base by comparing with the branch the user was working on (usually visible in the session's git status). If it did, run `git reset --hard {correct_branch}` before proceeding.

2. Determine the main repo root:
   ```bash
   git worktree list --porcelain | head -1 | sed 's/^worktree //'
   ```

3. Check if `{main_root}/.hooks/post-worktree-create.sh` exists

4. If it exists, run it with these environment variables:
   ```bash
   WORKTREE_PATH="$(pwd)" MAIN_ROOT="{main_root}" bash "{main_root}/.hooks/post-worktree-create.sh" < /dev/null
   ```
   Pipe `/dev/null` to stdin so interactive prompts are skipped.

**Why:** `claude-dev` and `codex-net` (the tmux launchers) run this hook automatically on worktree creation. `EnterWorktree` does not. Without the hook, worktrees are missing env files, node_modules, and built artifacts — they're unusable until manually set up. The rebase step was added because `EnterWorktree` can pick `main` as the base even when the user's active branch is `dev`.

**How to apply:** Every time `EnterWorktree` creates a new worktree (not when entering an existing one). The hook is project-specific (lives in `.hooks/`), so projects without it are unaffected.
