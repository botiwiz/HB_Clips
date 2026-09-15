# Builds and serves the HB_Clips Flutter web app as its own container,
# entirely separate from the vendored Supabase stack (docker-compose.yml)
# - it only shares that stack's Docker network so Caddy can reach the
# `api-gw` service internally. Built from the repo root (this file's build
# context, set by docker-compose.web.yml's `context: ../../`), so it needs
# the whole HB_Clips source tree, not just this directory.
#
# Requires the repo root's `.env` (gitignored, see ../../.env.example) to
# exist on disk BEFORE `docker compose build` runs: flutter_dotenv loads
# `.env` as a bundled asset at build time (pubspec.yaml's `assets:` list),
# not read at container runtime, so it has to be present when `flutter
# build web` runs in the builder stage below.
#
# ghcr.io/cirruslabs/flutter is a widely-used community-maintained image
# (there's no official one from Google/Flutter) - pinned to the exact
# Flutter version this app was built/tested against.
FROM ghcr.io/cirruslabs/flutter:3.35.5 AS builder
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release --no-web-resources-cdn

# Slim runtime: just the static build output + Caddy as both file server
# and reverse proxy, so the browser talks to one origin for everything
# (the page itself and the Supabase API paths) with no CORS configuration
# needed anywhere.
FROM caddy:2-alpine
COPY --from=builder /app/build/web /srv
COPY supabase/selfhost/web/Caddyfile /etc/caddy/Caddyfile
