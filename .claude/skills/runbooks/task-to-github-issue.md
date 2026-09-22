# Task → GitHub Issue

Turn a task from a tracker (Jira, Asana, Linear, a Slack thread, a plain
paragraph) into a GitHub issue a developer — or `/fix-issue` — can pick up
cold.

## When to use

- "create a GitHub issue from Jira task ABC-123"
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

Gathering context is open-ended — scanning the docs at the repo root
(`setup.md`, `review-loops.md`, `sdlc-standards.md`, `laptop-setup.md`),
`adr/`, `templates/`, `laptop/`, and prior issues for anything related. Do
this via a single `Explore` subagent pinned to **Haiku**, not inline `grep` /
`gh issue list` in the main session. Broad searches in the main context
re-read the whole cached conversation every time at the main model's rate; a
Haiku subagent returns the same result for a fraction of the cost.

This repo is docs-and-templates only — there is no application code, so
"code anchors" here means the shipped artifacts under `templates/` and
`laptop/` and the prose that documents them.

```
Agent({
  subagent_type: "Explore",
  model: "haiku",
  description: "Find related context",
  prompt: "Thoroughness: quick. The task is: <one-paragraph summary including key terms, affected entities, and any referenced endpoints or data sources>.

Return a concise report with four sections:
1. **Related skills / runbooks** — matching files under `.claude/skills/`. Path + one-line summary.
2. **Related ADRs / docs** — matching files under `adr/` or the root-level *.md docs. Path + one-line summary.
3. **Overlapping GitHub issues** — up to 5 on HGInsights/claude-code-setup (open or closed) whose title or body clearly overlaps. Number, title, state, why relevant.
4. **Relevant artifacts** — up to 5 files under `templates/` or `laptop/` the work would touch, and the doc section that describes each. `path:line` with a one-line reason.

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

Present the analysis with `AskUserQuestion`: what is well-defined, what gaps
you found, and your suggested answers.

### 🔒 Gate A — grill until requirements are resolved

Mandatory. You may **not** advance past Step 3 by silently filling gaps with
your own assumptions.

1. Present gaps as a numbered list, each with your recommended answer so the
   user has something concrete to react to:

   ```
   Before I write the issue, I found gaps that need your call:

   1. **Edge case not covered**: what does the endpoint return for an unknown
      input? I'd suggest a 200 with an empty match rather than a 404.
   2. **Success criteria vague**: "should be fast" — I'd propose p95 < 200ms.
   3. **Missing dependency**: this seems to need <X> — is that available?
   4. **Persona unclear**: who is the actor — an external consumer, or an
      internal service?

   For each: accept my recommendation, or give me the right answer.
   ```

2. **Loop, don't one-shot.** If an answer opens a new ambiguity or only
   partially resolves a gap, ask the follow-up. Keep going until every
   material gap is resolved or consciously accepted.

3. Only then mark the gate complete.

Even when the task looks well-defined, surface your read of the requirements
and personas and get an explicit "yes, proceed." Do not skip the gate.

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
3. Show the user the drafted stories and criteria and ask for explicit
   sign-off: *"Do these capture it? Anything to add, remove, or sharpen before
   I create it?"*
4. Wait for an explicit yes. If changes are requested, revise and re-confirm.

If the work is split across multiple issues, **each** must clear this gate.

### Quality checklist — apply to every issue before creating

1. Could a developer (or `/fix-issue`) start on this today? If not, what's
   missing?
2. Could two developers independently implement this and arrive at similar
   solutions? If not, it's too ambiguous.
3. Can every acceptance criterion be verified with a test?
4. Are there implied requirements not written down? Make them explicit.
5. Does the issue stand alone — no need to visit the tracker, this
   conversation, or any exploration output?
6. **Bugs:** is the exact file and line that must change cited? "Fix the
   wrapper" is not enough. Show before/after, and state what adjacent content
   must NOT change. In this repo a "bug" is usually a shipped artifact that
   misbehaves, or a doc that describes something its file doesn't do.
7. **Bugs:** is concrete evidence included — the failing command and its
   output, or the doc line quoted beside the file line that contradicts it?
   The implementer shouldn't need to reproduce it to understand it.
8. **Is the verification spelled out?** There is no test suite here, so say
   how the change will be checked: the shell command to run against a shipped
   script, the `grep -rn '{{'` placeholder sweep, the disclosure scan, or
   `npx --yes markdownlint-cli2` on touched markdown.
9. Is the story↔AC trace bidirectional? Orphans in either direction fail.
10. Did both hard gates pass? If either is unmet, stop.

## Step 6: Labels

This repo uses the default GitHub set. Pick what fits:

- `documentation` — changes to the prose docs (`setup.md`, `review-loops.md`,
  `sdlc-standards.md`, `laptop-setup.md`, `adr/`)
- `enhancement` — a new or improved shipped artifact under `templates/` or
  `laptop/`
- `bug` — a shipped artifact is wrong, or a doc describes something the file
  doesn't do (the staleness class ADR 0002 exists to prevent)
- `good first issue` / `help wanted` — as appropriate
- `question` — a scope or design call that needs a decision before work starts

Most issues here are `documentation` or `enhancement`. If a change touches
both a shipped file and the doc explaining it, label it for the artifact —
that is the part a consumer copies.

## Step 7: Create the issue(s)

```bash
gh issue create --repo HGInsights/claude-code-setup \
  --title "<title>" \
  --body-file <(cat <<'BODY'
<issue body>
BODY
) \
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
