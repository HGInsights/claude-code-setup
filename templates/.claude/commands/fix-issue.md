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
  {{GH_REPO}}          owner/repo for gh commands
  {{REVIEW_BAR}}       the review bar, as filled in the reviewer agents
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
7. **Plan approval (only when needed)** — `activeForm: "Checking whether plan approval is needed"`
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

**First, check that nothing blocks it**, on every start, fresh or resumed (a
blocker can be reopened after a session began). Read the issue's
`Blocked by:` line in `## Dependencies` (`/task-to-github-issue` writes it;
`Soft:` lines never block). For each listed issue, read
`gh issue view <M> --repo {{GH_REPO}} --json state,stateReason`. A blocker is
cleared only when it is `CLOSED` with `stateReason` `COMPLETED`: closed as not
planned or duplicate means the work never landed. **Fail closed:** if the body
or any blocker can't be read (a `gh` error, a rate limit, unparseable output),
treat that as blocked. Either way, stop: don't branch, plan or ask anything.
Report "#$ARGUMENTS is blocked by #<M> (open)" or "#$ARGUMENTS: couldn't
confirm blocker #<M>", and end. Starting anyway builds on code that doesn't
exist yet.

**Then move into the issue's own worktree, before anything is written.**
Everything this command writes (decisions, dev docs, branch, code) lives in
`.claude/worktrees/issue-$ARGUMENTS-<slug>`, never in the checkout the session
started from: several `/fix-issue` sessions can start from one checkout in
parallel, and a branch switch or a stray file there affects all of them. Use
Claude Code's `EnterWorktree` tool, on branch
`<type>/issue-$ARGUMENTS-<slug>` from the fresh remote default if the worktree
doesn't exist yet. The tool moves the session's working directory, so the
subagents (plan-reviewer, code-reviewer, Explore) run there too. **Don't**
create it with a plain `git worktree add` and keep working from the launch
checkout: the reviewers would then diff the shared checkout, the
wrong-worktree failure `code-reviewer.md` warns about. On resume, if
`git rev-parse --show-toplevel` is already that worktree, stay; otherwise
re-enter it. Then look for the dev docs inside it:

```bash
ls {{DEV_DOCS_DIR}}/issue-$ARGUMENTS/ 2>/dev/null
```

**If the directory exists but has no `tasks.md`**, the last session stopped
in Step 2, after recording some decisions and before Step 4 created the dev
docs. Start at Step 1, keep `context.md` → `## Decisions` as it is, and don't
ask again about anything already in it.

**If the directory exists and has `tasks.md`**, this is a resumed session:

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

Every question follows `.claude/skills/runbooks/operator-questions.md`:
`AskUserQuestion` only, one tag, answerable on its own, one decision per
question. Technical questions go to the `decision-consult` agent, not the
user. Record every decision in `context.md` → `## Decisions` as soon as it is
made.

### Step 3: Create the branch

Step 0 created it with the worktree: `<type>/issue-$ARGUMENTS-<slug>`, from
the fresh remote default. Nothing to do here unless Step 0 found an existing
worktree on another branch; then stop and ask.

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
4. Write a phased plan to `plan.md`. It ends with a `## Decisions` section:
   one line per decision the plan makes, grouped under **product**,
   **architecture** and **technical**. Technical lines carry their
   `second reviewer: external|in-model` value; product and architecture lines
   say `decided by: user`, or `decided by: default` for a product decision
   taken as an assumed default (`operator-questions.md` → Assumed defaults).
   Settle technical choices that come up while planning with
   `decision-consult`. Ask each architecture decision found while planning as
   its own `[architecture]` question (after its consult) before plan approval.

   The plan also has a **`## Gates & tests`** section, never omitted (a plan
   without it is not ready for review):
   - **Tests per story**: each story or criterion → test tier, test file and
     what the test asserts, or `manual: <steps> — <why>`. A bug fix names its
     regression test.
   - **Gates expected**: the checks this diff will trigger, from
     `{{CHECK_CMD}}` to the required CI checks ({{REQUIRED_CHECKS}}): coverage
     thresholds, manifests a new test must be registered in, generated files.
   - **Quality-ratchet risks**: any limit the change is likely to cross (file
     or function size, complexity, duplication) and the planned split.
   - **Docs to update**, or `N/A: <reason>`.

   Plan gaps were the largest single source of code-review findings, and most
   plan reviews hit the round cap with gate failures still open: a test tier
   nobody chose, a spec nobody registered, a size limit crossed on purpose.
   Naming them up front moves those findings to the plan, where they cost a
   line.
