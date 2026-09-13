---
name: design-directions
description: Run a direction round before any visible surface is built. A brand director writes N genuinely divergent directions, a design director writes craft rules and one art-direction sheet per direction, one builder per direction works from its own sheet only, an independent QA pass grades every build against a fixed protocol, then each direction is published as a live preview inside one gallery for the founder to pick from. Invoke for "give me options", "a few designs I can pick from", "bring in a brand director", "4 options and I'll pick one", or before any PR that draws a new user-visible surface.
user-invocable: true
argument-hint: "<surface> [--full|--short] [--directions N]"
version: 1.0.0
repo: https://github.com/bshakr/agent-skills
skill_path: design-directions
---

# Design Directions

The rule this skill mechanises, from `feedback_design_quality_bar` (2026-09-03):

> Before any visual build, run a direction step: a brand director defines the bar from references and four divergent directions with a differentiation test (copy removed, still distinguishable by colour, composition, motion); a design director writes the craft rules and per-direction art-direction sheets and QAs renders before Bassem sees them.

Four spec-compliant homepage builds were rejected in one message because a single brief locked all four lanes to one skeleton, one token set and drawn chrome. Four agents given the same cage converge. Spec correctness was never the problem; visual ambition was. The round that replaced it produced four builds cleared at 12/12 and is the only design process Bass has accepted.

## When this fires

| Signal | Action |
|---|---|
| "give me options", "a few designs I can pick from", "give me 4 options and I'll pick one" | this skill, FULL or SHORT by surface |
| "bring in a brand director", "a senior design director" | this skill, FULL |
| "I'm not in love with the aesthetics, start fresh" | this skill, FULL, and ask whether the brand itself is in scope |
| A ticket whose diff draws a **new** user-visible surface | this skill, SHORT, **before** the implementation brief |
| A redesign of an existing surface Bass has complained about | this skill, SHORT |
| One approved prototype exists and the job is to build it | not this skill. Open the prototype, quote it, go to `ship-ticket` |
| Copy, spacing or colour fix inside an approved surface | not this skill. `/design-review` or `ship-ticket` |

