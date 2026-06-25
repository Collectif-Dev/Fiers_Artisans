#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_DIR="$REPO_ROOT/infrastructure"
ENV_FILES=("$REPO_ROOT/.env" "$INFRA_DIR/.env")
COMPOSE_FILES=(
  "$INFRA_DIR/docker-compose.yml"
  "$INFRA_DIR/docker-compose.dev.yml"
  "$INFRA_DIR/docker-compose.portainer.yml"
)
COMPOSE_ARGS=()

MODE="dry-run"
INITIAL_NODE_ENV="${NODE_ENV:-}"
INITIAL_APP_ENV="${APP_ENV:-}"
INITIAL_ENVIRONMENT="${ENVIRONMENT:-}"
INITIAL_STAGE="${STAGE:-}"

usage() {
  cat <<'EOF'
Usage:
  infrastructure/scripts/reset_clean_environment.sh                # dry-run (default)
  infrastructure/scripts/reset_clean_environment.sh --dry-run
  infrastructure/scripts/reset_clean_environment.sh --execute      # asks for confirmation phrase
  infrastructure/scripts/reset_clean_environment.sh --guide

What it does (execute mode):
  - PostgreSQL: purge business data while preserving schema/migrations/static refs/admin users
  - MongoDB: purge app dynamic collections but keep documents linked to admin users
  - Redis: delete only known Fiers Artisans runtime key prefixes
  - MinIO: delete user objects inside buckets while preserving admin/system prefixes and admin media objects

What it never does:
  - DROP DATABASE / DROP SCHEMA / DROP TABLE
  - migration/schema/policy/index/function deletion
  - env/secrets/server config changes (.env checksums verified)
EOF
}

guide() {
  cat <<'EOF'
Guide: reset_clean_environment.sh
=================================

Role
----
Reset dynamic development data for Fiers Artisans while preserving:
  - database schema and migrations
  - static category references
  - PostgreSQL users with role='ADMIN'
  - MongoDB documents linked to admin users when the schema contains a user reference
  - MinIO admin/system prefixes and MinIO objects referenced by admin media metadata

Default mode
------------
Running the script without arguments is a dry-run:

  infrastructure/scripts/reset_clean_environment.sh
  infrastructure/scripts/reset_clean_environment.sh --dry-run

The dry-run prints the reset plan and deletes nothing.

Execute mode
------------
Execute mode is destructive and intentionally requires both:

  1) an explicit environment variable
  2) an interactive confirmation phrase

Example:

  RESET_CLEAN_ENVIRONMENT_ALLOWED=true \
    infrastructure/scripts/reset_clean_environment.sh --execute

Then type exactly:

  RESET-OK

Production guard
----------------
The script refuses to run in production-like environments when one of these
variables is set to "production" or "prod":

  NODE_ENV, APP_ENV, ENVIRONMENT, STAGE

There is no --yes bypass. This is intentional.

Preflight
---------
Before deleting anything, execute mode verifies:

  - required Docker Compose services are running
  - PostgreSQL is reachable and required tables exist
  - MongoDB credentials work
  - Redis responds to PING
  - MinIO is reachable
  - buckets exist or are at least queryable
  - the pinned minio/mc client image can run
  - .env checksums are captured

Redis policy
------------
The script does not use FLUSHALL. It deletes only these known app prefixes:

  otp:*
  auth:pin:*
  PAYMENT_UPLOAD:*
  PAYMENT_SUBMIT_THROTTLE:*

MinIO policy
------------
The script processes these buckets:

  portfolio, documents, media, payment-proofs, profiles

