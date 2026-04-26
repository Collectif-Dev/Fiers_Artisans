#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# Fiers Artisans — Script de backup
# ══════════════════════════════════════════════════════════════════════

set -euo pipefail

BACKUP_DIR="/opt/fierartisans/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔄 Backup PostgreSQL..."
docker exec fiers-postgres pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "$BACKUP_DIR/postgres.sql.gz"

echo "🔄 Backup MongoDB..."
docker exec fiers-mongodb mongodump --username="${MONGO_USER}" --password="${MONGO_PASSWORD}" --authenticationDatabase=admin --db="${MONGO_DB}" --archive | gzip > "$BACKUP_DIR/mongodb.gz"

echo "🔄 Backup Redis..."
docker exec fiers-redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE
sleep 2
docker cp fiers-redis:/data/dump.rdb "$BACKUP_DIR/redis.rdb"

# Retention : supprimer les backups de plus de 7 jours
find /opt/fierartisans/backups -type d -mtime +7 -exec rm -rf {} +

echo "✅ Backup terminé : $BACKUP_DIR"
