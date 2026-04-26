#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
# Fiers Artisans — Script de déploiement
# ══════════════════════════════════════════════════════════════════════

set -euo pipefail

echo "🚀 Déploiement Fiers Artisans..."

cd /opt/fierartisans

# Pull les dernières images
echo "📦 Pull des images..."
docker compose -f infrastructure/docker-compose.yml pull

# Build backend + admin web
echo "🔨 Build backend + admin web..."
docker compose -f infrastructure/docker-compose.yml build api admin-web

# Restart applicatif avec ordre contrôlé
echo "🔄 Restart des services applicatifs..."
docker compose -f infrastructure/docker-compose.yml up -d --no-deps api admin-web
docker compose -f infrastructure/docker-compose.yml up -d nginx

# Cleanup
echo "🧹 Nettoyage des anciennes images..."
docker image prune -f

echo "✅ Déploiement terminé !"
docker compose -f infrastructure/docker-compose.yml ps
echo "📍 Liens utiles :"
echo "   - Admin web : https://admin.fierartisans.ci/"
echo "   - API health: https://api.fierartisans.ci/health"
echo "🧾 Logs utiles :"
echo "   docker compose -f infrastructure/docker-compose.yml logs -f api admin-web nginx"
