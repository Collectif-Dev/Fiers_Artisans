#!/usr/bin/env bash
# Verifie les points de synchronisation les plus sensibles entre backend,
# Flutter, admin-web et configuration d'environnement.
#
# Ce script ne prouve pas que tous les contrats sont parfaits. Il donne un
# controle rapide avant MR pour eviter les oublis classiques: DTO backend sans
# modele Flutter, variable d'environnement ajoutee sans `.env.example`, ou type
# admin manquant.

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "${ROOT_DIR}"

failures=0

require_file() {
  local path="$1"
  local reason="$2"
  if [[ ! -f "${path}" ]]; then
    echo "MANQUANT: ${path} - ${reason}"
    failures=$((failures + 1))
  else
    echo "OK: ${path}"
  fi
}

require_env() {
  local name="$1"
  if ! grep -Eq "^${name}=" .env.example; then
    echo "MANQUANT dans .env.example: ${name}"
    failures=$((failures + 1))
  else
    echo "OK env: ${name}"
  fi
}

echo "Verification des contrats paiement manuel..."
require_file "backend/src/modules/payment-manual/dto/create-payment-manual.dto.ts" "DTO initiation backend"
require_file "backend/src/modules/payment-manual/dto/submit-proof.dto.ts" "DTO preuve backend"
require_file "Fiers Artisans/lib/data/models/manual_payment_model.dart" "modele mobile"
require_file "Fiers Artisans/lib/data/repositories/payment_manual_repository.dart" "repository mobile"
require_file "admin-web/src/types/index.ts" "types admin-web"

echo
echo "Verification des variables critiques..."
require_env "JWT_SECRET"
require_env "JWT_REFRESH_SECRET"
require_env "POSTGRES_PASSWORD"
require_env "MONGO_PASSWORD"
require_env "REDIS_PASSWORD"
require_env "MINIO_SECRET_KEY"
require_env "GRAFANA_ADMIN_PASSWORD"
require_env "PAYMENT_MANUAL_RECIPIENT_ORANGE_MONEY"
require_env "PAYMENT_MANUAL_RECIPIENT_MTN_MOMO"
require_env "PAYMENT_MANUAL_RECIPIENT_WAVE"
require_env "PAYMENT_MANUAL_RECIPIENT_MOOV_MONEY"

echo
if [[ "${failures}" -gt 0 ]]; then
  echo "Verification contrats terminee avec ${failures} probleme(s)."
  exit 1
fi

echo "Verification contrats terminee sans probleme detecte."
