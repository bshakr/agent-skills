# QA protocol for a direction round

Run by an agent that did not build the thing. `model: "sonnet"` for the
measurements; the design director on `model: "fable"` when a verdict needs
taste. Checks 1 to 11 are generic and always run. Check 12 is the per-round
addendum the design director wrote from the sheets; paste it in before
dispatching.

Every check reports a **measurement**, not an impression. "Looks fine" is not a
result. Where a check passes, say what you measured; where it fails, give the
selector, the computed value and the coordinates.

## The core

1. **No horizontal overflow.** `document.documentElement.scrollWidth ===
   window.innerWidth` at 1440, 1024, 768 and 390, in **both themes**, and again
   **with the mobile menu or any drawer open**. Report the number at each.
2. **Type and spacing on the sheet's scales.** Collect every computed
   `font-size` on the page and show the set. Anything outside the sheet's
   declared set is a failure. Same for the spacing scale, naming any exception
   the sheet allows.
3. **Accent only at the declared moments.** Count every appearance of the accent
   colour and list where. Round two failed a build on a fourth accent button
   against a binding three.
4. **Visible focus states.** Every focusable element shows the sheet's ring, at
   the sheet's width and offset, in both themes. Tab the whole page.
5. **Reduced motion equals JS-off.** Render with `prefers-reduced-motion:
   reduce` and render with JavaScript disabled, and diff. Report the pixel
   difference and exactly where it sits. Anything outside a declared breathing
   or looping element is a failure.
6. **No clipping, no truncation, at any width.** Probe the boxes; do not
   eyeball. Measure each content box against its container and report the
   numbers. The classic failure: `min-height` on an `aspect-ratio` box transfers
   into a min-width (424px inside a 350px column), `overflow-x: clip` hides it
   from `scrollWidth`, and the text is cut mid-word. Also check every label at
   360 and 390 for ellipsis.
7. **Contrast.** Measure every text pairing and record the ratio. Body text
   meets 4.5:1. Decorative exceptions are allowed only where the sheet names
   them, with the number.
8. **The declared fold.** At 1440x900, report exactly what the fold cuts and at
   what pixel, and compare to the sheet. If the sheet's arithmetic was wrong,
   say so and accept or reject deliberately; do not fail a build for a sheet
   error.
9. **Disclosures and keyboard.** Summary and row target sizes against the sheet;
   Escape closes and returns focus to the summary; the open state is reachable
   and exitable by keyboard alone.
10. **Source precision in rendered copy.** Rates and trends render to one
    decimal ("+6.7%", "26.3%"), never whole percents. Counts and currency at
    their natural precision. Flag any wording that differs between directions
    ("3%" in one build, "3.0%" in another) so the port settles it once.
11. **Independent render of canvas artboards** (SHORT mode). Render the
    artboards in a headless browser and measure fit; do not judge from the
    markup. This check caught clipping twice, once a board losing its call to
    action entirely.
12. **Per-round addendum** from `qa-addendum.md`: the exact type set for this
    direction, the colour inventory count, the geometry assertions (which edge
    aligns to which and by how many pixels), and the named motion beats.

## Verdict

Exactly one of:

- **`FIX FIRST`**: for each failure: check number, evidence (selector, computed
  value, coordinates), and the exact fix. Send to the builder, then re-check on
  its confirmation.
- **`SHIP TO FOUNDER`**: every check passes. Taste notes that are not blockers
  go under "remaining notes" and travel to the gallery, not back to the builder.

Then three lines, **what a founder notices first**: one good, one bad, one
mixed. These are what the coordinator quotes when presenting the pick.

## Fix loop and the stop condition

Two fix rounds maximum per build. After the second re-check, freeze the build
whatever its state, publish it, and write the outstanding defect into the
gallery note and the design record README. A third round on prose or polish is
not QA; file it as a ticket instead.

## Standing cross-build notes

Collect the notes that apply to every direction rather than to one (capture
technique, copy wording mismatches, invented contact details, anything that will
matter at production build time) and hand them to the coordinator as one list.
They belong in the design record, not in four separate verdicts.
