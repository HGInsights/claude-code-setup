# Task → GitHub Issue

Turn a task from a tracker (Jira, Asana, Linear, a Slack thread, a plain
paragraph) into a GitHub issue a developer — or `/fix-issue` — can pick up
cold.

<!--
TEMPLATE. Replace before use:
  {{GH_REPO}}      owner/repo
  {{TRACKER}}      Jira | Asana | Linear | …
  {{CODE_ROOT}}    where source lives, e.g. "src/"
  {{DOCS_ROOT}}    where docs/ADRs live
  {{LABELS}}       your issue label taxonomy
  {{DEV_DOCS_DIR}} where dev docs live (drafts and decisions go here)
  {{ARCH_DOCS}}    the docs that record your architecture decisions
Only Step 1 is tracker-specific — swap the adapter and the rest is unchanged.
-->

## When to use

- "create a GitHub issue from {{TRACKER}} task ABC-123"
- "convert this ticket to a GitHub issue"
- The user pastes a task URL, key, or description and wants an issue

## Mandatory task list

The command file that invokes this runbook creates the task list. Do not skip
steps, and do not create an issue before both hard gates pass.

### 🔒 Hard gates — issue creation is BLOCKED until both pass

- **Gate A** (Step 3): requirements grilled, every material gap resolved or
  consciously accepted by the user.
- **Gate B** (Step 5): user stories + acceptance criteria explicitly signed off.

Neither gate is satisfiable by your own judgement. Both require the user to
answer.

### Asking the user

Every question in this runbook follows
[operator-questions.md](operator-questions.md): `AskUserQuestion` only, never
a plain-text question; one tag (`[product]`, `[architecture]`, `[technical]`)
at the start; answerable on its own, with absolute paths; one decision per
question, recommended option first. Technical questions go to the
`decision-consult` agent instead of the user, as that file's Routing section
says.

## Step 1: Fetch the task — the tracker adapter

This is the **only** tracker-specific step. Everything after it works the same
whatever the source.

What you need to come away with, regardless of tracker:

1. Title, description, and type (bug / feature / chore)
2. Any subtasks or linked items
3. Any linked spec, design doc, or thread — read those too
4. The task's URL or key, for the link-back in Step 8

**Jira** (worked example):

```bash
jira issue view ABC-123 --plain
jira issue list --parent ABC-123 --plain 2>/dev/null   # subtasks
```

No `jira` CLI? Use the Atlassian MCP tools (`getJiraIssue`,
`searchJiraIssuesUsingJql`), or ask the user to paste the content.

**Asana:**

```bash
# via MCP tools where available; otherwise the REST API
curl -s -H "Authorization: Bearer $ASANA_TOKEN" \
  "https://app.asana.com/api/1.0/tasks/<task_gid>?opt_fields=name,notes,completed,subtasks"
```

**Linear:**

```bash
linear issue view ABC-123     # if the CLI is installed
```

or the Linear MCP server, or the GraphQL API.

**No tracker at all** — a Slack thread, an email, a paragraph the user typed:
that is a legitimate input. Skip to Step 2 with what you have; the gap
analysis in Step 3 matters *more* here, not less, because there is no ticket
to lean on.

> Whatever the source, treat it as **the starting point, not the source of
> truth** — see the warning in Step 5.

## Step 1b: Reproduce the issue (bugs — standing instruction)

**Always reproduce before writing anything.** For any bug-type task, replicate
the problem first so the issue carries a confirmed root cause and exact code
citations, not a restatement of the reporter's words. This is not optional.

Reproduce at the most concrete level available:

- **Code-level** (default for deterministic logic, schema, or query bugs):
  trace the path from where the symptom surfaces back to the defective line.
  Pin the precise `file:line`, the current wrong code, and confirm the data a
  correct fix needs is actually available upstream. This is usually enough to
  write a self-contained "Fix — exact changes required" section.
- **Live** (when behavior depends on runtime state or real data): reproduce
  against a running app, a real query, or a staging environment, and capture
  the concrete evidence — the request, the wrong response, the error.

Record for the issue body:

1. The exact trigger condition
2. The observed wrong behavior, with evidence (`file:line`, error, response)
3. The root cause — *why*, not just *that*
4. Which adjacent code is already correct and must NOT change

If you genuinely cannot reproduce (non-deterministic, environment-specific, no
access), say so explicitly during the grilling step and ask for repro steps or
evidence. **Do not paper over an unreproduced bug with a guessed root cause.**

For feature requests, this step becomes "confirm the current behavior or gap
the feature addresses."

