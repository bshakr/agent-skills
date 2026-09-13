# Appendix: houserota (Rota Monster)

Repo `/Users/bassemshaker/code/houserota`, monorepo: `apps/api` (Rails 8, JSON) and `apps/web`
(Next 16, Turbopack). Worktrees live in `.koh/`. GitHub `bshakr/rota`.

## Boot

One `.env` at the repo root serves both apps (`apps/web/next.config.ts` loads it with
`loadEnvConfig`, `apps/api/config/application.rb` points Rails' loader at it). Defaults from
`.env.example`: `API_URL=http://localhost:3000`, `APP_URL=http://localhost:3001`,
`WORKOS_REDIRECT_URI=http://localhost:3001/callback`.

```bash
cp /Users/bassemshaker/code/houserota/.env <worktree>/.env     # ls -la first, never write through a symlink
cd <worktree>/apps/api && SMS_ADAPTER=null bin/rails server -p 3900
cd <worktree>/apps/web && npm ci
API_URL=http://localhost:3900 APP_URL=http://localhost:3901 npx next dev -p 3901
```

`API_URL` and `APP_URL` must match the ports you claimed, they are read at request time by
`apps/web/src/lib/api/http.ts` and by the WorkOS redirect. `npm run dev` hardcodes `-p 3001`, so
pass `-p` yourself. Never symlink `apps/web/node_modules`: Turbopack rejects a symlink that
escapes the project root while lint and tsc still pass.

**`SMS_ADAPTER=null` for every capture run.** Any flow that assigns cover sends a real text
otherwise: the seeded numbers are plausible dialable UK mobiles on purpose
(`apps/api/db/seeds.rb`).

## Surfaces and login

| Surface | Route | Auth |
|---|---|---|
| Member magic link | `/s/<token>` | Opaque member token, no login. **Capturable.** |
| Household entry | `/h/<slug>` | Public. **Capturable.** |
| Styleguide | `/styleguide` | Public. **Capturable**, good for token/theme diffs. |
| Admin | `/dashboard`, `/members`, `/rotas`, `/shifts`, `/sms` | WorkOS AuthKit at the proxy **and** a WorkOS-signed JWT at the API. **Not capturable headlessly.** |

Member tokens: `bin/rails runner 'Member.active.each { |m| puts "#{m.name} /s/#{m.access_token}" }'`.
The token is a credential: never print it in a report, a manifest, a filename, or a visible URL bar.

### The `/h/capture` harness: TO BE ADDED

It does not exist on disk (checked `apps/api/config/routes.rb` and `apps/web/src/app` on `main`
at 2026-09-13; the session that used it never landed it). The design that worked: a dev-only Next
route at `apps/web/src/app/h/capture/page.tsx` that mints an admin session for the seeded group.
It works because the AuthKit proxy matcher excludes `h/`:
`PROXY_MATCHER = "/((?!s/|h/|callback|_next/|.*\\..*).*)"` in
`apps/web/src/lib/auth/proxy-matcher.ts`. Until it lands, admin routes go in the VERDICT's
"Could not capture" list with "WorkOS at both layers, no headless bypass".

## Seeded fixtures (`apps/api/db/seeds.rb`, idempotent)

Group "Flat 4, Alma Road" (`workos_organization_id: org_demo_flat_4`, timezone Europe/London),
members Ciara, Bass, Eliza, Raph, rotas "Kitchen deep clean" and "Bins out". No shifts are
seeded: they come from `ShiftGenerator`. Non-idempotent ad-hoc seeding has left 7 members in the
demo group before, so create fixtures inside a transaction you can roll back, and take back any
cover you created for a shot.

## DB isolation for parallel worktrees

The dev and test Postgres databases are shared across worktrees, so a second branch's migration
lands in your `schema.rb` dump. Per-worktree databases (see the memory note
`houserota-worktree-db-isolation`):

1. In `apps/api/config/database.yml`, dev and test only:
   `database: houserota_api_` becomes `database: <%= ENV.fetch("DB_NAME_PREFIX", "houserota_api") %>_`
2. `git update-index --skip-worktree apps/api/config/database.yml` so it never shows in `git status`.
3. `.env.development.local` and `.env.test.local` at the worktree root: `DB_NAME_PREFIX=houserota_<tag>`.
4. `bin/rails db:prepare && RAILS_ENV=test bin/rails db:prepare`.

Add worktrees sequentially; four parallel `git worktree add` calls race on the `.git/config` lock.

## Other facts

- No feature-flag system (no Flipper, no Redis flag store). "flag on/off" briefs do not apply here.
- Single theme (Soft Clay). `npm run check:tokens` and `npm run check:bundle` guard token parity.
- Root `.gitignore` has `/.koh/`, which is relative to the main checkout, so a shots dir inside a
  worktree is NOT ignored. Keep PNGs in the scratchpad.
- Screenshots: Playwright from the Playwright MCP package
  (`/opt/homebrew/lib/node_modules/@playwright/mcp/node_modules/playwright`). `gstack browse`
  answers every command with "No active page" and Claude-in-Chrome reports "not connected".
- Viewports used before: 1440x900 desktop, 390x844 phone. The phone overflow probe caught a 36px
  landing-page overflow on `main`.
