#!/usr/bin/env bash
# Backup serveur des donnees principales Fiers Artisans.
#
# Variables configurables:
#   BACKUP_ROOT=/opt/fiers-artisans/backups
#   POSTGRES_CONTAINER=fiers-postgres
#   MONGO_CONTAINER=fiers-mongodb
#   REDIS_CONTAINER=fiers-redis
#   BACKUP_RETENTION_DAYS=7
#
# Le script lit les credentials depuis l'environnement. Sur serveur, chargez
# `.env` avant execution ou lancez depuis un service/cron qui expose deja ces
# variables.

set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/opt/fiers-artisans/backups}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-fiers-postgres}"
MONGO_CONTAINER="${MONGO_CONTAINER:-fiers-mongodb}"
REDIS_CONTAINER="${REDIS_CONTAINER:-fiers-redis}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

: "${POSTGRES_USER:?POSTGRES_USER est requis}"
: "${POSTGRES_DB:?POSTGRES_DB est requis}"
: "${MONGO_USER:?MONGO_USER est requis}"
: "${MONGO_PASSWORD:?MONGO_PASSWORD est requis}"
: "${MONGO_DB:?MONGO_DB est requis}"
: "${REDIS_PASSWORD:?REDIS_PASSWORD est requis}"

export MONGO_USER MONGO_PASSWORD MONGO_DB

BACKUP_DIR="${BACKUP_ROOT}/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backup PostgreSQL..."
docker exec "${POSTGRES_CONTAINER}" pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "$BACKUP_DIR/postgres.sql.gz"

echo "Backup MongoDB..."
docker exec \
  -e MONGO_USER \
  -e MONGO_PASSWORD \
  -e MONGO_DB \
  "${MONGO_CONTAINER}" \
  sh -ceu '
    config_file="$(mktemp)"
    trap "rm -f \"$config_file\"" EXIT
    umask 077
    {
      printf "%s\n" "password: |-"
      printf "%s\n" "$MONGO_PASSWORD" | sed "s/^/  /"
    } > "$config_file"
    mongodump --username="$MONGO_USER" --config="$config_file" --authenticationDatabase=admin --db="$MONGO_DB" --archive
  ' | gzip > "$BACKUP_DIR/mongodb.gz"

echo "Backup Redis..."
REDISCLI_AUTH="$REDIS_PASSWORD" docker exec -e REDISCLI_AUTH "${REDIS_CONTAINER}" redis-cli BGSAVE
sleep 2
docker cp "${REDIS_CONTAINER}:/data/dump.rdb" "$BACKUP_DIR/redis.rdb"

# Retention : supprimer les backups de plus de 7 jours
find "${BACKUP_ROOT}" -type d -mtime "+${BACKUP_RETENTION_DAYS}" -exec rm -rf {} +

echo "Backup termine : $BACKUP_DIR"
