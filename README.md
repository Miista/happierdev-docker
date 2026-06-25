# happierdev-docker

Slim Docker images for [Happier](https://github.com/happier-dev/happier) — a web, desktop and mobile client for Claude Code and other AI coding agents.

The [official image](https://hub.docker.com/r/happierdev/relay-server) is built from source and weighs ~2 GB. These images are built directly from the pre-compiled binaries published on the [Happier releases page](https://github.com/happier-dev/happier/releases), stripping unused platform artifacts, resulting in images that are ~85% smaller.

## Images

| Tag | Description | Size |
|-----|-------------|------|
| `latest`, `<version>` | Relay server + embedded web UI | ~263 MB |
| `headless`, `<version>-headless` | Relay server only | ~173 MB |

Use `headless` if you connect exclusively via the native desktop or mobile app. Use `latest` if you want the web UI available at the server URL.

## Usage

```yaml
services:
  happier:
    image: ghcr.io/miista/happierdev-docker:latest
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
