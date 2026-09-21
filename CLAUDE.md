# CLAUDE.md

This file provides guidance to AI coding assistants working in this repository.
It is the single source of truth: `AGENTS.md` (Codex) and `GEMINI.md` (Gemini CLI)
are symlinks to this file, so edit only this one.

## Repository Purpose

HG Insights' official AI SDLC: production-tested Claude Code configuration
patterns, extracted from a large Next.js + TypeScript monorepo running these in
production. This documents what's actually running, not theoretical ideas.

This repo is **public**. Do not name the private source repo, its internal URLs,
or its infrastructure specifics in files, commit messages, or PR descriptions.
Generalize patterns rather than copying project-specific names. When a concrete
identifier is load-bearing to the lesson (a commit-status string, a workflow
trigger), describe its *shape* rather than reproducing the real value.

## Scope

This repo is scoped to **harness customization** — configuring the coding agent
itself: commands, skills, hooks, subagents, review loops, and the repo-level
standards an agent must respect. That surface is stable.

It ships two kinds of artifact:

- **`templates/`** — per-repo Claude Code config a developer copies into their
  own project: subagents, slash commands, hooks, `skill-rules.json`, settings.
- **`laptop/`** — one-time machine setup: the worktree helper, the status line,
  the git aliases. Claude-adjacent tooling only, not general dotfiles.

Everything else is documentation explaining *why* those artifacts look the way
they do.

Cost-audit tooling is **not in this repo**. It lives in its own repo,
[claude-code-audit](https://github.com/HGInsights/claude-code-audit), because it is a Python CLI with a test suite and CI
and this repo has no root-level build. Do not reintroduce it at the root, and do not
add a root-level `audit/` directory — `.gitignore` blocks it deliberately.
Changes to the audit tool belong in that repo.

## Key Files

- **templates/** - Copyable per-repo Claude Code config (subagents, commands, hooks, skill rules, settings)
- **laptop/** - Copyable machine setup (worktree helper, status line, git aliases)
- **setup.md** - Per-repo Claude Code configuration (hooks, skills, slash commands, subagents, dev docs, review loops) — the *why* behind `templates/`
- **review-loops.md** - Production-hardened review loops (external-primary/in-model-fallback reviewers, the `MATERIAL_FINDINGS` contract, three review passes, credential-stripping wrapper, subagent scope hygiene)
- **sdlc-standards.md** - Repo-level engineering invariants an agent must respect (generated-file discipline, migration-as-deploy-gate, nightly→release gating, preview-env smoke tests, fail-fast env validation)
- **laptop-setup.md** - One-time machine setup (worktrees, status line, usage monitoring, keyboard shortcuts)
- **adr/** - Architecture decision records for non-obvious configuration choices
- **README.md** - Public-facing description of the repository
- **LICENSE** - MIT, Copyright (c) 2026 HG Insights
- **CONTRIBUTING.md** - How to propose changes

## This Repo's Own Configuration

The repo eats its own dog food, scoped to what a project with no product code
can use:

```text
CLAUDE.md              # single source of truth
AGENTS.md -> CLAUDE.md # symlink (Codex CLI)
GEMINI.md -> CLAUDE.md # symlink (Gemini CLI)
adr/                   # architecture decision records
templates/             # SHIPPED: per-repo config a consumer copies
laptop/                # SHIPPED: one-time machine setup
.claude/               # RUNS HERE: this repo's own config
  settings.json        # permissions allow-list (committed)
  commands/create-pr.md
  hooks/codex-safe.sh  # credential-stripping wrapper (review-loops.md §4)
```

Root `create-pr.md` is deliberately a trimmed variant of the shipped template
plus a public-repo disclosure checklist. That divergence is the ships-vs-runs
split working as intended, not drift to reconcile.

### Ships vs. runs

Two different things live here, and conflating them is the mistake to avoid:

- **What this repo *ships*** lives in `templates/` and `laptop/`. It is config
  for *other* people's repos and machines. It is not active here.
- **What this repo *runs*** is `.claude/` at the root — currently a permissions
  allow-list, `create-pr`, and `codex-safe.sh`. There is no build, no test
  suite, and no dependency install at the root, because there is no product
  code to check.

So: do not wire a template into root `.claude/` to "test" it, and do not delete
something from `templates/` because this repo doesn't run it. A build-checker
hook belongs in `templates/`; it would be dead weight at the root.

### Templates are dependency-free

Shipped hooks are POSIX shell. No `package.json`, no `tsx`, no install step —
in `templates/` or at the root. A consumer must be able to `cp` a hook and have
it run.

Where a TypeScript implementation is genuinely better, document the 5-line
`npx tsx` shim pattern so a reader can adopt it in their own repo, and keep the
shipped default in shell. Hooks must work on stock macOS: no GNU-only flags
(`grep -oP`), no `timeout`/`gtimeout`, and read the hook JSON contract on stdin
rather than guessing at `CLAUDE_TOOL_*` environment variables.

### No fenced artifacts

If a reader is told to copy a script, config, or command, it must exist as a
real file they can `cp`. Never as a fenced block in a doc.

This is not style. `laptop-setup.md` documented a worktree helper while the
working version on disk drifted well ahead of it — the doc taught the stale
one. Prose copies of code rot silently. Docs reference files by path and
explain *why*; the file is the source of truth.

Corollary: when extracting from a working repo or machine, take the live file,
not a fence that describes it. See
[ADR 0002](adr/0002-ship-copyable-artifacts.md) for the reasoning and the
migration sequence.

If you add a new instruction file for another assistant, symlink it to
`CLAUDE.md` rather than copying. Duplicated instruction files drift.

## Git Workflow

Always use feature branches and PRs for changes:

1. Create a branch: `git checkout -b feature/description`
2. Make commits on the branch
3. Push and create PR: `gh pr create`
4. Wait for approval before merging
5. Never push directly to master
