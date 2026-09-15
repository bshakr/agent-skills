#!/usr/bin/env bash
# Stop hook
#
# Refuses to end the turn while a PR opened in THIS session is not handover
# clean: CI pending or red, a UI diff with no gallery link in the body, or a
# branch that has gone conflicted. Bass should never be the one who notices.
#
# FAIL-OPEN, hard 25 s budget, skipped inside subagents and on the second pass
# (stop_hook_active). Bypass: CLAUDE_SKIP_STOP_CHECK=1.
set -uo pipefail

INPUT=$(cat)

read -r -d '' PYCODE <<'PY' || true
import json, os, re, subprocess, sys, time

DEADLINE = time.monotonic() + 22.0

data = json.loads(sys.stdin.read() or "{}")

# loop guard: never block twice in a row on the same condition
if data.get("stop_hook_active"):
    sys.exit(0)

transcript = data.get("transcript_path") or ""
if data.get("agent_id") or "/subagents/" in transcript:
    sys.exit(0)
if not transcript or not os.path.isfile(transcript):
    sys.exit(0)

PR_RE = re.compile(r"https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/pull/\d+")

# Only PRs this session created: a Bash tool_use whose command runs `gh pr create`,
# and the PR URL taken from THAT call's tool_result. A PR URL merely mentioned in
# the transcript (a peer's message, a retro report, a pasted link) is not ours.
urls = []
create_ids = set()
CREATE_RE = re.compile(r"(?:^|[;&|(]\s*|\n\s*)gh\s+pr\s+create\b")
try:
    with open(transcript, "r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if "gh pr create" not in line and "tool_result" not in line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                continue
            content = ((entry.get("message") or {}).get("content")) or []
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_use" and block.get("name") == "Bash":
                    cmd = str((block.get("input") or {}).get("command") or "")
                    if CREATE_RE.search(cmd):
                        create_ids.add(block.get("id"))
                elif (
                    block.get("type") == "tool_result"
                    and block.get("tool_use_id") in create_ids
                ):
                    raw = block.get("content")
                    text = raw if isinstance(raw, str) else json.dumps(raw)
                    for match in PR_RE.findall(text):
                        if match not in urls:
                            urls.append(match)
except Exception as exc:
    sys.stderr.write("stop-check.sh: transcript unreadable (%s)\n" % exc)
    sys.exit(0)

if not urls:
    sys.exit(0)
urls = urls[-5:]  # most recent five: old merged PRs sit at the top of a long transcript

UI_DIR_RE = re.compile(r"(^|/)(apps/web|admin-web|client-web|components|app/views)/")
UI_EXT_RE = re.compile(r"\.(tsx|jsx|vue|erb|css|scss)$", re.IGNORECASE)
PENDING = {"QUEUED", "IN_PROGRESS", "PENDING", "WAITING", "REQUESTED"}
FAILING = {
    "FAILURE",
    "TIMED_OUT",
    "CANCELLED",
    "ACTION_REQUIRED",
    "STARTUP_FAILURE",
    "ERROR",
    "STALE",
}

problems = []
for url in urls:
    remaining = DEADLINE - time.monotonic()
    if remaining <= 2:
        break
    try:
        proc = subprocess.run(
            [
                "gh",
                "pr",
                "view",
                url,
                "--json",
                "state,mergeable,mergeStateStatus,statusCheckRollup,files,body",
            ],
            capture_output=True,
            text=True,
            timeout=min(remaining, 12),
        )
    except Exception:
        continue
    if proc.returncode != 0 or not proc.stdout.strip():
        continue
    try:
        pr = json.loads(proc.stdout)
    except Exception:
        continue

    if (pr.get("state") or "").upper() != "OPEN":
        continue

    rollup = pr.get("statusCheckRollup") or []
    pending = failing = False
    for check in rollup:
        if not isinstance(check, dict):
            continue
        status = (check.get("status") or "").upper()
        conclusion = (check.get("conclusion") or "").upper()
        state = (check.get("state") or "").upper()
        if status in PENDING or state in PENDING:
            pending = True
        if conclusion in FAILING or state in FAILING:
            failing = True
    if failing or pending:
        problems.append(
            "PR %s: CI %s. Run pr-ci-wait in the background and fix before "
            "handing over." % (url, "failing" if failing else "pending")
        )

    # a file that gained no lines was deleted or only lost code: nothing new
    # to screenshot. additions missing (older gh) still counts as a UI change.
    paths = [
        f.get("path") or ""
        for f in (pr.get("files") or [])
        if isinstance(f, dict) and f.get("additions") != 0
    ]
    touches_ui = any(
        UI_DIR_RE.search("/" + p) or UI_EXT_RE.search(p) for p in paths
    )
    body = pr.get("body") or ""
    if touches_ui and "claude.ai/code/artifact" not in body:
        problems.append(
            "PR %s changes UI but its body has no gallery link. Run "
            "capture-pairs + rp-gallery and pr-append-section." % url
        )

    if (pr.get("mergeStateStatus") or "").upper() == "DIRTY":
        problems.append("PR %s has conflicts; rebase on origin/main." % url)

if problems:
    sys.stdout.write(
        json.dumps({"decision": "block", "reason": "\n".join(problems)})
    )
sys.exit(0)
PY

if [ "${CLAUDE_SKIP_STOP_CHECK:-}" = "1" ]; then exit 0; fi

RUNNER=""
command -v timeout >/dev/null 2>&1 && RUNNER="timeout 25"

ERRFILE=$(mktemp -t claudehook 2>/dev/null) || ERRFILE=/dev/null
OUT=$(printf '%s' "$INPUT" | $RUNNER python3 -c "$PYCODE" 2>"$ERRFILE")
RC=$?
if [ "$RC" -ne 0 ]; then
  printf 'stop-check.sh: internal error or timeout, allowing the stop (%s)\n' \
    "$(tail -n 1 "$ERRFILE" 2>/dev/null)" >&2
  [ "$ERRFILE" != /dev/null ] && rm -f "$ERRFILE"
  exit 0
fi
[ "$ERRFILE" != /dev/null ] && rm -f "$ERRFILE"
[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
