# HB_Clips self-hosted Supabase

This directory is a vendored copy of the official [`supabase/supabase`](https://github.com/supabase/supabase)
repo's `docker/` self-hosting stack (Postgres + GoTrue Auth + Storage +
Realtime + the `api-gw` gateway + Studio). It's used as-is, not forked —
HB_Clips-specific configuration lives entirely in `.env` (gitignored, never
committed) and in the app's own migrations under `../migrations/`.

**Why vendored instead of just documented:** so the exact files the app was
built and tested against travel with the repo, and `git diff` against a
future `supabase/supabase` re-vendor shows precisely what upstream changed.

## What's here

- `docker-compose.yml` + override files (`docker-compose.*.yml`) — unmodified
  from upstream.
- `run.sh` / `reset.sh` / `setup.sh` / `update.sh` — upstream's management
  scripts. `sh run.sh start` / `sh run.sh status` / `sh run.sh stop` are the
  ones used below.
- `utils/generate-keys.sh` — generates all secrets (`JWT_SECRET`, `ANON_KEY`,
  `SERVICE_ROLE_KEY`, `POSTGRES_PASSWORD`, `DASHBOARD_PASSWORD`, ...) purely
  via local `openssl` calls, no network access.
- `.env.example` — upstream's full template. Copy to `.env` and override the
  values below for HB_Clips.
- `volumes/` — service configs (Envoy gateway routing, Postgres init SQL,
  etc.) and, once running, the actual Postgres/Storage data directories
  (gitignored).

## HB_Clips-specific `.env` overrides

On top of whatever `utils/generate-keys.sh` fills in, these need to be set
by hand for this app's use case (no login screens, anonymous-auth only,
reached only over Tailscale — never the public internet):

```
ENABLE_ANONYMOUS_USERS=true
DISABLE_SIGNUP=true
ENABLE_EMAIL_SIGNUP=false
ENABLE_PHONE_SIGNUP=false

# Replace <tailscale-name> with the server's Tailscale MagicDNS hostname
# (or its Tailscale IP), e.g. http://my-server.tailnet-name.ts.net:8000
SUPABASE_PUBLIC_URL=http://<tailscale-name>:8000
API_EXTERNAL_URL=http://<tailscale-name>:8000/auth/v1
SITE_URL=http://<tailscale-name>:8000
```

No reverse proxy, domain, or TLS cert is needed — Tailscale itself is the
trust boundary, and only the gateway's port (`8000` by default, via
`API_GW_HTTP_PORT` if you need to change it) needs to be reachable from your
other devices.

## Deploying to your home server

*(This section is completed in full, with a real command-by-command
smoke test, once the stack has been validated against a throwaway instance
in the dev sandbox — see the project plan's Phase B/D. Placeholder for now.)*
