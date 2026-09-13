# Task <N>: <one-line title>

Fill every angle-bracket slot. Delete nothing. Dispatch with an explicit
`model:` and never with `name:`.

---

**Where this fits:** <one line: what the branch is doing and why this task exists>

**Worktree (absolute):** `<~/code/<repo>/.koh/<branch>>`
Work only inside it. Do not `cd` out of it, do not touch the parent checkout.

**Read first, it is your requirements:** `<workspace>/task-<N>-brief.md`
Use its exact values verbatim: numbers, magic strings, signatures, test cases.
Do not read the whole plan file.

**Interfaces from earlier tasks that your brief cannot know:**
<the signatures, table names, flags, component props other tasks settled; or "none">

**Ambiguity already ruled on by the coordinator:**
<the ruling, or "none">

**Global constraints (binding):**
<copied verbatim from the plan's Global Constraints or the spec>

**Tests:** write the failing test first, confirm RED, implement, confirm GREEN.
Name the covering test files in your report with the command and its output.

**Commit:**
```bash
git commit -m "<msg>" -- <explicit file list>   # pathspec on the COMMIT
```
Never `git add -A` or `git add .` (a concurrent agent's staged files land in
your commit otherwise). Never `--no-verify`. **Never push.** The coordinator
pushes once, at hand-off.

**Commit trailer, matched to YOUR model:**
```
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: <session url>
```
If that trailer does not name the model you are actually running on, correct it
to your own model and say so in your report. (On BLO-1667 a Fable trailer was
copied into 13 Opus briefs.)

**No fan-out:** do not dispatch subagents, helpers, or your own reviewer.
Review comes from the coordinator after your report.

**Report protocol:** write your full report to `<workspace>/task-<N>-report.md`
(status DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED, commits with SHAs,
files touched, test command and output, concerns). Make your LAST action a
SendMessage containing only: the report path, a one-line verdict, and
Critical/Important/Minor counts. Never paste the report inline. Never write a
report as plain assistant text mid-task.
