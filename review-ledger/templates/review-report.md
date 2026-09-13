# Review: Task <N> round <R>

- Package: `<workspace>/review-<base7>..<head7>.diff`
- Brief: `<workspace>/task-<N>-brief.md`
- Range: `<base7>..<head7>` (<n> commits)
- Spec compliance: PASS | FAIL
- Counts: Critical <c> / Important <i> / Minor <m>

## Critical
<!-- ships a bug, loses data, leaks a secret, breaks auth or tenancy -->
### C1. <title>
- Where: `path/to/file.rb:120`
- What breaks: <the concrete failure, with the input that triggers it>
- Evidence: <command run and its output, or the lines that prove it>
- Mutation (required for any "untested" claim): deleted `<guard>`, ran
  `<command>`, result `<N tests, 0 failures>`, so nothing covers it.

## Important
<!-- wrong under a realistic path, or a spec requirement unmet -->

## Minor
<!-- style, naming, comments. Deferred by default, never enters the fix loop. -->

## Cannot verify from the diff
<!-- requirements living in unchanged code or spanning tasks; the coordinator resolves each -->

## Delta pass (re-reviews only)
Per named finding: ADDRESSED | NOT ADDRESSED, with the line that proves it.
Then the fix commit reviewed as new code: what did the fix break?
