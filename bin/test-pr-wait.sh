#!/usr/bin/env bash
# State-file tests for pr-ci-wait and pr-merge-wait against a stubbed gh.
# Usage: bin/test-pr-wait.sh          (no network: gh is a stub on PATH)
set -uo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }
check() { # <description> <command...>
	local d=$1; shift
	if "$@" >/dev/null 2>&1; then ok; else bad "$d"; fi
}

# ---- gh stub: answers by argument pattern, STUB_MODE picks the scenario ----
mkdir -p "$WORK/stub"
cat >"$WORK/stub/gh" <<'STUB'
#!/usr/bin/env bash
args="$*"
sha=abc1234def
body='Summary
| a | b |
Gallery: https://claude.ai/artifact/xyz "quoted"'
case "$args" in
*"pr view"*"--json number,state,url,headRefOid,title"*)
	jq -cn --arg sha "$sha" --arg body "$body" \
		'{number: 7, state: "OPEN", url: "https://github.com/acme/widgets/pull/7", headRefOid: $sha, title: "Add widgets", body: $body}'
	;;
*"pr checks"*"--required"*) printf 'build\n' ;;
*"pr view"*"--json headRefOid -q"*) printf '%s\n' "$sha" ;;
*"pr checks"*"--json name,state,bucket,link,workflow"*)
	if [ "${STUB_MODE:-}" = pending ]; then
		printf '[{"name":"build","state":"IN_PROGRESS","bucket":"pending","link":"","workflow":"ci"}]\n'
	elif [ "${STUB_MODE:-}" = fail ]; then
		printf '[{"name":"build","state":"FAILURE","bucket":"fail","link":"https://ci.example/1","workflow":"ci"},{"name":"lint","state":"SUCCESS","bucket":"pass","link":"","workflow":"ci"}]\n'
	else
		printf '[{"name":"build","state":"SUCCESS","bucket":"pass","link":"https://ci.example/1","workflow":"ci"},{"name":"lint","state":"SKIPPED","bucket":"skipping","link":"","workflow":"ci"}]\n'
	fi
	;;
*"pr view"*"mergeStateStatus"*)
	# Real JSON through the caller's own -q, so the query itself is under test.
	n=$3
	q=""
	while [ $# -gt 0 ]; do [ "$1" = -q ] && q=$2; shift; done
	st=OPEN
	[ "${STUB_MODE:-}" = merged ] && [ "$n" = 8 ] && st=MERGED
	jq -cn --arg st "$st" --arg n "$n" --arg sha "$sha" --arg body "$body" '{state: $st,
		mergeable: "MERGEABLE", mergeStateStatus: "CLEAN", headRefName: ("feat-" + $n),
		mergeCommit: (if $st == "MERGED" then {oid: "m123"} else null end),
		headRefOid: $sha, title: ("PR " + $n), body: $body}' | jq -r "$q"
	;;
*) printf 'stub gh: unhandled: %s\n' "$args" >&2; exit 1 ;;
esac
STUB
chmod +x "$WORK/stub/gh"
export PATH="$WORK/stub:$PATH"

run() { # <state-dir> <outfile> <script> <args...>; echoes exit code
	local dir=$1 out=$2; shift 2
	PR_WATCH_STATE_DIR=$dir "$@" >"$out.stdout" 2>"$out.stderr"
	printf '%s' "$?"
}

