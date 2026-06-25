FROM debian:12-slim AS fetch
ARG TARGETARCH
ARG SERVER_TAG=server-v0.2.10-dev.4
ARG SERVER_VERSION=0.2.10-dev.4

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*

# Extract server tarball twice: with and without the bundled ui-web
RUN mkdir -p /srv/server /srv/server-ui && \
    ARCH=$(case "$TARGETARCH" in \
        amd64)   echo "x64"   ;; \
        arm64)   echo "arm64" ;; \
        *) echo "ERROR: unsupported TARGETARCH=$TARGETARCH" >&2; exit 1 ;; \
    esac) && \
    curl -fsSL "https://github.com/happier-dev/happier/releases/download/${SERVER_TAG}/happier-server-v${SERVER_VERSION}-linux-${ARCH}.tar.gz" \
    | tee /tmp/server.tar.gz \
    | tar -xz --strip-components=1 -C /srv/server-ui && \
    tar -xz --strip-components=1 --exclude='*/ui-web' -C /srv/server < /tmp/server.tar.gz && \
    rm /tmp/server.tar.gz && \
    test -d /srv/server-ui/ui-web/current || { echo "ERROR: ui-web not found in server tarball"; exit 1; } && \
    for dir in /srv/server /srv/server-ui; do \
        rm -rf "$dir/generated/mysql-client" && \
        find "$dir/generated/sqlite-client" -name '*.node' \
            ! -name 'libquery_engine-debian-openssl-3.0.x.so.node' \
            ! -name 'libquery_engine-linux-arm64-openssl-3.0.x.so.node' -delete && \
        rm -rf "$dir/node_modules/@img/sharp-libvips-linuxmusl-x64" \
               "$dir/node_modules/@img/sharp-linuxmusl-x64"; \
    done

FROM debian:12-slim AS base
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
ENV PORT=3005
ENV HAPPIER_SERVER_FLAVOR=light
ENV HAPPIER_DB_PROVIDER=sqlite
ENV HAPPIER_SERVER_LIGHT_DATA_DIR=/data
VOLUME ["/data"]
EXPOSE 3005
ENTRYPOINT ["/srv/server/happier-server"]

FROM base AS server
COPY --from=fetch /srv/server /srv/server

FROM base AS server-ui
COPY --from=fetch /srv/server-ui /srv/server
ENV HAPPIER_SERVER_UI_DIR=/srv/server/ui-web/current
