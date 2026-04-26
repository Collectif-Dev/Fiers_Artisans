#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RAW_FILE="${ROOT_DIR}/tmp.stack.portainer.raw.yml"
OUT_FILE="${ROOT_DIR}/infrastructure/stack.portainer-managed.yml"

cd "${ROOT_DIR}"

docker compose \
  --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  config > "${RAW_FILE}"

awk '
BEGIN {
  in_services=0; in_networks=0; in_volumes=0;
  current_service="";
  skip_build=0; skip_portainer=0;
  skip_default_network=0; skip_portainer_volume=0;
}
{
  line=$0;

  if (line ~ /^services:$/) { in_services=1; in_networks=0; in_volumes=0; print line; next }
  if (line ~ /^networks:$/) { in_services=0; in_networks=1; in_volumes=0; print line; next }
  if (line ~ /^volumes:$/) { in_services=0; in_networks=0; in_volumes=1; print line; next }
  if (line ~ /^[^ ]/ && line !~ /^(services|networks|volumes):$/) { in_services=0; in_networks=0; in_volumes=0 }

  if (in_networks && line ~ /^  default:$/) { skip_default_network=1; next }
  if (skip_default_network) {
    if (line ~ /^  [^ ]/) { skip_default_network=0 } else { next }
  }

  if (in_volumes && line ~ /^  portainer_data:$/) { skip_portainer_volume=1; next }
  if (skip_portainer_volume) {
    if (line ~ /^  [^ ]/) { skip_portainer_volume=0 } else { next }
  }

  if (in_services && line ~ /^  [^ ]/) {
    current_service=line;
    sub(/^  /, "", current_service);
    sub(/:.*/, "", current_service);
    if (current_service == "portainer") { skip_portainer=1; next }
  }

  if (skip_portainer) {
    if (line ~ /^  [^ ]/) {
      current_service=line;
      sub(/^  /, "", current_service);
      sub(/:.*/, "", current_service);
      skip_portainer=0;
    } else {
      next
    }
  }

  if ((current_service == "api" || current_service == "admin-web") && line ~ /^    build:$/) {
    if (current_service == "api") {
      print "    image: infrastructure-api";
    } else {
      print "    image: infrastructure-admin-web";
    }
    skip_build=1;
    next;
  }

  if (skip_build) {
    if (line ~ /^    [^ ]/) {
      skip_build=0;
    } else {
      next;
    }
  }

  print line;
}
' "${RAW_FILE}" > "${OUT_FILE}"

docker compose -f "${OUT_FILE}" config > /dev/null
rm -f "${RAW_FILE}"

echo "Generated: ${OUT_FILE}"
