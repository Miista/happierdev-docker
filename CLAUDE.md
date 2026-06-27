# CLAUDE.md

## What this is

Slim multi-arch Docker images for [Happier](https://github.com/happier-dev/happier) (a relay server + web UI for Claude Code and other AI coding agents). Instead of building from source (~2 GB official image), the Dockerfile downloads Happier's pre-compiled release binaries, strips unused platform artifacts, and produces images ~85% smaller. Published to GHCR as `happier-ui` (server + embedded web UI, ~263 MB) and `happier-relay` (server only, ~173 MB). There is no application source here — only the Dockerfile, the entrypoint, and the CI that builds and publishes.

## Build / run / test

Build args (defaults track the `dev` channel; see `Dockerfile`): `SERVER_TAG`, `SERVER_VERSION`, `UI_WEB_TAG`, `UI_WEB_VERSION`, plus auto `TARGETARCH`. Two targets: `server` (relay only) and `server-ui` (adds the web UI bundle).

```sh
# Build relay-only image for a specific release
docker build --target server \
  --build-arg SERVER_TAG=server-stable --build-arg SERVER_VERSION=0.2.0 \
  -t happier-relay:local .

# Build server + UI
docker build --target server-ui \
  --build-arg SERVER_TAG=server-stable --build-arg SERVER_VERSION=0.2.0 \
  --build-arg UI_WEB_TAG=ui-web-stable --build-arg UI_WEB_VERSION=0.2.0 \
  -t happier-ui:local .

# Run (listens on 3005; HANDY_MASTER_SECRET required)
docker run -d -e HANDY_MASTER_SECRET=$(openssl rand -hex 32) \
  -v happier-data:/data -p 3005:3005 happier-ui:local
```

Smoke test (mirrors CI in `.github/workflows/build.yml`): boot against a fresh `/data`, wait ~10s, confirm the SQLite DB at `/data/happier-server-light.sqlite` has >=10 tables. CI fails a channel and publishes nothing for it if the schema isn't created.

## Architecture

- **`Dockerfile`** — two-stage. `fetch` stage (debian:12-slim) curls the server tarball from the Happier releases page, strips bundled `ui-web` (always fetched separately, channel-matched), drops the mysql client and non-matching Prisma query-engine `.node` libs and musl `sharp` libs to slim the image. `base` stage installs `ca-certificates` + `sqlite3`, copies `/srv/server`, installs the entrypoint, sets `PORT=3005`, `HAPPIER_SERVER_FLAVOR=light`, `HAPPIER_DB_PROVIDER=sqlite`, `HAPPIER_SERVER_LIGHT_DATA_DIR=/data`, declares the `/data` volume. `server` target = base; `server-ui` target = base + `/srv/ui` and `HAPPIER_SERVER_UI_DIR`.
- **`docker-entrypoint.sh`** — the only logic in this repo (see below).
- **`.github/workflows/build.yml`** — daily + on-push matrix build (2 variants × 3 channels: stable/preview/dev), each multi-arch (amd64/arm64). `detect` job resolves the current version per channel from upstream release assets and, on the daily schedule, skips channels whose version image already exists. Each channel is smoke-tested before publish. Float tags: stable→`latest`,`stable`; preview→`preview`; dev→`dev`; plus the immutable `<version>` tag.

### docker-entrypoint.sh

A `sh` script (`set -eu`) that back-fills a Prisma SQLite schema for older server binaries that don't self-migrate, then hands off to the server.

- **Why:** newer Happier binaries apply their bundled Prisma migrations on startup; older pinned builds (e.g. stable `0.2.0`, preview `0.2.1`) relied on the source image's `run-server.sh` running `prisma migrate deploy`, which isn't in the standalone binary. This script reproduces that step. On an already-migrated DB it is a no-op, so it is safe on every channel and retires itself once all upstream binaries self-migrate.
- **Env vars read:** `HAPPIER_SERVER_LIGHT_DATA_DIR` (default `/data`) → derives `DB=$DATA_DIR/happier-server-light.sqlite`. Migrations are read from the fixed path `/srv/server/prisma/sqlite/migrations`.
- **Startup flow:** runs `bootstrap_migrations`, then `exec /srv/server/happier-server "$@"` (replaces PID 1, so signals/`$@` pass through).
- **bootstrap_migrations:** returns early if the migrations dir is absent; queries `SELECT COUNT(*) FROM _prisma_migrations` and skips if any rows exist (already migrated). Otherwise it `mkdir -p`s the data dir, creates the `_prisma_migrations` table, and for each `migrations/*/migration.sql` (in directory order) applies it via `sqlite3 .read` and inserts a row mimicking Prisma's format — random UUID `id`, `sha256sum(migration.sql)` checksum, directory name as `migration_name`.

## Conventions / gotchas

- No app source lives here; this repo only packages upstream binaries. To change runtime behavior you change build args (which release) or the entrypoint.
- Migration SQL files carry their own `PRAGMA foreign_keys` toggles, which cannot run inside a transaction — that's why each file is applied with `.read` as-is and recorded in a separate statement rather than wrapped in a transaction.
- The entrypoint is deliberately a no-op on migrated databases. Don't make it unconditionally run migrations, or it will conflict with self-migrating binaries.
- GHCR repo/owner names must be lowercase — CI lowercases `OWNER` (`${OWNER,,}`); preserve that if editing tag logic.
- The `server` tarball may or may not bundle `ui-web`; it is always stripped in the `fetch` stage and `ui-web` is fetched separately so image layout is consistent across channels.
- Do not expose port 3005 directly to the internet without TLS (use a reverse proxy / tunnel).
