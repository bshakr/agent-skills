# Hooks

Claude Code hooks that enforce the standing rules mechanically, so they do not
depend on prompt text surviving a compaction. Verified against the hooks
reference for Claude Code 2.1.270.

All four are bash wrappers around python3, run in about 30 ms, and **fail open**:
any internal error, timeout or unparseable input allows the call and prints one
line to stderr (which lands in the hook debug log, not the transcript).

## Install

```bash
ln -sfn ~/code/agent-skills/hooks/pretool-agent.sh ~/.claude/hooks/pretool-agent.sh
ln -sfn ~/code/agent-skills/hooks/pretool-read.sh  ~/.claude/hooks/pretool-read.sh
ln -sfn ~/code/agent-skills/hooks/pretool-bash.sh  ~/.claude/hooks/pretool-bash.sh
ln -sfn ~/code/agent-skills/hooks/stop-check.sh    ~/.claude/hooks/stop-check.sh
```

Registered in `~/.claude/settings.json` under `hooks.PreToolUse` (matchers
`Agent`, `Read`, `Bash`) and `hooks.Stop`. Restart the session after changing
the registration; edits to the scripts themselves take effect immediately
because the symlink points at the repo.

## The hooks

### `pretool-agent.sh` (PreToolUse, matcher `Agent`)

Enforces the Subagent and Model Policy in `~/.claude/CLAUDE.md`.

| Condition | Decision |
|---|---|
| `tool_input.name` is set | **deny**: the idle-notification routing bug, Claude Code #81439. Address the agent by the `agent_id` the spawn returns |
| the call comes from inside a subagent (`agent_id` present, or `/subagents/` in `transcript_path`) | **deny**: subagents do not fan out, the request goes back to the coordinator |
| `subagent_type` is `fork` | allow untouched, a fork inherits the parent model by definition |
| `model` missing | allow with `updatedInput` setting `model` to `haiku` for `Explore`, `opus` otherwise |
| `model` contains `fable`, and description or the first 600 chars of the prompt read as design work | allow |
| `model` contains `fable`, anything else | **deny**: fable is for design, opus for implementation and review |
| `sonnet` / `haiku` / `opus` | allow, never blocked |

The design gate is a case-insensitive match on `design`, `mockup`, `mock-up`,
`artboard`, `canvas`, `brand`, `visual direction`, `art direction`, `wirefram`,
`aesthetic`, `typograph`, `palette`, `landing page`, `homepage design`, `logo`.

Bypass: `CLAUDE_ALLOW_FABLE=1` (fable gate), `CLAUDE_ALLOW_SUBAGENT_FANOUT=1`
(nested spawn), `CLAUDE_SKIP_AGENT_HOOK=1` (everything).

### `pretool-read.sh` (PreToolUse, matcher `Read`)

The coordinator never Reads an image: 150 image reads in one month were the
largest single consumer of main-session context. Denies `Read` on
`.png .jpg .jpeg .gif .webp .bmp .tif .tiff` from the main session only.
Subagent reads (`/subagents/` transcript, or an `agent_id` in the payload) are
allowed, so a capture agent still opens the shots and returns a verdict.

Bypass: `CLAUDE_ALLOW_IMAGE_READ=1`.

### `pretool-bash.sh` (PreToolUse, matcher `Bash`)

Inspects `tool_input.command`.

| Pattern | Decision | Why |
|---|---|---|
| `gh pr` + merge | **deny** | merging is never Claude's. Report "review clean, CI green, ready to merge" and wait |
| `git add -A`, `git add --all`, `git add .`, `git commit -a` / `-am` | **deny** | concurrent agents share the index, so commit with an explicit pathspec |
| `railway variables` without `--json` | **deny** | a staging password rendered into the transcript twice. Pipe `--json` through python that prints names plus the SHA-256 of values |
| `gwt-prune-merged --force` while some unlocked worktree is 0 commits ahead of `origin/main` | **deny**, naming the worktrees | that is how three live agents' worktrees got swept. `git worktree lock` each live one first |
| a command starting with `sleep` | **deny** | foreground polling. Use `pr-ci-wait` in the background, `Monitor`, or `ScheduleWakeup` |
| anything else | silent allow, normal permission flow continues | |

The prune check shells out to `git worktree list --porcelain` and
`git rev-list --count origin/main..<branch>` in the hook's `cwd`, skips locked,
bare and detached worktrees, and fails open on any git error.

The merge rule matches the literal command text, so a heredoc or an `echo` that
merely quotes the phrase is denied too. That is deliberate: the false positive
is cheap, the false negative deploys to production. Use the Write tool or a
bypass variable when writing documentation about it.

Bypass: `CLAUDE_ALLOW_PR_MERGE=1`, `CLAUDE_ALLOW_GIT_ADD_ALL=1`,
`CLAUDE_ALLOW_RAILWAY_VARS=1`, `CLAUDE_ALLOW_PRUNE_FORCE=1`,
`CLAUDE_ALLOW_SLEEP=1`, `CLAUDE_SKIP_BASH_HOOK=1` (everything). A hook reads the
environment of the Claude Code process, so exporting one of these inside a Bash
tool call does not reach it: set it before launching `claude`.

### `stop-check.sh` (Stop)

Refuses to end the turn while a PR opened in this session is not handover
clean. Returns `{"decision": "block", "reason": "..."}`.

1. `stop_hook_active` true, or running inside a subagent: allow immediately
   (loop guard, and Claude Code overrides a Stop hook after 8 consecutive
   blocks anyway).
2. Scans the session transcript for `https://github.com/<org>/<repo>/pull/<n>`
   appearing after a `gh pr create` call, dedupes, keeps the first 5.
3. For each, runs `gh pr view <url> --json` with
   `state,mergeable,mergeStateStatus,statusCheckRollup,files,body`.
   Closed and merged PRs are skipped.
4. Blocks when any open PR has checks queued, in progress or failing; or changes
   UI (paths under `apps/web`, `admin-web`, `client-web`, `components/`,
   `app/views`, or a `.tsx .jsx .vue .erb .css .scss` extension) while the body
   has no `claude.ai/code/artifact` link; or reports `mergeStateStatus: DIRTY`.

Hard budget 25 s (`timeout` plus an internal 22 s deadline), then it allows the
stop. Bypass: `CLAUDE_SKIP_STOP_CHECK=1`.

## Tests

```bash
hooks/test-hooks.sh
```

40 assertions, no network: the Stop tests put a stub `gh` on `PATH` and feed a
synthetic transcript. Every bypass variable is unset at the top of the run, so
the suite tests the rules rather than the escape hatches.

## Command-position guard

The Bash guards match only in command position (start of the command, after `;`, `&`, `|`, `(` or a newline), so prose mentions in commit messages, heredocs and quoted strings pass. `test-hooks-prose.sh` covers both sides.
