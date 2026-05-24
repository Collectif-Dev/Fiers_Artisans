#!/usr/bin/env bash
set -euo pipefail

# Safe Docker cleanup helper for the Fiers Artisans stack.
# It removes containers/images/cache/networks, but never named volumes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_DIR="$REPO_ROOT/infrastructure"
ROOT_ENV_FILE="$REPO_ROOT/.env"

BASE_COMPOSE="$INFRA_DIR/docker-compose.yml"
DEV_COMPOSE="$INFRA_DIR/docker-compose.dev.yml"
PORTAINER_COMPOSE="$INFRA_DIR/docker-compose.portainer.yml"

PRUNE_ALL=false

COMPOSE_FILES=()
COMPOSE_ARGS=()

PRESERVED_VOLUMES=(
  postgres_data
  mongo_data
  redis_data
  minio_data
  grafana_data
  prometheus_data
  portainer_data
)

MANAGED_SERVICES=(
  api
  admin-web
  postgres
  mongodb
  redis
  minio
  prometheus
  grafana
  portainer
  nginx
)

MANAGED_CONTAINERS=(
  fiers-api
  fiers-admin-web
  fiers-postgres
  fiers-mongodb
  fiers-redis
  fiers-minio
  fiers-prometheus
  fiers-grafana
  fiers-portainer
  fiers-nginx
)

if [[ -t 1 ]]; then
  COLOR_RESET=$'\033[0m'
  COLOR_GREEN=$'\033[0;32m'
  COLOR_YELLOW=$'\033[0;33m'
  COLOR_BLUE=$'\033[0;34m'
  COLOR_RED=$'\033[0;31m'
else
  COLOR_RESET=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_BLUE=""
  COLOR_RED=""
fi

usage() {
  cat <<'EOF'
Usage:
  infrastructure/scripts/clean-docker.sh
  infrastructure/scripts/clean-docker.sh --all

Options:
  --all       Nettoyage agressif des images inutilisees et du build cache.
              Les volumes ne sont jamais supprimes.
  -h, --help  Affiche cette aide.
EOF
}

log_info() {
  printf '%b[INFO]%b %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$*"
}

log_success() {
  printf '%b[OK]%b %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"
}

log_warn() {
  printf '%b[WARN]%b %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*"
}

log_error() {
  printf '%b[ERROR]%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
}

die() {
  log_error "$1"
  exit 1
}

count_lines() {
  local input="${1:-}"

  if [[ -z "$input" ]]; then
    printf '0'
    return
  fi

  awk 'NF { count++ } END { print count + 0 }' <<<"$input"
}

join_by() {
  local delimiter="$1"
  shift || true

  local output=""
  local item
  for item in "$@"; do
    if [[ -n "$output" ]]; then
      output+="$delimiter"
    fi
    output+="$item"
  done

  printf '%s' "$output"
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "docker est requis."
  docker compose version >/dev/null 2>&1 || die "docker compose est requis."
  docker info >/dev/null 2>&1 || die "Le daemon docker est inaccessible."
}

discover_compose_files() {
  [[ -f "$BASE_COMPOSE" ]] || die "Fichier compose requis introuvable : $BASE_COMPOSE"

  COMPOSE_FILES=("$BASE_COMPOSE")
  [[ -f "$DEV_COMPOSE" ]] && COMPOSE_FILES+=("$DEV_COMPOSE")
  [[ -f "$PORTAINER_COMPOSE" ]] && COMPOSE_FILES+=("$PORTAINER_COMPOSE")

  COMPOSE_ARGS=()
  if [[ -f "$ROOT_ENV_FILE" ]]; then
    COMPOSE_ARGS+=(--env-file "$ROOT_ENV_FILE")
  fi

  local compose_file
  for compose_file in "${COMPOSE_FILES[@]}"; do
    COMPOSE_ARGS+=(-f "$compose_file")
  done
}

docker_compose() {
  # Keep the prod-only profile visible so nginx is still part of the stack model
  # when docker-compose.dev.yml is present.
  local compose_profiles="prod-only"

  if [[ -n "${COMPOSE_PROFILES:-}" ]]; then
    compose_profiles="${COMPOSE_PROFILES},${compose_profiles}"
  fi

  (
    cd "$REPO_ROOT"
    COMPOSE_PROFILES="$compose_profiles" docker compose "${COMPOSE_ARGS[@]}" "$@"
  )
}

