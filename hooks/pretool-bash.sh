#!/usr/bin/env bash
# PreToolUse hook, matcher: Bash
#
# Blocks the five Bash shapes that cost Bass real time this month:
#   gh pr merge            merging is never Claude's call
#   git add -A / commit -a concurrent agents share the index
#   railway variables      without --json this renders secrets in the transcript
#   gwt-prune-merged --force  sweeps commitless worktrees a live agent still owns
#   leading sleep          foreground polling burns the turn
#
# FAIL-OPEN. Bypass: CLAUDE_SKIP_BASH_HOOK=1 (all), CLAUDE_ALLOW_PR_MERGE=1,
#   CLAUDE_ALLOW_GIT_ADD_ALL=1, CLAUDE_ALLOW_RAILWAY_VARS=1,
#   CLAUDE_ALLOW_PRUNE_FORCE=1, CLAUDE_ALLOW_SLEEP=1.
set -uo pipefail

INPUT=$(cat)

read -r -d '' PYCODE <<'PY' || true
import json, os, re, subprocess, sys

data = json.loads(sys.stdin.read() or "{}")
ti = data.get("tool_input") or {}
if not isinstance(ti, dict):
    sys.exit(0)
cmd = ti.get("command")
cmd = cmd if isinstance(cmd, str) else ""
if not cmd.strip():
    sys.exit(0)
cwd = data.get("cwd") or os.getcwd()


def deny(reason):
    sys.stdout.write(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )
    sys.exit(0)


def off(var):
    return os.environ.get(var) == "1"


# Command position only: start of the command, after ; & | ( or a newline.
# Prose mentions inside quotes, heredocs or commit messages do not match.
POS = r"(?:^|[;&|(]\s*|\n\s*)"


# 1. never merge
if not off("CLAUDE_ALLOW_PR_MERGE") and re.search(POS + r"gh\s+pr\s+merge\b", cmd):
    deny(
        "Merging is never Claude's. Report: review clean, CI green, ready to "
        "merge - want me to?"
    )

# 2. explicit pathspecs
if not off("CLAUDE_ALLOW_GIT_ADD_ALL"):
    add_all = re.search(POS + r"git\s+add\s+(?:-A\b|--all\b|\.(?:\s|$|;|&|\|))", cmd)
    commit_all = re.search(
        POS + r"git\s+commit\b[^;|&\n]*?\s(?:--all\b|-(?!-)[A-Za-z]*a[A-Za-z]*\b)", cmd
    )
    if add_all or commit_all:
        deny(
            "Commit with an explicit pathspec on git commit (concurrent agents "
            "share the index)."
        )

# 3. never render raw railway variables
if not off("CLAUDE_ALLOW_RAILWAY_VARS") and re.search(
    POS + r"railway\s+variables\b", cmd
):
    if "--json" not in cmd:
        deny(
            "Never render raw railway variables (a staging password leaked "
            "twice). Use `railway variables --json` piped through python that "
            "prints names and SHA-256 of values only."
        )

# 4. gwt-prune-merged --force would sweep commitless live worktrees
if not off("CLAUDE_ALLOW_PRUNE_FORCE") and re.search(
    POS + r"gwt-prune-merged\b", cmd
) and re.search(r"(?:^|\s)(?:--force|-f)(?:\s|$)", cmd):

    def git(args, timeout=5):
        return subprocess.run(
            ["git"] + args,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )

    try:
        listing = git(["worktree", "list", "--porcelain"])
        if listing.returncode == 0:
            blocks, current = [], {}
            for line in listing.stdout.splitlines():
                if not line.strip():
                    if current:
                        blocks.append(current)
                        current = {}
                    continue
                key, _, value = line.partition(" ")
                current[key] = value
            if current:
                blocks.append(current)

            at_risk = []
            for block in blocks[1:]:  # blocks[0] is the main worktree
                if "locked" in block or "bare" in block or "detached" in block:
                    continue
                ref = block.get("branch") or ""
                if not ref.startswith("refs/heads/"):
                    continue
                branch = ref[len("refs/heads/") :]
                counted = git(
                    ["rev-list", "--count", "origin/main..%s" % branch]
                )
                if counted.returncode != 0:
                    continue
                if counted.stdout.strip() == "0":
                    at_risk.append(
                        "%s (%s)" % (block.get("worktree", "?"), branch)
                    )

            if at_risk:
                deny(
                    "These worktrees are commitless and would be swept as "
                    "merged: %s. `git worktree lock` each live one first, then "
                    "re-run." % ", ".join(at_risk)
                )
    except Exception as exc:  # fail open on any git trouble
        sys.stderr.write("pretool-bash.sh: prune guard skipped (%s)\n" % exc)

# 5. no foreground polling
if not off("CLAUDE_ALLOW_SLEEP") and re.match(r"^\s*sleep\b", cmd):
    deny("Run pr-ci-wait (CI) or pr-merge-wait (merges) with run_in_background; the harness wakes you when it exits.")

sys.exit(0)
PY

if [ "${CLAUDE_SKIP_BASH_HOOK:-}" = "1" ]; then exit 0; fi

ERRFILE=$(mktemp -t claudehook 2>/dev/null) || ERRFILE=/dev/null
OUT=$(printf '%s' "$INPUT" | python3 -c "$PYCODE" 2>"$ERRFILE")
RC=$?
if [ "$RC" -ne 0 ]; then
  printf 'pretool-bash.sh: internal error, allowing the call (%s)\n' \
    "$(tail -n 1 "$ERRFILE" 2>/dev/null)" >&2
  [ "$ERRFILE" != /dev/null ] && rm -f "$ERRFILE"
  exit 0
fi
[ "$ERRFILE" != /dev/null ] && rm -f "$ERRFILE"
[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
