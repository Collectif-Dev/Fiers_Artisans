#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_DIR="$REPO_ROOT/infrastructure"
ENV_FILES=("$REPO_ROOT/.env" "$INFRA_DIR/.env")

MODE="dry-run"
AUTO_YES="false"

usage() {
  cat <<'EOF'
Usage:
  infrastructure/scripts/reset_clean_environment.sh                # dry-run (default)
  infrastructure/scripts/reset_clean_environment.sh --dry-run
  infrastructure/scripts/reset_clean_environment.sh --execute      # asks for confirmation phrase
  infrastructure/scripts/reset_clean_environment.sh --execute --yes

What it does (execute mode):
  - PostgreSQL: purge business data while preserving schema/migrations/static refs/admin users
  - MongoDB: purge app dynamic collections but keep documents tagged as admin
  - Redis: flush runtime cache/keys
  - MinIO: delete user objects inside buckets (keep buckets, preserve admin/system prefixes)

What it never does:
  - DROP DATABASE / DROP SCHEMA / DROP TABLE
  - migration/schema/policy/index/function deletion
  - env/secrets/server config changes (.env checksums verified)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      ;;
    --execute)
      MODE="execute"
      ;;
    --yes)
      AUTO_YES="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker is required." >&2
  exit 1
fi

if [[ ! -d "$INFRA_DIR" ]]; then
  echo "[ERROR] infrastructure directory not found: $INFRA_DIR" >&2
  exit 1
fi

PRESENT_ENV_FILES=()
for env_file in "${ENV_FILES[@]}"; do
  if [[ -f "$env_file" ]]; then
    PRESENT_ENV_FILES+=("$env_file")
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi
done

ENV_CHECKSUM_TOOL=""
if command -v sha256sum >/dev/null 2>&1; then
  ENV_CHECKSUM_TOOL="sha256sum"
fi

capture_env_checksums() {
  if [[ -z "$ENV_CHECKSUM_TOOL" || ${#PRESENT_ENV_FILES[@]} -eq 0 ]]; then
    return 0
  fi

  local file
  for file in "${PRESENT_ENV_FILES[@]}"; do
    "$ENV_CHECKSUM_TOOL" "$file"
  done | sort
}

: "${POSTGRES_DB:=fiers_artisans}"
: "${POSTGRES_USER:=fiers_artisans}"
: "${MONGO_DB:=fiers_artisans}"
: "${MONGO_USER:=${MONGO_INITDB_ROOT_USERNAME:-fiers_artisans}}"
: "${MONGO_PASSWORD:=${MONGO_INITDB_ROOT_PASSWORD:-}}"
: "${MINIO_ACCESS_KEY:=${MINIO_ROOT_USER:-}}"
: "${MINIO_SECRET_KEY:=${MINIO_ROOT_PASSWORD:-}}"
: "${MINIO_BUCKET_PORTFOLIO:=portfolio}"
: "${MINIO_BUCKET_DOCUMENTS:=documents}"
: "${MINIO_BUCKET_MEDIA:=media}"
: "${MINIO_PAYMENT_PROOF_BUCKET:=payment-proofs}"

if [[ "$MODE" == "dry-run" ]]; then
  cat <<EOF
[DRY-RUN] Reset plan (no data deleted):
  1) PostgreSQL (service: postgres)
     - Preserve tables: migrations, typeorm_metadata, categories, subcategories, users, spatial_ref_sys
     - Truncate all other public tables with RESTART IDENTITY CASCADE
      - Keep only users where role='ADMIN' (no admin profile field wipe)

  2) MongoDB (service: mongodb, db: $MONGO_DB)
      - deleteMany(non-admin documents) on collections:
       messages, conversations, notifications, activity_logs, portfolio_items, media_files

  3) Redis (service: redis)
     - FLUSHALL

  4) MinIO (service: minio)
      - Remove user objects only (keep bucket structure and admin/system prefixes):
       $MINIO_BUCKET_PORTFOLIO, $MINIO_BUCKET_DOCUMENTS, $MINIO_BUCKET_MEDIA, $MINIO_PAYMENT_PROOF_BUCKET

Requirements before --execute:
  - docker compose stack up in infrastructure
  - explicit destructive confirmation phrase
EOF
  exit 0
fi

cd "$INFRA_DIR"

