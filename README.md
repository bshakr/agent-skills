# agent-skills

Personal collection of portable, [Agent Skills](https://agentskills.io)-compatible workflows for Claude Code, Codex, and other supporting agent harnesses.

Repository: https://github.com/bshakr/agent-skills

## Skills

| Skill | Version | Purpose |
|-------|---------|---------|
| [`standup`](./standup) | 1.4.1 | Generate a daily standup report against weekly goals, cross-referencing Linear tickets and GitHub PRs, formatted for Slack. Supports sprint-themed quotes/facts at the top. |
| [`pr-comments`](./pr-comments) | 1.4.1 | Resolve PR review comments end-to-end — fetch, evaluate validity, fix valid ones, commit, push, and draft replies for approval. |
| [`ship-ticket`](./ship-ticket) | 2.0.0 | Ship a Linear ticket end-to-end: duplicate check, locked worktree, premise reproduction, opus implementer, mandatory review gate, then `pr-handover`. |
| [`review-ledger`](./review-ledger) | 1.0.0 | Coordinate review of multi-task subagent work: blocking pre-flight plan scan, per-task brief, first review, consolidated fix batch, scoped delta re-review, ruling ledger, prose-only freeze. |
| [`pr-handover`](./pr-handover) | 1.0.0 | Coordinator tail from reviewed HEAD to handed-over PR: re-run the gates yourself, rebase, duplicate-PR check, capture agent, gallery Artifact, PR from the template, `pr-append-section` only, CI wait, mergeable check, backlinks, merge watch. |
| [`design-directions`](./design-directions) | 1.0.0 | Run the direction round before any visible surface is built: a brand director writes N divergent directions with a differentiation test, a design director writes craft rules plus one art-direction sheet per direction, one builder per lane sees only its own sheet, independent 12-check QA returns FIX FIRST or SHIP TO FOUNDER, then a live preview per direction inside one gallery, the design record, and the pick. |
| [`capture-pairs`](./capture-pairs) | 1.0.0 | Before/after screenshot capture run by a capture subagent: detached worktree at the true fork point, private ports, injected sessions, per-shot route/theme assertions, phone overflow probe, fixture restore, rp-gallery manifest + VERDICT. Per-project appendices. |
| [`test-plan-builder`](./test-plan-builder) | 1.0.1 | Build a code-grounded, multi-tab QA test plan for a feature spanning one or more repos — fans out parallel research subagents per repo/layer, reconciles what's actually implemented vs the spec, and outputs a formatted spreadsheet. |
| [`rich-report`](./rich-report) | 1.0.0 | Turn a completed Markdown plan, summary, or report into a polished local web page — an editorial layer of highlights, timelines, risks, and mermaid diagrams over the full source. Reports are added to a single hub at `~/.rich-report` that serves them all from one long-running server on port 4400 with an index grouped by project. The agent authors one MDX file per report; dependencies install once for the hub. |

## Scripts

Command-line tools in [`bin/`](./bin) that the skills call by name. Full usage and exit
codes: [`bin/README.md`](./bin/README.md).

| Script | Purpose |
|--------|---------|
| [`pr-ci-wait`](./bin/pr-ci-wait) | Wait for a PR's checks to register and then settle, print a compact table, and treat a skipped required check as red. Never `--watch`, so it cannot pass on a stale run. |
| [`pr-append-section`](./bin/pr-append-section) | Add or replace exactly one section of a PR body, re-fetching the live body first and verifying the whole body byte-for-byte after. No shell, so backticks survive. |
| [`rp-gallery`](./bin/rp-gallery) | Build the self-contained before/after screenshot gallery HTML from a manifest, images inlined, no external resources, downscaled to fit the size cap. |
| [`linear-start`](./bin/linear-start) | Move a Linear ticket to "In Progress" (`linear issue start` alone lands it in "In Review"), verify it stuck, and print the branch name. |

Install by symlink into `~/.local/bin` (already on PATH):

```bash
for s in pr-ci-wait pr-append-section rp-gallery linear-start; do
  ln -sfn ~/code/agent-skills/bin/$s ~/.local/bin/$s
done
```

## Hooks

Claude Code hooks in [`hooks/`](./hooks) that enforce the rules the skills rely on. Details, bypass
env vars and the test suites: [`hooks/README.md`](./hooks/README.md).

| Hook | Event | Enforces |
|------|-------|----------|
| [`pretool-agent.sh`](./hooks/pretool-agent.sh) | PreToolUse `Agent` | No `name:` on spawns, no grandchild agents, explicit model (haiku for Explore, opus otherwise), fable only for design-shaped briefs. |
| [`pretool-read.sh`](./hooks/pretool-read.sh) | PreToolUse `Read` | The coordinator never reads an image; capture subagents may. |
| [`pretool-bash.sh`](./hooks/pretool-bash.sh) | PreToolUse `Bash` | In command position only: no PR merging, no `git add -A` / `commit -a`, no raw `railway variables`, no forced worktree prune over commitless live worktrees, no leading `sleep`. |
| [`stop-check.sh`](./hooks/stop-check.sh) | Stop | Will not end the turn while a PR opened this session has pending or red CI, a UI diff with no gallery link, or conflicts. |

Install by symlink and register in `~/.claude/settings.json` (see `hooks/README.md`); verify with
`bash hooks/test-hooks.sh && bash hooks/test-hooks-prose.sh`.

## Install

Clone the repo somewhere stable:

```bash
git clone https://github.com/bshakr/agent-skills ~/code/agent-skills
```

Symlink the skills you want into Claude Code:

```bash
mkdir -p ~/.claude/skills
ln -s ~/code/agent-skills/standup ~/.claude/skills/standup
ln -s ~/code/agent-skills/pr-comments ~/.claude/skills/pr-comments
ln -s ~/code/agent-skills/ship-ticket ~/.claude/skills/ship-ticket
ln -s ~/code/agent-skills/review-ledger ~/.claude/skills/review-ledger
ln -s ~/code/agent-skills/pr-handover ~/.claude/skills/pr-handover
ln -s ~/code/agent-skills/capture-pairs ~/.claude/skills/capture-pairs
ln -s ~/code/agent-skills/design-directions ~/.claude/skills/design-directions
ln -s ~/code/agent-skills/test-plan-builder ~/.claude/skills/test-plan-builder
ln -s ~/code/agent-skills/rich-report ~/.claude/skills/rich-report
```

Or into Codex:

```bash
mkdir -p ~/.codex/skills
ln -s ~/code/agent-skills/rich-report ~/.codex/skills/rich-report
```

Symlinks mean `git pull` instantly updates the live skill. Restart the agent session afterwards so its skill index reloads.

### Per-skill setup

Some skills need additional config. See the individual `SKILL.md` for details:

- `standup` — requires `~/.claude/weekly-goals.yaml`. Format documented in `standup/SKILL.md`.

## Updates

Skills with a `version:` field in their frontmatter self-check for updates on each invocation (cached for 24h). When a newer version is available, the skill will prompt before running. Accept and it pulls the repo for you.

To update manually:

```bash
git -C ~/code/agent-skills pull --ff-only
```

## Versioning

Skills follow [SemVer](https://semver.org):

- **Patch** (`1.1.0` → `1.1.1`) — wording tweaks, bug fixes, no behaviour change for the user.
- **Minor** (`1.1.0` → `1.2.0`) — new optional fields, new statuses, additive features.
- **Major** (`1.1.0` → `2.0.0`) — breaking changes to YAML schema or output contract.

Each `SKILL.md` carries the version in its frontmatter:

```yaml
---
name: standup
version: 1.1.0
repo: https://github.com/bshakr/agent-skills
skill_path: standup
---
```

## Contributing

This is a personal repo. Open an issue if something is broken or unclear.
