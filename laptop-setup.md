# Laptop Setup (One-Time)

One-time machine configuration for Claude Code workflows. Run these once per laptop, not per project.

---

## 1. Git Worktrees

Worktrees enable running multiple Claude instances on overlapping work without conflicts.

**Basic worktree creation:**
```bash
git worktree add ../feature-branch feature-branch
# Run separate Claude instance in each worktree
```

**Fast worktree function (recommended):**

Since worktrees don't include gitignored files, use a shell function that:
1. Creates the worktree with a new branch, from the fresh remote default branch
2. Copies all `.env` files (including in subdirectories)
3. Copies the top-level `.claude/` folder
4. Opens the new worktree in your editor

The function is [`laptop/wt.zsh`](laptop/wt.zsh) — copy that file rather than retyping it.

It resolves the repo's default branch from `origin/HEAD` and bases the new
worktree on the freshly fetched remote tip, so a worktree never starts from a
stale local branch. See [laptop/README.md](laptop/README.md) for install steps
and the assumptions it makes.

**Key features:**
- Creates worktrees in `project-worktrees/` adjacent to your project
- Recursively finds and copies all `.env*` files
- Copies `.claude/` so your Claude config travels with the worktree
- Opens directly in your editor

### Git aliases

[`laptop/gitconfig-aliases`](laptop/gitconfig-aliases) carries 14 aliases; the
one that matters for this workflow is `bdone`.

Running agents in parallel worktrees breaks ordinary branch cleanup, because
the usual "delete merged branches" one-liner tries to delete branches another
worktree has checked out. `bdone` skips anything a worktree holds, then prunes
stale worktrees, deletes branches whose upstream is gone, deletes branches
merged into the default, and closes out `pr-<N>` branches whose PR is merged or
closed.

It refuses to act when the tree is dirty or a branch has unpushed commits.
Read it before running it — it does use `git branch -D` in two of those cases.

---

## 2. Custom Status Line

The statusline replaces Claude Code's default with a single line showing git state, model, context budget, and running cost. The context bar is the part that earns its keep — it makes context pressure visible before quality degrades, so you can `/compact` deliberately instead of getting auto-compacted mid-task.

**Sections, left to right:**

| Section | Shows |
|---------|-------|
| Git | Branch name, `(worktree)` marker when in a worktree, `✓` clean / `●` dirty |
| Model | Active model display name |
| Context | 20-char progress bar + used %, green <80k tokens, yellow <120k, red above |
| Stats | Session cost in USD, API time, lines added/removed |

**Install:**

The script is [`laptop/statusline-command.sh`](laptop/statusline-command.sh) — copy it to `~/.claude/statusline-command.sh` rather than retyping it, then register it in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /Users/<you>/.claude/statusline-command.sh"
  }
}
```

The script reads the session JSON payload on stdin and prints one line. Requires `jq`.

**Cost guidance:** the statusline runs on every render. Keep it to shell and `jq` — never have it call a Claude model. If a statusline genuinely needs a model call, pin it to Haiku explicitly. This is the same rule that applies to hooks (see `setup.md` § Cost guidance).

`/statusline` can also generate one interactively if you'd rather start from scratch.

---

## 3. Usage & Cost Monitoring (AI Meter)

The statusline shows *per-session* cost. It says nothing about how close you are to your **plan limits** — that's what [claude-meter](https://github.com/francisbrero/claude-meter) covers.

AI Meter is a lightweight macOS menu bar app that shows AI usage limits at a glance, for both Claude and Codex. It is a separate, independently maintained open-source project, not part of this repo — included here because it fills a real gap in the setup.

**What it gives you:**
- Session (5-hour) and weekly limits, per provider
- Color-coded status: green <70%, yellow 70–90%, red >90%
- Countdown to the next session and weekly reset
- Notifications at 80% and 90% usage
- Auto-refresh every 2 minutes

**Install:**
1. Download `AIMeter.zip` from [Releases](https://github.com/francisbrero/claude-meter/releases)
2. Unzip and move `AI Meter.app` to `/Applications`
3. **Right-click → Open** the first time (unsigned app; Gatekeeper blocks a double-click)

Or build from source:
```bash
git clone https://github.com/francisbrero/claude-meter.git
cd claude-meter/ClaudeMeter
brew install xcodegen
xcodegen generate
open AIMeter.xcodeproj   # ⌘B to build, ⌘R to run
```

**Requirements:** macOS 13+, and Claude Code and/or Codex CLI installed and logged in. It reads OAuth credentials from the macOS Keychain — credentials never leave the machine, and providers you haven't configured simply don't appear.

**Gotcha:** if you see "Token missing required scope," your OAuth token predates the usage API. Re-authenticate:
```bash
claude logout && claude
```

**Why both:** the statusline tells you what this session is costing; AI Meter tells you whether you're about to hit a wall. Together they cover the two questions worth asking mid-task.

---

## 4. Keyboard Shortcuts Reference

| Shortcut | Action |
|----------|--------|
| `Ctrl+U` | Delete entire line (faster than backspace) |
| `!` | Quick bash command prefix |
| `@` | Search for files |
| `/` | Initiate slash commands |
| `Shift+Enter` | Multi-line input |
| `Tab` | Toggle thinking display |
| `Esc Esc` | Interrupt Claude / restore code |

### Useful Commands

| Command | Action |
|---------|--------|
| `/fork` | Fork conversation for parallel work |
| `/rewind` | Go back to a previous state |
| `/statusline` | Customize status display |
| `/checkpoints` | File-level undo points |
| `/compact` | Manually trigger context compaction |
| `/plugins` | View and manage MCPs and plugins |
