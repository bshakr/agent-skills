# Appendix: ritualpass api

`/Users/bassemshaker/code/ritualpass/api` (Rails). **Mostly JSON, so most api PRs have no
user-visible surface of their own.** Do not invent one: the coordinator writes
"No user-visible surface" in the PR instead of a gallery.

## What the api itself renders (capturable)

- **`/flipper`**, the Flipper UI, real HTML behind `FLIPPER_UI_USERNAME` / `FLIPPER_UI_PASSWORD`.
  Capture it when a PR changes flag metadata, the catalog, or that UI.
- **`/letter_opener`** in development, plus the mailer previews. An email template change **is** a
  user-visible change and is capturable here. Capture the rendered email, both halves.
- Nothing else. There is no admin HTML surface.

## When an api diff changes what a frontend renders

That is the common case, and the pair is built differently: keep **one** frontend build and swap
the api underneath it, two api servers on distinct ports, the before one at the fork point.
Both halves must otherwise be identical. A single frontend against two apis is the only way to
attribute the difference to the api diff. Never point the two halves at two different apis by
accident: an api branch that already dropped a flag makes the "before" frontend render its
flag-off state.

## Boot

```bash
git worktree add --detach /tmp/api-before <base_sha>
cp /Users/bassemshaker/code/ritualpass/api/.env /tmp/api-before/.env    # REQUIRED
cd /tmp/api-before && bundle install && bin/rails server -p 3910
```

- **A fresh api worktree has no `.env`** (gitignored). Without it, login succeeds but every
  authenticated request 401s with "No verification key available", because `DEVISE_JWT_SECRET_KEY`
  is unset.
- A fresh worktree also needs `RAILS_ENV=test bin/rails db:create db:schema:load` before any test
  run.
- Postgres and Redis run under the **OrbStack** docker context, not Docker Desktop. `docker ps`
  showing exited containers while 5434 and 6379 answer means you queried the wrong engine: use
  `DOCKER_CONTEXT=orbstack` or `docker --context orbstack`.
- Preflight `pg_isready -p 5434` before blaming the app for a hang. Dev DB `ritualpass_development`,
  host and port from `DATABASE_HOST` (localhost) and `DATABASE_PORT` (5434).
- Seeded logins live in `db/seeds/development.rb`. Read the file; the passwords have been reseeded
  since several remembered values circulated.

## Flags

`config/initializers/flipper.rb` reads `FLIPPER_REDIS_URL` (falling back to `REDIS_URL`), **db 2**,
shared by every local api instance regardless of its Postgres. Give your capture api a private db
(`FLIPPER_REDIS_URL=redis://localhost:6379/<free db>`) rather than toggling a global; a global
disable has blacked out three other agents' work for minutes at a time, and it wipes the flag's
actor set as well.

## Reference

`/Users/bassemshaker/code/ritualpass/e2e/playwright.config.ts` drives api, admin-web and
client-web together with `E2E_API_PORT`, `E2E_ADMIN_PORT`, `E2E_CLIENT_PORT`, `E2E_TENANT`,
`E2E_TARGET`.
