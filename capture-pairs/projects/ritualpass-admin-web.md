# Appendix: ritualpass admin-web

`/Users/bassemshaker/code/ritualpass/frontend/apps/admin-web` (pnpm monorepo under
`frontend/`). Private repo, so inline PR images are impossible: the hosted gallery link is the
deliverable.

## Boot

```bash
# API first, from any api worktree (see projects/ritualpass-api.md for the .env trap)
cd /Users/bassemshaker/code/ritualpass/api && bin/rails server -p 3910
# admin-web, env passed as process vars so nothing is written to the (often symlinked) .env.local
cd .../frontend/apps/admin-web && pnpm install --frozen-lockfile
NEXT_PUBLIC_API_URL=http://localhost:3910 NEXT_PUBLIC_DEV_SUBDOMAIN=<tenant> PORT=3911 pnpm dev
```

`.env.local` defaults point at `:3010` / `:3011`; both are long-lived shared servers from other
sessions and may be running someone else's branch. Check
`lsof -nP -iTCP:3010 -sTCP:LISTEN` plus the listener's cwd before assuming. Prefer your own port.
`.npmrc` authenticates with `GITHUB_TOKEN`.

**Next refuses two dev servers from one directory**, so a flag-on/flag-off pair from one worktree
needs a restart between states, not parallel ports.

## Host and tenant

- Capture at `http://<subdomain>.localhost:<port>`, e.g. `downtown-yoga.localhost:3911`.
  The dev tenant is **`downtown-yoga`**, not `yoga`, despite the admin being `admin@yoga.com`.
- Plain `localhost:<port>` sends no `X-Tenant-Subdomain` header: `NEXT_PUBLIC_DEV_SUBDOMAIN` is
  read with a dynamic key inside the prebuilt `@ritualpass/core` bundle, so Next never inlines
  it and browser-side `process.env` is `{}`. Every `/api/v1/admin/*` call 403s and `/admin/home`
  bounces to `/admin`.
- The super-admin section renders only on host `admin.localhost` (any port) **and**
  `user.super_admin === true` (`lib/constants/routing.ts`).
- Branding: the seeded tenant `the-third-room` carries `primary_color: "#8C4EA3"`, which repaints
  every primary button purple at runtime and has already been mistaken for a code change. Capture
  on a branding-neutral tenant, or state the brand colours in the manifest intro.

## Login: inject, never type

- Cookie `ritualpass_jwt_token`, raw JWT, **host-only** on `*.localhost` since core 0.13.2.
  Playwright: `context.addCookies([{name, value: JWT, url: 'http://<tenant>.localhost:<port>'}])`.
- Mint the JWT read-only: `bin/rails runner` with `JwtEncoder.encode`. Zero writes, port-agnostic.
- Fallback: `POST /api/v1/auth/login` with **flat** params `{"email","password"}`; the
  Devise-nested `{"user":{…}}` shape silently 401s. Or navigate to `…/super-admin#auth_token=<JWT>`
  (the AuthProvider consumes the fragment).
- Seeded: `admin@yoga.com` with the seed password at `db/seeds/development.rb` (it has been
  reseeded since other values circulated, so read the file, do not trust a remembered string).
  `superadmin@dev.local` / `SuperAdmin123!` was hand-created and may not survive a reseed.
- Key any cached Playwright session by **subdomain + port**, or tenant A's session gets reused
  against tenant B and every text assertion still passes.

## Feature flags

Dev Flipper is shared **Redis db 2** (`config/initializers/flipper.rb`), across processes and
databases, so an isolated Postgres isolates nothing. For a flag-off half, run your own api with
`FLIPPER_REDIS_URL=redis://localhost:6379/<free db>`; dbs 2, 9, 10 and 13 have all been in use,
so check `dbsize` first. `redis-cli` is not installed on this Mac: use
`docker --context orbstack exec ritualpass_redis redis-cli -n <db> …`.
`Flipper.disable(:flag)` wipes the flag's **actor set** as well as the boolean, so record
`Flipper[:flag].boolean_value` and `.actors_value` before and restore both. Known flags include
`events_rollout` (boolean ON, so no tenant is naturally flag-off) and `enable_tier_gating`.
Anonymous requests carry no flags at all.

## Per-shot traps

- The sidebar What's-New dot compares localStorage `ritualpass:whats-new-last-seen` against an
  async fetch of `/api/release-notes/latest` and pops in mid-load. Read the real latest version
  at rig start and store that, then the dot never renders.
- Next's dev-tools "1 Issue" badge paints over the sidebar user row. Hide the overlay with
  identical CSS in both halves.
- localStorage is per-origin, and two dev ports are two origins: pin any state-dependent UI
  (theme key `ritualpass-admin-theme`) on both halves.
- Do not grow the viewport for fixed-position dialog shots; assert the dialog panel's own
  computed background, not the page behind it.
- Radix row-menu triggers reject Playwright clicks on list pages such as `/admin/locations`
  (5s actionability timeout). Drive them with JS focus plus Enter or Space.
- Fill forms only after networkidle; hydration eats early keystrokes. Poll `location.pathname`
  rather than `waitForURL` for client-side route changes.
- Capture settings that have worked: chromium, 1440x900, `deviceScaleFactor: 2`, light mode,
  fullPage, cursor parked at 1439,2.

## Reference

E2E harness with its own port knobs: `/Users/bassemshaker/code/ritualpass/e2e/playwright.config.ts`
(`E2E_API_PORT`, `E2E_ADMIN_PORT`, `E2E_CLIENT_PORT`, `E2E_TENANT`, `E2E_TARGET`).
