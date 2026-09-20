---
name: capture-pairs
description: Capture before/after screenshot pairs for a UI PR and emit an rp-gallery manifest plus a VERDICT. Run BY A CAPTURE SUBAGENT briefed by the coordinator: detached worktree at the true fork point for "before", both stacks on private ports, session injection instead of typed credentials, per-shot route/theme/title assertions, phone overflow probe, fixture restore with proof. Use whenever a PR changes what a user sees.
user-invocable: true
argument-hint: "<path to the capture brief, or the brief inline>"
version: 1.0.0
repo: https://github.com/bshakr/agent-skills
skill_path: capture-pairs
---

# capture-pairs

The before/after screenshot recipe. It has been rebuilt from memory notes 12+ times; this is the
copy that stops that.

**You are the capture subagent.** The coordinator briefs you, reads your files, publishes the
gallery and patches the PR. You never publish an Artifact, never edit the PR, never merge, and
never spawn your own subagents. The coordinator never opens an image, so *you* are the only
pair of eyes on these PNGs: a shot of the wrong route or a logged-out redirect is worse than
no shot at all.

Read `projects/<project>.md` in this skill directory before step 1. Core recipe below, project
facts (ports, login, seeds, DB isolation) in the appendix.

## 1. Inputs the brief must carry

Refuse to start and ask the coordinator if any of these is missing or ambiguous. Guessing one
is how a whole matrix gets recaptured.

| Input | Notes |
|---|---|
| `worktree` | Absolute path to the branch worktree. Write nothing outside it and the output dir. |
| `branch` | Branch name, for the VERDICT header. |
| `base_sha` | The **true fork point**, `git merge-base origin/main <branch>`, never the word "main". |
| `routes` | Route x state matrix: route, what state it must show (empty, populated, loading, error), how to reach that state. Only surfaces the diff touches, plus exactly one control pair of an unchanged surface; the coordinator derives it from the touched components, not from the app's route list. |
| `login` | Tenant/household, user, and the *injection* path (cookie, bearer token, harness), never a password to type. |
| `viewports` | Default `1440x900`; add `390x844` whenever layout or CSS changed, never for copy-only edits. |
| `themes` | `light`, `dark`, or both. State which is the default. |
| `flags` | Flag name plus the on and off variants required, only when the PR adds or changes a flag gate. Flag-off is the proof existing users are unaffected. |
| `out_dir` | Where PNGs, `manifest.json` and `VERDICT.md` go. Prefer the session scratchpad. |
| `ticket`/`pr_url` | For the manifest header. `pr_url` may be empty at first capture. |

### Brief template (coordinator copy-pastes this)

```
Run the capture-pairs skill (~/.claude/skills/capture-pairs/SKILL.md) and its
projects/<project>.md appendix. Do not skip a step; do not invent a route.

worktree:  /abs/path/.koh/<branch>
branch:    <branch>
base_sha:  <output of: git merge-base origin/main <branch>>   # frozen, see below
routes:
  - /dashboard | populated (3 upcoming shifts) | after login as <user>
  - /dashboard | empty (no shifts)             | delete shifts, restore SQL recorded
login:     <injection method from the appendix>
viewports: 1440x900, 390x844
themes:    light
flags:     <flag>=on and <flag>=off, both halves
out_dir:   <scratchpad>/<ticket>-shots
ticket:    https://linear.app/bloombase/issue/BLO-XXXX
pr_url:    <blank until the PR exists>

I have FROZEN rebases on <branch> until you report. Tell me before you start if
base_sha does not match the branch's current merge-base.
Own your resources: your own port block, your own browser context, your own
FLIPPER_REDIS_URL db. Kill only PIDs you started; never pkill -f.
Write your full report to <out_dir>/VERDICT.md and make your LAST action a reply
containing only: the paths, a one-line verdict, and shot counts
(captured / verified / uncapturable).
```

## 2. Recipe

**0. Confirm the premise.** Re-derive `git merge-base origin/main <branch>` yourself and compare
to `base_sha`. If they differ, stop and tell the coordinator: the branch was rebased and every
"before" shot would be against the wrong baseline. Confirm rebases are frozen for the duration.

