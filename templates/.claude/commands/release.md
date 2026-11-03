# Release

Run the release chain for {{PROJECT}}: **pin the target → show what ships →
gate → cut → deploy → verify what serves → report**.

`$ARGUMENTS` may contain a target SHA or a release tag. If empty, the target is
the current `origin/{{DEFAULT_BRANCH}}` HEAD.

<!--
TEMPLATE. Replace before use:
  {{PROJECT}}          human name of the codebase
  {{GH_REPO}}          owner/repo for gh commands
  {{DEFAULT_BRANCH}}   the branch releases are cut from
  {{MIGRATIONS_PATH}}  where schema migrations live, e.g. "db/migrations/"
  {{RISKY_PATTERN}}    a grep -E pattern for your highest-blast-radius commits,
                       e.g. "pricing|billing|credit|auth"
  {{RELEASE_GATE}}     the check a target must pass first, e.g. a nightly
                       suite run ON THAT SHA
  {{DEPLOY_STEPS}}     every deploy step publishing a release does NOT do
  {{SERVING_CHECK}}    how to prove which version is serving
  {{ROLLBACK}}         how to roll back
This is a skeleton: Steps 3, 6 and 7 are yours to fill. Keep the rest. Each
rule below is a failed or half-finished release.
-->

## Why this command exists

Releases fail in the same few ways in every pipeline:

1. **A gate that checks freshness instead of the SHA.** A green run from an
   hour ago says nothing about a target that moved one commit since. Key every
   gate on the exact target SHA.
2. **"Released" is not "deployed".** A published release often runs only part
   of the deploy (migrations, images) and leaves a manual step, such as an
   image tag in another repo. A fully green release workflow with production
   still on last week's code is the expected outcome if you stop there.
3. **The default branch drifts while you work.** Between choosing a target
   and cutting the release, more commits land. Cut from a pinned SHA, never
   from "latest".
4. **"It responds" proves nothing.** A 200 from production doesn't say which
   build served it. Verify the version that is actually serving.

## Progress tracking

Create a `TaskCreate` list for Steps 0–8 and update it as you go. Do not mark
Step 7 complete while production still serves the old version.

### Step 0: Pin the target and REFUSE to guess

```bash
git fetch origin {{DEFAULT_BRANCH}} --tags -q
TARGET=$(git rev-parse origin/{{DEFAULT_BRANCH}})   # or the SHA/tag from $ARGUMENTS
echo "target: $(git rev-parse "$TARGET^{commit}")"
```

If `$ARGUMENTS` names a tag, resolve it to a SHA and **state both**. Never
proceed on an ambiguous target: every later gate keys off this exact SHA.

### Step 1: Show the user what is actually shipping

```bash
LAST=$(gh release list --repo {{GH_REPO}} --limit 1 --json tagName --jq '.[0].tagName')
git log --oneline "$LAST".."$TARGET" | cat
git rev-list --count "$LAST".."$TARGET"
# Migrations: these run against the production database.
git diff "$LAST".."$TARGET" --name-only -- {{MIGRATIONS_PATH}}
# The highest-blast-radius commits.
git log --oneline "$LAST".."$TARGET" | grep -iE '{{RISKY_PATTERN}}'
```

**Stop and ask for explicit confirmation** (`AskUserQuestion`, naming the
files and commits) if the window contains a migration, a commit matching the
risky pattern, or more than ~20 commits. A release is rarely "just my
change": the person who asked for it usually has one PR in mind while the
window holds dozens. Never infer authorization for a billing migration from a
request to ship a UI fix.

### Step 2: Check that the target is a sensible cut point

```bash
git log --oneline "$TARGET"..origin/{{DEFAULT_BRANCH}} | cat   # commits AFTER the target
```

If commits after the target continue work that starts before it (the same
issue number, the same scope prefix, messages like "finish the sweep" or
"restore X after Y"), **say so and recommend moving the target forward**.
Shipping the middle of a correction sequence is worse than shipping neither
end: that is how a change reaches production without its follow-up fix.

### Step 3: Run the release gate ON THE TARGET

{{RELEASE_GATE}}

Run it on `$TARGET`, not on whatever ran last. If the gate fails, read the
error before anything else; never reach for a "skip the gate" switch for a
release that carries a migration.

### Step 4: Cut the release

Cut it from `$TARGET` explicitly (`gh release create <tag> --target "$TARGET"`),
never from the branch name. **Verify the SHA match immediately before
publishing, not after**: `git rev-parse "<tag>^{commit}"` must equal
`$TARGET`. That check turns a three-step recovery into a one-step release.
When a stranded tag (a failed earlier release) sits between the last deployed
release and this one, pass the notes' start tag explicitly, or the generated
notes silently omit everything before it.

### Step 5: Watch the release workflows

```bash
gh run list --repo {{GH_REPO}} --event release --limit 5 \
  --json databaseId,workflowName,status,conclusion
```

Watch every workflow the release fires until it concludes. A deploy job that
shows `skipped` means **nothing shipped**: a published tag alone is not a
deploy.

**After a failed release that contained migrations, verify they were applied
later.** A pipeline that decides whether to migrate from the diff between
release tags leaves a failed release's migrations outside the next release's
range: if that next window touches no migration path, the migration step is
skipped and the backlog silently persists. Check that the step actually ran,
and run it by hand if it didn't.

### Step 6: Deploy steps the release doesn't do

{{DEPLOY_STEPS}}

For each value you pin by hand (an image tag, a version in a manifest),
**verify the rendered result, not the line you edited**: an override
elsewhere can silently shadow it, and CI in another repo may not check it.

**Announce every wait for a human.** When a step waits for someone else (a
review of a deploy PR, an approval), say so in one line before you start
polling: who, on what, and how you'll know it's done. Silent polling looks
exactly like a hang to whoever is watching the session.

### Step 7: Verify what is actually serving

{{SERVING_CHECK}}

Prove the version, not the status code: an image tag reported by the running
workload, a version endpoint, or a content hash only this release has. Then
smoke the actual change from the release.

- **Quote your shell variables** in these checks. An unquoted multi-line
  variable splits on newlines, builds a malformed URL, and returns zeros that
  look exactly like "the fix isn't deployed".
- **One check mid-rollout is not evidence of failure.** During a progressive
  rollout the old version still serves some traffic. Re-check after the
  rollout reports it converged before concluding anything.

### Step 8: Report honestly

State: target SHA, tag, commit count, migrations applied, the deployed version
before → after, and what was smoke-verified. If any step was skipped or
couldn't be verified, **say which and why**: a release report that implies
verification which did not happen is worse than one that admits a gap.

## Rollback

{{ROLLBACK}}

Prefer reverting the change and cutting a patch release over editing
production by hand.
