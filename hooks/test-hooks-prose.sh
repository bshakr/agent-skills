#!/usr/bin/env bash
# Extra cases for pretool-bash.sh: prose mentions must pass, command position must deny.
H=~/code/agent-skills/hooks/pretool-bash.sh
run() { printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$1}}" | bash "$H"; }
check() { local label=$1 expect=$2 out; out=$(run "$3"); if [ "$expect" = allow ]; then [ -z "$out" ] && echo "ok   $label" || echo "FAIL $label -> $out"; else echo "$out" | grep -q '"deny"' && echo "ok   $label" || echo "FAIL $label -> (allowed)"; fi; }
check "prose merge in commit msg -> allow" allow '"git commit -m \"docs: never run gh pr merge in prose\" -- README.md"'
check "prose add -A in commit msg -> allow" allow '"git commit -m \"note: no git add -A\" -- x"'
check "heredoc line mentioning railway variables -> allow" allow '"cat <<EOF\nuse railway variables --json only\nEOF"'
check "merge after && -> deny" deny '"cd x && gh pr merge 5"'
check "merge on new line -> deny" deny '"cd x\ngh pr merge 5 --squash"'
check "merge at start -> deny" deny '"gh pr merge 5"'
check "add -A after ; -> deny" deny '"cd x; git add -A"'
check "commit -am at start -> deny" deny '"git commit -am wip"'
check "raw railway variables after | -> deny" deny '"true | railway variables"'
check "railway variables --json -> allow" allow '"railway variables --json"'