## Step 2: Gather repo context (delegate to Haiku)

Gathering context is open-ended — scanning {{CODE_ROOT}}, {{DOCS_ROOT}},
`.claude/skills/`, and prior issues for anything related. Do this via a single
`Explore` subagent pinned to **Haiku**, not inline `grep` / `gh issue list` in
the main session. Broad searches in the main context re-read the whole cached
conversation every time at the main model's rate; a Haiku subagent returns the
same result for a fraction of the cost.

```
Agent({
  subagent_type: "Explore",
  model: "haiku",
  description: "Find related context",
  prompt: "Thoroughness: quick. The task is: <one-paragraph summary including key terms, affected entities, and any referenced endpoints or data sources>.

Return a concise report with four sections:
1. **Related skills / runbooks** — matching files under `.claude/skills/`. Path + one-line summary.
2. **Related ADRs / docs** — matching files under {{DOCS_ROOT}}. Path + one-line summary.
3. **Overlapping GitHub issues** — up to 5 on {{GH_REPO}} (open or closed) whose title or body clearly overlaps. Number, title, state, why relevant.
4. **Relevant code anchors** — up to 5 files/symbols under {{CODE_ROOT}} the work would touch. `path:line` with a one-line reason.

If a category has no matches, say 'None found' — don't pad."
})
```

Read the report and the files it cites. **Do not** run `grep -r` or
`gh issue list` inline — that is the pattern this step replaces.

> Step 3 stays in the main context — it is the reasoning-heavy part.

## Step 3: PM-coach gap analysis

Evaluate the task through a PM lens before writing anything. Common gaps:

