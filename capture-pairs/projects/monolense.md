# Monolense (`report/` React/Vite app, `server/` Rails API)

Screens are captured against the repo's stub API, not Rails. From `report/`:

```
pnpm install                                                   # a fresh "before" worktree has no node_modules
STUB_PORT=<p> STUB_INTERVIEW_SCENARIO=<s> STUB_STORY_SCENARIO=<t> node scripts/stub-api.mjs
VITE_API_TARGET=http://localhost:<p> pnpm dev --port <v> --strictPort
```

- Vite proxies `/api` to `VITE_API_TARGET`. The stub answers `GET /api/auth/me`, so there is no login: the app is signed in as `stub@monolense.test` on load.
- ONE Vite server per side (several on one worktree evict each other's `node_modules/.vite` deps; the app 504s into its error boundary). Change scenario by restarting that side's stub on the same port and reloading; `POST /api/_stub/reset` puts answered cards back.
- Scenarios are documented in the header of `report/scripts/stub-api.mjs` (`cards`, `importing`, `lots`, `ready_met`, `returning_one`, ...). The stub is stateful like the server: answered cards do not come back within a process.
- The Interview's deferred/answered ids live in `sessionStorage` per user: use a fresh browser context per shot.
- Theme: light by default; a nav toggle writes `localStorage["theme"]` and sets `.dark` on `<html>`; inject before load rather than clicking.
- Playwright Chromium is available at `/opt/homebrew/lib/node_modules/@playwright/mcp/node_modules/playwright`.
- No database and no fixtures to restore. Title to assert: `Monolense — See your money with clarity`.
- The readiness pill's count `<span>` is `display: grid`, so `innerText` breaks "1 to check" into two lines; assert on "to check".

Reference run: BLO-1793 (2026-09-19), ports 7311/5311 before and 7312/5312 after.
