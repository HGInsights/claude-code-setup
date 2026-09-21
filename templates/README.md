# templates/

Per-repo Claude Code config to copy into your own project. These are not
active in this repo — see the ships-vs-runs rule in [CLAUDE.md](../CLAUDE.md).

Read [setup.md](../setup.md) and [review-loops.md](../review-loops.md) for why
these look the way they do; this directory is what you install.

## What's here

| File | What it is |
|---|---|
| `.claude/agents/code-reviewer.md` | Reviews a diff or PR. External reviewer CLI first, in-model fallback. |
| `.claude/agents/plan-reviewer.md` | Same contract, for an implementation plan. |
| `.claude/commands/fix-issue.md` | Issue → plan → review → implement → review → PR → CI gate. |
| `.claude/hooks/codex-safe.sh` | Credential-stripping, timeout-bounded wrapper for the external reviewer. |

## Install

```sh
cp -R templates/.claude/. /path/to/your-repo/.claude/
chmod +x /path/to/your-repo/.claude/hooks/codex-safe.sh
```

Then fill in the placeholders. Every file starts with an HTML comment listing
the ones it uses:

| Placeholder | Meaning |
|---|---|
| `{{PROJECT}}` | Human name of the codebase |
| `{{DEFAULT_BRANCH}}` | `main`, `master`, … |
| `{{DEV_DOCS_DIR}}` / `{{DEV_DOCS_DONE}}` | Where per-issue plan/context/tasks docs live and get archived |
| `{{CHECK_CMD}}` / `{{TEST_CMD}}` | Your fast check and test commands |
| `{{REQUIRED_CHECKS}}` | Names of the CI checks that gate a merge |
| `{{GUIDELINES}}` | Repo convention docs a reviewer should read |
| `{{IGNORE_PATHS}}` | Generated and vendored paths reviewers must not crawl |
| `{{REVIEW_RUBRIC}}` / `{{REVIEW_CHECKLIST}}` | Your review criteria |
| `{{REVIEWER_MODEL}}` | External reviewer model id |

```sh
grep -rn '{{' /path/to/your-repo/.claude/   # find what's left
```

## Don't trim the commentary

These files are long because each warning records a specific production
failure. A few, so you can judge for yourself:

- **The exit code is read via `${PIPESTATUS[0]:-$pipestatus[1]}`, not `$?`.**
  The invocation ends in `tee`, so `$?` is tee's status — always ~0. And in
  zsh the bash-only `PIPESTATUS` spelling reads empty. Get either wrong and
  the "reviewer failed" trigger silently never fires.
- **The reviewer is never allowed to fetch its own input.** From its sandbox it
  often can't reach the network, and then reviews whatever branch is checked
  out locally — returning a confident verdict on the wrong code.
- **Temp paths are session-scoped.** Bare `/tmp` is shared, so a parallel run
  clobbers the same filenames and you review another issue's diff while every
  anchoring gate still passes.
- **The CLI-error scan is column-0 anchored.** Unanchored, it matched the
  reviewed diff's own words — one repo had a quarter of its source files
  containing "credit"/"rate limit"/"unauthorized", so PRs touching auth and
  billing silently fell back to a single reviewer. The worst observed outcome
  was a rate-limiting PR shipping the same vulnerability class four times
  through reviews that looked converged.

The pattern behind all four: **a review loop that fails silently still looks
like it passed.** Most of the commentary exists to make failure loud.

## Not included

`skill-rules.json` isn't here. Its *schema* generalizes but its content is
entirely repo-specific; see setup.md for the shape and write your own.

Hooks beyond `codex-safe.sh` are still being generalized — the production
versions carry hardcoded monorepo paths. See ADR 0002 for the sequence.