# Shape every file must have, whichever watcher wrote it.
SHAPE='.version == 1 and (.repo | type) == "string" and (.number | type) == "number"
	and (.pid | type) == "number" and (.updatedAt | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$"))
	and (.headSha | type) == "string" and (.state | IN("OPEN", "MERGED", "CLOSED"))
	and (.checks | type) == "array"
	and all(.checks[]; (.name | type) == "string" and (.status | type) == "string"
		and (.conclusion == null or (.conclusion | type) == "string"))
	and (.exited | (.code | type) == "number" and (.at | type) == "string" and (.reason | type) == "string")'

no_tmp_left() { [ -z "$(find "$1" -name '*.tmp.*')" ]; }
normalise() { sed -E 's/\+[0-9]+s/+Ns/g; s/[0-9]+s ago/Ns ago/g' "$1"; }

# ---- pr-ci-wait: green ----
d="$WORK/ci-green"
code=$(run "$d" "$WORK/ci-green" "$BIN_DIR/pr-ci-wait" 7 --repo acme/widgets --interval 1 --timeout 30)
f="$d/acme__widgets__7.json"
check "ci green exits 0 (got $code)" test "$code" = 0
check "ci green writes the state file" test -f "$f"
check "ci green file matches the shape" jq -e "$SHAPE" "$f"
check "ci green fields" jq -e '.watcher == "ci-wait" and .repo == "acme/widgets" and .number == 7
	and .headSha == "abc1234def" and .title == "Add widgets" and .state == "OPEN"
	and (.url | endswith("/pull/7")) and (.body | contains("claude.ai/artifact/xyz"))
	and .exited.code == 0 and (.checks | length) == 2' "$f"
check "ci green maps checks" jq -e '(.checks[] | select(.name == "build")) == {name: "build", status: "COMPLETED", conclusion: "SUCCESS", required: true}
	and (.checks[] | select(.name == "lint") | .required == false and .conclusion == "SKIPPED")' "$f"
check "ci green leaves no tmp file" no_tmp_left "$d"

# ---- pr-ci-wait: failing ----
d="$WORK/ci-fail"
code=$(STUB_MODE=fail run "$d" "$WORK/ci-fail" "$BIN_DIR/pr-ci-wait" https://github.com/acme/widgets/pull/7 --interval 1 --timeout 30)
check "ci fail exits 1 (got $code)" test "$code" = 1
check "ci fail records exit 1" jq -e "$SHAPE"' and .exited.code == 1 and (.exited.reason | test("not green"))' "$d/acme__widgets__7.json"

# ---- pr-ci-wait --no-state: no file, byte-identical output ----
d="$WORK/ci-nostate"
code=$(run "$d" "$WORK/ci-nostate" "$BIN_DIR/pr-ci-wait" 7 --repo acme/widgets --interval 1 --timeout 30 --no-state)
check "ci --no-state exits 0 (got $code)" test "$code" = 0
check "ci --no-state writes nothing" test ! -e "$d"
check "ci stdout identical with and without state" diff "$WORK/ci-green.stdout" "$WORK/ci-nostate.stdout"
check "ci stderr identical with and without state" \
	diff <(normalise "$WORK/ci-green.stderr") <(normalise "$WORK/ci-nostate.stderr")

# ---- pr-merge-wait: one of two PRs merges ----
d="$WORK/mw"
code=$(STUB_MODE=merged run "$d" "$WORK/mw" "$BIN_DIR/pr-merge-wait" 8 9 --repo acme/widgets --interval 1 --timeout 30)
check "merge-wait merged exits 0 (got $code)" test "$code" = 0
for n in 8 9; do
	f="$d/acme__widgets__$n.json"
	check "merge-wait writes one file for PR $n" jq -e "$SHAPE"' and .watcher == "merge-wait" and .number == '"$n"'
		and .mergeable == "MERGEABLE" and .mergeStateStatus == "CLEAN" and .headSha == "abc1234def"
		and .title == "PR '"$n"'" and (.body | contains("| a | b |")) and .checks == []
		and .exited.code == 0 and (.exited.reason | test("merged: .*/pull/8$"))' "$f"
done
check "merge-wait PR 8 is MERGED" jq -e '.state == "MERGED"' "$d/acme__widgets__8.json"
check "merge-wait PR 9 is OPEN" jq -e '.state == "OPEN"' "$d/acme__widgets__9.json"
check "merge-wait leaves no tmp file" no_tmp_left "$d"

# ---- pr-merge-wait: timeout ----
d="$WORK/mw-timeout"
code=$(run "$d" "$WORK/mw-timeout" "$BIN_DIR/pr-merge-wait" 8 --repo acme/widgets --interval 1 --timeout 2)
check "merge-wait timeout exits 5 (got $code)" test "$code" = 5
check "merge-wait timeout records exit 5" jq -e "$SHAPE"' and .exited.code == 5 and .exited.reason == "timeout"' "$d/acme__widgets__8.json"

# ---- pr-merge-wait --no-state: no file, byte-identical output ----
d="$WORK/mw-nostate"
code=$(STUB_MODE=merged run "$d" "$WORK/mw-nostate" "$BIN_DIR/pr-merge-wait" 8 9 --repo acme/widgets --interval 1 --timeout 30 --no-state)
check "merge-wait --no-state exits 0 (got $code)" test "$code" = 0
check "merge-wait --no-state writes nothing" test ! -e "$d"
check "merge-wait stdout identical with and without state" diff "$WORK/mw.stdout" "$WORK/mw-nostate.stdout"
check "merge-wait stderr identical with and without state" diff "$WORK/mw.stderr" "$WORK/mw-nostate.stderr"

# ---- an unwritable state dir never fails the watch ----
code=$(run "/dev/null/nope" "$WORK/ci-unwritable" "$BIN_DIR/pr-ci-wait" 7 --repo acme/widgets --interval 1 --timeout 30)
check "ci unwritable state dir still exits 0 (got $code)" test "$code" = 0
check "ci unwritable state dir adds no output" diff <(normalise "$WORK/ci-green.stderr") <(normalise "$WORK/ci-unwritable.stderr")
code=$(STUB_MODE=merged run "/dev/null/nope" "$WORK/mw-unwritable" "$BIN_DIR/pr-merge-wait" 8 9 --repo acme/widgets --interval 1 --timeout 30)
check "merge-wait unwritable state dir still exits 0 (got $code)" test "$code" = 0
check "merge-wait unwritable state dir adds no output" diff "$WORK/mw.stdout" "$WORK/mw-unwritable.stdout"

# ---- a SIGTERM mid-sleep still dies by the signal and records it ----
term_run() { # <state-dir> <script> <args...>; echoes exit code
	local dir=$1; shift
	PR_WATCH_STATE_DIR=$dir "$@" >/dev/null 2>&1 &
	local p=$!
	perl -e 'select(undef, undef, undef, 1.5)'
	kill -TERM "$p"
	wait "$p"
	printf '%s' "$?"
}
d="$WORK/ci-term"
code=$(STUB_MODE=pending term_run "$d" "$BIN_DIR/pr-ci-wait" 7 --repo acme/widgets --interval 30)
check "ci SIGTERM exits 143 (got $code)" test "$code" = 143
check "ci SIGTERM records the signal" jq -e "$SHAPE"' and .exited.code == 143 and .exited.reason == "killed by SIGTERM"' "$d/acme__widgets__7.json"
d="$WORK/mw-term"
code=$(term_run "$d" "$BIN_DIR/pr-merge-wait" 8 --repo acme/widgets --interval 30)
check "merge-wait SIGTERM exits 143 (got $code)" test "$code" = 143
check "merge-wait SIGTERM records the signal" jq -e "$SHAPE"' and .exited.code == 143 and .exited.reason == "killed by SIGTERM"' "$d/acme__widgets__8.json"
code=$(term_run "$WORK/mw-term-nostate" "$BIN_DIR/pr-merge-wait" 8 --repo acme/widgets --interval 30 --no-state)
check "merge-wait --no-state SIGTERM exits 143 (got $code)" test "$code" = 143

printf '%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
