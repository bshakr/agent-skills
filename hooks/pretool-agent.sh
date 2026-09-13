#!/usr/bin/env bash
# PreToolUse hook, matcher: Agent
#
# Enforces Bass's subagent policy mechanically:
#   1. never pass `name:` to Agent (idle-notification routing bug, Claude Code #81439)
#   2. subagents never spawn their own fan-out
#   3. `model` is always explicit: haiku for Explore, opus otherwise
#   4. fable is reserved for design work
#
# FAIL-OPEN: any internal error allows the call and prints one stderr line.
# Bypass: CLAUDE_SKIP_AGENT_HOOK=1 (all checks), CLAUDE_ALLOW_FABLE=1 (fable gate),
#         CLAUDE_ALLOW_SUBAGENT_FANOUT=1 (nested spawn gate).
set -uo pipefail

INPUT=$(cat)

read -r -d '' PYCODE <<'PY' || true
import json, os, re, sys

data = json.loads(sys.stdin.read() or "{}")
ti = data.get("tool_input") or {}
if not isinstance(ti, dict) or not ti:
    sys.exit(0)  # nothing to judge: fail open
transcript = data.get("transcript_path") or ""
agent_id = data.get("agent_id") or ""


def emit(decision, reason, updated=None):
    hso = {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }
    if updated is not None:
        hso["updatedInput"] = updated
    sys.stdout.write(json.dumps({"hookSpecificOutput": hso}))
    sys.exit(0)


# 1. no name:
name = ti.get("name")
if isinstance(name, str) and name.strip():
    emit(
        "deny",
        "Do not pass name: to Agent (idle-notification routing bug, Claude Code "
        "#81439). Address the agent by the agent_id the spawn returns.",
    )

# 2. subagents do not fan out. Positive detection only, otherwise fail open.
in_subagent = bool(agent_id) or "/subagents/" in transcript
if in_subagent and os.environ.get("CLAUDE_ALLOW_SUBAGENT_FANOUT") != "1":
    emit(
        "deny",
        "Subagents do not spawn agents. Return the fan-out request to the "
        "coordinator.",
    )

subagent_type = ti.get("subagent_type")
subagent_type = subagent_type.strip() if isinstance(subagent_type, str) else ""
model = ti.get("model")
model = model.strip() if isinstance(model, str) else ""

# fork inherits the parent model by definition: leave it alone.
if subagent_type.lower() == "fork":
    sys.exit(0)

# 3. default the model explicitly
if not model:
    want = "haiku" if subagent_type.lower() == "explore" else "opus"
    updated = dict(ti)
    updated["model"] = want
    emit(
        "allow",
        "model was not passed; defaulted to %s per the subagent model policy "
        "(haiku for Explore, opus otherwise). Pass model explicitly next time."
        % want,
        updated,
    )

# 4. fable is for design work only
if "fable" in model.lower():
    if os.environ.get("CLAUDE_ALLOW_FABLE") == "1":
        sys.exit(0)
    description = ti.get("description")
    description = description if isinstance(description, str) else ""
    prompt = ti.get("prompt")
    prompt = prompt if isinstance(prompt, str) else ""
    haystack = description + "\n" + prompt[:600]
    design_re = re.compile(
        r"design|mockup|mock-up|artboard|canvas|brand|visual direction|"
        r"art direction|wirefram|aesthetic|typograph|palette|landing page|"
        r"homepage design|logo",
        re.IGNORECASE,
    )
    if design_re.search(haystack):
        emit("allow", "fable allowed: the brief reads as design work.")
    emit(
        "deny",
        "fable is reserved for design work (mockups, artboards, brand/visual "
        "direction). Use opus for implementation and review, or tag the "
        "description with design: if this really is design work.",
    )

# sonnet / haiku / opus and anything else: never blocked.
sys.exit(0)
PY

if [ "${CLAUDE_SKIP_AGENT_HOOK:-}" = "1" ]; then exit 0; fi

ERRFILE=$(mktemp -t claudehook 2>/dev/null) || ERRFILE=/dev/null
OUT=$(printf '%s' "$INPUT" | python3 -c "$PYCODE" 2>"$ERRFILE")
RC=$?
if [ "$RC" -ne 0 ]; then
  printf 'pretool-agent.sh: internal error, allowing the call (%s)\n' \
    "$(tail -n 1 "$ERRFILE" 2>/dev/null)" >&2
  [ "$ERRFILE" != /dev/null ] && rm -f "$ERRFILE"
  exit 0
fi
[ "$ERRFILE" != /dev/null ] && rm -f "$ERRFILE"
[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
