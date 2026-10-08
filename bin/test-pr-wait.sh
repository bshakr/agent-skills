#!/usr/bin/env bash
# State-file tests for pr-ci-wait and pr-merge-wait against a stubbed gh, plus a
# main-vs-branch comparison of stdout, stderr and exit code for every outcome.
# Usage: bin/test-pr-wait.sh   (no network; MAIN_REF defaults to origin/main)
set -uo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_REF=${MAIN_REF:-origin/main}
PASS=0
FAIL=0
WORK=$(mktemp -d)
trap '[ -n "${KEEP:-}" ] && echo "kept $WORK" || rm -rf "$WORK"' EXIT

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }
check() { # <description> <command...>
	local d=$1; shift
	if "$@" >/dev/null 2>&1; then ok; else bad "$d"; fi
}

# ---- main's scripts, for the comparison runs ----
mkdir -p "$WORK/main"
for s in pr-ci-wait pr-merge-wait; do
	git -C "$BIN_DIR" show "$MAIN_REF:bin/$s" >"$WORK/main/$s" && chmod +x "$WORK/main/$s"
done

# ---- gh stub: builds real JSON and applies the caller's own --jq ----
# STUB_MODE picks the scenario; STUB_SLOW_FROM=<n> sleeps STUB_SLOW seconds on
# the n-th and later calls; STUB_FAIL_FROM=<n> makes pr view fail from call n;
# STUB_STDERR=1 adds a gh warning on stderr to every successful call.
mkdir -p "$WORK/stub"
cat >"$WORK/stub/gh" <<'STUB'
#!/usr/bin/env bash
cnt="$STUB_DIR/count"
c=$(($(cat "$cnt" 2>/dev/null || printf 0) + 1))
printf '%s' "$c" >"$cnt"
sub="$1 $2"
n=${3:-}
q="" required=0
while [ $# -gt 0 ]; do
	case "$1" in -q | --jq) q=$2; shift ;; --required) required=1 ;; esac
	shift
done
if [ -n "${STUB_SLOW_FROM:-}" ] && [ "$c" -ge "$STUB_SLOW_FROM" ]; then sleep "${STUB_SLOW:-6}"; fi
mode=${STUB_MODE:-green}
sha=abc1234def
body='Summary
| a | b |
Gallery: https://claude.ai/artifact/xyz "quoted"'
case "$sub" in
"pr view")
	[ "$mode" = notfound ] && { printf 'GraphQL: Could not resolve to a PullRequest with the number of %s.\n' "$n" >&2; exit 1; }
	if [ -n "${STUB_FAIL_FROM:-}" ] && [ "$c" -ge "$STUB_FAIL_FROM" ]; then printf 'HTTP 502: Bad Gateway\n' >&2; exit 1; fi
	st=OPEN mrg=MERGEABLE mss=CLEAN
	case "$mode" in
	merged) [ "$n" = 8 ] && st=MERGED ;;
	closed) st=CLOSED ;;
	conflict) mrg=CONFLICTING mss=DIRTY ;;
	behind) mss=BEHIND ;;
	mergedlater) [ "$c" -gt 1 ] && st=MERGED ;;
	esac
	obj=$(jq -cn --arg st "$st" --arg n "$n" --arg sha "$sha" --arg body "$body" --arg mrg "$mrg" --arg mss "$mss" '{
		number: ($n | tonumber), state: $st, url: ("https://github.com/acme/widgets/pull/" + $n),
		mergeable: $mrg, mergeStateStatus: $mss, headRefName: ("feat-" + $n),
		mergeCommit: (if $st == "MERGED" then {oid: "m123"} else null end),
		headRefOid: $sha, title: ("PR " + $n), body: $body}')
	;;
"pr checks")
	if [ "$required" = 1 ]; then
		obj='[{"name":"build"}]'
	else
		case "$mode" in
		pending | mergedlater) obj='[{"name":"build","state":"IN_PROGRESS","bucket":"pending","link":"","workflow":"ci"}]' ;;
		fail) obj='[{"name":"build","state":"FAILURE","bucket":"fail","link":"https://github.com/acme/widgets/actions/runs/42/job/1","workflow":"ci"},{"name":"lint","state":"SUCCESS","bucket":"pass","link":"","workflow":"ci"}]' ;;
		*) obj='[{"name":"build","state":"SUCCESS","bucket":"pass","link":"https://ci.example/1","workflow":"ci"},{"name":"lint","state":"SKIPPED","bucket":"skipping","link":"","workflow":"ci"}]' ;;
		esac
	fi
	;;
