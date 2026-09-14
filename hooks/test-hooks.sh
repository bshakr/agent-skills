#!/usr/bin/env bash
# Feeds sample hook payloads to each hook and asserts the decision.
# Usage: hooks/test-hooks.sh          (no network, no gh: the Stop tests stub gh)
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

# Strip every bypass variable so the suite tests the hooks, not the escape hatches.
unset CLAUDE_ALLOW_FABLE CLAUDE_ALLOW_IMAGE_READ CLAUDE_SKIP_AGENT_HOOK \
      CLAUDE_SKIP_BASH_HOOK CLAUDE_SKIP_STOP_CHECK CLAUDE_ALLOW_PR_MERGE \
      CLAUDE_ALLOW_GIT_ADD_ALL CLAUDE_ALLOW_RAILWAY_VARS \
      CLAUDE_ALLOW_PRUNE_FORCE CLAUDE_ALLOW_SLEEP \
      CLAUDE_ALLOW_SUBAGENT_FANOUT 2>/dev/null || true

MAIN_TP='/Users/x/.claude/projects/-p/sess.jsonl'
SUB_TP='/Users/x/.claude/projects/-p/sess/subagents/agent-a1.jsonl'

# ---- payload builders (python does the quoting so the shell never has to) ----

agent_payload() { # <transcript> <name> <description> <prompt> <subagent_type> <model>
  python3 - "$@" <<'PY'
import json, sys
tp, name, desc, prompt, stype, model = sys.argv[1:7]
ti = {}
if name:
    ti["name"] = name
ti["description"] = desc
ti["prompt"] = prompt
if stype:
    ti["subagent_type"] = stype
if model:
    ti["model"] = model
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Agent",
                  "transcript_path": tp, "tool_input": ti}))
PY
}

read_payload() { # <transcript> <file_path>
  python3 - "$@" <<'PY'
import json, sys
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Read",
                  "transcript_path": sys.argv[1],
                  "tool_input": {"file_path": sys.argv[2]}}))
PY
}

bash_payload() { # <transcript> <cwd> <command>
  python3 - "$@" <<'PY'
import json, sys
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash",
                  "transcript_path": sys.argv[1], "cwd": sys.argv[2],
                  "tool_input": {"command": sys.argv[3]}}))
PY
}

stop_payload() { # <transcript> <stop_hook_active:true|false> [agent_id]
  python3 - "$@" <<'PY'
import json, sys
out = {"hook_event_name": "Stop", "transcript_path": sys.argv[1],
       "stop_hook_active": sys.argv[2] == "true"}
if len(sys.argv) > 3 and sys.argv[3]:
    out["agent_id"] = sys.argv[3]
print(json.dumps(out))
PY
}

# The parser reads the hook's stdout on stdin, so it cannot itself be fed by a
# heredoc: the heredoc would take over stdin and the hook output would be lost.
read -r -d '' PARSER <<'PY' || true
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("allow")
    sys.exit()
d = json.loads(raw)
if "decision" in d:
    print(d["decision"])
    sys.exit()
hso = d.get("hookSpecificOutput") or {}
out = hso.get("permissionDecision", "allow")
ui = hso.get("updatedInput")
if ui and "model" in ui:
    out += ":model=" + str(ui["model"])
print(out)
PY

# decision <hook> <json>  ->  "allow" | "deny" | "block" | "allow:model=<m>"
decision() {
  printf '%s' "$2" | "$HOOK_DIR/$1" 2>/dev/null | python3 -c "$PARSER"
}

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    printf '  ok   %-50s %s\n' "$1" "$3"
    PASS=$((PASS + 1))
  else
    printf '  FAIL %-50s expected %s, got %s\n' "$1" "$2" "$3"
    FAIL=$((FAIL + 1))
  fi
}

echo "pretool-agent.sh"
check "name: set -> deny" deny \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" retro-b01 'do a thing' 'the prompt' general-purpose opus)")"
check "spawn from inside a subagent -> deny" deny \
  "$(decision pretool-agent.sh "$(agent_payload "$SUB_TP" '' 'do a thing' 'the prompt' Explore haiku)")"
