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

**Prerequisites:** Docker + the Compose plugin (already installed per your
setup: Debian 13, Docker 29.8.0), and reachability over your own Tailscale
network — nothing here needs a public domain, port-forward, or TLS
certificate, since Tailscale itself is the trust boundary.

### 1. Get the files onto the server

Either `git clone` the whole HB_Clips repo on the server and `cd` into
`supabase/selfhost/`, or copy just this directory over:

```sh
scp -r supabase/selfhost/ your-user@your-server-tailscale-name:~/hb_clips_supabase
ssh your-user@your-server-tailscale-name
cd ~/hb_clips_supabase
```

### 2. Generate real secrets

```sh
cp .env.example .env
sh utils/generate-keys.sh --update-env
```

This writes a fresh `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`,
`POSTGRES_PASSWORD`, `DASHBOARD_PASSWORD`, and the rest, straight into
`.env` via local `openssl` calls — no network access, nothing to copy from
this conversation. **Keep this `.env` file private** (it's already
gitignored) — `SERVICE_ROLE_KEY` bypasses RLS entirely.

### 3. Apply the HB_Clips-specific overrides

Edit `.env` and set (see "HB_Clips-specific `.env` overrides" above for
why):

```
ENABLE_ANONYMOUS_USERS=true
DISABLE_SIGNUP=true
ENABLE_EMAIL_SIGNUP=false
ENABLE_PHONE_SIGNUP=false
SUPABASE_PUBLIC_URL=http://<tailscale-name>:8000
API_EXTERNAL_URL=http://<tailscale-name>:8000/auth/v1
SITE_URL=http://<tailscale-name>:8000
```

Replace `<tailscale-name>` with the server's actual Tailscale MagicDNS
hostname (`tailscale status` on the server shows it) or its Tailscale IP.

### 4. Start the stack

```sh
sh run.sh start      # docker compose up -d --wait
sh run.sh status      # docker compose ps - wait until every service is healthy
```

First start pulls ~10 images; give it a few minutes on a home connection.

### 5. Apply the migrations

Open `http://<tailscale-name>:8000` in a browser from any device on your
tailnet — this is Supabase Studio, behind HTTP basic auth
(`DASHBOARD_USERNAME`/`DASHBOARD_PASSWORD` from `.env`). Go to the **SQL
Editor**, and paste + run, **in order**:

1. `../migrations/0001_init.sql`
2. `../migrations/0002_schema_drift.sql`
3. Any later-numbered migration file in `../migrations/` — always in
   numeric order.

(Direct `psql` access to Supavisor's port `5432`/`6543` works too if you
prefer a terminal, but isn't required — the SQL Editor covers this fully
over just port 8000.)

### 6. Smoke-test the deployment

Run these from any machine on your tailnet (or on the server itself),
substituting `<tailscale-name>` and pulling `$ANON_KEY` out of the
server's `.env`:

```sh
BASE="http://<tailscale-name>:8000"
ANON_KEY="<paste from .env>"

# 1. Anonymous sign-up - expect a JWT with role=authenticated, is_anonymous=true
curl -s -X POST "$BASE/auth/v1/signup" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d '{}' | tee /tmp/signup1.json
JWT1=$(jq -r .access_token /tmp/signup1.json)
UID1=$(jq -r .user.id /tmp/signup1.json)
echo "$JWT1" | cut -d. -f2 | base64 -d 2>/dev/null | jq .   # confirm is_anonymous:true, role:authenticated

# 2. That user can create and read their own board
curl -s -X POST "$BASE/rest/v1/boards" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT1" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d "{\"name\":\"Smoke Test Board\",\"user_id\":\"$UID1\"}"

curl -s "$BASE/rest/v1/boards?select=*" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT1" | jq .

# 3. A second anonymous user must NOT see the first one's board (RLS proof)
curl -s -X POST "$BASE/auth/v1/signup" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" -d '{}' | tee /tmp/signup2.json
JWT2=$(jq -r .access_token /tmp/signup2.json)

curl -s "$BASE/rest/v1/boards?select=*" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT2" | jq .   # expect: []

# 4. Image upload/rejection (Storage RLS proof)
UID2=$(jq -r .user.id /tmp/signup2.json)
echo "test" > /tmp/test.png
curl -s -o /dev/null -w "own path: %{http_code}\n" -X POST \
  "$BASE/storage/v1/object/clip-images/$UID1/test-clip/original.png" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT1" \
  -H "Content-Type: image/png" --data-binary @/tmp/test.png   # expect 200

curl -s -o /dev/null -w "other users path: %{http_code}\n" -X POST \
  "$BASE/storage/v1/object/clip-images/$UID1/test-clip/original2.png" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $JWT2" \
  -H "Content-Type: image/png" --data-binary @/tmp/test.png   # expect 403
```

Requires `jq` (`apt install jq` if not already present). Report back what
each step actually returns — this is the real end-to-end proof that
GoTrue's anonymous auth, PostgREST's RLS enforcement, and Storage's RLS
enforcement all behave correctly against the real deployed stack (the
schema/RLS *logic* itself was already validated separately, without
Docker, in `../local-sql-validation/`).

### 7. Point the Flutter app at it

Once the smoke test passes, put these in HB_Clips' own `.env` (repo root,
already gitignored):

```
SUPABASE_URL=http://<tailscale-name>:8000
SUPABASE_ANON_KEY=<the same ANON_KEY from this stack's .env>
```

### 8. Full end-to-end app verification

The curl-based smoke test above proves the backend (GoTrue, PostgREST,
Storage, RLS) is behaving correctly on its own. Once the app is pointed at
your server, run through **[`E2E_CHECKLIST.md`](./E2E_CHECKLIST.md)** for
the fuller check — the app's own outbox/drain/realtime/reconciliation
logic against the real deployed stack: persistence across restarts,
cross-device realtime propagation, offline queueing, image/GIF round-trip
integrity, delete propagation, and the server-side 30-image cap.

### Notes

- Only port `8000` (the gateway, `API_GW_HTTP_PORT` if you change it from
  the default) needs to be reachable over your tailnet. Supavisor's
  Postgres ports (`5432`/`6543`) can stay unpublished, or bound to
  `127.0.0.1` on the server host, since the app never talks to Postgres
  directly - it only goes through the gateway.
- To stop the stack: `sh run.sh stop`. To tear it down completely
  (including volumes/data - irreversible): `sh reset.sh`.
- To view logs for a specific service if something looks wrong:
  `sh run.sh logs <service>` (service names match the compose file, e.g.
  `auth`, `rest`, `storage`, `db`, `api-gw`).