"run view") printf 'build\tstep\terror: it broke\n'; exit 0 ;;
"repo view") obj='{"nameWithOwner":"acme/widgets"}' ;;
*) printf 'stub gh: unhandled: %s\n' "$sub" >&2; exit 1 ;;
esac
if [ -n "$q" ]; then printf '%s' "$obj" | jq -r "$q"; else printf '%s\n' "$obj"; fi
[ -z "${STUB_STDERR:-}" ] || printf 'A new release of gh is available\n' >&2
exit 0
STUB
chmod +x "$WORK/stub/gh"
# sleep shim, so a failing sleep can be injected into both versions alike
cat >"$WORK/stub/sleep" <<'SHIM'
#!/bin/sh
[ -z "${STUB_SLEEP_FAIL:-}" ] || { echo "sleep: invalid time interval" >&2; exit 1; }
exec /bin/sleep "$@"
SHIM
chmod +x "$WORK/stub/sleep"
export PATH="$WORK/stub:$PATH"

N_RUN=0
# run <script-dir> <state-dir> <name> <script> <args...>; leaves $WORK/<name>.{stdout,stderr,code}
run() {
	local dir=$1 sd=$2 name=$3 s=$4; shift 4
	N_RUN=$((N_RUN + 1))
	export STUB_DIR="$WORK/stubstate.$N_RUN"
	mkdir -p "$STUB_DIR"
	PR_WATCH_STATE_DIR=$sd "$dir/$s" "$@" >"$WORK/$name.stdout" 2>"$WORK/$name.stderr"
	printf '%s' "$?" >"$WORK/$name.code"
}
code_of() { cat "$WORK/$1.code"; }
normalise() { sed -E 's/\+[0-9]+s/+Ns/g; s/after [0-9]+s/after Ns/g; s/[0-9]+s ago/Ns ago/g' "$1"; }

# Same scenario on main and on the branch: stdout, stderr and exit code must match.
same_as_main() { # <name> <script> <args...>
	local name=$1; shift
	run "$WORK/main" "$WORK/state-main-$name" "main-$name" "$@"
	run "$BIN_DIR" "$WORK/state-$name" "$name" "$@"
	check "$name: exit code matches main ($(code_of "main-$name") vs $(code_of "$name"))" \
		test "$(code_of "main-$name")" = "$(code_of "$name")"
	check "$name: stdout matches main" diff <(normalise "$WORK/main-$name.stdout") <(normalise "$WORK/$name.stdout")
	check "$name: stderr matches main" diff <(normalise "$WORK/main-$name.stderr") <(normalise "$WORK/$name.stderr")
}

