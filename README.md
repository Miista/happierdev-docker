# happierdev-docker

Slim Docker images for [Happier](https://github.com/happier-dev/happier) — a web, desktop and mobile client for Claude Code and other AI coding agents.

The [official image](https://hub.docker.com/r/happierdev/relay-server) is built from source and weighs ~2 GB. These images are built directly from the pre-compiled binaries published on the [Happier releases page](https://github.com/happier-dev/happier/releases), stripping unused platform artifacts, resulting in images that are ~85% smaller.

## Images

| Image | Description | Size |
|-------|-------------|------|
| `ghcr.io/miista/happier-ui` | Relay server + embedded web UI | ~263 MB |
| `ghcr.io/miista/happier-relay` | Relay server only | ~173 MB |

Use `happier-relay` if you connect exclusively via the native desktop or mobile app. Use `happier-ui` if you want the web UI available at the server URL.

## Channels

Both images mirror Happier's three upstream release channels:

| Tag | Upstream channel | Notes |
|-----|------------------|-------|
| `latest`, `stable` | `server-stable` | Stable releases. Recommended. |
| `preview` | `server-preview` | Happier's dev channel — periodic, fairly tested. |
| `dev` | `server-dev` | Bleeding edge — updated on every upstream push. |

Each build is also published under its immutable version tag (e.g. `:0.2.0`, `:0.2.10-dev.4`). Pin to a version tag for reproducible deployments.

### Build matrix

A full run produces **6 images** (2 variants × 3 channels), each a multi-arch manifest for `linux/amd64` and `linux/arm64`:

| | `happier-ui` | `happier-relay` |
|---|---|---|
| **stable** | `latest`, `stable`, `<version>` | `latest`, `stable`, `<version>` |
| **preview** | `preview`, `<version>` | `preview`, `<version>` |
| **dev** | `dev`, `<version>` | `dev`, `<version>` |

The comma-separated entries are **separate tags on the same image**, not combined — e.g. the preview `happier-ui` is published as both `happier-ui:preview` and `happier-ui:0.2.2-preview.1775585938.1`. Use a floating tag (`preview`) to track a channel, or a `<version>` tag to pin exactly.

On the daily schedule, a channel is skipped if its `<version>` is already published, so unchanged channels aren't rebuilt. Each built image is also smoke-tested — booted against a fresh database to confirm the schema is created — and is only published if that passes.

### Schema migrations

Recent Happier server binaries apply their bundled Prisma migrations on startup. Older pinned builds (e.g. stable `0.2.0`) don't — they expected the source image's `run-server.sh` to run `prisma migrate deploy`, which isn't part of the standalone binary. These images include a small entrypoint that back-fills that step: on an unmigrated database it applies the bundled `migration.sql` files and records them in `_prisma_migrations` exactly as Prisma would. On an already-migrated database (including one a self-migrating binary handles itself) it's a no-op, so it's safe across all channels and retires itself once upstream's binaries all self-migrate.

## Usage

```yaml
services:
  happier:
    image: ghcr.io/miista/happier-ui:latest
    restart: unless-stopped
    environment:
      HANDY_MASTER_SECRET: your-secret-here   # generate with: openssl rand -hex 32
    volumes:
      - happier-data:/data

volumes:
  happier-data:
```

The server listens on port `3005`. Expose it via a reverse proxy or Cloudflare Tunnel — do not expose it directly to the internet without TLS.

## Platforms

- `linux/amd64`
- `linux/arm64`

## Updates

Images are rebuilt daily. When a new Happier release is published upstream, the next daily run picks it up automatically and pushes updated images to GHCR.
