---
name: ship-ticket
description: End-to-end workflow for shipping a Linear ticket. Sets up a fresh worktree off origin/main, plans the work, runs TDD-style implementation, runs /review, addresses findings, and opens a PR. Invoke when the user says "ship X", "tackle the next ticket", "/ship-ticket BLO-XXX", or any phrasing that means "do a whole ticket end-to-end".
user-invocable: true
version: 2.0.0
repo: https://github.com/bshakr/agent-skills
skill_path: ship-ticket
---

# Ship Ticket — End-to-End Workflow

Use this when the user wants a ticket taken from "no branch yet" to "PR opened" without micro-managing each step.

## HARD GATE — `/review` is mandatory

Every ticket, every size, no "diff is small" / "deletions only" / "I already grepped" exception. The only valid post-commit sequence is **rebase → review → fix findings → push**; if the review gate hasn't run on current HEAD, you may not push. The PR body must carry `- [x] /review ran on <SHA> — <N findings | 0 findings>`. Skipping review shipped real regressions in BLO-944, BLO-985 and BLO-986.

## Defaults you no longer need to be told

Bass typed this topology at the start of six sessions. It is the default. Don't ask for it, don't restate it back.

- **Implementation runs in subagents on `model: "opus"`.** You plan, brief, verify, review and report. You don't write the feature diff yourself.
- **`model: "sonnet"`** for mechanical or fully specified work (captures, resends, formatting, small-diff re-reviews). **`Explore` with `model: "haiku"`** for read-only search. **`model: "fable"`** only for design work (mockups, artboards, visual direction). Pass `model` explicitly on every Agent call; never let one inherit.
- **Never pass `name:` to Agent** (idle-notification routing bug, Claude Code #81439). Address agents by the returned agent_id.
- **Every brief ends with this footer, verbatim:**

  > Write your full report to `<path>` and make your LAST action a SendMessage (or your final reply) containing only: the path, a one-line verdict, and Critical/Important/Minor counts. Never paste the report inline; never write reports as plain assistant text mid-task.

  Every brief below assumes that footer is attached. You read the file. You never spend a turn narrating an idle notification.
- **TaskStop every agent the moment its terminal report is in.** 41 live agents accumulated over three hours on 09-12.
- **Status line every ~10 minutes while agents run**, unprompted: what's running, what landed, what's next. Bass asking "how's it going?" is the failure.
- **Publish artifacts at first usable state**, then republish to the SAME URL as the rest arrives. Never hold a gallery for the last shot.

Subagents never spawn their own fan-out. Model and delegation policy live in `~/.claude/CLAUDE.md`; wave, merge, CI and screenshot-discipline rules in `~/.claude/rules/ritualpass-workflow.md`; multi-PR coordination in the `wave` skill. Follow them, don't restate them.

## Step 0: Version check (run first, every invocation)

Before doing anything else, check if a newer version of this skill is available. Skip the network call if it's been done in the last 24 hours. The probe covers the Claude Code and Codex install locations; on any other harness, set `SKILL_DIR` to wherever this `SKILL.md` is installed before running the block.

```bash
SKILL_NAME="ship-ticket"
SKILL_DIR=""
for d in "$HOME/.claude/skills/$SKILL_NAME" "$HOME/.codex/skills/$SKILL_NAME"; do
  [ -f "$d/SKILL.md" ] && SKILL_DIR="$d" && break
done
if [ -z "$SKILL_DIR" ]; then
  echo "SKILL_NOT_FOUND - set SKILL_DIR to this skill's install directory and re-run this block"
else
  CACHE_FILE="$SKILL_DIR/.last-version-check"
  RAW_URL="https://raw.githubusercontent.com/bshakr/agent-skills/main/ship-ticket/SKILL.md"
  LOCAL_VERSION=$(awk -F': ' '/^version:/ {print $2; exit}' "$SKILL_DIR/SKILL.md")
  NOW=$(date +%s)
  LAST_CHECK=$(cat "$CACHE_FILE" 2>/dev/null || echo 0)

  if [ $((NOW - LAST_CHECK)) -gt 86400 ]; then
    REMOTE_VERSION=$(curl -fsSL "$RAW_URL" 2>/dev/null | awk -F': ' '/^version:/ {print $2; exit}')
    echo "$NOW" > "$CACHE_FILE"
    if [ -n "$REMOTE_VERSION" ] && [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
      echo "UPDATE_AVAILABLE local=$LOCAL_VERSION remote=$REMOTE_VERSION"
    else
      echo "UP_TO_DATE version=$LOCAL_VERSION"
    fi
  else
    echo "SKIP_CHECK version=$LOCAL_VERSION"
  fi
fi
```

If it prints `SKILL_NOT_FOUND`, continue the task with the current version rather
than blocking on the check.

If the output starts with `UPDATE_AVAILABLE`, ask the user before proceeding:

> ship-ticket skill update available: `{local}` → `{remote}`. Pull updates? (y/n)

If yes, resolve the clone behind the install and pull:

```bash
REPO_DIR=$(git -C "$(dirname "$(readlink -f "$SKILL_DIR/SKILL.md")")" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$REPO_DIR" ]; then
  git -C "$REPO_DIR" pull --ff-only
else
  echo "NO_REPO_FOUND - reinstall from https://github.com/bshakr/agent-skills"
fi
```

If it prints `NO_REPO_FOUND` (the skill was copied, not symlinked), reinstall from https://github.com/bshakr/agent-skills instead. Then re-read this skill from disk before continuing. If the user declines, continue with the current version and don't pester again until the next 24h window.

If the output is `UP_TO_DATE` or `SKIP_CHECK`, proceed silently to Step 1.

## Inputs

- **Required:** Linear ticket id. If user said "next ticket", run `linear next` or `linear issues --mine --unblocked` and propose before claiming.
- **Optional:** target repo path (defaults to current working directory).

If no ticket id can be inferred, stop and ask. Do not invent.

## Step 1 — Claim the ticket and set up the worktree

**Duplicate check first, not at conflict time.** A second Claude account works the same board; on 08-29 a whole wave was superseded by PRs the other account had merged five hours earlier.

```bash
gh pr list --search "<TICKET-ID>" --state all --json number,title,state,url
```

Any open or merged hit: stop and report before writing a line of code.

**Already inside a supacode worktree?** If cwd is under `~/.supacode/repos/<repo>/<branch>/`, that IS your worktree. Confirm the branch matches the ticket and skip to Step 2 — never create a second worktree, never `cd` back to the parent checkout.

Otherwise, from the main repo (not from inside another worktree). CLAUDE.md mandates `.koh/<branch>`:

```bash
git fetch origin main
git worktree list                    # check for prior worktree on same branch
git worktree add .koh/<branch-name> -b <branch-name> origin/main
git worktree lock .koh/<branch-name> # a commitless worktree gets swept by gwt-prune-merged
cd .koh/<branch-name>
cp ~/code/ritualpass/api/.env .env   # api only — gitignored, and without it every
                                     # authenticated request 401s (no DEVISE_JWT_SECRET_KEY)
```

- **Branch naming:** `<TICKET-ID>-<short-kebab-summary>`, under ~50 chars.
- **Always branch off `origin/main`** unless this is a stacked epic (see below). Stacking off an unmerged branch is what produces the conflict pile-ups.
- **Same ticket already has a worktree + open PR:** push to that branch, don't create a parallel one.
- **Merged worktree:** note it, don't auto-remove without consent.

Then claim it with `linear-start <TICKET-ID>`. It runs `linear issue start`, forces the state to "In Progress" (the CLI lands tickets in "In Review"), verifies it stuck, and prints the suggested branch name. Don't hand-correct the state any more.

## Step 2 — Get ticket context

```bash
linear issue show <TICKET-ID>
```

Read the body, acceptance criteria, and any linked spec/plan docs (e.g. `docs/superpowers/plans/...`). If acceptance criteria are missing or scope is genuinely unclear, ask the user before writing code.

## Step 2b — Verify the premise

**Before any implementer is briefed, reproduce the reported symptom at runtime. Two minutes, hard cap.** Hit the endpoint, load the route, run the one failing case. BLO-1499 and BLO-1503 each burned a full implement → review → PR cycle on a bug that did not exist: one was already fixed by an earlier ticket, the other only reproduced inside `ActionDispatch::IntegrationTest`.

- **Reproduces:** record the exact command and output. It becomes the implementer's RED case.
- **Doesn't reproduce inside two minutes:** stop. Report what you ran, what you saw, and what you think the ticket actually describes. Do not dispatch. A grep of the route directory is not a reproduction.
- **Not reproducible by design** (infra, third-party state, production-only data): say so explicitly and name the evidence you used instead.

**Ticket references an approved design or prototype?** Open that file and quote the exact spec, values and copy into the implementer's brief. Design records live in the `ritualpass/docs` repo under `design/<topic>/`. Paraphrasing an approved design from memory is what caused the BLO-1532 rework.

## Step 3 — Plan carefully (yours, never delegated)

1. **Identify the files you'll touch.** Read + Grep them, including callers of any symbols you're about to change.
2. **Check existing patterns.** Match conventions of similar features (tests, error handling, naming).
3. **Find load-bearing constraints** (fixture relationships, validation contexts, idempotency keys, multi-tenant scoping). Document any deviation from spec with a one-sentence "why".
4. **Set up task tracking** with TaskCreate — one task per concrete deliverable, no speculative entries.
5. **State the plan to the user** in 3–6 lines: scope, files, deviations. Then start. This catches misdirections that would otherwise cost an hour of throwaway code.

Multi-task work: the `review-ledger` pre-flight plan scan (file collisions between parallel tasks, files that only exist on main, spec self-contradictions) is **mandatory before any parallel dispatch**.

## Step 4 — Implementation (one opus subagent per ticket)

One agent per ticket; one agent per task when the work is genuinely multi-task and the plan scan cleared the collisions. Each brief carries:

- **The absolute worktree path**, and an instruction to work only inside it (`git rev-parse --show-toplevel` when unsure).
- The plan, the acceptance criteria, the quoted design spec, and the Step 2b reproduction as the RED case.
- **TDD per task:** failing test → confirm RED → minimum implementation → confirm GREEN. Run dependent tests when a service or model is touched.
- **Steps 5 and 6 below, verbatim:** pre-commit gates, then ONE logical commit per ticket with an **explicit pathspec on `git commit`** — or one per green checkpoint when the relay rule below applies. No commits between tasks otherwise, and never one that leaves the tree red.
- **Do not push.** Pushing is the coordinator's, in `pr-handover`.
- **A `Co-Authored-By` trailer naming the model the agent actually runs on** — an opus implementer commits `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`. Never paste your own model's trailer into a brief; four implementers had to flag that on 09-12.
- **Relay rule.** Commit at every green checkpoint — they are all implementation commits and are never squashed, so the history still reads implementation then review fixes. At about 100 tool calls, or as soon as your context is clearly heavy with work still remaining, stop: commit what is green, write `<scratchpad>/relay-<task>.md` (30 lines at most: done with SHAs, remaining, traps, the exact next command) and return. Do not push on to finish. A fresh agent continues from the note; an agent's cost grows with the square of its length.

**Slice before dispatch.** A brief carries one side of a seam (server or UI), never a whole vertical. When an agent returns a relay note, dispatch a fresh agent with the note and the branch; never SendMessage the stopped agent to carry on, since that resumes the same heavy context.

When a report lands, **verify on disk, not on the claim**: `git -C <worktree> status --porcelain`, `git log --oneline`, `git show --stat HEAD`, and read the diff yourself. Then TaskStop the agent.

## Step 5 — Pre-commit checks

1. **Full test suite** (or the smallest scope known to cover all affected code). Rails/api: `PARALLEL_WORKERS=1 bin/rails test` — the bare command segfaults the pg gem. CI runs fully parallel, so shared-tmpfile races surface only there.
2. **Lint** changed files. Match the lockfile in that directory — `pnpm lint` where `pnpm-lock.yaml` exists, `npm run lint` where `package-lock.json` does, never mix the two. Ruby: `bundle exec rubocop -f simple <files>`. Python: `ruff` / `black --check`.
3. **Read `git diff` once** — no debug prints, no stray files. You re-run all three yourself after the agent reports; an agent's green is not evidence.

## Step 6 — Commit

```bash
git status --porcelain                # every staged path must be one you intend; an unexpected
                                      # entry means a concurrent agent is mid-write — wait
git commit -m "$(cat <<'EOF'
<TICKET-ID>: <one-line summary, imperative mood>

<2-4 paragraphs: WHAT changed and WHY. Note any spec deviation. Reference parent epic.>
EOF
)" -- <explicit-file-list>            # pathspec on the COMMIT, not just on `git add`
git show --stat --oneline HEAD        # verify the commit's scope
```

**The pathspec belongs on `git commit`.** A bare `git add <files> && git commit` still commits the whole index, so a concurrent subagent's staged files land in your commit under your message — BLO-1140 had to be split apart with `git reset --soft`, and three branches shipped a stray `.gitignore` rider this way. No `--no-verify`, no force ops, never `-uall`.

## Step 7 — Review

**Rebase first.** Other PRs may have landed:

```bash
git fetch origin main --quiet
git log --oneline HEAD..origin/main      # what landed since branch point?
git rebase origin/main                   # if anything new
```

Resolve conflicts deliberately — don't `--skip`. If risky, `--abort` and ask. Re-run tests after a clean rebase. **Capture the SHA**: `git rev-parse HEAD`.

- **Single-diff work → run `/review`** via the Skill tool: scope drift, critical pass (SQL safety, races, enum completeness), specialists for meaty diffs, adversarial pass (Claude + Codex).
- **Multi-task work → run the `review-ledger` skill.** It owns the per-task briefs, the per-task first review, the consolidated fix batch, the scoped re-review and the ruling log.

Classify findings:

- **AUTO-FIX** — mechanical fixes a senior engineer would apply without discussion (wasted eager load, idempotency key, comment). Apply directly; add tests where non-trivial.
- **ASK** — design decisions, user-visible behavior, scope changes. Batch into one AskUserQuestion with a recommendation.
- **Out of scope** — note in the PR body; don't expand the diff.

**Consolidate every review pass into ONE fix batch.** Never trickle fixes reviewer by reviewer. Commit the batch separately so the diff reads "implementation" then "review fixes". No delta review of the fix commit (Bassem, 2026-09-16): the coordinator ground-truths the fixer's report inline instead — splice the new specs onto the pre-fix tree and confirm they are red, diff the spec files for removed or weakened expectations, quote the gate lines. Re-run affected tests + full suite + lint.

**Stop condition:** once a round returns only prose or polish, freeze the branch and file the remainder as tickets. BLO-1486 took 10 commits and five declared "freezes"; the last two rounds produced no product.

**Zero findings is a valid outcome** — record `0 findings`. The gate enforces that review *ran*.

## Steps 8–9 — Run the `pr-handover` skill

Don't hand-roll screenshots, push, `gh pr create` and CI polling any more. `pr-handover` verifies HEAD on disk, re-runs the gates, rebases on `origin/main`, re-checks for a duplicate PR, dispatches a `capture-pairs` agent when the diff is user-visible, builds the gallery with `rp-gallery`, publishes it as an Artifact (or writes "No user-visible surface (API only)"), pushes, opens the PR from the template with the `/review ran on <SHA>` line, inserts the gallery link with `pr-append-section` (never `gh pr edit`), waits on `pr-ci-wait` in the background, verifies `mergeable`, comments the PR and gallery URLs on the Linear ticket, republishes the gallery with the PR backlink, hands the merge watch to a background `pr-merge-wait` per `wave` §2, and only then emits "review clean, CI green, ready to merge — want me to?". It refuses to say "ready" while a gallery link, green CI, `mergeable=MERGEABLE` or the review SHA line is missing.

After a merge, `wave` §3 owns the rest: fetch, rebase every open wave-mate, start the next ticket, post the rollup.

## Stacked epics

When a ticket genuinely depends on an unmerged PR (an epic shipped in ordered slices), stack deliberately rather than pretending it's independent:

- Branch off the previous PR's branch, not `origin/main`, and say so in the plan summary.
- Open with `gh pr create --base <previous-branch>` so the diff shows only this slice.
- **When the base merges, cascade immediately:** `git fetch origin main`, retarget with `gh api -X PATCH .../pulls/<N> -F base=main`, rebase onto the new `origin/main`, re-run the suite, force-push with lease, re-verify CI. Do this the moment the merge is detected, not when the conflicts surface.
- Serialize, don't parallelize, a stack. Two agents on adjacent slices is the top conflict source.

## What NOT to do

- **Do NOT skip the review gate, or push before it has run.** See the Hard Gate. If you're rationalizing "this one doesn't need it", that is exactly when to run it.
- **Do NOT add labels.** There is no label-triggered deploy — `deploy.yml` was deleted (BLO-1407), `staged` triggers nothing, and staging tracks `main`. Labels that deploy or publish need explicit current-wave permission anyway.
- **Do NOT use `gh pr edit`.** It reports success and silently discards body, title and label edits. Use `pr-append-section`, or `gh api -X PATCH .../pulls/<N> -F body=@<file>` and read the live body back.
- **Do NOT run a foreground `sleep` or a hand-rolled `for i in $(seq …); do sleep 60; gh pr checks` loop.** `pr-ci-wait` in the background, or Monitor with an until-loop.
- **Do NOT Read a PNG.** Capture agents open images and return a verdict plus paths; you build the gallery from paths.
- **Do NOT commit until implementation and tests pass.** Half-done commits pollute the diff.
- **Do NOT skip the plan summary** even when the ticket seems trivial.
- **Do NOT auto-merge or auto-deploy.** Merge authorization is per-wave and never carries forward.
- **Do NOT silently expand scope.** Out-of-scope items go in the PR description.

## End state

1. A green PR linked to the Linear ticket, mergeable against current `main`, its full URL printed in the chat.
2. Implementation commits — one, or one per relay checkpoint, never squashed — then review fixes as a separate commit; or implementation alone carrying `/review ran on <SHA> — 0 findings`.
3. UI PRs: a `## Screenshots` section whose first line is the gallery Artifact URL, and the gallery carrying the PR backlink. API-only PRs: the explicit "No user-visible surface" line.
4. A Linear comment on the ticket carrying the PR URL and the gallery URL, ticket in "In Review".
5. A background `pr-merge-wait` watching the PR, so the user never has to announce the merge and no turn is spent waiting for it.
6. Worktree left in place and locked — the PR is unmerged. Once it lands, clean up with `gwt-prune-merged` (dry run first, `--force` only on confirmation); `git worktree prune` and `git branch --merged` both misreport squash-merged branches.