SHAPE='.version == 1 and (.repo | type) == "string" and (.number | type) == "number"
	and (.watcher | IN("ci-wait", "merge-wait")) and (.pid | type) == "number"
	and (.updatedAt | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$"))
	and (.headSha | type == "string" and length > 0) and (.state | IN("OPEN", "MERGED", "CLOSED"))
	and (.stale | type) == "boolean" and (.lastOkAt == null or (.lastOkAt | test("Z$")))
	and (.checks | type) == "array"
	and all(.checks[]; (.name | type) == "string" and (.status | type) == "string"
		and (.conclusion == null or (.conclusion | type) == "string"))
	and (.title == null or (.title | type) == "string") and (.body == null or (.body | type) == "string")'
EXITED='(.exited | (.code | type) == "number" and (.at | type) == "string" and (.reason | type) == "string")'
no_tmp_left() { [ -z "$(find "$1" -name '*.tmp.*' 2>/dev/null)" ]; }
CI7=acme__widgets__7.ci-wait.json
MW8=acme__widgets__8.merge-wait.json
MW9=acme__widgets__9.merge-wait.json

# ===== exit codes and output match main =====
export STUB_MODE
STUB_MODE=green same_as_main ci-green pr-ci-wait 7 --repo acme/widgets --interval 1 --timeout 30
STUB_MODE=fail same_as_main ci-fail pr-ci-wait https://github.com/acme/widgets/pull/7 --interval 1 --timeout 30
STUB_MODE=pending same_as_main ci-timeout pr-ci-wait 7 --repo acme/widgets --interval 1 --timeout 1
STUB_MODE=closed same_as_main ci-closed pr-ci-wait 7 --repo acme/widgets --interval 1
STUB_MODE=notfound same_as_main ci-notfound pr-ci-wait 7 --repo acme/widgets --interval 1
STUB_MODE=mergedlater same_as_main ci-mergedlater pr-ci-wait 7 --repo acme/widgets --interval 1 --timeout 1
STUB_MODE=pending STUB_SLEEP_FAIL=1 same_as_main ci-sleepfail pr-ci-wait 7 --repo acme/widgets --interval 1 --timeout 30
STUB_MODE=merged same_as_main mw-merged pr-merge-wait 8 9 --repo acme/widgets --interval 1 --timeout 30
STUB_MODE=closed same_as_main mw-closed pr-merge-wait 8 --repo acme/widgets --interval 1 --timeout 30
STUB_MODE=conflict same_as_main mw-conflict pr-merge-wait 8 --repo acme/widgets --interval 1 --timeout 30
STUB_MODE=behind same_as_main mw-behind pr-merge-wait 8 --repo acme/widgets --interval 1 --timeout 30
STUB_MODE=green same_as_main mw-timeout pr-merge-wait 8 --repo acme/widgets --interval 1 --timeout 2
STUB_MODE=notfound same_as_main mw-ghfail pr-merge-wait 8 --repo acme/widgets --interval 1 --timeout 60
STUB_MODE=green STUB_FAIL_FROM=2 same_as_main mw-stale pr-merge-wait 8 --repo acme/widgets --interval 1 --timeout 3
STUB_MODE=green STUB_SLEEP_FAIL=1 same_as_main mw-sleepfail pr-merge-wait 8 --repo acme/widgets --interval 1 --timeout 30
STUB_MODE=merged STUB_STDERR=1 same_as_main mw-ghstderr pr-merge-wait 8 9 --repo acme/widgets --interval 1 --timeout 30
STUB_MODE=green STUB_STDERR=1 same_as_main ci-ghstderr pr-ci-wait 7 --repo acme/widgets --interval 1 --timeout 30
for n in ci-green ci-fail ci-timeout ci-closed ci-mergedlater mw-merged mw-closed mw-conflict mw-timeout mw-stale; do
	check "$n: no tmp file left" no_tmp_left "$WORK/state-$n"
done

# ===== state file contents =====
f="$WORK/state-ci-green/$CI7"
check "ci green: file matches the shape" jq -e "$SHAPE and $EXITED" "$f"
check "ci green: fields" jq -e '.watcher == "ci-wait" and .repo == "acme/widgets" and .number == 7
	and .headSha == "abc1234def" and .title == "PR 7" and .state == "OPEN" and .stale == false
	and (.url | endswith("/pull/7")) and (.body | contains("claude.ai/artifact/xyz"))
	and .exited.code == 0 and (.checks | length) == 2' "$f"
check "ci green: checks mapped" jq -e '(.checks[] | select(.name == "build")) == {name: "build", status: "COMPLETED", conclusion: "SUCCESS", required: true}
	and (.checks[] | select(.name == "lint") | .required == false and .conclusion == "SKIPPED")' "$f"
check "ci fail: exited 1" jq -e "$SHAPE"' and .exited.code == 1 and (.exited.reason | test("not green"))' "$WORK/state-ci-fail/$CI7"
check "ci timeout: exited 2, pending check" jq -e "$SHAPE"' and .exited.code == 2 and .checks[0].status == "IN_PROGRESS" and .checks[0].conclusion == null' "$WORK/state-ci-timeout/$CI7"
# ruling 4: exit 3 on a closed PR still writes its known state
check "ci closed: exit 3 writes CLOSED + exited" jq -e "$SHAPE"' and .state == "CLOSED" and .exited.code == 3' "$WORK/state-ci-closed/$CI7"
# ruling 6: nothing is written for a PR never read
check "ci notfound: no file" test ! -e "$WORK/state-ci-notfound/$CI7"
check "mw ghfail: no file for a PR never read" test ! -e "$WORK/state-mw-ghfail/$MW8"
# ruling 8: pr-ci-wait tracks state from its per-poll read
check "ci mergedlater: state follows the PR" jq -e '.state == "MERGED"' "$WORK/state-ci-mergedlater/$CI7"
# ruling 5: a failing sleep exits as on main, and is recorded
check "ci sleepfail: exited code 1" jq -e '.exited.code == 1' "$WORK/state-ci-sleepfail/$CI7"
for n in 8 9; do
	f="$WORK/state-mw-merged/acme__widgets__$n.merge-wait.json"
	check "mw merged: file for PR $n" jq -e "$SHAPE and $EXITED"' and .watcher == "merge-wait" and .number == '"$n"'
		and .mergeable == "MERGEABLE" and .mergeStateStatus == "CLEAN" and .headSha == "abc1234def" and .stale == false
		and .title == "PR '"$n"'" and (.body | contains("| a | b |")) and .checks == []
		and .exited.code == 0 and (.exited.reason | test("merged: .*/pull/8$"))' "$f"
done
check "mw merged: PR 8 MERGED, PR 9 OPEN" jq -se '.[0].state == "MERGED" and .[1].state == "OPEN"' "$WORK/state-mw-merged/$MW8" "$WORK/state-mw-merged/$MW9"
check "mw closed: exited 3" jq -e '.state == "CLOSED" and .exited.code == 3' "$WORK/state-mw-closed/$MW8"
check "mw conflict: exited 4" jq -e '.mergeable == "CONFLICTING" and .exited.code == 4' "$WORK/state-mw-conflict/$MW8"
check "mw timeout: exited 5, fresh" jq -e "$SHAPE"' and .exited.code == 5 and .stale == false and (.lastOkAt | type) == "string"' "$WORK/state-mw-timeout/$MW8"
# ruling 3: a failed newest poll is marked stale, with the last good read time
check "mw stale: stale true, lastOkAt kept" jq -e "$SHAPE"' and .stale == true and (.lastOkAt | type) == "string" and .exited.code == 5' "$WORK/state-mw-stale/$MW8"
check "mw sleepfail: exited code 1" jq -e '.exited.code == 1' "$WORK/state-mw-sleepfail/$MW8"
# ruling 9: gh stderr on success does not break the state parse
check "mw ghstderr: state parsed" jq -e '.title == "PR 8" and .headSha == "abc1234def"' "$WORK/state-mw-ghstderr/$MW8"
check "ci ghstderr: state parsed" jq -e '.title == "PR 7" and .headSha == "abc1234def"' "$WORK/state-ci-ghstderr/$CI7"

# ===== ruling 1: two watchers on one PR keep separate files; lowercase names =====
d="$WORK/state-both"
export STUB_DIR="$WORK/stubstate.both"; mkdir -p "$STUB_DIR"
STUB_MODE=green PR_WATCH_STATE_DIR=$d "$BIN_DIR/pr-ci-wait" 7 --repo Acme/Widgets --interval 1 >/dev/null 2>&1
STUB_MODE=green PR_WATCH_STATE_DIR=$d "$BIN_DIR/pr-merge-wait" 7 --repo Acme/Widgets --interval 1 --timeout 1 >/dev/null 2>&1
check "two watchers: ci-wait file keeps its verdict" jq -e '.watcher == "ci-wait" and .exited.code == 0' "$d/$CI7"
check "two watchers: merge-wait file separate" jq -e '.watcher == "merge-wait" and .exited.code == 5' "$d/acme__widgets__7.merge-wait.json"

# ===== --no-state =====
STUB_MODE=green run "$BIN_DIR" "$WORK/state-ci-nostate" ci-nostate pr-ci-wait 7 --repo acme/widgets --interval 1 --timeout 30 --no-state
check "ci --no-state: exit 0, no file, same output" test "$(code_of ci-nostate)" = 0 -a ! -e "$WORK/state-ci-nostate"
check "ci --no-state: stderr as with state" diff <(normalise "$WORK/ci-green.stderr") <(normalise "$WORK/ci-nostate.stderr")
STUB_MODE=merged run "$BIN_DIR" "$WORK/state-mw-nostate" mw-nostate pr-merge-wait 8 9 --repo acme/widgets --interval 1 --no-state
check "mw --no-state: exit 0, no file" test "$(code_of mw-nostate)" = 0 -a ! -e "$WORK/state-mw-nostate"
check "mw --no-state: stdout as with state" diff "$WORK/mw-merged.stdout" "$WORK/mw-nostate.stdout"

# ===== unwritable state dir never fails the watch =====
STUB_MODE=green run "$BIN_DIR" /dev/null/nope ci-unwritable pr-ci-wait 7 --repo acme/widgets --interval 1 --timeout 30
check "ci unwritable: exit 0, same output" diff <(normalise "$WORK/ci-green.stderr") <(normalise "$WORK/ci-unwritable.stderr")
STUB_MODE=merged run "$BIN_DIR" /dev/null/nope mw-unwritable pr-merge-wait 8 9 --repo acme/widgets --interval 1
check "mw unwritable: exit 0, same output" test "$(code_of mw-unwritable)" = 0

# ===== signals =====
hires() { perl -MTime::HiRes=time -e 'printf "%d", time * 1000'; }
# sig_run <dir> <state-dir> <name> <SIG> <delay> <script> <args...>; leaves <name>.code, <name>.ms (kill-to-exit)
sig_run() {
	local dir=$1 sd=$2 name=$3 sig=$4 delay=$5 s=$6; shift 6
	N_RUN=$((N_RUN + 1))
	export STUB_DIR="$WORK/stubstate.$N_RUN"; mkdir -p "$STUB_DIR"
	# A backgrounded script starts with INT ignored; perl restores the default and
	# gives it its own process group, so INT can go to the group like a Ctrl-C.
	PR_WATCH_STATE_DIR=$sd perl -e 'setpgrp(0, 0); $SIG{INT} = "DEFAULT"; $SIG{HUP} = "DEFAULT"; exec @ARGV' \
		"$dir/$s" "$@" >"$WORK/$name.stdout" 2>"$WORK/$name.stderr" &
	local p=$! t0
	perl -e "select(undef, undef, undef, $delay)"
	t0=$(hires)
	if [ "$sig" = INT ]; then kill -INT -- "-$p"; else kill -"$sig" "$p"; fi
	{ wait "$p"; } 2>/dev/null
	printf '%s' "$?" >"$WORK/$name.code"
	printf '%s' "$(($(hires) - t0))" >"$WORK/$name.ms"
}
for spec in "TERM 143" "INT 130" "HUP 129"; do
	read -r sig_name sig_code <<<"$spec"; set -- "$sig_name" "$sig_code"
	for s in pr-ci-wait pr-merge-wait; do
		n="sig-$1-$s"
		STUB_MODE=pending sig_run "$WORK/main" "$WORK/state-main-$n" "main-$n" "$1" 1.5 "$s" 7 --repo acme/widgets --interval 30
		STUB_MODE=pending sig_run "$BIN_DIR" "$WORK/state-$n" "$n" "$1" 1.5 "$s" 7 --repo acme/widgets --interval 30
		check "$n: exit $2 like main ($(code_of "main-$n") vs $(code_of "$n"))" test "$(code_of "$n")" = "$2" -a "$(code_of "main-$n")" = "$2"
		check "$n: records killed by SIG$1" jq -e "$EXITED"' and .exited.code == '"$2"' and .exited.reason == "killed by SIG'"$1"'"' \
			"$WORK/state-$n/acme__widgets__7.${s#pr-}.json"
		check "$n: no tmp file left" no_tmp_left "$WORK/state-$n"
		check "$n: stderr matches main" diff <(normalise "$WORK/main-$n.stderr") <(normalise "$WORK/$n.stderr")
	done
done
# ruling 2: a signal while gh runs stops the watch at once (stub gh sleeps 6s)
STUB_MODE=pending STUB_SLOW_FROM=4 sig_run "$BIN_DIR" "$WORK/state-sig-gh-ci" sig-gh-ci TERM 1.5 pr-ci-wait 7 --repo acme/widgets --interval 1
check "signal during gh (ci): exit 143 within 2s (took $(cat "$WORK/sig-gh-ci.ms")ms)" \
	test "$(code_of sig-gh-ci)" = 143 -a "$(cat "$WORK/sig-gh-ci.ms")" -lt 2000
check "signal during gh (ci): exited recorded" jq -e '.exited.code == 143' "$WORK/state-sig-gh-ci/$CI7"
STUB_MODE=green STUB_SLOW_FROM=2 sig_run "$BIN_DIR" "$WORK/state-sig-gh-mw" sig-gh-mw TERM 2 pr-merge-wait 8 --repo acme/widgets --interval 1
check "signal during gh (mw): exit 143 within 2s (took $(cat "$WORK/sig-gh-mw.ms")ms)" \
	test "$(code_of sig-gh-mw)" = 143 -a "$(cat "$WORK/sig-gh-mw.ms")" -lt 2000
check "signal during gh (mw): exited recorded" jq -e '.exited.code == 143' "$WORK/state-sig-gh-mw/$MW8"

# ruling 7: a signal that lands mid-write leaves no tmp file (jq shim slows the state write)
mkdir -p "$WORK/slowjq"
cat >"$WORK/slowjq/jq" <<SHIM
#!/bin/sh
case "\$*" in *watcher:*) /bin/sleep 2 ;; esac
exec $(command -v jq) "\$@"
SHIM
chmod +x "$WORK/slowjq/jq"
for s in pr-ci-wait pr-merge-wait; do
	n="sig-midwrite-$s"
	PATH="$WORK/slowjq:$PATH" STUB_MODE=pending sig_run "$BIN_DIR" "$WORK/state-$n" "$n" TERM 1 "$s" 7 --repo acme/widgets --interval 30
	check "$n: exit 143" test "$(code_of "$n")" = 143
	check "$n: no tmp file left" no_tmp_left "$WORK/state-$n"
	check "$n: exited recorded" jq -e '.exited.code == 143' "$WORK/state-$n/acme__widgets__7.${s#pr-}.json"
done

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