PRE_ENV_CHECKSUMS="$(capture_env_checksums || true)"

if [[ "$AUTO_YES" != "true" ]]; then
  echo "[SAFEGUARD] This will purge dynamic data across PostgreSQL, MongoDB, Redis and MinIO."
  echo "Type exactly: RESET-OK"
  read -r CONFIRM
  if [[ "$CONFIRM" != "RESET-OK" ]]; then
    echo "[ABORT] Confirmation phrase mismatch."
    exit 1
  fi
fi

required_services=(postgres mongodb redis minio)
running_services="$(docker compose ps --services --status running || true)"
for svc in "${required_services[@]}"; do
  if ! grep -qx "$svc" <<<"$running_services"; then
    echo "[ERROR] Service '$svc' is not running. Start stack first: cd infrastructure && docker compose up -d" >&2
    exit 1
  fi
done

echo "[1/5] PostgreSQL purge..."
docker compose exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;

DO $$
DECLARE
  tbl text;
  preserve text[] := ARRAY[
    'migrations',
    'typeorm_metadata',
    'categories',
    'subcategories',
    'users',
    'spatial_ref_sys'
  ];
BEGIN
  FOR tbl IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND NOT (tablename = ANY (preserve))
  LOOP
    EXECUTE format('TRUNCATE TABLE public.%I RESTART IDENTITY CASCADE', tbl);
  END LOOP;
END $$;

DELETE FROM public.users
WHERE role IS DISTINCT FROM 'ADMIN';

COMMIT;
SQL

echo "[2/5] MongoDB purge..."
if [[ -z "${MONGO_PASSWORD:-}" ]]; then
  echo "[ERROR] MONGO_PASSWORD is not set in environment/.env" >&2
  exit 1
fi
export MONGO_USER MONGO_PASSWORD MONGO_DB
docker compose exec -T \
  -e MONGO_USER \
  -e MONGO_PASSWORD \
  -e MONGO_DB \
  mongodb \
  mongosh --nodb --quiet <<'JS'
const requiredEnv = ['MONGO_USER', 'MONGO_PASSWORD', 'MONGO_DB'];
for (const key of requiredEnv) {
  if (!process.env[key]) {
    throw new Error(`${key} is not set`);
  }
}

const mongoUser = encodeURIComponent(process.env.MONGO_USER);
const mongoPassword = encodeURIComponent(process.env.MONGO_PASSWORD);
const mongoDbName = process.env.MONGO_DB;
const appDb = new Mongo(`mongodb://${mongoUser}:${mongoPassword}@127.0.0.1:27017/?authSource=admin`).getDB(mongoDbName);

const targets = [
  'messages',
  'conversations',
  'notifications',
  'activity_logs',
  'portfolio_items',
  'media_files',
];

const adminMarkers = [
  { role: 'ADMIN' },
  { userRole: 'ADMIN' },
  { actorRole: 'ADMIN' },
  { recipientRole: 'ADMIN' },
  { targetRole: 'ADMIN' },
  { createdByRole: 'ADMIN' },
  { updatedByRole: 'ADMIN' },
  { isAdmin: true },
  { admin: true },
];

const existing = new Set(appDb.getCollectionNames());
for (const name of targets) {
  if (!existing.has(name)) {
    print(`[mongo] ${name}: not found`);
    continue;
  }
  const result = appDb.getCollection(name).deleteMany({ $nor: adminMarkers });
  print(`[mongo] ${name}: ${result.deletedCount} deleted`);
}
JS

echo "[3/5] Redis purge..."
if [[ -z "${REDIS_PASSWORD:-}" ]]; then
  echo "[ERROR] REDIS_PASSWORD is not set in environment/.env" >&2
  exit 1
fi
REDISCLI_AUTH="$REDIS_PASSWORD" docker compose exec -T -e REDISCLI_AUTH redis \
  redis-cli FLUSHALL >/dev/null
echo "[redis] FLUSHALL done"

echo "[4/5] MinIO object purge (bucket structures preserved)..."
if [[ -z "${MINIO_ACCESS_KEY:-}" || -z "${MINIO_SECRET_KEY:-}" ]]; then
  echo "[ERROR] MINIO_ACCESS_KEY / MINIO_SECRET_KEY must be set in environment/.env" >&2
  exit 1
