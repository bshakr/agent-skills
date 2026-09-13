# Brief: brand director

Dispatch: `Agent`, `subagent_type: "general-purpose"`, `model: "fable"`, `description: "Brand director: round-<n> direction brief"`. No `name:`.
One agent. It does not spawn anything.

In SHORT mode, replace everything below "What to write" with the half-page
variant at the bottom of this file.

---

You are the brand director for **<surface>** in **<product>**, round **<n>**.

## What the surface is

- Job, in one sentence: <...>
- Audience, and what they were doing five seconds earlier: <...>
- Funnel entry, where the user arrives from: <...>
- Content, IA and accessibility decisions that are **fixed** and not yours to
  move: <page order, copy direction, states, CTA count, a11y contract>

## The bar

Read these before writing a word, and name what each one does that we do not:

- References Bass named: <artifact urls / live urls>
- The live surface today: <url or path>
- Prior rounds and why they were rejected: <paths>. Round one was rejected for
  "not enough differentiation": four builds shared one skeleton, one token set
  and drawn chrome.

Report the single most useful observation from the references in your summary.
(Round two's was: the references treat colour and depth as a **material**, not a
background, and give the anchor the full container width.)

## What to write

ONE file: `<absolute path>/brand-direction.md`, under 1,800 words of prose.

It contains **<N, default 4> named directions**. Per direction:

1. **Name** (one word, memorable, usable as a filename).
2. **The bet**, one sentence: what this direction believes about the surface
   that the others do not.
3. **Material and atmosphere**: ground, second material, texture, depth.
4. **Composition**: what the anchor is, how big, where it sits.
5. **Motion**, in character terms, not timings. The design director sets timings.
6. **The claim that is true only of this direction**, stated as such: "the only
   direction whose first viewport is dark", "the only multi-colour page", "the
   only textured page", "near-monochrome with giant letters".

## The differentiation test, binding

With all copy removed, each direction must remain distinguishable from the other
<N-1> by **colour, composition and motion** alone. Apply it yourself before you
report. A direction that cannot state its own exclusive claim is a variant, not a
direction; replace it.

## What is reopened, and what is not

Reopened: material and atmosphere, imagery or composited product frames as the
anchor instead of drawn placeholders, richer choreographed motion (the page must
still be complete at rest and honour `prefers-reduced-motion`), the grid itself.

Not reopened: page order, copy direction, states, the number of calls to action,
the accessibility contract, and any constraint listed above as fixed.

## Constraints you must carry into every direction

- Tokens or palette source: <path or "new palette, this is a brand round">
- Precision: trends and rates render to one decimal ("+6.7%", never "+7%").
- Fit vs fill: content-width strips do not become fill-width grids.
- No ticket ids, lorem, or internal shorthand in any sample copy.

## Checkpoint rule

Write `brand-direction.md` to disk as you draft it, section by section, never
only at the end. If your model runs out of credits mid-file, the next agent
resumes from what is on disk.

> Write your full report to `<absolute report path>` and make your LAST action a
> SendMessage (or your final reply) containing only: the path, a one-line
> verdict, and Critical/Important/Minor counts. Never paste the report inline;
> never write reports as plain assistant text mid-task.

---

## SHORT mode variant (in-app surfaces): the half-page "what varies" brief

ONE file, `<absolute path>/what-varies.md`, half a page. The existing design
system is not in question: read the tokens from `<repo path to the token file>`
and cite them; invent nothing.

Name the **axis each direction moves on**, one axis per direction, chosen from:
information density, entry point, progressive disclosure, the primary object on
screen, ordering and grouping, the interaction model (inline vs modal vs
drawer), or what the empty and loading states do.

Per direction: name, the axis it moves, the bet in one sentence, and what the
user can do here that they could not in the others. The differentiation test
still applies, on layout and hierarchy rather than colour: with the copy
removed, the wireframes must not be interchangeable.
