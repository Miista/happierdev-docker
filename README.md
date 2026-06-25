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