check "fable + design mockups -> allow" allow \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'design mockups for the dashboard' 'three artboards please' general-purpose fable)")"
check "fable + implement BLO-1 -> deny" deny \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'implement BLO-1' 'write the migration and the service object' general-purpose fable)")"
check "missing model -> updatedInput opus" allow:model=opus \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'implement BLO-1' 'write the migration' general-purpose '')")"
check "Explore missing model -> updatedInput haiku" allow:model=haiku \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'find the callers' 'search the repo' Explore '')")"
check "fork missing model -> untouched" allow \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'continue this' 'keep going' fork '')")"
check "sonnet -> allow" allow \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'run the tests' 'bin/ci' general-purpose sonnet)")"
check "opus -> allow" allow \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'implement BLO-1' 'write it' general-purpose opus)")"
check "haiku -> allow" allow \
  "$(decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'grep for x' 'search' Explore haiku)")"
check "fable + CLAUDE_ALLOW_FABLE=1 -> allow" allow \
  "$(CLAUDE_ALLOW_FABLE=1 decision pretool-agent.sh "$(agent_payload "$MAIN_TP" '' 'implement BLO-1' 'write it' general-purpose fable)")"
check "empty tool_input -> allow (fail open)" allow \
  "$(decision pretool-agent.sh '{"tool_name":"Agent","transcript_path":"/a/b.jsonl","tool_input":{}}')"

echo "pretool-read.sh"
check "foo.png from the main transcript -> deny" deny \
  "$(decision pretool-read.sh "$(read_payload "$MAIN_TP" /tmp/shots/foo.png)")"
check "foo.JPEG from the main transcript -> deny" deny \
  "$(decision pretool-read.sh "$(read_payload "$MAIN_TP" /tmp/shots/foo.JPEG)")"
check "foo.png from a /subagents/ transcript -> allow" allow \
  "$(decision pretool-read.sh "$(read_payload "$SUB_TP" /tmp/shots/foo.png)")"
check "VERDICT.md from the main transcript -> allow" allow \
  "$(decision pretool-read.sh "$(read_payload "$MAIN_TP" /tmp/shots/VERDICT.md)")"
check "foo.png + CLAUDE_ALLOW_IMAGE_READ=1 -> allow" allow \
  "$(CLAUDE_ALLOW_IMAGE_READ=1 decision pretool-read.sh "$(read_payload "$MAIN_TP" /tmp/shots/foo.png)")"

echo "pretool-bash.sh"
bash_case() { # <label> <expected> <command>
  check "$1" "$2" "$(decision pretool-bash.sh "$(bash_payload "$MAIN_TP" "$PWD" "$3")")"
}
bash_case "gh pr merge -> deny" deny 'gh pr merge 28 --squash'
bash_case "git add -A -> deny" deny 'git add -A'
bash_case "git add --all -> deny" deny 'git add --all'
bash_case "git add . -> deny" deny 'git add .'
bash_case "git commit -am -> deny" deny 'git commit -am "wip"'
bash_case "git commit -a -> deny" deny 'git commit -a'
bash_case "git commit -m with pathspec -> allow" allow 'git commit -m "fix" app/models/shift.rb'
bash_case "git add with pathspec -> allow" allow 'git add app/models/shift.rb'
bash_case "railway variables -> deny" deny 'railway variables'
bash_case "railway variables --json -> allow" allow 'railway variables --json | python3 hash.py'
bash_case "sleep 30 -> deny" deny 'sleep 30'
bash_case "echo sleep 30 -> allow" allow 'echo sleep 30'
bash_case "gh pr view -> allow" allow 'gh pr view 28 --json state'

echo "stop-check.sh"
check "stop_hook_active true -> allow" allow \
  "$(decision stop-check.sh "$(stop_payload "$MAIN_TP" true)")"
check "no transcript on disk -> allow" allow \
  "$(decision stop-check.sh "$(stop_payload /nope/missing.jsonl false)")"
