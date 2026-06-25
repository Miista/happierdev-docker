#!/bin/sh
# Bootstrap the SQLite schema for server binaries that don't self-migrate.
#
# Newer Happier server binaries apply their bundled Prisma migrations on
# startup. Older pinned builds (e.g. stable 0.2.0, preview 0.2.1) do not —
# they relied on the source image's run-server.sh calling `prisma migrate
# deploy`, which isn't available in the standalone binary distribution.
#
# This script back-fills that step: on an unmigrated database it applies the
# bundled prisma/sqlite/migrations/*/migration.sql in order and records each
# in _prisma_migrations using Prisma's format (id, sha256(migration.sql) as
# checksum, directory name as migration_name). On databases that are already
# migrated — including those a self-migrating binary handles itself — it is a
# no-op, so it is safe across all channels.
set -eu

DATA_DIR="${HAPPIER_SERVER_LIGHT_DATA_DIR:-/data}"
DB="${DATA_DIR%/}/happier-server-light.sqlite"
MIG_DIR="/srv/server/prisma/sqlite/migrations"

bootstrap_migrations() {
  [ -d "$MIG_DIR" ] || return 0

  applied=$(sqlite3 "$DB" "SELECT COUNT(*) FROM _prisma_migrations;" 2>/dev/null || echo 0)
  if [ "${applied:-0}" -gt 0 ]; then
    echo "[entrypoint] database already migrated (${applied} migrations); skipping"
    return 0
  fi

  echo "[entrypoint] bootstrapping schema from bundled migrations -> $DB"
  mkdir -p "$DATA_DIR"
  sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS _prisma_migrations (
    id TEXT PRIMARY KEY,
    checksum TEXT NOT NULL,
    finished_at DATETIME,
    migration_name TEXT NOT NULL,
    logs TEXT,
    rolled_back_at DATETIME,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    applied_steps_count INTEGER NOT NULL DEFAULT 0
  );"

  for dir in "$MIG_DIR"/*/; do
    name=$(basename "$dir")
    sql="${dir}migration.sql"
    [ -f "$sql" ] || continue

    sum=$(sha256sum "$sql" | awk '{print $1}')
    id=$(cat /proc/sys/kernel/random/uuid)
    echo "[entrypoint]   applying ${name}"

    # migration.sql carries its own PRAGMA foreign_keys toggles, which cannot
    # run inside a transaction, so apply the file as-is then record it.
    sqlite3 "$DB" ".read ${sql}"
    sqlite3 "$DB" "INSERT INTO _prisma_migrations
      (id, checksum, migration_name, started_at, finished_at, applied_steps_count)
      VALUES ('${id}', '${sum}', '${name}', datetime('now'), datetime('now'), 1);"
  done

  echo "[entrypoint] schema bootstrap complete"
}

bootstrap_migrations
exec /srv/server/happier-server "$@"
