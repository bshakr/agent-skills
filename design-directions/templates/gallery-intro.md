# Gallery intro and manifest for a direction round

The gallery is built with `rp-gallery` and published as one Artifact, then
republished **to the same url** as each lane lands. Publish it as soon as the
first direction is usable; never hold it for the last one.

A direction round has no before/after, so every entry is a `solo`, one per
direction, plus the shots that carry it. The per-direction live preview is its
own Artifact and its url goes in that direction's `note`, because the note is
the only place `rp-gallery` renders free text per entry.

## Manifest shape

```json
{
  "title": "<Surface> · direction round <n>",
  "pr_url": "",
  "ticket_url": "https://linear.app/bloombase/issue/BLO-XXXX",
  "intro": "<the intro below>",
  "pairs": [],
  "solos": [
    {
      "label": "<Direction> · 1440 light",
      "route": "<route or surface>",
      "state": "<the state shown: populated, empty, flag-on>",
      "path": "shots/<direction>-1440-light.png",
      "note": "The bet: <one sentence>. Live preview: <artifact url>. What to look for: <one thing>. QA: <12/12 | 11/12, note>."
    }
  ]
}
```

One solo per direction per viewport and theme you are showing. Keep the order of
directions identical everywhere: manifest, intro, final message, docs README.

## Intro (adapt, keep the shape)

> **<Surface>, round <n>: <N> directions to pick from.**
>
> Each page below is a complete, independently art-directed take on the same
> content. Page order, copy direction, states and the accessibility contract are
> identical across all <N>; everything visual is different by design. With the
> copy removed each one is still distinguishable from the others by colour,
> composition and motion.
>
> Every direction was graded independently against a <12>-check protocol
> (overflow at four widths in both themes with the menu open, type and spacing on
> the declared scale, accent only at declared moments, focus states, reduced
> motion matching the JavaScript-off render, clipping, contrast, the fold, keyboard
> escape, source precision). Verdicts are on each card.
>
> **What is being asked of you:** pick one. The bet each direction makes is on
> its card. Nothing is merged into a "best of" unless you ask for it.

## Per-direction card line, for the final message

One line each, in the same order as the gallery:

> **<Name>**: <the bet in one sentence>. <good thing a founder notices>;
> <the bad one>. <artifact url>

## The link block, always last, always consolidated

> - Gallery, all <N> side by side: <gallery artifact url>
> - <Name>: <artifact url>
> - <Name>: <artifact url>
> - Design record: <docs PR url> · Ticket: <linear url>

Bass has asked for a consolidated link list three times across the retro window.
Four previews spread over five messages is the failure this block prevents.

## Republish rules

- Same url on every update. Never publish a second copy of a gallery or a
  preview.
- When a build changes in a way that is visible, refresh **both** its preview
  Artifact and the gallery renders, and say which changed.
- A file's own `<title>` beats the `title` parameter; set the title in the HTML.
- Note frozen defects in the card's `note`, do not quietly omit them.
