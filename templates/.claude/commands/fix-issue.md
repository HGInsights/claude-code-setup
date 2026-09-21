# Fix GitHub Issue

Fetch and implement GitHub issue #$ARGUMENTS

<!--
TEMPLATE. Replace before use:
  {{PROJECT}}          human name of the codebase
  {{DEV_DOCS_DIR}}     where dev docs live, e.g. "docs/dev/active"
  {{DEV_DOCS_DONE}}    archive dir, e.g. "docs/dev/completed"
  {{DEFAULT_BRANCH}}   e.g. main
  {{CHECK_CMD}}        fast local check, e.g. "npm run check"
  {{TEST_CMD}}         test command
  {{REQUIRED_CHECKS}}  names of required CI checks
  {{GUIDELINES}}       repo convention docs to reference during implementation
Drop steps that don't apply (a repo with no preview envs drops the smoke
step). Keep Step 0b — compaction recovery is generic and load-bearing.
-->

## Progress Tracking

**REQUIRED**: create a task list at the start using `TaskCreate`, one task per
step. Set `in_progress` when starting, `completed` when finishing. Create them
all at once, then chain them with `addBlockedBy` so each is blocked by the
previous.

1. **Fetch issue #$ARGUMENTS** — `activeForm: "Fetching issue details"`
2. **Clarify requirements** — `activeForm: "Reviewing requirements"`
3. **Create branch** — `activeForm: "Creating branch"`
4. **Create dev docs** — `activeForm: "Setting up dev docs"`
5. **Research & plan** — `activeForm: "Researching and planning"`
6. **Plan review** — `activeForm: "Running automated plan review"`
7. **Get user approval on plan** — `activeForm: "Waiting for plan approval"`
8. **Implement changes** — `activeForm: "Implementing changes"`
9. **Code review** — `activeForm: "Running automated code review"`
10. **Run tests & checks** — `activeForm: "Running tests and checks"`
11. **Commit & create PR** — `activeForm: "Creating commit and PR"`
12. **Post-PR review** — `activeForm: "Running post-PR review"`
13. **CI green gate** — `activeForm: "Waiting for CI to pass"`
14. **Archive dev docs** — `activeForm: "Archiving dev docs"`

> **Do not mark the CI green gate complete — or report the workflow done —
> while any required check ({{REQUIRED_CHECKS}}) is pending or failing.** Local
> green is not the finish line; the green CI run on the pushed commit is.

## Workflow

### Step 0: Check for an existing session

```bash
ls {{DEV_DOCS_DIR}}/issue-$ARGUMENTS/ 2>/dev/null
```

**If the directory exists**, this is a resumed session:

1. Read `tasks.md` for current status
2. Read `context.md` for last recorded state
3. Read `plan.md` if planning completed
4. Re-create the task list from `tasks.md` (completed → `completed`, the last
   in-progress → `in_progress`, the rest → `pending`)
5. Skip forward to the right step — do not redo completed work

**If it does not exist**, this is a fresh session — proceed to Step 1.

### Step 0b: Recovering after a compaction

**Not a sequential step** — condition-triggered, whenever you detect the
conversation has been compacted, at any point, however many times. Signs: the
conversation opens with a summary of prior work rather than the work itself;
files you know you read are no longer in context; you recall *that* you did
something but not its specifics.

Auto-compaction cannot be steered — unlike `/compact <instructions>` it takes
no focus argument, and no setting, template, or hook influences what the
summarizer keeps. It re-injects the system prompt, `CLAUDE.md`, env info, and
tool schemas — but **not** arbitrary files read during the session. The dev
docs are durable on disk but are *not* automatically back in context. Writing
them is necessary but not sufficient; you must explicitly re-read them.

**Before taking any other action:**

1. **Re-read the dev docs** — `plan.md` and `context.md`, in full. Do this
   before answering the user, editing a file, or resuming a loop.

   If you no longer know the issue number (`$ARGUMENTS` resolves at invocation,
   so it can be paraphrased away like anything else), recover it from the
   branch name — `git branch --show-current` yields e.g.
   `chore/issue-1234`. If the branch doesn't follow that convention, fall back
   to listing `{{DEV_DOCS_DIR}}/`; if that lists more than one issue directory,
   disambiguate by matching the branch and the current diff rather than
   assuming the only or newest one. Do not guess it.

2. **Reconcile the record against reality.** Compare
   `## Implementation Summary` → `### What changed and why` with:

   ```bash
   # Worktrees frequently have NO local default-branch ref — verify first.
   git rev-parse --verify {{DEFAULT_BRANCH}} >/dev/null 2>&1 \
     && BASE={{DEFAULT_BRANCH}} || BASE=origin/{{DEFAULT_BRANCH}}
   git diff "$BASE"...HEAD --stat
   ```

   Use `--stat` to scope, then the full diff for any file the summary already
   lists — a file can be named in the record while later edits to it went
   unrecorded, and a filename-level check alone would pass that.

   If the diff is empty when you believe you made changes, suspect a missing or
   stale base ref before concluding no work was done — a bad base looks
   identical to a clean tree.

   If the doc does not account for everything in the diff, it is **stale**. Say
   so explicitly in your next message, then rebuild the record from the diff
   before continuing. Do **not** proceed on a stale record and do **not**
   quietly paper over the gap — a compaction landing right after a burst of
   un-recorded edits is exactly what this check exists for, and reporting the
   wrong set of changes is worse than pausing to reconstruct them.