fi

MINIO_CONTAINER_ID="$(docker compose ps -q minio)"
if [[ -z "$MINIO_CONTAINER_ID" ]]; then
  echo "[ERROR] Could not resolve running minio container id." >&2
  exit 1
fi

MINIO_NETWORK="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$MINIO_CONTAINER_ID" | head -n 1 | tr -d '[:space:]')"
if [[ -z "$MINIO_NETWORK" ]]; then
  echo "[ERROR] Could not resolve minio container network." >&2
  exit 1
fi

for bucket in "$MINIO_BUCKET_PORTFOLIO" "$MINIO_BUCKET_DOCUMENTS" "$MINIO_BUCKET_MEDIA" "$MINIO_PAYMENT_PROOF_BUCKET"; do
  docker run --rm \
    --network "$MINIO_NETWORK" \
    --entrypoint /bin/sh \
    -e MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY" \
    -e MINIO_SECRET_KEY="$MINIO_SECRET_KEY" \
    -e BUCKET="$bucket" \
    minio/mc \
    -lc '
      mc alias set local http://fiers-minio:9000 "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null || exit 1
      mc find "local/$BUCKET" | while IFS= read -r obj; do
        key="${obj#local/$BUCKET/}"
        case "$key" in
          admin/*|admins/*|system/*|config/*)
            continue
            ;;
        esac
        mc rm --force "$obj" >/dev/null 2>&1 || true
      done
    '
  echo "[minio] bucket '$bucket' cleaned (objects only, admin/system prefixes preserved)"
done

echo "[5/5] Integrity checks..."
docker compose exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 <<'SQL'
SELECT
  COUNT(*) FILTER (WHERE role = 'ADMIN') AS admin_users,
  COUNT(*) FILTER (WHERE role <> 'ADMIN') AS non_admin_users
FROM public.users;

SELECT 'subscriptions' AS table_name, COUNT(*) AS rows FROM public.subscriptions
UNION ALL
SELECT 'payments', COUNT(*) FROM public.payments
UNION ALL
SELECT 'payment_manual', COUNT(*) FROM public.payment_manual
UNION ALL
SELECT 'payment_proof', COUNT(*) FROM public.payment_proof
UNION ALL
SELECT 'reviews', COUNT(*) FROM public.reviews;
SQL

docker compose exec -T \
  -e MONGO_USER \
  -e MONGO_PASSWORD \
  -e MONGO_DB \
  mongodb \
  mongosh --nodb --quiet <<'JS'
const requiredEnv = ['MONGO_USER', 'MONGO_PASSWORD', 'MONGO_DB'];
for (const key of requiredEnv) {
  if (!process.env[key]) {
    throw new Error(`${key} is not set`);
  }
}

const mongoUser = encodeURIComponent(process.env.MONGO_USER);
const mongoPassword = encodeURIComponent(process.env.MONGO_PASSWORD);
const mongoDbName = process.env.MONGO_DB;
const appDb = new Mongo(`mongodb://${mongoUser}:${mongoPassword}@127.0.0.1:27017/?authSource=admin`).getDB(mongoDbName);

const targets = ['messages','conversations','notifications','activity_logs','portfolio_items','media_files'];
for (const name of targets) {
  const count = appDb.getCollectionNames().includes(name) ? appDb.getCollection(name).countDocuments({}) : -1;
  print(`[mongo-check] ${name}: ${count >= 0 ? count : 'not found'}`);
}
JS

redis_dbsize="$(REDISCLI_AUTH="$REDIS_PASSWORD" docker compose exec -T -e REDISCLI_AUTH redis redis-cli DBSIZE)"
echo "[redis-check] dbsize=$redis_dbsize"

if [[ -n "$ENV_CHECKSUM_TOOL" && ${#PRESENT_ENV_FILES[@]} -gt 0 ]]; then
  POST_ENV_CHECKSUMS="$(capture_env_checksums || true)"
  if [[ "$PRE_ENV_CHECKSUMS" != "$POST_ENV_CHECKSUMS" ]]; then
    echo "[CRITICAL] .env integrity check failed: environment files changed during execution." >&2
    exit 1
  fi
  echo "[env-check] .env files unchanged."
fi

echo "[DONE] Clean data reset completed without altering schema/architecture."
