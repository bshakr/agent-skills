# Brief: builder (one per direction)

Dispatch: one `Agent` per direction, **in parallel, in a single message**.
`subagent_type: "general-purpose"`; `model: "fable"` in FULL mode, `model:
"opus"` in SHORT mode. `description: "design: build round-<n> direction <Name>"`
(the `design:` prefix is what lets the Agent hook admit a fable spawn).
No `name:`. Builders never spawn anything.

The prompt you send opens with this line, verbatim, before the brief below:

> You are the builder for one art direction in a design-directions round. Build the page for the direction named below from its art-direction sheet only.

**Each builder gets its own sheet and nothing else.** Do not attach the other
sheets, the other lanes' output, a shared page skeleton, a shared stylesheet or
a shared component file. Four agents given one cage converge, and that is the
rejection this whole skill exists to prevent.

---

You are building the **<Name>** direction of **<surface>**, round **<n>**.

## Read first, in this order

1. `<absolute path>/brand-direction.md`, your direction's section only.
2. `<absolute path>/design-critique.md`, the craft rules (all of them bind).
3. `<absolute path>/sheets/<direction>.md`, your art-direction sheet. This is
   the specification. Where it and the brand direction disagree, the sheet wins,
   and it says why.
4. <The approved prototype or prior decision, by absolute path, if one exists.
   Open it. Quote the part that constrains you in your notes file.>

## Fixed, not yours to move

Page order, copy direction, states, the number of calls to action, the
accessibility contract, and: <list>.

SHORT mode only: design tokens come from `<repo path>`. Read them, cite the
path, use the token names. Never invent a value, never nudge one "just for the
mockup".

## Build

Output, all under `<absolute output path>/`:

- `<direction>.html` (FULL) or the artboards / component prototype (SHORT).
- `<direction>.md`: your notes. Thesis in one sentence; the move that carries
  it; the differentiation statement ("copy removed, this page is the only one
  that ..."); every measurement you took; and a numbered list of **deviations
  from the sheet with the reason and the measurement that forced each one**.
- `shots/<direction>-1440-light.png`, `-1440-dark.png`, `-390-light.png`,
  `-390-dark.png`.

## Capture, the trap that shipped a broken hero

A full-page screenshot re-rasterises the page and **restarts entrance
animations**, which then hold their `from` values. Tinted Week shipped an
almost untinted week strip that way and it was caught only on a late audit.

Either put the load choreography behind a class the page removes once it settles
(so the resting page carries no entrance animation at all), or wait on
`animationend` for every entrance beat before capturing. Then prove it: diff the
capture against the JS-off render and report the pixel difference and where it
sits. A non-zero diff outside a declared breathing element is a defect.

## Self-QA before you report

Run the protocol in `<path to qa-protocol.md>` yourself and report the numbers.
This is not the gate: an independent design director grades you next and has
found real defects in builds that passed their own QA. Report honestly,
including the risk you are least sure about; that flagged risk has twice been
the thing QA confirmed.

## Checkpoint rule

Write the page, the notes and the renders to disk **as you go**, never only at
the end. If your model runs out of credits or the session dies mid-check, the
next agent resumes from what is on disk. A builder died on credit exhaustion at
18:04 in round two with an unreported page already written; that lane was
recoverable only because of this.

## Fix rounds

QA returns `FIX FIRST` with a check number, evidence and an exact fix, or
`SHIP TO FOUNDER`. Apply every fix, **recapture every shot the fix can touch**
(a footer change moves the 1440 renders too), verify, and report back for the
re-check. Two fix rounds maximum.

Do not commit. Do not push. Do not touch any file outside your output path.

> Write your full report to `<absolute report path>` and make your LAST action a
> SendMessage (or your final reply) containing only: the path, a one-line
> verdict, and Critical/Important/Minor counts. Never paste the report inline;
> never write reports as plain assistant text mid-task.