It preserves:

  admin/*, admins/*, system/*, config/*
  objects referenced by admin-owned media_files metadata

Stop conditions
---------------
If a preflight check fails, no purge starts.
If a purge step fails after destructive work has started, stop immediately and
inspect the printed step. Cross-service reset cannot be truly transactional,
so do not run this script without a backup when data matters.
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
    --guide)
      MODE="guide"
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

if [[ "$MODE" == "guide" ]]; then
  guide
  exit 0
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "[ERROR] docker is required." >&2
  exit 1
fi

if [[ ! -d "$INFRA_DIR" ]]; then
  echo "[ERROR] infrastructure directory not found: $INFRA_DIR" >&2
  exit 1
fi

trim_env_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_env_file() {
  local env_file="$1"
  local line key value first_char last_char
  local line_number=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    line="${line#"${line%%[![:space:]]*}"}"

    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == export[[:space:]]* ]]; then
      line="${line#export}"
      line="${line#"${line%%[![:space:]]*}"}"
    fi

    if [[ ! "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      echo "[ERROR] Invalid active .env line in $env_file:$line_number" >&2
      echo "        Comment command examples with # before running this script." >&2
      exit 1
    fi

    key="${BASH_REMATCH[1]}"
    value="$(trim_env_value "${BASH_REMATCH[2]}")"

    if [[ "$key" == "RESET_CLEAN_ENVIRONMENT_ALLOWED" ]]; then
      echo "[ERROR] RESET_CLEAN_ENVIRONMENT_ALLOWED must not be stored in $env_file:$line_number." >&2
      echo "        Pass it inline only for a single --execute command." >&2
      exit 1
    fi

    case "$key" in
      BASH_ENV|ENV|SHELLOPTS|BASHOPTS|SHLVL|PATH|CDPATH|GLOBIGNORE|PROMPT_COMMAND|PS4)
        continue
        ;;
    esac

    first_char="${value:0:1}"
    last_char="${value: -1}"
    if [[ "$first_char" == '"' && "$last_char" == '"' ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$first_char" == "'" && "$last_char" == "'" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == *[[:space:]]* ]]; then
      echo "[ERROR] Unquoted whitespace in .env value at $env_file:$line_number ($key)." >&2
      echo "        Quote the value or comment the line." >&2
      exit 1
    fi

    export "$key=$value"
  done < "$env_file"
}

PRESENT_ENV_FILES=()
for env_file in "${ENV_FILES[@]}"; do
  if [[ -f "$env_file" ]]; then
    PRESENT_ENV_FILES+=("$env_file")
    load_env_file "$env_file"
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

init_compose_args() {
  COMPOSE_ARGS=()
  if [[ -f "$REPO_ROOT/.env" ]]; then
    COMPOSE_ARGS+=(--env-file "$REPO_ROOT/.env")
  fi

  local compose_file
  for compose_file in "${COMPOSE_FILES[@]}"; do
    if [[ -f "$compose_file" ]]; then
      COMPOSE_ARGS+=(-f "$compose_file")
    fi
  done
}

docker_compose() {
  docker compose "${COMPOSE_ARGS[@]}" "$@"
}

init_compose_args

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
: "${MINIO_PROFILES_BUCKET:=profiles}"
: "${MINIO_MC_IMAGE:=minio/mc@sha256:a7fe349ef4bd8521fb8497f55c6042871b2ae640607cf99d9bede5e9bdf11727}"

PRESERVED_MINIO_OBJECTS_FILE=""
MINIO_NETWORK=""
ADMIN_USER_IDS_JSON="[]"

cleanup() {
  if [[ -n "$PRESERVED_MINIO_OBJECTS_FILE" && -f "$PRESERVED_MINIO_OBJECTS_FILE" ]]; then
    rm -f "$PRESERVED_MINIO_OBJECTS_FILE"
  fi
}
trap cleanup EXIT

REDIS_RESET_PATTERNS=(
  'otp:*'
  'auth:pin:*'
  'PAYMENT_UPLOAD:*'
  'PAYMENT_SUBMIT_THROTTLE:*'
)

MINIO_RESET_BUCKETS=(
  "$MINIO_BUCKET_PORTFOLIO"
  "$MINIO_BUCKET_DOCUMENTS"
  "$MINIO_BUCKET_MEDIA"
  "$MINIO_PAYMENT_PROOF_BUCKET"
  "$MINIO_PROFILES_BUCKET"
)

lowercase() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

require_execute_safety() {
  local env_name
  local env_value
  for env_name in NODE_ENV APP_ENV ENVIRONMENT STAGE; do
    env_value="$(lowercase "${!env_name:-}")"
    if [[ "$env_value" == "production" || "$env_value" == "prod" ]]; then
      echo "[ERROR] Refusing destructive reset because ${env_name}=${!env_name}." >&2
      exit 1
    fi
  done

  local initial_env_values=(
    "NODE_ENV=$INITIAL_NODE_ENV"
    "APP_ENV=$INITIAL_APP_ENV"
    "ENVIRONMENT=$INITIAL_ENVIRONMENT"
    "STAGE=$INITIAL_STAGE"
  )
  local pair
  for pair in "${initial_env_values[@]}"; do
    env_name="${pair%%=*}"
    env_value="$(lowercase "${pair#*=}")"
    if [[ "$env_value" == "production" || "$env_value" == "prod" ]]; then
      echo "[ERROR] Refusing destructive reset because initial ${env_name}=${pair#*=}." >&2
      exit 1
    fi
  done

  if [[ "${RESET_CLEAN_ENVIRONMENT_ALLOWED:-}" != "true" ]]; then
    cat >&2 <<'EOF'
[ERROR] Destructive reset is locked.
Set RESET_CLEAN_ENVIRONMENT_ALLOWED=true for this command only, then rerun --execute.
Example:
  RESET_CLEAN_ENVIRONMENT_ALLOWED=true infrastructure/scripts/reset_clean_environment.sh --execute
EOF
    exit 1
  fi
}

run_postgres_preflight() {
  local missing_tables
  docker_compose exec -T postgres \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 <<'SQL' >/dev/null
SELECT 1;
SQL

  missing_tables="$(
    docker_compose exec -T postgres \
      psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -At <<'SQL'
WITH required(name) AS (
  VALUES
    ('users'),
    ('subscriptions'),
    ('payments'),
    ('payment_manual'),
    ('payment_proof'),
    ('reviews')
)
SELECT name
FROM required
WHERE to_regclass(format('public.%I', name)) IS NULL;
SQL
  )"

  if [[ -n "$missing_tables" ]]; then
    echo "[ERROR] PostgreSQL required table(s) missing:" >&2
    printf '%s\n' "$missing_tables" >&2
    exit 1
  fi
}

load_admin_user_ids() {
  ADMIN_USER_IDS_JSON="$(
    docker_compose exec -T postgres \
      psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -Atc \
        "SELECT COALESCE(json_agg(id::text), '[]'::json)::text FROM public.users WHERE role = 'ADMIN';"
  )"

  if [[ -z "$ADMIN_USER_IDS_JSON" ]]; then
    ADMIN_USER_IDS_JSON="[]"
  fi
}

run_mongo_preflight() {
  if [[ -z "${MONGO_PASSWORD:-}" ]]; then
    echo "[ERROR] MONGO_PASSWORD is not set in environment/.env" >&2
    exit 1
  fi

  export MONGO_USER MONGO_PASSWORD MONGO_DB
  docker_compose exec -T \
    -e MONGO_USER \
    -e MONGO_PASSWORD \
    -e MONGO_DB \
    mongodb \
    mongosh --nodb --quiet <<'JS' >/dev/null
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
appDb.getCollectionNames();
JS
}

run_redis_preflight() {
  if [[ -z "${REDIS_PASSWORD:-}" ]]; then
    echo "[ERROR] REDIS_PASSWORD is not set in environment/.env" >&2
    exit 1
  fi

  REDISCLI_AUTH="$REDIS_PASSWORD" docker_compose exec -T -e REDISCLI_AUTH redis \
    redis-cli PING >/dev/null
}

resolve_minio_network() {
  local minio_container_id
  minio_container_id="$(docker_compose ps -q minio)"
  if [[ -z "$minio_container_id" ]]; then
    echo "[ERROR] Could not resolve running minio container id." >&2
    exit 1
  fi

  MINIO_NETWORK="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$minio_container_id" | head -n 1 | tr -d '[:space:]')"
  if [[ -z "$MINIO_NETWORK" ]]; then
    echo "[ERROR] Could not resolve minio container network." >&2
    exit 1
  fi
}

run_minio_preflight() {
  if [[ -z "${MINIO_ACCESS_KEY:-}" || -z "${MINIO_SECRET_KEY:-}" ]]; then
    echo "[ERROR] MINIO_ACCESS_KEY / MINIO_SECRET_KEY must be set in environment/.env" >&2
    exit 1
  fi

  resolve_minio_network

  local bucket
  for bucket in "${MINIO_RESET_BUCKETS[@]}"; do
    docker run --rm \
      --network "$MINIO_NETWORK" \
      --entrypoint /bin/sh \
      -e MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY" \
      -e MINIO_SECRET_KEY="$MINIO_SECRET_KEY" \
      -e BUCKET="$bucket" \
      "$MINIO_MC_IMAGE" \
      -lc '
        set -eu
        mc alias set local http://fiers-minio:9000 "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null
        mc ls "local/$BUCKET" >/dev/null
      ' >/dev/null
  done
}

build_preserved_minio_objects_file() {
  PRESERVED_MINIO_OBJECTS_FILE="$(mktemp)"

  export MONGO_USER MONGO_PASSWORD MONGO_DB ADMIN_USER_IDS_JSON
  docker_compose exec -T \
    -e MONGO_USER \
    -e MONGO_PASSWORD \
    -e MONGO_DB \
    -e ADMIN_USER_IDS_JSON \
    mongodb \
    mongosh --nodb --quiet <<'JS' > "$PRESERVED_MINIO_OBJECTS_FILE"
const requiredEnv = ['MONGO_USER', 'MONGO_PASSWORD', 'MONGO_DB', 'ADMIN_USER_IDS_JSON'];
for (const key of requiredEnv) {
  if (!process.env[key]) {
    throw new Error(`${key} is not set`);
  }
}

const adminIds = JSON.parse(process.env.ADMIN_USER_IDS_JSON);
if (!Array.isArray(adminIds)) {
  throw new Error('ADMIN_USER_IDS_JSON must be an array');
}

const mongoUser = encodeURIComponent(process.env.MONGO_USER);
const mongoPassword = encodeURIComponent(process.env.MONGO_PASSWORD);
const mongoDbName = process.env.MONGO_DB;
const appDb = new Mongo(`mongodb://${mongoUser}:${mongoPassword}@127.0.0.1:27017/?authSource=admin`).getDB(mongoDbName);

if (adminIds.length === 0 || !appDb.getCollectionNames().includes('media_files')) {
  quit(0);
}

appDb.media_files
  .find({ userId: { $in: adminIds } }, { bucket: 1, objectKey: 1, thumbnailKey: 1 })
  .forEach((doc) => {
    if (doc.bucket && doc.objectKey) {
      print(`${doc.bucket}/${doc.objectKey}`);
    }
    if (doc.bucket && doc.thumbnailKey) {
      print(`${doc.bucket}/${doc.thumbnailKey}`);
    }
  });
JS
}

run_preflight() {
  echo "[preflight] Checking services..."
  local required_services=(postgres mongodb redis minio)
  local running_services
  if ! running_services="$(docker_compose ps --services --status running)"; then
    echo "[ERROR] Could not inspect Docker Compose services." >&2
    exit 1
  fi
  local svc
  for svc in "${required_services[@]}"; do
    if ! grep -qx "$svc" <<<"$running_services"; then
      echo "[ERROR] Service '$svc' is not running. Start stack first with docker compose, then rerun this script." >&2
      exit 1
    fi
  done

  echo "[preflight] Checking PostgreSQL..."
  run_postgres_preflight
  load_admin_user_ids

  echo "[preflight] Checking MongoDB..."
  run_mongo_preflight
  build_preserved_minio_objects_file

  echo "[preflight] Checking Redis..."
  run_redis_preflight

  echo "[preflight] Checking MinIO..."
  run_minio_preflight

  echo "[preflight] All destructive prerequisites passed."
}

if [[ "$MODE" == "dry-run" ]]; then
  cat <<EOF
[DRY-RUN] Reset plan (no data deleted):
  1) PostgreSQL (service: postgres)
     - Preserve tables: migrations, typeorm_metadata, categories, subcategories, users, spatial_ref_sys
     - Truncate all other public tables with RESTART IDENTITY CASCADE
      - Keep only users where role='ADMIN' (no admin profile field wipe)

  2) MongoDB (service: mongodb, db: $MONGO_DB)
      - deleteMany(non-admin-linked documents) on collections:
       messages, conversations, notifications, activity_logs, portfolio_items, media_files

  3) Redis (service: redis)
     - Delete only known Fiers Artisans runtime key prefixes:
       ${REDIS_RESET_PATTERNS[*]}

  4) MinIO (service: minio)
      - Remove user objects only (keep bucket structure, admin/system prefixes, admin media refs):
       ${MINIO_RESET_BUCKETS[*]}

Requirements before --execute:
  - Docker Compose stack running for this project
  - RESET_CLEAN_ENVIRONMENT_ALLOWED=true
  - explicit destructive confirmation phrase
EOF
  exit 0
fi

cd "$INFRA_DIR"

PRE_ENV_CHECKSUMS="$(capture_env_checksums)"

require_execute_safety
run_preflight

echo "[SAFEGUARD] This will purge dynamic data across PostgreSQL, MongoDB, Redis and MinIO."
echo "[SAFEGUARD] Admin users and admin-linked Mongo/MinIO data will be preserved where the schema allows it."
echo "Type exactly: RESET-OK"
read -r CONFIRM
if [[ "$CONFIRM" != "RESET-OK" ]]; then
  echo "[ABORT] Confirmation phrase mismatch."
  exit 1
fi

echo "[1/5] PostgreSQL purge..."
docker_compose exec -T postgres \
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
export MONGO_USER MONGO_PASSWORD MONGO_DB ADMIN_USER_IDS_JSON
docker_compose exec -T \
  -e MONGO_USER \
  -e MONGO_PASSWORD \
  -e MONGO_DB \
  -e ADMIN_USER_IDS_JSON \
  mongodb \
  mongosh --nodb --quiet <<'JS'
const requiredEnv = ['MONGO_USER', 'MONGO_PASSWORD', 'MONGO_DB', 'ADMIN_USER_IDS_JSON'];
for (const key of requiredEnv) {
  if (!process.env[key]) {
    throw new Error(`${key} is not set`);
  }
}

const adminIds = JSON.parse(process.env.ADMIN_USER_IDS_JSON);
if (!Array.isArray(adminIds)) {
  throw new Error('ADMIN_USER_IDS_JSON must be an array');
}

const mongoUser = encodeURIComponent(process.env.MONGO_USER);
const mongoPassword = encodeURIComponent(process.env.MONGO_PASSWORD);
const mongoDbName = process.env.MONGO_DB;
const appDb = new Mongo(`mongodb://${mongoUser}:${mongoPassword}@127.0.0.1:27017/?authSource=admin`).getDB(mongoDbName);

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

const purgeFilters = {
  messages: {
    $and: [
      { senderId: { $nin: adminIds } },
      { $nor: adminMarkers },
    ],
  },
  conversations: {
    $and: [
      { participants: { $nin: adminIds } },
      { $nor: adminMarkers },
    ],
  },
  notifications: {
    $and: [
      { userId: { $nin: adminIds } },
      { $nor: adminMarkers },
    ],
  },
  activity_logs: {
    $and: [
      { actorId: { $nin: adminIds } },
      { targetId: { $nin: adminIds } },
      { $nor: adminMarkers },
    ],
  },
  portfolio_items: {
    $nor: adminMarkers,
  },
  media_files: {
    $and: [
      { userId: { $nin: adminIds } },
      { $nor: adminMarkers },
    ],
  },
};

const existing = new Set(appDb.getCollectionNames());
for (const [name, filter] of Object.entries(purgeFilters)) {
  if (!existing.has(name)) {
    print(`[mongo] ${name}: not found`);
    continue;
  }
  const result = appDb.getCollection(name).deleteMany(filter);
  print(`[mongo] ${name}: ${result.deletedCount} deleted`);
}
JS

echo "[3/5] Redis purge..."
purge_redis_pattern() {
  local pattern="$1"
  local deleted=0
  local -a batch=()
  local key
  local keys_file

  keys_file="$(mktemp)"
  if ! REDISCLI_AUTH="$REDIS_PASSWORD" docker_compose exec -T -e REDISCLI_AUTH redis \
    redis-cli --scan --pattern "$pattern" > "$keys_file"; then
    rm -f "$keys_file"
    return 1
  fi

  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    batch+=("$key")
    if (( ${#batch[@]} >= 100 )); then
      if ! REDISCLI_AUTH="$REDIS_PASSWORD" docker_compose exec -T -e REDISCLI_AUTH redis \
        redis-cli DEL "${batch[@]}" >/dev/null; then
        rm -f "$keys_file"
        return 1
      fi
      deleted=$((deleted + ${#batch[@]}))
      batch=()
    fi
  done < "$keys_file"
  rm -f "$keys_file"

  if (( ${#batch[@]} > 0 )); then
    if ! REDISCLI_AUTH="$REDIS_PASSWORD" docker_compose exec -T -e REDISCLI_AUTH redis \
      redis-cli DEL "${batch[@]}" >/dev/null; then
      return 1
    fi
    deleted=$((deleted + ${#batch[@]}))
  fi

  echo "[redis] pattern '$pattern': $deleted key(s) deleted"
}

for pattern in "${REDIS_RESET_PATTERNS[@]}"; do
  purge_redis_pattern "$pattern"
done

echo "[4/5] MinIO object purge (bucket structures preserved)..."
for bucket in "${MINIO_RESET_BUCKETS[@]}"; do
  docker run --rm \
    --network "$MINIO_NETWORK" \
    --entrypoint /bin/sh \
    -v "$PRESERVED_MINIO_OBJECTS_FILE:/tmp/preserved-minio-objects:ro" \
    -e MINIO_ACCESS_KEY="$MINIO_ACCESS_KEY" \
    -e MINIO_SECRET_KEY="$MINIO_SECRET_KEY" \
    -e BUCKET="$bucket" \
    "$MINIO_MC_IMAGE" \
    -lc '
      set -eu
      mc alias set local http://fiers-minio:9000 "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null || exit 1
      mc find "local/$BUCKET" > /tmp/minio-objects
      is_preserved_object() {
        candidate="$1"
        while IFS= read -r preserved; do
          [ "$preserved" = "$candidate" ] && return 0
        done < /tmp/preserved-minio-objects
        return 1
      }
      while IFS= read -r obj; do
        key="${obj#local/$BUCKET/}"
        case "$key" in
          admin/*|admins/*|system/*|config/*)
            continue
            ;;
        esac
        if is_preserved_object "$BUCKET/$key"; then
          continue
        fi
        mc rm --force "$obj" >/dev/null
      done < /tmp/minio-objects
    '
  echo "[minio] bucket '$bucket' cleaned (admin/system prefixes and admin media refs preserved)"
done

echo "[5/5] Integrity checks..."
docker_compose exec -T postgres \
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

docker_compose exec -T \
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

redis_dbsize="$(REDISCLI_AUTH="$REDIS_PASSWORD" docker_compose exec -T -e REDISCLI_AUTH redis redis-cli DBSIZE)"
echo "[redis-check] dbsize=$redis_dbsize"

if [[ -n "$ENV_CHECKSUM_TOOL" && ${#PRESENT_ENV_FILES[@]} -gt 0 ]]; then
  POST_ENV_CHECKSUMS="$(capture_env_checksums)"
  if [[ "$PRE_ENV_CHECKSUMS" != "$POST_ENV_CHECKSUMS" ]]; then
    echo "[CRITICAL] .env integrity check failed: environment files changed during execution." >&2
    exit 1
  fi
  echo "[env-check] .env files unchanged."
fi

echo "[DONE] Clean data reset completed without altering schema/architecture."
