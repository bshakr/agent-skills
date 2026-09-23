---
name: pr-handover
description: Coordinator-owned tail of shipping a ticket. Runs after implementation and review are done: verifies HEAD, re-runs the gates itself, rebases, checks for duplicate PRs, dispatches the screenshot capture agent, builds and publishes the gallery Artifact, pushes, opens the PR from the template, waits for CI, verifies mergeability, backlinks Linear and the gallery, and arms the merge watch. Invoke when the user says "open the PR", "hand this over", "finish the PR", "/pr-handover", or when ship-ticket reaches Step 8.
user-invocable: true
argument-hint: "<TICKET-ID> [worktree-path]"
version: 1.0.0
repo: https://github.com/bshakr/agent-skills
skill_path: pr-handover
---

# PR Handover (coordinator tail)

**You, the coordinator, run every step of this skill.** Never delegate the skill
itself; the only delegation is the one capture agent in Step 4. Every
codified-rule violation in the one-month retro happened in this tail, which is
why it is mechanical now.

Prerequisite: implementation is committed and `/review` (or `review-ledger`) has
run on the current HEAD. If either is untrue, stop and go back.

## Step 0 — Entry check (on disk, not from an agent's word)

```bash
cd <worktree>
git rev-parse HEAD                    # record as HEAD_SHA
git status --porcelain                # MUST be empty
git log --oneline -5
```

- Dirty tree: an agent is mid-write or a fix was never committed. Commit with an
  explicit pathspec on `git commit`, or stop. Never push a dirty worktree.
- **The review SHA line must exist for THIS HEAD.** You must be able to state
  "`/review` ran on `<HEAD_SHA>`, N findings addressed (or 0 findings)". If the
  recorded SHA is older than HEAD, re-run review on HEAD or state in the PR body
  that the later commit was only the auto-fix batch from the recorded SHA. No
  review line for this HEAD means go back to review, not forward.
- An agent saying "done" is not evidence; `git log`, `git status` and the file
  are.

## Step 1 — Re-run the gates yourself

Never accept agent-attested green. Run each gate yourself and read the output.

- Tests: the full suite, or the smallest scope provably covering the diff.
  Rails/api: `PARALLEL_WORKERS=1 bin/rails test` (the bare command segfaults the
  pg gem). Node: match the lockfile in that directory, `pnpm` where
  `pnpm-lock.yaml` exists, `npm` where `package-lock.json` does.
- Lint changed files: `bundle exec rubocop -f simple <files>`, `pnpm lint`,
  `ruff` / `black --check`.
- `tsc --noEmit` wherever TypeScript is involved. **`pnpm build` does not
  typecheck `__tests__/`**: vitest transpiles past TS errors, so two lanes once
  declared gates green with broken types and CI caught it.

**Piping hides failures.** A pipe once masked a red suite and the red commit got
pushed. When you pipe, print the real exit code:

```bash
bin/rails test 2>&1 | tail -40; echo "EXIT:${pipestatus[1]}"   # zsh
# bash: echo "EXIT:${PIPESTATUS[0]}"
```

`EXIT:0` or it did not pass. Same for `git fetch ... | tail`, which reports
`tail`'s status.

## Step 2 — Rebase on origin/main

```bash
git fetch origin main --quiet
git log --oneline HEAD..origin/main     # what landed since the branch point?
git rebase origin/main
```

Resolve conflicts deliberately, never `--skip`. If risky, `--abort` and ask.
**Re-run Step 1 after any non-trivial rebase** (anything beyond a clean
fast-forward). Re-record `HEAD_SHA` after the rebase.

## Step 3 — Duplicate-PR check

```bash
gh pr list --search "<TICKET-ID>" --state all --json number,title,state,url,author
```

Whole repo, all states, not just your own PRs and not just open ones: two Claude
accounts once shipped the same tickets in parallel. A hit means continue on that
PR's branch, or stop and report the collision. Never open a second PR for a
ticket that already has one.

## Step 4 — UI decision and capture

Decide from `git diff --name-only origin/main...HEAD`, not from the ticket text.
Touching components, pages, routes, styles, templates, views, copy or anything
rendered? It is a UI PR. Otherwise write the literal line
`No user-visible surface (API only)` into the Screenshots section and go to
Step 6. Skip explicitly; silence reads as an omission.

A UI-path diff that renders nothing differently (a refactor, a build-config or
CSS change whose built output drops only unused rules) is not captured either
(Bassem, 2026-09-23): write `No visual change: <evidence>` as the Screenshots
section's first line, the evidence being something checkable such as the
built-CSS diff. The stop hook accepts that line in place of a gallery.

