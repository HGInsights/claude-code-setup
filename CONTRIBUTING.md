# Contributing

Thanks for your interest. This repo documents an AI software development
lifecycle that is actually running in production — that constraint shapes what
belongs here.

## What belongs here

Patterns you have **run in production** and can describe concretely: what it
does, why it exists, and what broke before you added it. The value of this repo
is that nothing in it is speculative.

What doesn't belong:

- Untested ideas, or "this should work" configuration
- Monitoring and cost-audit tooling — out of scope for this release; see the
  Scope section in [CLAUDE.md](CLAUDE.md)
- Anything naming a private repository, internal URL, or infrastructure
  specific. Generalize the pattern instead; where a concrete identifier carries
  the lesson, describe its shape rather than the real value.

## Before you open a PR

1. **Branch.** Never push directly to `master`.
2. **Check for leaked specifics.** Search your diff for company names, internal
   hostnames, repo codenames, credentials, and absolute paths under a home
   directory.
3. **Keep instruction files in sync.** `AGENTS.md` and `GEMINI.md` are symlinks
   to `CLAUDE.md`. Edit `CLAUDE.md` only — never replace a symlink with a copy.
4. **Say what you verified.** In the PR description, state what you actually
   ran and observed, and what you did not.

## Reporting a problem

Open an issue describing what you expected, what happened, and the setup you
were running. If a documented pattern is wrong or has drifted from current
Claude Code behavior, that's worth an issue on its own — stale guidance is
worse than none.

## Code of conduct

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