**1. Build the "before" tree.** `git worktree add --detach <tmp>/before <base_sha>`. A detached
worktree at the fork point, never the shared parent checkout, never `git checkout <sha> -- app/`
under a running server (the bundler serves a stale stylesheet and no number of reloads fixes it).
Copy the env file in (see the appendix; check with `ls -la` first, a worktree `.env*` is often a
symlink into the main checkout and writing to it corrupts another agent's rig).

**2. Install deps.** Real install in each tree. Never symlink `node_modules` from a sibling
worktree: Turbopack hard-fails on symlinks that escape the project root, while lint and tsc pass
through it happily, so "gates green" is not proof the app boots.

**3. Claim ports.** Pick a block of 2 to 4 consecutive free ports well away from the project
defaults, e.g. `39xx`. For each: `lsof -nP -iTCP:<port> -sTCP:LISTEN` must be empty. A port that
answers `200` may be another session's branch, so check the listener's cwd before trusting it,
and re-check after boot that the PID on the port is yours. Record the block and every PID in
`<out_dir>/rig.txt`. Boot both stacks: before on block A, after on block B, both pointing at the
**same** API instance so time-dependent and flag-dependent content cannot diverge. Warm each
route with `curl` so a cold compile does not eat the settle timeout.

**4. Get a session.** Inject it: set the auth cookie or bearer token directly, or use the
project's capture harness. Do not drive a login form: the permission classifier refuses to type
credentials (and refuses to relay them in a message), which has blocked a whole gallery before.
Use a **fresh browser context per shot-set**, with your own daemon/state file, and assert the
cookie jar is empty before a logged-out shot. Auth cookies on `.localhost` historically ignored
the port, so a new port is not a new session: verify the session state visible *in the frame*.

**5. Mutate fixtures, with the undo written first.** Before any write, dump the current state to
`<out_dir>/restore.sql` (or a JSON file) and record it in the VERDICT. For flags, record both the
boolean gate and the actor set, because disabling a flag wipes its actors too. Prefer changing
tenant/group settings or per-actor gates over a global flag flip. Never toggle a shared global.

**6. Capture the matrix.** For every (route x state x viewport x theme x flag) cell, and for each
half (before, after), before the shutter assert:
- `location.pathname` is the intended route (poll it; do not trust `waitForURL`),
- the resolved theme attribute matches the requested theme,
- `document.title` matches what this branch should render,
- the in-DOM content proves which half you are on (a stale bundle passes a pixel check silently),
- the tenant/household identity is on screen for empty-state shots (an absence assertion passes
  against the wrong tenant),
- dev overlays are hidden by the same CSS in both halves (Next's issue badge paints over real UI).
Disable animations or wait for `animationend` before a full-page shot: `fullPage` re-rasterises
and restarts entrance animations, which is how a 9%-opacity hero got shipped.

**7. Probe phone overflow.** At 390px, read `document.documentElement.scrollWidth` against
`window.innerWidth` and record both numbers per route. Any excess is a real defect, report it in
the VERDICT even when it exists on main too. This probe found a 36px landing-page overflow that
three code reviews missed.

**8. Verify every PNG by eye.** Open them. Contact sheets (a grid of thumbnails per route) are
fine and cheaper than one-by-one, but every file must be looked at, and the VERDICT records
verified yes/no per shot. "The script exited 0" is not verification.

**9. Prove the no-change pairs.** For any pair that is meant to be identical (flag-off, or a
surface the change should not touch), `md5` both files and record the digests. Matching digests
go into the manifest as `"identical": true`. A byte-identical pair is far stronger evidence than
"looks the same", and it is the pair most likely to expose a regression.

**10. Write the outputs.** `manifest.json` in the rp-gallery format and `VERDICT.md` (section 3).

**11. Restore, and prove it.** Replay `restore.sql`, re-read the mutated rows, and paste the
read-back into the VERDICT. Restore flag gates including actors. Undo anything the app created as
a side effect of a shot (a cover assignment, a sent message).

**12. Tear down.** Kill only the PIDs in `rig.txt`, by PID. Never `pkill -f "next dev"` or
`pkill -f rails`: that has killed three other lanes' servers. Stop your own browser daemon. Never
clear a shared daemon's cookies or tabs on the theory its owner finished. `git worktree remove`
the detached before-tree. Then check the gitignore: `git -C <worktree> status --short` must be
clean of your PNG dir. A root-level `/.koh/` ignore rule is relative to the **main** checkout, so
`.screenshots/` inside a worktree is NOT ignored; either keep shots in the scratchpad (preferred)
or add the path to `$(git rev-parse --git-common-dir)/info/exclude`, never to the tracked
`.gitignore` (that adds a rider hunk to the PR).

## 3. Output contract

**`<out_dir>/manifest.json`**, exactly the rp-gallery shape (`rp-gallery <manifest.json> --out
<gallery.html>` consumes it; paths relative to the manifest):

```json
{"title":"BLO-1234 member dashboard","pr_url":"","ticket_url":"https://linear.app/…/BLO-1234",
 "intro":"one paragraph: what changed and what to look for",
 "pairs":[{"label":"Dashboard, populated","route":"/dashboard","state":"logged in as member, 3 shifts",
           "viewport":"1440x900","before":"shots/dash-before.png","after":"shots/dash-after.png",
           "note":"what to look for","identical":false}],
 "solos":[{"label":"New empty state","route":"/dashboard","state":"no shifts","path":"shots/empty.png","note":"…"}]}
```

State the active brand colours in `intro` if the capture tenant carries any brand override.

**`<out_dir>/VERDICT.md`**: header (branch, base_sha, rig ports, date), then a row per shot with
route, state, viewport, theme, flag, file, **verified by eye yes/no**, and anomalies seen; then
the phone-overflow numbers; then `md5` digests for identical pairs; then **"Could not capture"**
with a reason per route; then the fixture restore read-back proof.

**Final message to the coordinator**: the two paths, a one-line verdict, and counts
(captured / verified / uncapturable). Nothing else. No inline report, no pasted findings, no
images. Honest gaps beat invented coverage: if 8 of 14 routes need a session you cannot mint,
say so and say what you did instead.

## 4. Traps, each with its fix

- **Fork point moves mid-capture.** A rebase during capture invalidated 24 shots. Confirm `base_sha` at step 0 and hold the coordinator to a rebase freeze.
- **Branded tenant tints every shot.** A seeded `primary_color` override turned every button purple and read as a code change. Capture on a branding-neutral tenant, or name the active brand colours in the intro.
- **Ticket ids in seed data.** Seed rows named "BLO-1629 Retired Perk" rendered as customer copy in a gallery. No ticket ids, no "BLO-" strings, in anything that renders.
- **Shared Redis Flipper.** Flag state is global across processes and databases, so an isolated Postgres isolates nothing. Run your API with a private `FLIPPER_REDIS_URL` db, or use actor-scoped gates. `Flipper.disable` also wipes the actor set: record `boolean_value` and `actors_value` before, restore both.
- **`pkill -f`.** It has killed other lanes' dev servers repeatedly. Kill only your own PIDs from `rig.txt`.
- **Shared browser daemon.** One Chromium across agents means another lane navigates your tab mid-shot, and its viewport is context-global and sticky, so your "390px mobile" frames come back as desktop. Run your own daemon/context with its own port and state file; re-assert the viewport before every shot if you cannot.
- **Plain `localhost` drops the tenant header.** The subdomain is what sets it; on bare localhost the admin calls 403 and the page bounces or spins. Use the subdomain host from the appendix.
- **`gstack browse` and Claude-in-Chrome are dead on this Mac** (verified across three agents). Use the Playwright bundled with the Playwright MCP package: `require("/opt/homebrew/lib/node_modules/@playwright/mcp/node_modules/playwright")`, or the copy in `~/.npm/_npx/`.
- **Typed credentials get blocked.** The permission classifier refuses `fill` with an email/password and refuses to relay the string. Use the API-token / cookie / session-injection path.
- **Full-page capture restarts animations.** `fullPage` re-rasterises; entrance animations replay into the frame. Disable animations globally or await `animationend`, and do not blanket-clear inline `transform`s (that un-hides Radix's off-screen native checkbox and looks like a styling bug).
- **`pnpm build` does not typecheck tests.** If you touch anything to make capture work, `tsc --noEmit` before you claim a tree is healthy.
- **`.screenshots/` is not gitignored in a worktree.** The root `/.koh/` rule is main-checkout relative. Keep shots in the scratchpad.
- **Scratchpad filenames collide.** Prefix every script and output with the ticket id (`blo1666-capture.js`), the scratchpad is shared.
- **`/private/tmp` does not survive a reboot.** Copy the shot set somewhere durable before a long gap.
- **A "before" that never existed.** If a route is new on the branch, it is a `solos` entry, not a pair with a 404 on the left.
- **Silent uncapturable routes.** Report them. Never quietly drop a route from the matrix.

## 5. Appendices

- `projects/houserota.md` (Rota Monster)
- `projects/ritualpass-admin-web.md`
- `projects/ritualpass-client-web.md`
- `projects/ritualpass-api.md`