list_running_managed_containers() {
  local docker_ps_output
  docker_ps_output="$(docker ps --format '{{.Names}}')"

  local container_name
  for container_name in "${MANAGED_CONTAINERS[@]}"; do
    if grep -Fxq "$container_name" <<<"$docker_ps_output"; then
      printf '%s\n' "$container_name"
    fi
  done
}

list_stopped_containers() {
  docker ps -aq \
    --filter status=created \
    --filter status=exited \
    --filter status=dead | sort -u
}

list_dangling_images() {
  docker image ls -q --filter dangling=true | sort -u
}

list_unused_images_after_container_prune() {
  local -a active_containers=()
  mapfile -t active_containers < <(
    docker ps -aq
  )

  if (( ${#active_containers[@]} == 0 )); then
    docker image ls -aq --no-trunc | sort -u
    return
  fi

  comm -23 \
    <(docker image ls -aq --no-trunc | sort -u) \
    <(docker inspect --format '{{.Image}}' "${active_containers[@]}" | sort -u)
}

list_orphan_networks() {
  docker network ls -q --filter dangling=true | sort -u
}

list_dangling_anonymous_volumes() {
  docker volume ls -q --filter dangling=true | grep -E '^[a-f0-9]{64}$' | sort -u || true
}

get_build_cache_reclaimable() {
  local builder_du_output
  if ! builder_du_output="$(docker builder du 2>/dev/null)"; then
    printf 'n/a'
    return
  fi

  local reclaimable
  reclaimable="$(awk -F':' '/^Reclaimable:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }' <<<"$builder_du_output")"

  if [[ -n "$reclaimable" ]]; then
    printf '%s' "$reclaimable"
  else
    printf 'n/a'
  fi
}

extract_prune_total() {
  local prune_output="${1:-}"

  awk -F'Total:[[:space:]]*' '/Total:/ { print $2 }' <<<"$prune_output" \
    | tail -n 1 \
    | tr -d '\r'
}

prune_build_cache() {
  if docker buildx version >/dev/null 2>&1; then
    if docker buildx prune --all --force 2>&1; then
      return 0
    fi

    log_warn "docker buildx prune a echoue. Bascule sur docker builder prune."
  fi

  docker builder prune -a -f 2>&1
}

maybe_stop_stack() {
  local running_containers
  local running_count
  local response

  running_containers="$(list_running_managed_containers)"
  running_count="$(count_lines "$running_containers")"

  if [[ "$running_count" -eq 0 ]]; then
    log_info "Aucun conteneur Fiers Artisans en cours d'execution."
    return
  fi

  log_warn "Conteneurs Fiers Artisans en cours : $(join_by ', ' ${running_containers//$'\n'/ })"

  if [[ ! -t 0 ]]; then
    log_warn "Session non interactive detectee. La stack reste active ; le nettoyage continue."
    return
  fi

  printf '%b[WARN]%b Arreter la stack maintenant avec docker compose down --remove-orphans ? [y/N] ' \
    "$COLOR_YELLOW" "$COLOR_RESET"
  read -r response

  case "$response" in
    y|Y|yes|YES|o|O|oui|OUI)
      log_info "Arret de la stack Docker Compose sans suppression des volumes..."
      docker_compose down --remove-orphans
      log_success "Stack arretee proprement. Les volumes nommes ont ete preserves."
      ;;
    *)
      log_warn "Stack laissee active. Le nettoyage continue sans docker compose down."
      ;;
  esac
}

print_header() {
  local -a display_files=()
  local compose_file

  for compose_file in "${COMPOSE_FILES[@]}"; do
    display_files+=("${compose_file#$REPO_ROOT/}")
  done

  printf 'Nettoyage Docker - Fiers Artisans\n'
  printf '============================================================\n'
  log_info "Fichiers Compose detectes : $(join_by ', ' "${display_files[@]}")"
  log_info "Services couverts : $(join_by ', ' "${MANAGED_SERVICES[@]}")"

  if [[ "$PRUNE_ALL" == true ]]; then
    log_warn "Mode : --all. Nettoyage agressif des images inutilisees et du build cache."
  else
    log_info "Mode : nettoyage standard securise avec purge complete du build cache."
  fi
}

run_cleanup() {
  local stopped_container_ids=""
  local candidate_image_ids=""
  local orphan_network_ids=""
  local dangling_anonymous_volume_ids=""
  local container_count=0
  local image_count=0
  local network_count=0
  local anonymous_volume_count=0
  local build_cache_value="0B"
  local build_cache_before="n/a"
  local build_cache_after="n/a"
  local builder_output=""

  if [[ "$PRUNE_ALL" == true ]]; then
    candidate_image_ids="$(list_unused_images_after_container_prune)"
  else
    candidate_image_ids="$(list_dangling_images)"
  fi

  stopped_container_ids="$(list_stopped_containers)"
  orphan_network_ids="$(list_orphan_networks)"
  dangling_anonymous_volume_ids="$(list_dangling_anonymous_volumes)"
  build_cache_before="$(get_build_cache_reclaimable)"

  container_count="$(count_lines "$stopped_container_ids")"
  image_count="$(count_lines "$candidate_image_ids")"
  network_count="$(count_lines "$orphan_network_ids")"
  anonymous_volume_count="$(count_lines "$dangling_anonymous_volume_ids")"

  log_info "Suppression des conteneurs arretes..."
  docker container prune -f >/dev/null

  if [[ "$PRUNE_ALL" == true ]]; then
    log_info "Suppression de toutes les images inutilisees..."
    docker image prune -a -f >/dev/null
  else
    log_info "Suppression des images dangling..."
    docker image prune -f >/dev/null
  fi

  log_info "Purge complete du build cache inutilise..."
  builder_output="$(prune_build_cache)"
  build_cache_after="$(get_build_cache_reclaimable)"
  build_cache_value="$(extract_prune_total "$builder_output")"
  if [[ -z "$build_cache_value" ]]; then
    if [[ "$build_cache_before" != "n/a" && "$build_cache_after" == "0B" ]]; then
      build_cache_value="$build_cache_before"
    elif [[ "$build_cache_before" == "$build_cache_after" ]]; then
      build_cache_value="0B"
    else
      build_cache_value="$build_cache_before"
    fi
  fi

  log_info "Suppression des reseaux orphelins..."
  docker network prune -f >/dev/null

  if [[ "$anonymous_volume_count" -gt 0 ]]; then
    log_info "Suppression des volumes anonymes orphelins..."

    local volume_id
    while IFS= read -r volume_id; do
      [[ -n "$volume_id" ]] || continue
      docker volume rm "$volume_id" >/dev/null
    done <<<"$dangling_anonymous_volume_ids"
  else
    log_info "Aucun volume anonyme orphelin a supprimer."
  fi

  if [[ "$build_cache_after" != "n/a" && "$build_cache_after" != "0B" ]]; then
    log_warn "Du build cache subsiste apres nettoyage : $build_cache_after"
  fi

  printf '%s\n' '------------------------------------------------------------'
  printf 'Nettoyage Docker - Fiers Artisans\n'
  printf '============================================================\n'
  printf 'Conteneurs arretes supprimes : %s\n' "$container_count"

  if [[ "$PRUNE_ALL" == true ]]; then
    printf 'Images inutilisees supprimees (--all) : %s\n' "$image_count"
  else
    printf 'Images dangling supprimees : %s\n' "$image_count"
  fi

  printf 'Build cache libere : %s\n' "$build_cache_value"
  printf 'Build cache restant : %s\n' "$build_cache_after"
  printf 'Reseaux orphelins supprimes : %s\n' "$network_count"
  printf 'Volumes anonymes orphelins supprimes : %s\n' "$anonymous_volume_count"
  printf 'Volumes preserves : %s\n' "$(join_by ', ' "${PRESERVED_VOLUMES[@]}")"
  printf '============================================================\n'
  printf 'Nettoyage termine.\n'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        PRUNE_ALL=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage
        die "Option inconnue : $1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  require_docker
  discover_compose_files
  print_header
  maybe_stop_stack
  run_cleanup
}

main "$@"