Both surfaces Bass rejected this month (`admin-web` #455's member perks, BLO-1532's event region) were spec-compliant single builds shipped with no options step. A PR is not exempt because a spec exists.

Adjacent skills, referenced not duplicated: `design-shotgun` (gstack) generates variants and a comparison board but has no director, no art-direction sheet and no QA gate; `design-consultation` (gstack) proposes a whole design system and is the right call when there is no brand yet; the `design` skill draws the canvas artboards this skill uses as SHORT-mode deliverables; `capture-pairs` owns screenshot conventions; `ship-ticket` builds the winner.

## Step 0: Version check (run first, every invocation)

Before doing anything else, check if a newer version of this skill is available. Skip the network call if it's been done in the last 24 hours. The probe covers the Claude Code and Codex install locations; on any other harness, set `SKILL_DIR` to wherever this `SKILL.md` is installed before running the block.

```bash
SKILL_NAME="design-directions"
SKILL_DIR=""
for d in "$HOME/.claude/skills/$SKILL_NAME" "$HOME/.codex/skills/$SKILL_NAME"; do
  [ -f "$d/SKILL.md" ] && SKILL_DIR="$d" && break
done
if [ -z "$SKILL_DIR" ]; then
  echo "SKILL_NOT_FOUND - set SKILL_DIR to this skill's install directory and re-run this block"
else
  CACHE_FILE="$SKILL_DIR/.last-version-check"
  RAW_URL="https://raw.githubusercontent.com/bshakr/agent-skills/main/design-directions/SKILL.md"
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

If it prints `SKILL_NOT_FOUND`, continue the task with the current version rather than blocking on the check. If the output starts with `UPDATE_AVAILABLE`, ask before proceeding:

> design-directions skill update available: `{local}` → `{remote}`. Pull updates? (y/n)

On yes, resolve the clone behind the install and `git -C "$REPO_DIR" pull --ff-only` (same block as `ship-ticket` Step 0).

## Step 1: Pick the mode and say which one out loud

State the mode in your first message. The two rounds are not interchangeable.

**FULL** for brand, marketing and standalone pages, or any round where the aesthetic itself is in question. Directions are standalone HTML pages, each with its own art direction: its own grid, type scale, colour material, hero construction and motion choreography. Nothing is inherited from the app's design system except the content decisions.

**SHORT** for in-app surfaces inside a product that already has a design system. Directions are layout, hierarchy and interaction options **inside** that system, built as `design` canvas artboards or as component prototypes in the repo. Design tokens are read out of the repo and quoted by path; they are never invented and never nudged "just for the mockup". The brand director step collapses into a half-page "what varies" brief naming the axis each direction moves on (density, entry point, disclosure, primary object, ordering). The design director step stays, in full.

If the mode is genuinely ambiguous, ask in one line. Do not run FULL on an in-app card.

## Step 2: Inputs to collect before spawning anything

Nothing is dispatched until every row has an answer or an explicit "unknown, assumed X".

| Input | Why it is mandatory |
|---|---|
| The surface and the job it does in one sentence | a direction that does not know the job diverges on decoration |
| Audience, and what they were doing five seconds earlier | |
| **Funnel entry: where the user arrives from** | three onboarding prototypes were re-framed because "choose your plan" precedes onboarding and nobody modelled it |
| Any approved prototype or prior decision | **open the file and quote it in the brief.** BLO-1532 was built from the ticket text while `v6-shapes.html` already specified a per-event card with its own cumulative chart; the PR was retitled DO NOT MERGE |
| References Bass has named (artifact URLs, the live page) | the bar is set by the references, not by your taste |
| Constraints: existing tokens (by file path), precision rules (trends and rates render to one decimal, "+6.7%" never "+7%"), fit-vs-fill (content-width strips do not become fill-width grids), copy that is fixed | the two regressions in `066ef8ac` were both constraint drift, not code defects |
| Number of directions, default 4, hard cap 4 | |
| Round number, and where round n-1 lives | the design director opens it |

If Bass says "I'm not sure", that is not a mandate to decide. Ask, in one line: "decide, or options?". Locking a direction on an unanswered question cost four hours and three adversarial review rounds in `7e0ae284`.

## Step 3: Cost guard, stated before the first spawn

Post one line naming the fleet and its rough cost, then spawn.

> Fleet: 1 brand director (fable) + 1 design director (fable) + 4 builders (fable, parallel) + QA (sonnet) + capture (sonnet). Roughly 1.5M to 2.5M subagent tokens for a FULL round, 400k to 700k for SHORT.

Caps and tiering: N directions never exceeds 4. QA and capture run on `sonnet` unless a verdict needs judgment, in which case the design director re-reads on `fable`. SHORT-mode builders may run on `opus`; FULL-mode builders are the one case where `fable` is correct. Pass `model` explicitly on every Agent call and never pass `name:` (idle-notification routing bug, Claude Code #81439); address agents by the returned agent_id. **Every `fable` spawn's `description` starts with `design:`** (for example `design: brand director`, `design: build Lantern`): the `pretool-agent.sh` hook admits fable only when the description or the first 600 characters of the prompt read as design work, and denies it otherwise.

## Step 4: Brand director (`fable`, one agent)

Brief from `templates/brand-director.md`. It reads the references, the live surface, and every prior round, and writes ONE file: the brand direction, with N named directions.

The binding constraint on that file is the **differentiation test**: with all copy removed, each direction must still be distinguishable from the other N-1 by colour, composition and motion alone. The brief makes the director state, per direction, the one thing that is true only of it ("the only direction whose first viewport is dark", "the only multi-colour page", "the only textured page"). A direction that cannot claim one is not a direction, it is a variant, and it goes back.

Content, IA and accessibility decisions stay fixed across directions. Visual constraints are reopened: material and atmosphere, imagery or composited product frames as the anchor rather than drawn placeholders, richer choreographed motion.

## Step 5: Design director (`fable`, one agent)

Brief from `templates/design-director.md`. Two deliverables, in order, both to disk:

1. **Craft rules plus failure analysis of the prior round.** Per-lane critique with CSS and screenshot evidence, the cross-lane failures, the references' craft values (spacing scale, type ratios and tracking, colour moments, named keyframes with durations, shadow and tint technique), and roughly 20 pass/fail craft rules. Round one's critique named the three that mattered: one layout grammar, one surface with no colour moment, and the two character-carrying elements being the most uniform things on the page.
2. **One art-direction sheet per direction**, `sheets/<direction>.md`, each carrying: grid, type scale with the exact computed set, colour moments and their inventory ("terracotta appears at exactly these five places"), hero construction with real pixel geometry, motion choreography with named easings and timings, the signature detail, the declared fold marker, and every contrast measurement. A sheet that corrects its direction (a colour that fails body contrast, a display size below the brand floor) records the numbers and says so.

The design director also writes the **per-round QA addendum** (Step 7) and owns every verdict.

## Step 6: Builders (one per direction, parallel)

Brief from `templates/builder.md`. `fable` in FULL mode, `opus` in SHORT mode.

**Each builder sees only its own sheet.** Not the other sheets, not the other lanes' output, not a shared skeleton, not a shared component file. The single most expensive mistake available here is handing four agents one page structure. The brand direction and the craft rules are shared; everything below them is not.

Every brief carries an **absolute output path**, the report-to-file footer, and the checkpoint rule:

> Write the page, your notes file and your renders to disk **as you go**, never at the end. If your model runs out of credits or the session dies mid-check, the next agent resumes from what is on disk. The Tinted Week builder died on credit exhaustion at 18:04 with an unreported page on disk; the lane was recoverable only because the HTML was already written.

Builders self-QA and record deviations from the sheet with reasons and measurements, then hand to independent QA. Self-QA is never the gate: the design director found defects in three of four builds that had each passed themselves.

## Step 7: QA, verdicts and the fix loop

Independent of the builder, always. `sonnet` against the written protocol; the design director on `fable` when a verdict needs taste. Protocol in `templates/qa-protocol.md`: a generic core plus a per-round addendum the design director writes from the sheets.

Generic core, every build, every round:

1. No horizontal overflow: `scrollWidth === innerWidth` at 1440, 1024, 768 and 390, in both themes, **and with any menu or drawer open**.
2. Type and spacing sit on the sheet's declared scales. Every computed size is in the declared set.
3. The accent colour appears only at the declared moments. Count them.
4. Visible focus state on every focusable, matching the sheet.
5. The reduced-motion render equals the JS-off render (record the pixel diff and where it sits).
6. No clipping and no truncation at any width. Probe the box, do not eyeball it: Poster's plate looked fine because `overflow-x: clip` hid a 424px min-width in a 350px column while the status column was cut mid-word.
7. Contrast measured and recorded for every text pairing, decorative exceptions named.
8. The declared fold marker lands where the sheet says, or the sheet's arithmetic is corrected in writing.
9. Disclosures: target sizes, Escape closes and refocuses the summary.
10. Source-precision rules hold in the rendered copy: rates and trends to one decimal, no "3%" where the source says "3.0%".
11. Renders of canvas artboards are checked independently by rendering them, not by reading the markup. The independent render check caught clipping twice in `9533b54f`, once a board losing its call to action entirely.
12. Plus the per-round addendum.

**Verdict per build: `FIX FIRST` or `SHIP TO FOUNDER`.** `FIX FIRST` carries the failed check, the evidence (selector, computed value, coordinates) and the exact fix. The builder applies, recaptures, and the same QA agent re-checks. **Cap: two fix rounds.** After the second, freeze the build, publish it anyway, and write the remaining defect into the gallery note and the design record. A third round on taste notes is not QA.

## Step 8: Previews and the gallery

Publish at first usable state, then republish in place. Never hold the set for the last lane.

- **Each direction gets its own Artifact** (the live page in FULL mode, the canvas in SHORT mode). A `sonnet` agent reads the file end to end, checks for secrets, real names and external assets, publishes, and returns the URL and byte size. Republish to the SAME url when the build changes; never publish a second copy. Note that a file's own `<title>` beats the `title` parameter.
- **One gallery** built with `rp-gallery` from a manifest of `solos`, one per direction, with the per-direction Artifact link and a one-line "what to look for" in each note. Intro from `templates/gallery-intro.md`. Publish it as soon as one direction is usable; republish to the same url as each lane lands.
- **Capture** runs on `sonnet` under the `capture-pairs` conventions. The one trap specific to this round: **a full-page screenshot re-rasterises the page and restarts entrance animations, which then hold their `from` values.** Tinted Week shipped an almost untinted hero that way. Either put the load choreography behind a class the page removes after it settles, or wait on `animationend` for every entrance beat before capturing, and diff the capture against the JS-off render to prove it. Never capture on a tenant with a brand colour override.
- **One consolidated link block in the final message.** Gallery url first, then one line per direction. Bass asked "give me a link to all of them pls" after four previews arrived across five messages over 22 hours, and has asked for a consolidated list twice more since.

## Step 9: The design record

Design records live in the docs repo, never in an app repo (app-repo docs PRs redeploy production and bloat history with PNGs, and a second Claude account cannot see your artifacts, so the repo is the source of record and the artifact is the mirror).

Write to `ritualpass/docs` (or the project's own docs repo) under `design/<topic>/round-<n>/`: the brand direction, the craft rules and failure analysis, every sheet, every build and its notes, the QA verdicts, the PNGs, and a `README.md` carrying the artifact URLs, the verdict per direction and the standing notes. Update `design/<topic>/README.md` to point at the round. Open a docs PR, and comment the ticket with the gallery url plus the per-direction urls.

If `design/<topic>/` does not exist on `main`, base the docs PR on the branch that creates it and say so in the PR body (docs #23 had to do exactly that).

## Step 10: The pick

Present N directions, **one line each on the bet it makes**, not a paragraph each. Then the director's single most useful note per direction (the thing a founder notices first: one good, one bad). Then the link block. Then stop and wait.

Bass picks in a few words ("lets go with soft clay"). Record the decision in the docs README and in the Linear comment, both naming the direction and the date. The winning direction's page, sheet and QA verdict become the spec input for `ship-ticket`; hand over the absolute paths, not a summary.

**Never merge directions into a "best of" unless Bass asks.** Averaging four directions reproduces exactly the convergence this skill exists to prevent.

## While the fleet runs

You are the coordinator. You brief, verify on disk, rule and report; you do not
draw anything yourself.

- **Ground-truth every report.** A builder's "done" is checked with the file on
  disk and the capture agent's verdict, never with the agent's own summary.
- **TaskStop every agent the moment its terminal report is in.** A director
  stays alive through QA; a builder does not survive its `SHIP TO FOUNDER`.
- **Never narrate an idle notification.** It is not an event.
- **Post an unprompted status line every ~10 minutes**: which lanes are
  building, which are in QA, which are published, and what is next. Bass asking
  "how's it going?" is the failure.
- **Keep working while agents run:** draft the gallery manifest, prepare the
  docs record, write the link block. Never sit in a silent open-ended wait.
- **Never `Read` a PNG.** Image reads are the largest consumer of coordinator
  context; the capture or QA agent opens them and returns paths plus a verdict.

## When a lane dies

On a 529, a credit exhaustion, or an agent that stops mid-check: **resume that lane from its on-disk checkpoint, do not restart it.** Read the page, the notes and the renders that exist, brief a replacement (`opus` is fine for a finisher) with the same sheet plus a list of what is already done, and send it through the same QA, preview and gallery path. The other lanes keep running. A restarted lane costs a full build and loses the deviations the dead agent had already recorded.

## What NOT to do

- **No single build from a spec** for any new visible surface. Both rejections this month were spec-compliant single builds.
- **No shared skeleton, shared tokens or shared component file across lanes.** That is the original sin.
- **No builds before the direction step.** Not "while the director works", not "just a starting point".
- **"I'm not sure" is not a mandate to decide.** Ask "decide, or options?" and wait.
- **No capture on a tenant with a brand colour override**, and no ticket ids, lorem, or internal shorthand in seed copy. Seed copy is read as the design.
- **No invented tokens in SHORT mode.** Read them from the repo and cite the path.
- **Never `Read` a PNG as coordinator.** The capture or QA agent opens images and returns a verdict plus paths.
- **Never merge, never push, never publish to production** off the back of a pick. The pick produces a ticket.
