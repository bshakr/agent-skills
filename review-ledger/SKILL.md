---
name: review-ledger
description: Coordinator-driven review loop for multi-task work implemented by parallel subagents. Runs a blocking pre-flight plan scan, writes one brief per task, drives first review, consolidated fix batch and scoped delta re-review, and records every ruling in a ledger file. Invoke for "review the wave", "coordinate these tasks", "run the review ledger", or any plan with 3+ tasks dispatched to subagents. For a single diff use /review instead.
user-invocable: true
version: 1.0.0
repo: https://github.com/bshakr/agent-skills
skill_path: review-ledger
---

# Review Ledger

You are the coordinator. Subagents implement and review; you rule, verify on
disk, and record. Built from the BLO-1667 run (13 tasks, 26 pre-flight
findings, 8 fix rounds) which found real defects: secrets printed by
`masked_url`, a rack-attack throttle bypassed by a `.json` suffix, a
`PG::CardinalityViolation`. None of those were nits.

## When to use this, and when not to

| Situation | Use |
|---|---|
| One branch, one diff, one author | `/review`. Stop here. |
| A plan with 3+ tasks dispatched to parallel or sequential subagents | this skill |
| An epic split into subtickets sharing a worktree | this skill |
| A fix round on a PR that already has a ledger | this skill, resume at the open task |

This skill is the review half of `superpowers:subagent-driven-development`.
Reuse that plugin's scripts rather than reimplementing them:

```bash
SDD=~/.claude/plugins/cache/claude-plugins-official/superpowers/6.3.0/skills/subagent-driven-development/scripts
$SDD/sdd-workspace PLAN_FILE            # prints the per-plan artifact dir
$SDD/task-brief PLAN_FILE N             # extracts task N's text to a file
$SDD/review-package PLAN_FILE BASE HEAD # commit list + stat + diff -U10 to a file
```

Version-pin drift: if that path is missing, `find ~/.claude/plugins -name task-brief`.
Diffs and briefs go to the reviewer as file paths. Nothing large enters your context.

## Step 0: workspace and ledger

Work inside the ticket's worktree (absolute path, never the parent checkout).
Put the ledger at `<workspace>/ledger.md` from `templates/ledger.md`, first
line naming the plan file. The ledger, not your memory, is the recovery map:
after a compaction trust the ledger and `git log`.

## Step 1: pre-flight plan scan (blocking)

Dispatch ONE agent, `model: "opus"`, before any implementer. It reads the plan
and the spec, and reports to file. It writes code only in the sense of reading it.

It must produce a row per finding for each of these, and say explicitly which
checks it ran:

1. **File collisions across tasks that would run in parallel.** One row per
   pair of tasks sharing a file or an interface: the two tasks, the shared
   path, what one produces against what the other consumes. BLO-1667 had two
   supposedly independent pairs colliding on `Gemfile` and `dashboard.test.ts`.
2. **Files that exist only on `origin/main`, not on this branch** (and the
   reverse). Three tasks targeted files that were not in the worktree.
   Check with `git ls-tree -r --name-only origin/main` against the branch.
3. **Tasks that contradict their own spec or each other.** A `masked_url` task
   specified behaviour its own implementation section contradicted.
4. **Missing test targets.** Every task that claims a behaviour change names
   the test file that will assert it, and that file exists or the task creates it.
5. Anything the plan mandates that the review rubric treats as a defect
   (a test asserting nothing, a duplicated logic block).

Severity is Critical / Important / Minor. **Dispatch is blocked until every
Critical is resolved**: re-sequence colliding tasks into series, correct the
plan text, or record a ruling that says why the item stands. Copy the scan
table into the ledger with your ruling beside each row. "The scan is clean"
without those rows is not a scan you ran.

## Step 2: one brief per task

Compose from `templates/brief.md`. A brief is the task's single source of
requirements; never make a subagent read the whole plan, and never paste
prior-task history into a later brief.

Every brief carries, without exception:

