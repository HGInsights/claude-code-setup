# Create PR

Open a pull request for the current branch, with a title that follows the
repo's convention and a body that reproduces the repo's PR template.

<!--
TEMPLATE. Replace before use:
  {{GH_REPO}}          owner/repo for gh commands
  {{DEFAULT_BRANCH}}   e.g. main
  {{DEV_DOCS_DIR}}     where /fix-issue keeps per-issue dev docs
Then fill in `## Repo specifics` at the end. Sections 1-7 are meant to stay
identical across your repos: when several repos share this command, change them
together and keep every difference in `## Repo specifics`.
-->

## Inputs

All optional.

- `$ARGUMENTS`: a title override, or an issue number.
- `base: <branch>`: the branch to diff against and open the PR into. Default
  `{{DEFAULT_BRANCH}}`; a stacked PR names its parent branch.

## 1. Check the branch

1. Never work on the base branch, and never push to it.
2. Commit everything first. `git status` (never `-uall`) must be clean.
3. In a worktree the branch is often named after the directory, not the work.
   Push it under a descriptive name so the PR head reads well:
   `git push -u origin HEAD:<type>/<topic>`.

## 2. Gather the changes

1. Run `git fetch origin <base>` on its own first.
2. Then, in parallel: `git log origin/<base>..HEAD --oneline`,
   `git diff origin/<base>...HEAD --stat`, and the full
   `git diff origin/<base>...HEAD` for the files you need.
3. **Always compare against `origin/<base>`, never a bare `<base>`.** A local
   base branch only moves when someone pulls it in the primary checkout, so in
   a worktree it is often several commits stale. Diffing against it describes
   commits that already landed as part of this PR.
4. Read ALL commits on the branch, not just the last one.

## 3. Read the linked issue

1. Find the issue number: `$ARGUMENTS`, the branch name (`*/issue-<N>-*`), or
   `Closes #<N>` in a commit message.
2. `gh issue view <N> --repo {{GH_REPO}} --json title,body,labels`.
3. If `{{DEV_DOCS_DIR}}/issue-<N>/context.md` exists, read its
   `## Implementation Summary` and its review sections: the body carries them
   (section 5).
4. No linked issue: say so, and write `N/A` in the template's issue-dependent
   sections.

## 4. Write the title

1. Follow the title convention in `## Repo specifics`. With none given, use
   `<type>(<scope>): <summary>`: `<type>` one of `feat`, `fix`, `chore`,
   `docs`, `refactor`, `test`, `perf`, `ci`; `(<scope>)` the area touched,
   optional; `<summary>` lowercase, no trailing period, under 70 characters.
2. Never put `#<N>` in the title; it goes in the body.
3. `$ARGUMENTS` given as a title overrides all of this.
4. Use plain ASCII (`->`, not `→`). Title checks in CI and some tools choke on
   anything else.

## 5. Write the body

1. Read `.github/pull_request_template.md` if it exists.
   **`gh pr create --body` replaces GitHub's template auto-fill**, so the body
   MUST reproduce every section, in order, with the same headings. Do not skip
   or rename sections.
2. Fill every section from the diff and the issue. `None`, `No` or
   `N/A: <reason>` are valid answers; a blank is not. A blank reads as "forgot",
   and a reviewer can't tell it from "checked, nothing to say".
3. **Summary**: built from all commits. Say what did NOT change when the scope
   could be misread.
4. **Linked issue**: `Closes #<N>`.
5. **Tests**: one line per story or behavior criterion, naming the test
   (`file › test name`) or the manual steps and why they were manual. None
   added: `No new tests: <reason>`.
6. **Review record**, when `/fix-issue` ran: each review loop's rounds and
   reviewer (`r1 external, r2 in-model, ...`), the findings accepted as-is and
   the unresolved or deferred ones from `context.md`, each with its reason. If
   every round of a loop fell back to `in-model`, say so plainly: the second
   reviewer never ran.
7. Fill the repo's own sections as listed in `## Repo specifics`.

## 6. Push and create

1. Push with `-u` if the branch does not track a remote yet. Never force-push
   unless asked, except the `--force-with-lease=<branch>:<old head>` push after
   rebasing onto the PR's base (`/fix-issue`,
   [Bringing a PR branch up to date](fix-issue.md#bringing-a-pr-branch-up-to-date)).
   Never merge the base into the branch, and never open a new branch or PR to
   get around a conflict. Every other push is a plain `git push`.
2. Create the PR, body in a quoted HEREDOC so nothing in it is expanded:

   ```bash
   gh pr create --repo {{GH_REPO}} --base <base> --title "<title>" \
     --body "$(cat <<'EOF'
   <filled-in template>
   EOF
   )"
   ```

3. Print the PR URL.

## 7. After the PR

Run the repo's after-PR step from `## Repo specifics`, if it has one.

## Repo specifics

<!--
Everything that differs per repo goes here, so sections 1-7 can be shared.
-->

| Key | Value |
| --- | --- |
| Repo | `{{GH_REPO}}` |
| Default base | `{{DEFAULT_BRANCH}}`, or the `base:` input (stacked branches) |
| Title convention | e.g. conventional commits, or a `(ABC-123)` key suffix |

**Template sections only this repo has:** e.g. a validation checklist (tick
only the commands you actually ran), user story verification (one
`- **Story N:** <evidence>` bullet per story), rollout or revert notes.

**After the PR:** e.g. a non-gating summary comment, or nothing.