**Problem definition** — Is the "why" clear (what user pain or business need)?
Is scope bounded (can a developer tell what's in vs. out)? Are assumptions
stated?

**Success criteria** — Is "done" measurable; can you write a test for each
criterion? Are edge cases identified (empty result, unknown input, missing
data)? Is the happy path distinct from error paths?

**User stories** — Who benefits; are the actors/personas identified? Is the
flow described step by step? Are multiple consumers affected?

**Technical clarity** — Are interfaces defined (paths, request/response
shapes, fields)? Are dependencies explicit (what must exist first)? Is the
testing strategy clear (unit vs. integration)?

For each gap, form a recommended answer, then tag it per
[operator-questions.md](operator-questions.md) → Tags and route it:

- **`[product]`** gaps (scope, edge-case behavior the user sees, success
  criteria, personas, accepted risks) go to the user at Gate A, unless one
  qualifies as an assumed default
  ([operator-questions.md](operator-questions.md) → Assumed defaults): then
  take the recommendation, record it, and list it at Gate B.
- **`[architecture]`** gaps (a new component or dependency, a change to a
  decision in {{ARCH_DOCS}}) go to `decision-consult` once, then to the user
  at Gate A with both positions.
- **`[technical]`** gaps (how to build it within the recorded design) go to
  `decision-consult`. Settled ones are not asked. Only an unresolved
  disagreement after 2 exchanges reaches the user.

The split matters: a product owner answering Gate A should be asked about
behavior, scope and risk, not about storage, cache keys or hook points they
don't review. Asking them the technical gaps too is how a gate turns into a
rubber stamp.

Write every decision to `{{DEV_DOCS_DIR}}/<TASK-KEY>/decisions.md` (or
`{{DEV_DOCS_DIR}}/<slug>/decisions.md` with no tracker key) **as soon as it is
made**, before the next question or consult
([operator-questions.md](operator-questions.md) → Recording decisions). A
resumed session re-reads the file and doesn't ask again about anything in it.
At Gate B the technical lines are copied into the draft's
`## Technical Notes` → `### Decisions settled with the second reviewer`.

### 🔒 Gate A — grill until requirements are resolved

Mandatory. You may **not** advance past Step 3 by silently filling gaps with
your own assumptions.

1. **One `AskUserQuestion` question per gap**, up to 4 questions per call;
   more gaps means more calls. Never a numbered list of gaps inside one
   question: the user can't answer "accept 1 and 3, change 2" through options,
   and a reader who sees only the question can't see the list. Each question
   names the task (key and title), says what the gap is and why it matters for
   the issue, and offers your recommended answer first with
   ` (Recommended)`. Each option's `description` says what choosing it means
   for the user or the product. For example:

   ```text
   question: "[product] Drafting the GitHub issue for ABC-31 ('Search
     endpoint for accounts'): the task doesn't say what the endpoint returns
     for an unknown account name. The acceptance criteria need one behavior.
     What should a caller get?"
   header: "Unknown name"
   options:
     - label: "200, empty list (Recommended)"
       description: "Callers treat 'no match' like any other result; no
         error handling needed. Typos look like 'nothing found'."
     - label: "404 Not Found"
       description: "Callers can tell 'no match' from an empty search, but
         every client must handle the error."
   ```

   **Ask all of them together**, in as few calls as the 4-per-call limit
   allows, and put the Step 4 structure question in this first round, not a
   round of its own (unless the work is plainly one issue).

2. **Loop, don't one-shot.** If an answer opens a new ambiguity or only
   partially resolves a gap, ask the follow-up, again as its own standalone
   question. Keep going until every material gap is resolved or consciously
   accepted.

3. Only then mark the gate complete.

**If no gap question reached the user** (you found no gaps, or every gap
was settled as an assumed default or by the consult), still get an explicit
"yes, proceed": ask one `[product]` question whose text restates your read of
the requirements, the personas and the scope (in and out) in full, and lists
the assumed defaults taken so far, with "Proceed with this reading
(Recommended)" as the first option. Do not skip the gate. When gap questions did reach the
user, don't add this confirmation: it only replays answers just given, and
Gate B restates the scope anyway.

## Step 4: Decide issue structure

**Single issue** if focused and completable in one PR. **Multiple** if large
and separable into independent, shippable increments — then identify
boundaries, dependencies (what must come first), labels, and sizes.

Recommend, and get confirmation before creating.

## Step 5: Write the issue(s)

### ⚠️ The task is the starting point, not the source of truth

The issue must be **fully self-contained**. A developer picking it up cold —
no tracker access, no access to this conversation, none of your exploration —
must have everything needed to implement it correctly. If they would have to
re-derive something you already found (file paths, line numbers, the offending
query, existing patterns to follow, what is already correct and must not
change), the issue is incomplete.

### Body structure

`## Context` · `## Problem` · `## Fix — exact changes required` (bugs) ·
`## Requirements` · `## User Stories` · `## Acceptance Criteria` ·
`## Technical Notes` · `## Dependencies` · `## Size: [Small/Medium/Large]`

### User stories — end-user altitude, NOT restated unit tests

Keep the literal `### Story <N>: <title>` form — downstream parsers
(`/fix-issue` pre-flight, the code reviewer's User Story Verification) match on
it.

A story describes **an actor interacting with the system and the outcome they
experience**. It must be implementation-agnostic — still correct even if the
internal design changes completely.

**The test:** if a story reads like the name of a `test_*` function, or
mentions a function, kwarg, `file:line`, or "a default is centralized so no
endpoint can omit it" — it is written too low. Rewrite as **persona + intent +
observable outcome**. All mechanical detail belongs in the acceptance
criteria.

- ❌ Too low: "A centralized default `max_execution_time` is applied by the DB
  client so no endpoint can omit it."
- ✅ Right altitude: "As an API consumer hitting any endpoint, when a query is
  slow my request fails fast with a clear `408` instead of hanging — the same
  way on every endpoint."

Include **at least one error/edge-case story**, not just happy paths.

### Acceptance criteria — bidirectional trace

Every criterion references at least one story, and every story is referenced
by at least one criterion. Use a bold `**Story N:**` prefix so the trace is
visible at a glance.

```markdown
- [ ] **Story 1 (happy path):** [testable criterion]
- [ ] **Story 1 (edge case):** [testable criterion]
- [ ] **Story 2 (error case):** [testable criterion]
- [ ] **Story N (tests):** [specific test types required]
```

### 🔒 Gate B — story + AC sign-off

Blocks `gh issue create`. Before Step 6:

1. Verify **at least one concrete user story** plus **at least one error/edge
   story**, each using the literal heading form.
2. Verify every criterion is testable and carries the `**Story N:**` prefix,
   and every story is covered by at least one criterion — no orphans in either
   direction.
3. **Write the full draft issue body to a file** before asking:
   `{{DEV_DOCS_DIR}}/<TASK-KEY>/issue-draft.md`, or `{{DEV_DOCS_DIR}}/<slug>/issue-draft.md`
   with no tracker key. When the work is split, one file per issue in
   dependency order: `issue-draft.md`, `issue-draft-2.md`, … Resolve the
   file's absolute path (`$(git rev-parse --show-toplevel)/…`) and use the
   literal path in the question.
4. Ask for sign-off with one `[product]` `AskUserQuestion` question per issue.
   The question text contains the issue title and, **verbatim from the draft
   file**:
   - every `### Story N:` heading with its story text;
   - every acceptance criterion with its `**Story N:**` prefix;
   - the draft file's absolute path, for the full body;
   - every architecture decision with a consequence the user will notice,
     one line each, or "none";
   - **"Assumed defaults (change any)"**: every product decision taken as a
     default, one line each, or "none".

   It never says "these stories" or "the draft" without them: the reader may
   see nothing but the question. Options: approve as drafted (first,
   ` (Recommended)`), and request changes (the user types what to change).
   For example:

   ```text
   question: "[product] Sign-off for the GitHub issue drafted from ABC-31,
     'Search endpoint for accounts'. Full draft:
     /work/repo/{{DEV_DOCS_DIR}}/ABC-31/issue-draft.md

     ### Story 1: Find an account by name
     As a support agent, I type part of an account name and see matching
     accounts within a second, so I can open the right one.
     ### Story 2: No match
     As a support agent, when nothing matches I see an empty result, not an
     error.

     - [ ] **Story 1:** GET /accounts?name=acm returns accounts whose name
       contains 'acm', case-insensitive, p95 < 200ms on the test dataset.
     - [ ] **Story 2:** an unknown name returns 200 with an empty list.

     Assumed defaults (change any): result order is by name, A to Z.

     Do these stories and criteria capture it?"
   header: "Sign-off"
   options:
     - label: "Approve as drafted (Recommended)"
       description: "The issue is created with exactly these stories and
         criteria; /fix-issue builds and verifies against them."
     - label: "Request changes"
       description: "Nothing is created yet. Type what to add, remove or
         sharpen; I revise the draft file and ask again."
   ```

5. Wait for an explicit yes. If changes are requested, revise the draft file
   and re-confirm with a new question that again carries the full stories and
   criteria. If the user changed an assumed default, update its line in
   `decisions.md` to the new choice and `decided by: user` first.

If the work is split across multiple issues, **each** must clear this gate,
with its own question.

### Quality checklist — apply to every issue before creating

1. Could a developer (or `/fix-issue`) start on this today? If not, what's
   missing?
2. Could two developers independently implement this and arrive at similar
   solutions? If not, it's too ambiguous.
3. Can every acceptance criterion be verified with a test?
4. Are there implied requirements not written down? Make them explicit.
5. Does the issue stand alone — no need to visit the tracker, this
   conversation, or any exploration output?
6. **Bugs:** is the exact code that must change cited with file path and line
   numbers? "Fix the query" is not enough. Show before/after for every line,
   and state what adjacent code must NOT change.
7. **Bugs:** is concrete evidence included — the error, the trigger, the
   observed behavior? The implementer shouldn't need to reproduce it to
   understand it.
8. Is the test pattern spelled out — test file, pattern to follow, minimum
   cases?
9. Is the story↔AC trace bidirectional? Orphans in either direction fail.
10. Did both hard gates pass? If either is unmet, stop.

## Step 6: Labels

{{LABELS}}

## Step 7: Create the issue(s)

Create from the draft file Gate B signed off, so the issue says exactly what
the user approved. If you changed anything after sign-off, Gate B wasn't
passed for that text: ask again.

```bash
# Gate B marker: a hash of exactly the body the user signed off. /fix-issue
# checks it before skipping plan approval, so a hand-written or later-edited
# issue can't pass as signed off.
body=$(tr -d '\r' < "<absolute path to the signed-off issue-draft.md>")
sha=$(printf '%s' "$body" | shasum -a 256 | cut -c1-12)
printf '%s\n\n<!-- gate-b-signed-off: %s -->\n' "$body" "$sha" > "<draft dir>/issue-body.md"
gh issue create --repo {{GH_REPO}} \
  --title "<title>" \
  --body-file "<draft dir>/issue-body.md" \
  --label "<labels>"
```

Create in dependency order when there are several, so earlier issues can be
referenced by number in later ones.

## Step 8: Link back and confirm

Comment the GitHub issue URL(s) back on the source task where the tracker
supports it, then summarize for the user: issue number(s), title(s), labels,
size, and the dependency order.

## Error handling

- **Tracker CLI unavailable** — fall back to MCP tools, then to asking the
  user to paste the content. Do not invent task details.
- **`gh` not authenticated** — surface `gh auth status` and stop; do not
  attempt a partial create.
- **Task too vague** — that is what Gate A is for. Grill, don't guess.
- **Task too large for one issue** — Step 4; propose a split with explicit
  dependencies.
