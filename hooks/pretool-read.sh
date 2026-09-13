#!/usr/bin/env bash
# PreToolUse hook, matcher: Read
#
# The coordinator never Reads an image: image reads are the single largest
# consumer of main-session context. Capture agents open the shots and return a
# verdict plus paths. Subagent Reads are allowed.
#
# FAIL-OPEN. Bypass: CLAUDE_ALLOW_IMAGE_READ=1.
set -uo pipefail

INPUT=$(cat)

read -r -d '' PYCODE <<'PY' || true
import json, re, sys

data = json.loads(sys.stdin.read() or "{}")
ti = data.get("tool_input") or {}
if not isinstance(ti, dict):
    sys.exit(0)

path = ti.get("file_path")
path = path if isinstance(path, str) else ""
path = path.replace("\\", "/")

if not re.search(r"\.(png|jpe?g|gif|webp|bmp|tiff?)$", path, re.IGNORECASE):
    sys.exit(0)

transcript = data.get("transcript_path") or ""
if "/subagents/" in transcript or data.get("agent_id"):
    sys.exit(0)

sys.stdout.write(
    json.dumps(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    "The coordinator never Reads an image (largest context "
                    "cost). Delegate to a capture agent (capture-pairs skill) "
                    "and read its VERDICT.md."
                ),
            }
        }
    )
)
PY

if [ "${CLAUDE_ALLOW_IMAGE_READ:-}" = "1" ]; then exit 0; fi

ERRFILE=$(mktemp -t claudehook 2>/dev/null) || ERRFILE=/dev/null
OUT=$(printf '%s' "$INPUT" | python3 -c "$PYCODE" 2>"$ERRFILE")
RC=$?
if [ "$RC" -ne 0 ]; then
  printf 'pretool-read.sh: internal error, allowing the call (%s)\n' \
    "$(tail -n 1 "$ERRFILE" 2>/dev/null)" >&2
  [ "$ERRFILE" != /dev/null ] && rm -f "$ERRFILE"
  exit 0
fi
[ "$ERRFILE" != /dev/null ] && rm -f "$ERRFILE"
[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