**Scope the matrix to changed surfaces** (Bassem, 2026-09-18). Build the
`routes` list from the components the diff touches (follow imports up to the
page), not from every route the app has. Exactly one control pair of an
unchanged surface, proven by md5. Flag-off pair only when the PR adds or
changes a flag gate. `390x844` only when layout or CSS changed. A copy-only
edit is one pair on the one screen. The same rule governs re-capture: after
review fixes or a rebase, `git diff --name-only <old-sha>..HEAD` against the
captured surfaces decides which after-shots to redo; none moved, none redone.

For a UI PR, dispatch **ONE** capture agent (never two, never a fan-out) running
the `capture-pairs` skill:

- `model: "sonnet"` for a routine matrix, `opus` when the surface needs judgment.
  Pass `model` explicitly. Never pass `name:` (report-routing bug, Claude Code
  #81439).
- Brief carries: worktree path, branch, **the true fork point SHA**
  (`git merge-base origin/main HEAD`) as the base ref, never the string "main";
  routes and states matrix; tenant subdomain and login method; viewport(s);
  theme(s); on AND off variants of every flag gate the PR adds or changes;
  output dir. End it with the
  report protocol: "Write your full report to `<dir>/VERDICT.md` and make your
  LAST action a reply containing only: the path, a one-line verdict, and
  Critical/Important/Minor counts."
- **FREEZE rebases while it runs.** A rebase under a running capture invalidates
  the base SHA and the before shots. If main moves, wait; rebase after Step 5.

When the verdict lands: **never `Read` a PNG** (image reads are the largest
context consumer), read `VERDICT.md` and `manifest.json` only, and check the
manifest covers **every changed surface** from `git diff --name-only`, including
the **flag-off pair** when the PR adds or changes a flag gate, and every state the
diff implies (empty, populated, loading, error). A missing surface goes back to the same agent; do
not paper over it. Gaps that genuinely cannot be captured are named in
`VERDICT.md` and repeated in the PR body with what you did instead. `TaskStop`
the agent once its terminal report is in.

## Step 5 — Gallery

`rp-gallery <dir>/manifest.json --out <dir>/gallery.html`, then publish
`gallery.html` with the **Artifact** tool: `title` = ticket id plus the surface
(for example "BLO-1666 member dashboard"), a `favicon`, a one-sentence
`description`. **Publish at the first usable state**; when late shots arrive,
re-run `rp-gallery` and republish to the **same URL** (pass its `url`). Never
publish a second copy.

## Step 6 — Push and open the PR

```bash
git push -u origin <branch>
gh pr create --title "<TICKET-ID>: <one-line summary>" --body-file <body.md>
```

Fill `templates/pr-body.md` from this skill directory. Non-negotiable in it:
Screenshots section first line is the gallery URL,
`No user-visible surface (API only)` or `No visual change: <evidence>`; the
`- [x] /review ran on <SHA> — <N findings ...>` line; `Fixes <TICKET-ID>` so
Linear auto-closes; every PR and ticket reference a full clickable URL,
including inside tables; the Claude Code attribution footer.

## Step 7 — The body is now append-only

```bash
pr-append-section <pr> --title "## Screenshots" --file section.md --replace
```

`pr-append-section` is the **only** way to touch the body after creation. It
re-fetches the live body immediately before writing and verifies the result
byte-for-byte. **Never `gh pr edit`** (it reports success and silently discards
body, title and label edits), and **never rebuild the whole body from a
snapshot**: a stale-snapshot rebuild destroyed the gallery link on
[core #35](https://github.com/ritualpass/core/pull/35), and a read-back that
greps only for its own additions can never detect what it deleted.

## Step 8 — CI

```bash
pr-ci-wait <pr>            # run_in_background: true
```

Never `gh pr checks --watch` in the foreground, and never a ScheduleWakeup
beside it — the background exit is the wake. Handle the exits:

| Exit | Meaning | What you do |
|---|---|---|
| 0 | all green | continue to Step 9 |
| 1 | a check failed | fix it in the worktree, commit, push, re-run `pr-ci-wait`. Never hand over red |
| 2 | timeout | **never hand over.** Report "CI still running", re-run `pr-ci-wait` in the background |
| 3 | PR not found / not open | someone merged or closed it. Go to wave §3 |

A required check reporting `skipped` is NOT green; `pr-ci-wait` warns and names
it. An org billing failure once made jobs never start and downstream checks
report skipped, which reads as red-but-mergeable.

## Step 9 — Mergeability

```bash
gh pr view <pr> --json mergeable,mergeStateStatus,state
```

Required: `mergeable: MERGEABLE` with `mergeStateStatus` `CLEAN`, or `BLOCKED`
solely because a human review is required. `CONFLICTING` / `DIRTY` means rebase
on origin/main, re-run Step 1, `push --force-with-lease`, re-run Steps 8 and 9.
Bass reported the conflict first four times out of four; do not let him be the
one who notices. **Stacked PRs:** squash-merging a base retargets the stacked PR
and conflicts ([api #540](https://github.com/ritualpass/api/pull/540),
[api #561](https://github.com/ritualpass/api/pull/561)), so re-check
mergeability on every open wave branch after any merge.

## Step 10 — Backlinks and records

1. Re-run `rp-gallery` with `pr_url` filled in, republish to the **same**
   Artifact URL. The artifact is not finished until the PR backlink is in.
2. `linear issue comment <TICKET-ID> "..."` with the full PR URL and the full
   gallery URL. Both clickable.
3. Memory write **only** for a non-obvious learning (a new trap, a fixture
   relationship, a tool that lies). Routine runs write nothing.

## Step 11 — Hand the merge watch to a background process (wave §2)

Merges and conflicts get detected without Bass typing them, and without a turn
spent waiting. With the ready report:

```bash
pr-merge-wait <pr> [<pr> ...]   # run_in_background: true, then END THE TURN
```

It is silent while every watched PR stays open and clean, and wakes you exactly
once — when there is something to do. **Never** arm ScheduleWakeup, `/loop` or
Monitor to wait on a human decision: each wake is a whole coordinator turn that
re-reads 300–400k of context to report "still open, still clean" (51 of them
measured on 2026-09-20). A background watch armed and the turn ended is not
idling; it *is* the watch.

| Exit | Meaning | What you do |
|---|---|---|
| 0 | merged, SHA printed | **wave §3:** `git fetch origin main`, rebase every remaining open wave branch and re-verify its CI, start the next serialized ticket off the NEW origin/main, post an unprompted rollup, leave merged worktrees in place and suggest `gwt-prune-merged` (dry run) at wave end |
| 2 | gh or usage error | fix the invocation, re-arm |
| 3 | closed unmerged | report it; ask Bass before reopening or re-pushing |
| 4 | conflicting / behind | `git fetch origin main` first (a wave-mate landed), rebase that branch on origin/main, `push --force-with-lease`, re-run Steps 8–9, re-arm |
| 5 | timeout, still open and clean | re-arm in the background if the wait should continue |

## Hard gate — before the word "ready" is used

| Must be true | Check |
|---|---|
| Gallery Artifact URL is the first line of `## Screenshots` (UI diff) | open the PR body |
| API-only PRs say `No user-visible surface (API only)`; a UI-path diff with no rendered change says `No visual change: <evidence>` | open the PR body |
| Every changed surface covered, flag-off pair where the PR adds or changes a flag gate | `VERDICT.md` vs `git diff --name-only` |
| CI green | `pr-ci-wait` exit 0 |
| `mergeable: MERGEABLE` (CLEAN, or BLOCKED only by review requirement) | `gh pr view --json` |
| `- [x] /review ran on <SHA>` present and matching HEAD | PR body vs `git rev-parse HEAD` |
| Every PR and ticket reference is a full clickable URL, tables included | read the body |
| The merge watch is a background `pr-merge-wait`, never a wakeup | the Bash call carries `run_in_background: true` |

Any row unmet: the report leads with **"DO NOT MERGE YET"** and names the open
item. All rows met, the last line is verbatim:

> review clean, CI green, ready to merge — want me to?

Then **wait**. Stating intent is not consent, silence is not consent, and
authorization from a previous wave does not carry forward.

## Status rollups

While `pr-ci-wait` or a capture agent is running, post a **one-line status every
~10 minutes of wall clock, unprompted**: what is running, elapsed, next step.
Never end a turn "waiting to hear back", never make Bass ask "how's it going?".
Idle is not finished.

## What NOT to do

- **Never merge.** Merge is auto-deploy to production and is the one step that is
  never yours. Same for anything else that deploys or publishes.
- **Never add labels.** `deploy.yml` was deleted (BLO-1407); `staged` triggers
  nothing. Staging tracks `main`.
- **Never `gh pr edit`**, never rebuild a PR body from a snapshot, never publish
  a second copy of a gallery instead of republishing in place.
- **Never `Read` a PNG** as coordinator, and **never commit PNGs to the branch**:
  on a private repo camo cannot fetch them, so the hosted gallery is the
  compliant form. Stage the PNGs in a folder and note the path in the PR.
- **Never hand over red or pending CI**, and never say "ready" with a gate row
  unmet. Bass should never be the one who notices red CI.