3. **Relocate your position.** Re-read `tasks.md`, find the first unchecked or
   `[~]` item, resume there. Do not restart completed phases or re-explore code
   the docs show you already examined.

4. **Re-invoke any skill the remaining work depends on.** An invoked skill
   survives compaction as a *reference* — you recall having used it — but its
   instruction **content** is paraphrased away. Acting on a half-remembered
   runbook produces output that looks right and violates the template. If you
   are about to perform a step whose procedure you cannot state in full,
   re-invoke its skill first.

**Anchor yourself semantically, not by step number.** Phase numbering differs
across repos, so locate yourself by phase *name* — "plan review",
"implementation", "code review", "PR creation" — as recorded in `tasks.md`.

### Step 1: Fetch the issue

`gh issue view $ARGUMENTS` — title, description, labels, acceptance criteria.

### Step 2: Clarify requirements

Ask about anything ambiguous *before* planning. A wrong assumption here costs
a full plan-and-review cycle.

### Step 3: Create the branch

Branch from the fresh remote default: `<type>/issue-$ARGUMENTS-<slug>`.

### Step 4: Create dev docs

Create `{{DEV_DOCS_DIR}}/issue-$ARGUMENTS/` with `plan.md`, `context.md`, and
`tasks.md`.

`context.md` must contain an `## Implementation Summary` section with
`### What changed and why`, `### Review findings accepted as-is`, and
`### Unresolved / deferred findings`.

`## Implementation Summary` is the durable record of the work and it is what
makes an auto-compacted session recoverable. Compaction paraphrases away exact
file contents, so anything not written here is gone. **Keep it current as work
proceeds** — a summary written only at the end is worthless, because
compaction fires at an arbitrary token boundary, not a semantic one.

`tasks.md` uses `[x]` completed, `[~]` in-progress, `[ ]` pending — that is
what Step 0's resume detection reads.

### Step 5: Research & plan

1. Analyze requirements thoroughly.
2. **Search with the right tool for the job:**
   - **Targeted lookups** (known path, specific symbol) — `Read` or
     `Bash grep` directly in the main context. Cheap and precise.
   - **Open-ended exploration** ("where does X live", "find all callers of Y")
     — spawn the `Explore` subagent pinned to **Haiku**. Do **not** broad-grep
     inline: every exploratory grep on the main session re-reads the full
     cached context at the main model's rates.
3. Check `.claude/skills/` for relevant patterns.
4. Write a phased plan to `plan.md`.
5. Run the plan review loop (Step 6).
6. Present the converged plan to the user.

**Wait for user approval before implementing.**

### Step 6: Automated plan review

1. **Spawn the `plan-reviewer` subagent**, passing the plan file path as the
   prompt.
2. **Parse the response** for the plain-text markers:

   ```
   MATERIAL_FINDINGS: true|false
   REVIEWER: external|in-model
   FILES_REVIEWED: <n>
   FINDINGS:
   1. [severity] description
   SUMMARY: assessment
   ```

3. **If `MATERIAL_FINDINGS: true`** — update the plan, re-run the review.
   **Circuit breaker:** stop after 10 rounds. **Convergence:** stop at
   `MATERIAL_FINDINGS: false`.
4. **Update `context.md` after each round** so a crashed session resumes at the
   right round count:

   ```
   ## Plan Review
   Round: N/10
   Last result: MATERIAL_FINDINGS true|false — [one line summary]
   Reviewers: [r1 external (N files), r2 in-model (N files), ...]
   ```

   **If a loop converges with every round on the in-model fallback, say so
   explicitly in your handoff** — it means the external reviewer never ran and
   the "two independent reviewers" property the loop is designed around did not
   hold. Do not treat that as a normal convergence.

### Step 7: Implementation

Per phase: mark in-progress in `tasks.md` → implement following
{{GUIDELINES}} → run `{{CHECK_CMD}}` after each significant change → update
`context.md` (including `### What changed and why`) → mark complete.

Refresh the implementation summary at minimum as each phase completes, and
mid-phase whenever you have made a substantial set of edits and a long phase is
still running.

### Step 8: Automated code review

Commit work-in-progress first, so the diff against {{DEFAULT_BRANCH}} reflects
the full change set. Then spawn the `code-reviewer` subagent with scope
`base {{DEFAULT_BRANCH}}` — the most honest scope, matching what a human
reviewer and the post-PR pass will see.

The subagent materializes the diff itself and feeds the bytes to the reviewer.
Do not prescribe a raw reviewer invocation here; see
`.claude/agents/code-reviewer.md` for the mechanics.

Same parse, same circuit breaker, same `context.md` bookkeeping as Step 6 under
a `## Code Review` heading.

### Step 9: Tests & checks

Run `{{TEST_CMD}}` and `{{CHECK_CMD}}`. Fix failures rather than skipping them.

### Step 10: Commit & create PR

Invoke the `create-pr` skill. Re-invoke it if the session compacted since you
last read it.

### Step 11: Post-PR review

Spawn `code-reviewer` with scope `pr <url>`. Same loop, recorded under
`## Post-PR Review`.

### Step 12: CI green gate

Wait for required checks ({{REQUIRED_CHECKS}}) to pass on the pushed commit.
**A local green is not the finish line.** If a check fails, fix it and push
again — do not report success with a red or pending check.

### Step 13: Archive dev docs

Move `{{DEV_DOCS_DIR}}/issue-$ARGUMENTS/` to `{{DEV_DOCS_DONE}}/`.