5. Run the plan review loop (Step 6).
6. **Decide whether plan approval is needed.** It is **not** needed when all
   of these hold, and then you skip the question entirely:
   - the issue's Gate B marker verifies: its body ends with
     `<!-- gate-b-signed-off: <sha> -->` (written by `/task-to-github-issue`
     Step 7) and the body without that line still hashes to `<sha>`, so the
     stories and criteria are exactly what the user signed off. Formatting
     alone (`### Story N:` headings) proves nothing: a hand-written or
     later-edited issue looks the same.

     ```bash
     # Strip CR first: a body saved from GitHub's web editor comes back CRLF,
     # and the marker's `-->$` never matches before a trailing \r.
     raw=$(gh issue view $ARGUMENTS --repo {{GH_REPO}} --json body --jq .body | tr -d '\r')
     body=$(printf '%s\n' "$raw" | grep -v '^<!-- gate-b-signed-off: ')
     recorded=$(printf '%s\n' "$raw" | sed -n 's/^<!-- gate-b-signed-off: \([0-9a-f]*\) -->$/\1/p')
     [ -n "$recorded" ] && [ "$(printf '%s' "$body" | shasum -a 256 | cut -c1-12)" = "$recorded" ] \
       && echo GATE_B_VERIFIED || echo GATE_B_NOT_VERIFIED
     ```

   - the plan adds no product decision beyond those criteria, other than
     assumed defaults;
   - every architecture decision the plan makes was already asked as its own
     `[architecture]` question (item 4);
   - no blocking plan-review finding is still open after the circuit breaker.

   When skipped, record in `context.md`:
   `Plan approval: skipped — Gate B marker verified, no open product or
   architecture decisions`, list any assumed defaults there, and go straight
   to Step 7. The plan's decision summary, with "Assumed defaults (change
   any)", goes in the PR body: that is the user's sign-off point for this
   run, and they change a default by commenting on the PR. (Once the product
   decisions were settled at Gate B, reviewing the plan only cost the user a
   context switch: in practice they approved every one unread.)

   **When it is needed**, ask about exactly what is open, not the whole plan.
   A new product decision gets its own `[product]` question. An issue without
   signed-off stories, or a blocking finding left open, gets one `[product]`
   plan-approval question whose text contains, in this order:
   - the issue number and title, and one sentence on what the plan delivers;
   - **the decision summary**: one line per decision from the plan's
     `## Decisions`, with "Assumed defaults (change any)";
   - **the plan-review outcome**: the number of rounds, each round's
     reviewer, and the final `MATERIAL_FINDINGS` result. If every round was
     `in-model`, say so in plain words: the external reviewer never saw this
     plan;
   - the **absolute path** to the plan
     (`$(git rev-parse --show-toplevel)/{{DEV_DOCS_DIR}}/issue-$ARGUMENTS/plan.md`,
     pasted as a literal);
   - any blocking plan-review finding still open, or "none".

   Never "approve the plan?" without these. Options: approve (first,
   ` (Recommended)`), and request changes (the user types what to change).

**When plan approval is needed, wait for it before implementing.**

### Step 6: Automated plan review

1. **Spawn the `plan-reviewer` subagent**, passing the plan file path as the
   prompt. From round 2, add `settled: <absolute path to context.md>`, after
   writing the previous round's list there (below).
2. **Parse the response** for the plain-text markers:

   ```
   MATERIAL_FINDINGS: true|false
   REVIEWER: external|in-model
   FILES_REVIEWED: <n>
   FINDINGS:
   1. [severity] description
   SUMMARY: assessment
   ```

