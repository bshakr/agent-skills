# Monolense (`report/` React/Vite app, `server/` Rails API)

Screens are captured by the checked-in rig, not a hand-rolled harness. Do not write a Playwright script. Write a manifest, run it once, open the PNGs. From `report/`, after `pnpm install`:

```
node scripts/capture.mjs --manifest <scratch>/<ticket>.json --out <scratch>/<ticket>-shots
node scripts/capture.mjs --help          # manifest keys and exit codes
```

- Start from `report/scripts/capture.example.json` and keep only the surfaces the diff touches, plus one `control` pair.
- `--before` defaults to a detached temporary worktree at the merge-base with `origin/main`, installed and removed by the rig. Override with `--before <report dir>` or `--before-ref <sha>`; `--after <report dir>` when the branch is not this checkout.
- The rig runs against the repo's stub API, not Rails, and there is no login: the stub answers `GET /api/auth/me` as `stub@monolense.test`. It picks its own ports, runs one stub and one Vite server per side, and runs the sides one after the other (two Vite servers on one worktree evict each other's deps and the app 504s into its error boundary).
- Scenario names are in the header of `report/scripts/stub-api.mjs` (`cards`, `importing`, `lots`, `ready_met`, `returning_one`, ...). Put them in the shot's `stub` object, or `stub_before` / `stub_after` when the sides differ. Only `STUB_*` variables are accepted, and an unknown scenario fails the run by name. A scenario the before side's stub does not have means an `after_only` shot.
- Per shot the rig asserts the title, the final path AND query (the app rewrites an unavailable `month` and drops `scene`; set `expect_url` when that is intended), the theme on `<html>`, that web fonts loaded, and your `assert`. It fails on the app's failure copy, a Vite overlay or a 504. `body`, `html` and `#root` are rejected as assertion selectors.
- The readiness pill's count `<span>` is `display: grid`, so its text breaks "1 to check" over two lines; assert on "to check".
- Unknown manifest keys, wrong types and ids that are not plain file stems exit 2 before any server starts. A typo is an error, never a silently different shot.
- At 390px the rig records scrollWidth against clientWidth and fails on overflow that is new or grew on the after side; pre-existing overflow is reported in `verdict.md`.
- Output: `<out>/manifest.json` in the `rp-gallery` shape (hand it to the coordinator as it is), `<out>/verdict.md`, a per-shot table, and a last line `RIG: PASS` or `RIG: FAIL (<n> shots)`. That line covers assertions only. You still open every PNG, fill the "verified by eye" column and the "Could not capture" section, and write the capture VERDICT yourself.
- Playwright is not a repo dependency: `PLAYWRIGHT_PATH`, else `/opt/homebrew/lib/node_modules/@playwright/mcp/node_modules/playwright`.
- No database and no fixtures to restore.

If the rig itself misbehaves, stop and report it to the coordinator; a rig fix is its own change, dispatched with an `opus-capture:` description.