- The **absolute worktree path**, and "do not `cd` out of it".
- The brief file path from `task-brief`, introduced as "read this first".
- **Report protocol** (contract §1): "Write your full report to `<path>` and
  make your LAST action a SendMessage (or final reply) containing only: the
  path, a one-line verdict, and Critical/Important/Minor counts. Never paste
  the report inline; never write a report as plain assistant text mid-task."
- **Commit with an explicit pathspec on `git commit`**, never `git add -A`
  or `.`, and **never push**. The coordinator pushes, once, at hand-off.
- The **Co-Authored-By trailer for the model that agent is actually running
  on**, plus the line "if this trailer does not name your model, correct it
  and say so in your report". On BLO-1667 the Fable trailer was copied into
  all 13 briefs while every agent ran on Opus; four caught it, the rest did not.
- No fan-out: the implementer never dispatches its own subagents, and never
  its own reviewer.

Model policy (contract §2), passed explicitly on every Agent call: `opus` for
implementation and review, `sonnet` for mechanical work and small-diff
re-reviews, `haiku` for `Explore`, `fable` only for design. Never pass `name:`
to Agent (idle-notification routing bug, Claude Code #81439); address agents by
the returned agent_id.

Record BASE (`git rev-parse HEAD`) before each dispatch. `review-package`
needs it; `HEAD~1` silently drops all but the last commit of a multi-commit task.

## Step 3: first review round

One reviewer per task, dispatched after you have confirmed the implementer's
commits exist on disk.

**Reviewer model by diff size.** Count with `git diff --stat BASE..HEAD`:

- `opus` when the diff exceeds 150 changed lines or 3 files, **or** touches
  auth, money, tenancy, migrations, concurrency, background jobs or secrets
  regardless of size.
- `sonnet` below that threshold with none of those surfaces, and for every
  scoped re-review whose fix diff is under 150 lines.

The reviewer gets three paths (brief, implementer report, review package) plus
the plan's Global Constraints copied verbatim as its attention lens. Do not
pre-judge findings for it: "don't flag X" or "at most Minor" in a review prompt
means you are sparing yourself a loop.

It writes `reviews/<task>-r<N>.md` using `templates/review-report.md`:
`## Critical`, `## Important`, `## Minor`, each finding with file:line, what
breaks, and the evidence. It returns only the path, a verdict, and the counts.

**Mutation check, mandatory.** Any finding of the form "this is untested" or
"the test does not assert the behaviour" is unproven until the reviewer has
deleted the guard, the branch or the line and shown the suite still green:
"deleted the 24h cap in X, 7 hook tests still pass". Paste the command and
result into the finding. A test-gap finding without a mutation result is
downgraded to Minor on sight. This is how BLO-1455, BLO-1434 and BLO-1440 were
caught claiming coverage they did not have.

## Step 4: consolidated fix batch, then a scoped delta re-review

**Batch the findings.** One fix dispatch per task carrying every Critical and
Important finding verbatim, not one dispatch per finding. Minors go to the
ledger as deferred, never into the loop. Rounds 1 to 3 resume the original
implementer (its context is intact); rounds 4 and 5 take a fresh implementer
one model tier up, told "a prior implementer attempted this N times; you own
it now, read the report file". Never fix findings yourself: a coordinator fix
skips review.

**The re-review is scoped and is a delta review.** Run
`review-package PLAN_FILE FIX_BASE HEAD` where FIX_BASE is the head the previous
review saw. The re-reviewer does exactly two things:

1. Verdicts each named finding ADDRESSED or NOT ADDRESSED, with the line proving it.
2. Reviews the fix commit **as new code**: did the fix introduce breakage?

Point 2 is not optional and is where the value is. Three shipped-quality
regressions were introduced by fixes and caught only here: an out-of-order
`charge.dispute.updated` permanently suppressing the chargeback email; a race
fix that let a later read cancel an in-flight write so a success toast lied;
a fix that put `paused` into the expiring set, so one response read "0 active
members" beside "1 membership expiring".

New Critical or Important breakage in the fix diff joins the open findings.
Out-of-scope observations go to the ledger as deferred minors and never extend
the loop.

## Step 5: the ledger

One row per task, updated the moment each terminal report lands. Full clickable
URLs for tickets and PRs, inside the table too.

```markdown
| # | Task | First review | C/I/M | Fix SHA | Re-review | Ruling | Status |
|---|------|--------------|-------|---------|-----------|--------|--------|
| 4 | masked_url redaction | reviews/t4-r1.md | 1/2/1 | a7f3c9d | reviews/t4-r2.md | all 3 addressed; minor deferred to BLO-1702 | done |
| 7 | rack-attack throttle | reviews/t7-r1.md | 0/0/2 | - | - | minors deferred, no fix round | done |
```

Statuses: `dispatched`, `reviewing`, `fixing r<N>`, `done`, `parked`.
Below the table keep `Rulings` (one line each:
`Task 7: parked, <finding>, Ruling: <why the code stands>, cost if wrong: <x>`)
and `Deferred minors` for the final review to triage.

## Step 6: stop condition

**Once a round returns only prose or polish with no product defect, stop.**
Wording, comment phrasing, a table row's copy, a naming preference: these are
not another round. BLO-1486 took 10 commits across 4 rounds and 5 separate
declarations of "frozen"; BLO-1487 spent 4 rounds on one table row and the
reviewer wrote "this is the SECOND correction pass on this one table row to
introduce a new false claim". The last two rounds of each were prose, not product.

When you hit it:

1. Freeze the branch. No further fix dispatches.
2. File the remaining items as Linear follow-ups: `linear issue create --title "..."`,
   one per item, linked from the ledger by full URL.
3. **Say so out loud**, in the status line and in the ledger: "frozen at
   `<SHA>`; round 3 returned prose only; 2 items filed as
   https://linear.app/bloombase/issue/BLO-XXXX".

## Coordinator duties

- **Ground-truth every report on disk before ruling.** An agent's "done" is
  checked with `git log --oneline`, `git status --porcelain`, `git show --stat`
  and the report file itself. A crossing between your instruction and an agent's
  report made a coordinator re-issue an instruction already executed, off a
  stale HEAD.
- **TaskStop every agent the moment its terminal report is in.** 41 agents
  accumulated over three hours on BLO-1667 and Bass killed them all.
- **Never narrate an idle notification.** It is not an event. Say nothing.
- **Post an unprompted status line every few minutes** while agents run: tasks
  done / in review / fixing, and what you are doing next. "how's it going?"
  was typed 6 times in one batch.
- Keep working while agents run: update the ledger, package the next review,
  read reports. Never sit in a silent open-ended wait.
- Publish the ledger as an Artifact when it exceeds ~5 tasks, and redeploy to
  the SAME url on every update.

## Hand-off to `pr-handover`

When the ledger shows every task `done` or `parked` and the branch is frozen,
pass exactly four things:

1. **Branch name** and the absolute worktree path.
2. **HEAD SHA** verified with `git rev-parse HEAD` in that worktree.
3. **Ledger path** (and its Artifact url if published).
4. **The review SHA line** for the PR body, which is the gate `pr-handover`
   checks for:
   `- [x] review-ledger ran on <SHA>: <N> tasks, <C>/<I>/<M> findings, all Critical and Important addressed, <K> minors deferred (<ticket urls>)`

Do not push, do not open the PR, do not merge. `pr-handover` owns push through
CI, and merging is never yours to take.

## What NOT to do

- Do not run this for a single diff. That is `/review`.
- Do not dispatch implementers before the pre-flight Criticals are resolved.
- Do not accept a test-gap finding without its mutation result.
- Do not let a re-review skip the delta pass on the fix commit.
- Do not run a fourth round on prose.
- Do not `git add -A`, do not push from a subagent, do not merge.
