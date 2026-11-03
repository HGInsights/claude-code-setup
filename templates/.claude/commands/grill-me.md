Interview me relentlessly about a plan, design, or idea until we reach
shared understanding. Topic: $ARGUMENTS (ask if empty).

<!--
TEMPLATE. Replace before use:
  {{DEV_DOCS_DIR}}   where dev docs live, e.g. "docs/dev/active"
  {{ARCH_DOCS}}      the docs that record your architecture decisions
This is the front half of /fix-issue: use it before filing an issue, while the
thinking is still fuzzy. Every question follows
.claude/skills/runbooks/operator-questions.md.
-->

Step 1: Get a detailed description: the problem, solutions considered,
        known constraints, what they're unsure about. When you have to ask
        for it (or for the topic), ask a `[product]` question per
        `.claude/skills/runbooks/operator-questions.md` with the options
        "I'll describe it below (Recommended)" (the user types into the
        free-text answer) and "Stop for now".

Step 2: Explore the codebase and {{ARCH_DOCS}} FIRST. Never ask the user
        something the code or the docs already answer. Verify claims about
        current state, find existing patterns, identify constraints they
        didn't mention. Delegate broad exploration to an `Explore` subagent
        on Haiku.

Step 3: Systematic interrogation. Every question follows
        `.claude/skills/runbooks/operator-questions.md`: asked with
        `AskUserQuestion` (never a plain-text question), starting with one
        tag (`[product]`, `[architecture]`, `[technical]`), answerable on its
        own (it names the topic and gives artifacts by absolute path), one
        decision per question. Route by tag:
  - `[product]`: ask the user, unless it qualifies as an assumed default
    (`operator-questions.md` → Assumed defaults); list those in Step 4
  - `[architecture]`: run the `decision-consult` agent once, then ask the
    user, showing both positions and whether they agree
  - `[technical]`: run `decision-consult` instead of asking; only a
    disagreement that survives 2 exchanges reaches the user
  - Write each decision to `{{DEV_DOCS_DIR}}/<topic>/decisions.md` as soon as
    it is made (consult-settled, answered, or taken as a default); a resumed
    session re-reads it and doesn't re-ask anything in it
  For each topic area:
  - Ask ONE question at a time; never dump a batch
  - Provide a recommended answer with each question, as the first option,
    labeled "(Recommended)"
  - Resolve dependencies first (nail down A before asking about B)
  - Challenge assumptions; play devil's advocate even on reasonable answers
  - Be specific: "How will you handle X?" beats "What about error handling?"

  Cover: problem framing, solution alternatives and what was ruled out,
  architecture fit and failure modes, explicit scope boundaries, edge cases
  and rollback, validation and success metrics, sequencing and blockers.

Step 4: Synthesize: shared understanding, decisions and rationale,
        remaining risks, next steps. List "Assumed defaults (change any)".
        Include "Decisions settled with the second reviewer": one line per
        technical decision the consult settled, each ending in
        `second reviewer: external` or `second reviewer: in-model`
        (`operator-questions.md` → Recording decisions).
        Then ask one `[product]` `AskUserQuestion` per the contract. The
        synthesis text may not be visible where the question is read, so the
        question itself carries the "Assumed defaults (change any)" list (or
        "none") and the one-line decisions. Options: "Write it to plan.md
        (Recommended)" (saved to `{{DEV_DOCS_DIR}}/<topic>/plan.md`) and
        "Change something first" (the user types which default or decision
        to change; update its line in `decisions.md` to `decided by: user`
        and ask again).

Rules:
- Always recommend; never just ask "What do you think?"
- Never end a turn with a plain-text question; use `AskUserQuestion`
- Read the code before asking
- Know when to stop: consistent, specific, confident answers means done
