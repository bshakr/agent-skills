# Review ledger, plan: <absolute path to plan or spec>

Branch `<branch>` | worktree `<absolute path>` | ticket <full linear url>
Status: <in progress | frozen at SHA>

## Pre-flight scan
Report: `<path>` | Critical <c> / Important <i> / Minor <m> | dispatch unblocked: <yes/no>

| # | Check | Finding | Severity | Ruling |
|---|-------|---------|----------|--------|
| 1 | collision: T3 x T7 | both edit `Gemfile` | Critical | serialized, T7 after T3 |
| 2 | origin/main only | `app/x.rb` absent from branch | Critical | T5 rebased onto origin/main |
| 3 | spec contradiction | `masked_url` section vs impl | Critical | spec wins, plan text corrected |
| 4 | missing test target | T9 names no test file | Important | T9 creates `test/x_test.rb` |

## Tasks

| # | Task | First review | C/I/M | Fix SHA | Re-review | Ruling | Status |
|---|------|--------------|-------|---------|-----------|--------|--------|
| 1 | <title> | reviews/t1-r1.md | 0/0/1 | - | - | minor deferred | done |
| 2 | <title> | reviews/t2-r1.md | 1/2/0 | <sha7> | reviews/t2-r2.md | 3 addressed, no new breakage | done |

Statuses: dispatched | reviewing | fixing r<N> | done | parked

## Rulings
- Task <N>: parked, <finding>. Ruling: <why the code stands>. Cost if wrong: <x>.

## Deferred minors
- Task <N>: <one-liner> <- final review triages before merge

## Freeze
Frozen at `<SHA>` after round <R> returned prose only.
Follow-ups filed: <full linear urls>

## Hand-off to pr-handover
- Branch: `<branch>` | worktree `<absolute path>`
- HEAD: `<sha>` (verified with `git rev-parse HEAD`)
- Ledger: `<this path>` | artifact `<url>`
- PR line: `- [x] review-ledger ran on <SHA>: <N> tasks, <C>/<I>/<M> findings, all Critical and Important addressed, <K> minors deferred (<ticket urls>)`
