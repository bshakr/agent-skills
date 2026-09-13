<!--
pr-handover PR body template.

Fill every <angle-bracket> placeholder and delete this comment and any section
that genuinely does not apply (do NOT delete "## Screenshots"; an API-only PR
states that fact on its first line).

Rules this template encodes:
- Screenshots section, FIRST LINE = the gallery Artifact URL, or the literal
  "No user-visible surface (API only)". A filename table alone is never
  acceptable; it may follow the link as a supplement.
- Keep the "/review ran on <SHA>" line. It is the hard gate.
- Every PR and ticket reference is a full clickable URL, inside tables too.
- After `gh pr create`, edit this body ONLY via
  `pr-append-section <pr> --title "## <heading>" --file <f> [--replace]`.
  Never `gh pr edit`, never a whole-body rebuild from a snapshot.
- No em dashes in prose.
-->

## Summary

<2 to 4 sentences: what this PR does and which epic it belongs to.>

Fixes <TICKET-ID>.

Ticket: <https://linear.app/<workspace>/issue/<TICKET-ID>>

## Screenshots

<GALLERY ARTIFACT URL — or exactly: No user-visible surface (API only)>

| Pair | Route | State | Viewport | What to look for |
|------|-------|-------|----------|------------------|
| Before / after | `<route>` | <empty / populated / loading / error> | 1440x900 | <one line> |
| Flag off (before / after) | `<route>` | <flag disabled, existing users> | 1440x900 | <proof nothing changed> |

<Surfaces that could not be captured, and what was done instead. Delete if none.>

## What changes

- <Meaningful change. Skip noise.>
- <Spec deviation, with the one-sentence why.>

## Out of scope

- <Deferred item, linked by full URL: https://linear.app/<workspace>/issue/<ID>>
- <Review finding accepted as a design decision.>

## Test plan

- [x] <test runner invocation + result, e.g. "49 runs, 143 assertions, 0 failures">
- [x] Full suite passes
- [x] Lint clean
- [x] Typecheck clean (`tsc --noEmit`) <delete if not a TypeScript repo>
- [x] /review ran on <SHA> — <N findings, all addressed | 0 findings>
- [ ] After merge: manual verification on staging

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_<SESSION_ID>
