# laptop/

One-time machine setup. Claude-adjacent tooling only — not general dotfiles.

These are the working files, copied from a machine that runs them. Read
[laptop-setup.md](../laptop-setup.md) for why each exists; this directory is
what you actually install.

| File | Install to | What it does |
|---|---|---|
| `wt.zsh` | `~/.config/zsh/wt.zsh`, sourced from `~/.zshrc` | `wt <name>` creates a git worktree in an adjacent `<repo>-worktrees/` dir, based on the fresh remote default branch, copies `.env*` files and top-level `.claude/`, and opens it in your editor |
| `statusline-command.sh` | `~/.claude/statusline-command.sh` | Claude Code status line: context use, session cost, model |
| `gitconfig-aliases` | append to `~/.gitconfig`, or `include.path` it | 14 git aliases, worktree-aware branch cleanup being the useful one |

## Install

```sh
mkdir -p ~/.config/zsh ~/.claude
cp wt.zsh ~/.config/zsh/wt.zsh
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh

# in ~/.zshrc
source ~/.config/zsh/wt.zsh

# git aliases — keep them in their own file and include it
git config --global include.path "$(pwd)/gitconfig-aliases"
```

Wire the status line into `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

## Assumptions worth knowing

**`origin/HEAD` must be set.** Both `wt.zsh` and the git aliases resolve the
default branch from it rather than assuming `master` or `main`. A clone that
lacks it falls back to `master`, which may be wrong. Fix it once per clone:

```sh
git remote set-head origin --auto
```

**`wt.zsh` opens `cursor`.** Change the `cursor -n` line for a different
editor; it warns and prints the path if the CLI isn't installed.

**`wt.zsh` copies `.env*` and `.claude/` into the worktree.** That is the
point — a worktree without them can't run — but it means secrets land in a
second location on disk. It prunes `node_modules`, `.git`, and `.next` so it
doesn't drag dependency fixtures along.

**`bdone` deletes branches.** It skips anything held by a worktree, refuses to
recreate a branch with unpushed commits or a dirty tree, and uses `git branch
-d` (safe) for merged branches — but it does use `-D` on branches whose
upstream is gone and on closed `pr-<N>` branches. Read it before you run it.
It needs `gh` for the PR-state check.