3. **Triage every finding before changing anything.** Only in-scope
   `[critical]` and `[high]` findings block (that is what
   `MATERIAL_FINDINGS: true` means). For each `[major]` and `[minor]`, decide
   **fix**, **accept** or **defer**, and record the decision with a one-line
   reason under the round in `context.md`. Judge every finding against the
   review bar (the reviewers' `{{REVIEW_BAR}}`):
   - `[below-bar]` (it only matters beyond the bar) is accepted, with the
     reason "below the review bar: <which part>". It never gets a follow-up
     issue. If the reviewer didn't tag a finding that is below the bar, accept
     it the same way and say so.
   - `[out-of-scope]` (within the bar, but the issue's acceptance criteria
     don't require it) is never fixed in this branch. File a follow-up issue
     only when it is likely in normal use; otherwise accept it with its
     reason. Follow-up issues are the exception, not the default way to close
     a finding.

   **Fix with the smallest change that closes the finding, and push back when
   the reviewer is wrong.** A fix goes to every site with the same pattern and
   comes with a test that fails without it; it doesn't redesign the
   surrounding code. A finding that misreads the code, re-raises a settled
   decision or asks for work outside the issue is declined, with the reason
   recorded. Declining is a normal outcome, not a failure to converge.

   **Same class twice: stop patching.** When a blocking finding is a variant
   of one fixed in an earlier round (another spelling, another input of the
   same kind, another path around the same check), the check is trying to
   list an open-ended set and won't converge. Don't fix the new variant. Ask
   an `[architecture]` question (`operator-questions.md`), with the second
   reviewer's position, offering to narrow the feature so it doesn't need the
   check, or to accept the remaining risk. Record the answer in
   `## Decisions`.

   **Prefer running something to another round.** When a finding can be
   settled by a live run or a failure-injection test, run it instead of
   starting another review round.

   > **Why.** Fixing every finding until the reviewer came back clean didn't
   > converge: one loop ran 10 plan rounds and 5 code rounds, and about six of
   > its findings were real bugs; most of the rest were edge cases in
   > machinery added to answer earlier findings, each fix creating the next
   > round's findings. Another spent five rounds finding one more way for a
   > shell to spell `rm`, and still documented gaps it couldn't close. Without
   > a stated bar the reviewer applies the strictest one, and each pass finds
   > the next layer down. The real bugs were found by live runs and
   > failure-injection tests as often as by review rounds.

   Then, if anything blocking was fixed, write the previous round's list into
   `context.md` (each finding → fixed in `<sha>` | declined: reason |
   accepted: reason | deferred: reason) and re-run the review with
   `settled:`. A decision the revision introduces is routed like any other
   (`operator-questions.md` → Routing). **Circuit breaker:** stop after 3
   rounds; list any blocking finding still open in the plan-approval
   question. **Convergence:** stop at `MATERIAL_FINDINGS: false`.
4. **Update `context.md` after each round** so a crashed session resumes at the
   right round count:

   ```
   ## Plan Review
   Round: N/3
   Last result: MATERIAL_FINDINGS true|false — [one line summary]
   Reviewers: [r1 external (N files), r2 in-model (N files), ...]
   Triage: [finding → fix | accept | defer — reason, ...]
   ```

   **Keep one reviewer for every round of a loop.** If round 1 fell back to
   in-model, later rounds of that loop do too: swapping reviewers mid-loop
   reopens what the first one already passed.

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

Same parse, triage, circuit breaker (3 rounds) and `context.md` bookkeeping as
Step 6, under a `## Code Review` heading. From round 2, the scope line is
followed by `prev: <the commit the last round reviewed>` and
`settled: <absolute path to context.md>`: the reviewer checks the previous
findings first, reviews the changes since that round closely, and reopens
code an earlier round passed only for `[critical]`/`[high]`. Record the commit
each round reviewed:

```text
Reviewed head: <git rev-parse HEAD when the round ran>
```

The head of the last clean review round (Step 8, later Step 11) is the
**convergence SHA**. Step 11 and
[Bringing a PR branch up to date](#bringing-a-pr-branch-up-to-date) decide
from it whether a later review would see anything new.

### Step 9: Tests & checks

Run `{{TEST_CMD}}` and `{{CHECK_CMD}}`. Fix failures rather than skipping them.

### Step 10: Commit & create PR

Invoke the `create-pr` skill. Re-invoke it if the session compacted since you
last read it.

### Step 11: Post-PR review

Spawn `code-reviewer` with scope `pr <url>`. Same loop, triage and 3-round
breaker, recorded under
`## Post-PR Review`, with the head each round reviewed.

**Skip it when nothing changed since the last code review.** If the pushed PR
head is the Step 8 convergence SHA, and that last round's `REVIEWER:` was
`external`, the post-PR pass would review identical bytes. Record
`## Post-PR Review: skipped — PR head <sha> = last reviewed commit` instead.
Run it when anything was committed after convergence, or when Step 8's last
round was `in-model`: the PR then still gets an external pass.

### Step 12: CI green gate

1. **Mergeable first.**
   `gh pr view <P> --repo {{GH_REPO}} --json mergeable,mergeStateStatus`. If it
   reports `CONFLICTING`, `DIRTY` or `BEHIND`, follow
   [Bringing a PR branch up to date](#bringing-a-pr-branch-up-to-date) before
   waiting on CI. `UNKNOWN` means GitHub is still computing: wait 10 s and ask
   again, at most 3 times.
2. Wait for required checks ({{REQUIRED_CHECKS}}) to pass on the pushed commit.
   **A local green is not the finish line.** If a check fails, fix it and push
   again (a plain `git push`) — do not report success with a red or pending
   check.

### Step 13: Archive dev docs

Move `{{DEV_DOCS_DIR}}/issue-$ARGUMENTS/` to `{{DEV_DOCS_DONE}}/`.

## Bringing a PR branch up to date

Do it only when GitHub reports the PR `CONFLICTING`, `DIRTY` or `BEHIND`.
**Rebase onto the base; never merge the base into the PR branch.** A repo that
merges by rebase can't land a branch with a merge commit in it (GitHub reports
it can't be rebased and refuses the merge), and in any repo a conflict
resolved inside a merge commit is code no review round sees as a diff. Never
open a new branch or PR to get around a conflict.

1. `BASE=$(gh pr view <P> --repo {{GH_REPO}} --json baseRefName -q .baseRefName)`.
   That is `{{DEFAULT_BRANCH}}` for a normal PR and the parent branch for a
   stacked one; never hard-code `{{DEFAULT_BRANCH}}`, or a stacked child pulls
   its parent's commits into its diff. When a parent PR is rebased, rebase its
   children afterwards in stack order, each onto its own `baseRefName`:
   - Before rebasing the parent, record its old head (`PARENT_OLD`, the
     parent's `headRefOid`).
   - On each child's own branch, run
     `git rebase --onto "origin/$BASE" "$PARENT_OLD"`, not a plain rebase. The
     child still carries the parent's old commits, and a plain rebase drops
     them only when they are patch-identical to the rewritten ones; after a
     parent rebase that resolved conflicts they would conflict again or show
     up in the child's diff.
   - **No trailing `HEAD`** on that command: it detaches HEAD and leaves the
     local branch where it was.
   - If someone else rebased the parent, recover `PARENT_OLD` with
     `git merge-base --fork-point "origin/$BASE"`. If that prints nothing (a
     fresh clone has no reflog of the old tip), stop and ask for the parent's
     pre-rebase head. Never run the rebase with an empty `PARENT_OLD`.
2. `OLD=$(gh pr view <P> --repo {{GH_REPO}} --json headRefOid -q .headRefOid)`,
   and confirm `git rev-parse HEAD` equals `$OLD`. If it doesn't, the local
   branch is missing remote commits: `git fetch origin <branch>`, then
   `git rebase origin/<branch>` (or `git reset --hard origin/<branch>` when you
   have no local-only commits). Never a plain `git pull`, which merges. Then
   re-read `OLD` and confirm it is an ancestor of HEAD
   (`git merge-base --is-ancestor "$OLD" HEAD`).
3. `git fetch origin "$BASE" && git rebase "origin/$BASE"` (for a child of a
   rewritten parent, the `--onto` form from item 1), resolve conflicts, then
   run `{{CHECK_CMD}}` and `{{TEST_CMD}}`.
4. `git push --force-with-lease=<branch>:$OLD origin HEAD:<branch>`, always to
   the PR's own branch. **Name the lease explicitly**: a bare
   `--force-with-lease` trusts the local remote-tracking ref, which any
   background `git fetch` (an editor, another session) moves, and the lease
   then protects nothing.
5. If the push is rejected, someone else pushed. Don't retry and never fall
   back to `--force`: fetch, look at what changed, and tell the user.
6. **Re-review or not.** If the rebase needed conflict resolution, the post-PR
   review (Step 11) runs again: the resolutions are new code. Record the new
   head as the convergence SHA once it passes. After a clean rebase, skip the
   review only when the convergence SHA equals `$OLD`, meaning nothing was
   committed after the review converged; record the new HEAD as the
   convergence SHA. If commits came after it (CI fixes, a teammate's push),
   the review runs. **Never diff the old convergence SHA against the rebased
   HEAD** to see what changed: that lists everything the base brought in too.

Every other push (review fixes, CI fixes) is a plain `git push`.
