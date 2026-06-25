FROM debian:12-slim AS fetch
ARG TARGETARCH
ARG SERVER_TAG=server-v0.2.10-dev.4
ARG SERVER_VERSION=0.2.10-dev.4
ARG UI_WEB_TAG=ui-web-v0.2.10-dev.180
ARG UI_WEB_VERSION=0.2.10-dev.180

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /srv/server /srv/ui && \
    ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x64") && \
    curl -fsSL "https://github.com/happier-dev/happier/releases/download/${SERVER_TAG}/happier-server-v${SERVER_VERSION}-linux-${ARCH}.tar.gz" \
    | tar -xz --strip-components=1 --exclude='*/ui-web' -C /srv/server && \
    rm -rf /srv/server/generated/mysql-client && \
    find /srv/server/generated/sqlite-client -name '*.node' ! -name 'libquery_engine-debian-openssl-3.0.x.so.node' ! -name 'libquery_engine-linux-arm64-openssl-3.0.x.so.node' -delete && \
    rm -rf /srv/server/node_modules/@img/sharp-libvips-linuxmusl-x64 \
           /srv/server/node_modules/@img/sharp-linuxmusl-x64

RUN curl -fsSL "https://github.com/happier-dev/happier/releases/download/${UI_WEB_TAG}/happier-ui-web-v${UI_WEB_VERSION}-web-any.tar.gz" \
    | tar -xz --strip-components=1 -C /srv/ui

FROM debian:12-slim AS base
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=fetch /srv/server /srv/server
ENV PORT=3005
ENV HAPPIER_SERVER_FLAVOR=light
ENV HAPPIER_DB_PROVIDER=sqlite
ENV HAPPIER_SERVER_LIGHT_DATA_DIR=/data
VOLUME ["/data"]
EXPOSE 3005
ENTRYPOINT ["/srv/server/happier-server"]

FROM base AS server

FROM base AS server-ui
COPY --from=fetch /srv/ui /srv/ui
ENV HAPPIER_SERVER_UI_DIR=/srv/ui