check "inside a subagent -> allow" allow \
  "$(decision stop-check.sh "$(stop_payload "$SUB_TP" false a1)")"

# Live path with a stubbed `gh` on PATH: no network, no real PR.
STUB_DIR=$(mktemp -d)
TRANSCRIPT="$STUB_DIR/sess.jsonl"
cat > "$TRANSCRIPT" <<'JSONL'
{"type":"user","message":{"content":[{"type":"text","text":"peer says https://github.com/bshakr/rota/pull/45 has conflicts"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_create1","name":"Bash","input":{"command":"gh pr create --title x --body y"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_create1","content":"https://github.com/bshakr/houserota/pull/28"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"see also https://github.com/bshakr/rota/pull/99 (not ours)"}]}}
JSONL
# A transcript that only MENTIONS PR URLs (peer message, pasted link) owns no PR.
MENTION_TP="$STUB_DIR/mention.jsonl"
cat > "$MENTION_TP" <<'JSONL'
{"type":"user","message":{"content":[{"type":"text","text":"PR https://github.com/bshakr/rota/pull/45 has conflicts, rebase on origin/main"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"the skill runs gh pr create later; https://github.com/bshakr/rota/pull/45"}]}}
JSONL
printf '#!/usr/bin/env bash\ncat "$GH_STUB_PAYLOAD"\n' > "$STUB_DIR/gh"
chmod +x "$STUB_DIR/gh"

stop_case() { # <label> <expected> <pr-json>
  printf '%s' "$3" > "$STUB_DIR/payload.json"
  check "$1" "$2" "$(PATH="$STUB_DIR:$PATH" GH_STUB_PAYLOAD="$STUB_DIR/payload.json" \
    decision stop-check.sh "$(stop_payload "$TRANSCRIPT" false)")"
}
stop_case "open PR, CI in_progress -> block" block \
  '{"state":"OPEN","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"status":"IN_PROGRESS","conclusion":null}],"files":[{"path":"app/models/shift.rb"}],"body":"Summary"}'
stop_case "open PR, CI failure -> block" block \
  '{"state":"OPEN","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"status":"COMPLETED","conclusion":"FAILURE"}],"files":[{"path":"app/models/shift.rb"}],"body":"Summary"}'
stop_case "open PR, UI diff, no gallery -> block" block \
  '{"state":"OPEN","mergeStateStatus":"CLEAN","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}],"files":[{"path":"apps/web/app/dashboard/page.tsx"}],"body":"Summary"}'
stop_case "open PR, UI diff, gallery linked -> allow" allow \
  '{"state":"OPEN","mergeStateStatus":"CLEAN","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}],"files":[{"path":"apps/web/app/dashboard/page.tsx"}],"body":"See https://claude.ai/code/artifact/abc"}'
stop_case "open PR, conflicts -> block" block \
  '{"state":"OPEN","mergeStateStatus":"DIRTY","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}],"files":[{"path":"README.md"}],"body":"Summary"}'
stop_case "merged PR -> allow" allow \
  '{"state":"MERGED","mergeStateStatus":"UNKNOWN","statusCheckRollup":[],"files":[{"path":"apps/web/x.tsx"}],"body":""}'
stop_case "green non-UI PR -> allow" allow \
  '{"state":"OPEN","mergeStateStatus":"CLEAN","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}],"files":[{"path":"app/models/shift.rb"}],"body":"Summary"}'
# The stub returns a conflicted PR for ANY url; a mention-only transcript must never query it.
printf '%s' '{"state":"OPEN","mergeStateStatus":"DIRTY","statusCheckRollup":[],"files":[],"body":""}' > "$STUB_DIR/payload.json"
check "PR only mentioned by a peer, not created here -> allow" allow \
  "$(PATH="$STUB_DIR:$PATH" GH_STUB_PAYLOAD="$STUB_DIR/payload.json" \
    decision stop-check.sh "$(stop_payload "$MENTION_TP" false)")"
rm -rf "$STUB_DIR"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
