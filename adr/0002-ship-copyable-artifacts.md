# ADR 0002: Ship copyable artifacts, not fenced code blocks

- **Status:** Accepted
- **Date:** 2026-09-21
- **Scope:** Repository layout; `setup.md` and `laptop-setup.md`; the
  ships-vs-runs rules in `CLAUDE.md`

## Context

This repo was published as documentation: five markdown files totalling ~2,000
lines describing a production Claude Code setup. Everything a reader might
install — hooks, subagents, slash commands, the worktree helper, the status
line — lived inside fenced code blocks to be retyped.

Three findings forced a rethink.

**The docs had already gone stale, silently.** `laptop-setup.md` documents a
`wt()` worktree function in a 64-line fence. The version actually in use on the
author's machine is 98 lines and materially better: it resolves the default
branch via `origin/HEAD` and bases the worktree on the fetched remote branch
rather than whatever is checked out, prunes `node_modules`/`.git`/`.next` when
copying `.env`, and guards for a missing editor CLI. None of that is in the
doc. A reader following the documentation gets the worse implementation, with
nothing signalling that a better one exists. Nobody edited the fence when the
file changed, because nothing connects them.

**The docs already think in files.** Several `setup.md` sections are *titled*
with their destination path — `.claude/commands/create-pr.md` — and then
present the contents as a fence. The conversion to real files was started and
never finished. Only `create-pr.md` and `codex-safe.sh` exist as files, the
latter added precisely because `review-loops.md` names its path and "a script a
reader is told to copy should be copyable."

**The highest-value tooling was never documented at all.** A survey of the live
machine setup found ~15 git aliases in `~/.gitconfig` that appear nowhere in
the repo, including a worktree-aware branch-cleanup alias that prunes merged
branches, skips branches held by worktrees, and closes out PR branches via
`gh`. Prose documentation has a floor on effort — a 1,500-character shell alias
is unpleasant to write up, so it never was. Files have no such floor.

The common cause: a copy of code inside prose has no mechanism keeping it
honest. It cannot be executed, linted, diffed against its origin, or copied
without transcription. It rots from the moment it is written.

## Decision

**Every artifact a reader is told to copy exists as a real file.** Docs
reference files by path and explain *why*; the file is the source of truth.

The repo ships two artifact trees:

- `templates/` — per-repo Claude Code config: subagents, slash commands,
  hooks, `skill-rules.json`, settings.
- `laptop/` — one-time machine setup: worktree helper, status line, git
  aliases. Claude-adjacent tooling only, not general dotfiles.

Three rules govern them.

**Ships vs. runs.** What the repo ships (`templates/`, `laptop/`) is config for
other people's repos and machines, and is not active here. What the repo runs
is root `.claude/`. Neither may be edited to satisfy the other: a template is
not wired into root `.claude/` to "test" it, and nothing is deleted from
`templates/` because this repo doesn't run it. The previous instruction —
"deliberately absent: skills and the rest of the hook suite" — was correct
about the root and would now delete the product.

**Templates are dependency-free.** Shipped hooks are POSIX shell. No
`package.json`, no `tsx`, no install step. A consumer must be able to `cp` a
hook and have it run. Hooks must work on stock macOS: no GNU-only flags, no
`timeout`/`gtimeout`, and read the hook JSON contract on stdin rather than
guessing at `CLAUDE_TOOL_*` environment variables.

**Extract from the live file, never from the doc.** Where a fence and a working
file disagree, the working file wins. The fence is evidence of what was true
once.

## Migration

Sequenced by confidence, each step independently shippable.

1. **Harden `codex-safe.sh`.** Fold two guards from the production variant into
   the copy already in this repo: a stdin redirect, and a perl-`alarm` timeout.
   The latter matters because macOS ships no `timeout`, so a `timeout` written
   into an agent definition is *silently inert* — the observed failure was a
   ~25-minute zero-output hang. No new files, no dependencies.

2. **`laptop/`.** Extract the live worktree helper, status line, and git
   aliases as files; rewrite `laptop-setup.md` to reference them. Fixes the
   known staleness and ships the undocumented aliases. Parameterize the aliases
   that hardcode a `master` default branch.

3. **`templates/` — subagents and `fix-issue`.** These genuinely generalize:
   `code-reviewer` and `plan-reviewer` appear in three production repos with an
   identical contract (scopes `uncommitted` / `base <branch>` / `pr <URL>`,
   Codex-first invocation, structured findings), differing in repo name, model,
   and accumulated commentary. `fix-issue` appears in three repos at 650/489/474
   lines with the same numbered skeleton. Take the most elaborated version as
   the base — its extra length is largely generic failure-mode knowledge (use
   session-scoped temp paths, since concurrent sessions clobber shared ones and
   review the wrong diff; read `PIPESTATUS` not `$?` behind a `tee`;
   `CLAUDE_PROJECT_DIR` may be unset in a subagent shell, failing as exit 127
   that reads like "tool unavailable"). Parameterize repo name, model, and
   dev-docs path.

4. **`templates/` — hooks.** Port the shell hooks that carry their weight.
   Where the better implementation is TypeScript, document the `npx tsx` shim
   pattern and ship shell as the default, per the dependency-free rule.

5. **Deferred.** A preflight-context hook whose hardcoded path map must become
   configuration first; a post-tool-use tracker where two production repos have
   unrelated implementations sharing a filename and no clear winner.

Note for step 4: hooks sharing a name across repos are frequently independent
re-implementations rather than copies, with different input mechanisms and
different intent. Extraction is curation — pick a winner per hook, deliberately.

## Consequences

Docs shrink and change register, from transcription to explanation. `setup.md`
(1,233 lines) is largely fenced artifacts and should end up substantially
shorter, pointing at `templates/`.

Disclosure review becomes a per-file gate rather than a prose habit. Extracted
files carry specifics that prose naturally elided: real issue numbers in
comments, internal hostnames, monorepo directory layouts, vendor names in
environment allow-lists. The existing `codex-safe.sh` is the model — the
company-specific prefix list was stripped on the way in, keeping the mechanism.
Where a comment's *reasoning* is the valuable part, keep the lesson and rewrite
the specifics.

Templates will drift from the private repos they came from. That is acceptable
and mostly invisible; the alternative — a sync mechanism into a public repo —
is worse. Periodic re-extraction, treating the live file as the source of
truth, is the intended maintenance path.

The dependency-free rule costs real capability. The strongest hook
implementations found are TypeScript, typed and reading the documented stdin
contract, and shipping shell means shipping the weaker version of some of them.
Accepted because a template that requires an install step is one most readers
will not adopt, and the shim pattern gives the motivated reader a documented
upgrade path.

## Alternatives considered

**Keep documentation-only.** Cheapest, and wrong: the observed failure is
exactly that a documented artifact drifted from its working version and the doc
taught the stale one. More prose discipline does not fix a structural problem.

**Full runnable repo** — root `package.json`, the repo running its own hooks
and porting the production hook tests. Most dogfooding, and tempting given
those tests exist. Rejected for now: it imposes the dependency on every
consumer by example, and there is no product code here for a build-checker to
check. Revisit if templates grow complex enough that untested shell becomes the
larger risk.

**Wholesale dotfiles.** Rejected on scope and safety. The survey that found the
useful git aliases also found ~11 live plaintext credentials in the shell
config beside them. `laptop/` stays Claude-adjacent, where the disclosure
surface is small enough to review by eye.
