#!/usr/bin/env bash
# Deploiement Compose prod-like pour Fiers Artisans.
#
# Variables configurables:
#   DEPLOY_DIR=/opt/fiers-artisans
#   ENV_FILE=.env
#   COMPOSE_FILE=infrastructure/docker-compose.yml
#   ADMIN_PUBLIC_URL=https://admin.example.com/
#   API_HEALTH_URL=https://api.example.com/health
#
# Exemple:
#   DEPLOY_DIR=/opt/fiers-artisans ENV_FILE=.env ./infrastructure/scripts/deploy.sh

set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/opt/fiers-artisans}"
ENV_FILE="${ENV_FILE:-.env}"
COMPOSE_FILE="${COMPOSE_FILE:-infrastructure/docker-compose.yml}"
ADMIN_PUBLIC_URL="${ADMIN_PUBLIC_URL:-https://admin.example.com/}"
API_HEALTH_URL="${API_HEALTH_URL:-https://api.example.com/health}"

echo "Deploiement Fiers Artisans..."

cd "${DEPLOY_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Fichier env introuvable: ${DEPLOY_DIR}/${ENV_FILE}"
  echo "Copiez .env.example vers ${ENV_FILE}, puis renseignez les secrets reels."
  exit 1
fi

# Pull les dernières images
echo "Pull des images..."
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" pull

# Build backend + admin web
echo "Build backend + admin web..."
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" build api admin-web

# Restart applicatif avec ordre contrôlé
echo "Restart des services applicatifs..."
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --no-deps api admin-web
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d nginx

# Cleanup
echo "Nettoyage des anciennes images..."
docker image prune -f

echo "Deploiement termine."
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
echo "Liens utiles :"
echo "   - Admin web : ${ADMIN_PUBLIC_URL}"
echo "   - API health: ${API_HEALTH_URL}"
echo "Logs utiles :"
echo "   docker compose --env-file ${ENV_FILE} -f ${COMPOSE_FILE} logs -f api admin-web nginx"
