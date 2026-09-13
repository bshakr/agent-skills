# Appendix: ritualpass client-web

`/Users/bassemshaker/code/ritualpass/frontend/apps/client-web`. The member and public surface.
Everything in `projects/ritualpass-admin-web.md` about tenants, the JWT cookie, Flipper and the
private-repo gallery rule applies here too; only the differences are below.

## Boot

```bash
cd .../frontend/apps/client-web
GH_PACKAGE_TOKEN=$(gh auth token) pnpm install --frozen-lockfile
NEXT_PUBLIC_API_URL=http://localhost:3910 PORT=3912 pnpm dev -- -H 127.0.0.1
```

- `.npmrc` authenticates with **`GH_PACKAGE_TOKEN`**, not `GITHUB_TOKEN` (admin-web uses the
  latter). A session exporting only `GITHUB_TOKEN` fails `pnpm install` here.
- It runs `node-linker=hoisted`, unlike admin-web's strict linker, and has **no `.env.local`**
  anywhere. Builds and tests pass without one.
- `-H 127.0.0.1` is required: `next dev` binds IPv6-only by default while Chromium resolves
  `*.localhost` to IPv4, which surfaces as `ERR_CONNECTION_REFUSED`.
- Second, stacked cause of the same error: `middleware.ts` redirects unauthenticated `/member/*`
  to **port 3001**, so the refusal can be about the redirect target, not your server. Seed the
  `ritualpass_jwt_token` cookie instead of driving the login UI.
- Default port in the e2e harness is 3002 (`E2E_CLIENT_PORT`).

## Anonymous surfaces

Anonymous requests carry no feature flags: `GET /me/flags` returns only
`{"signup_stripe_checkout": true}`. Any `eventsEnabled`-style value is permanently false for
visitors, so public surfaces gate on the tenant's `offerings` plus data presence. Anonymous
`GET /tenant` does carry `offerings`, and anonymous `GET /api/v1/events` returns 200 because
`feature_enabled?` falls through to the tenant actor when `current_user` is nil.

For a "studio does not offer this" state, change the tenant's `settings["offerings"]` (write the
original to a file first and restore after) rather than touching a global flag.

## Gotchas

- The auth cookie is host-only per subdomain but shared across ports within one host, so a
  "logged out" capture on a fresh port can still render a signed-in header. Use a clean browser
  context and assert an empty cookie jar before a logged-out shot.
- Public schedule and card layouts have produced real cross-location occlusion bugs, so capture
  the populated multi-location state, not just the happy single-location one.
