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

urls = []
seen_create = False
try:
    with open(transcript, "r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not seen_create:
                if "gh pr create" in line:
                    seen_create = True
                continue
            for match in PR_RE.findall(line):
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

    paths = [
        f.get("path") or ""
        for f in (pr.get("files") or [])
        if isinstance(f, dict)
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
