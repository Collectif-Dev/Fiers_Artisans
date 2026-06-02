#!/bin/bash
# =============================================================================
# check-contracts-sync.sh
# Contrôle simple de présence des contrats API entre backend, Flutter et admin-web.
# Usage: ./check-contracts-sync.sh [module]
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_DTOS="${PROJECT_ROOT}/backend/src"
FLUTTER_MODELS="${PROJECT_ROOT}/fiers_artisans_app/lib"
ADMIN_TYPES="${PROJECT_ROOT}/admin-web/src"

log() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC}  $1"; }
info() { echo -e "   $1"; }

modules=("auth" "payment-manual" "users" "chat" "subscription" "verification" "reviews")
exit_code=0

if [ $# -gt 0 ]; then
    modules=("$1")
    info "Vérification du module spécifique : $1"
else
    info "Vérification de tous les modules..."
fi

echo -e "${BOLD}Contrôle simple des contrats API${NC}"
echo "===================================================="
echo "Ce script vérifie la présence de fichiers liés. Il ne remplace pas une génération OpenAPI typée."

for module in "${modules[@]}"; do
    echo ""
    echo -e "--- ${BOLD}Module : $module${NC} ---"

    # --- Backend DTOs ---
    dto_count=$(find "$BACKEND_DTOS" -path "*/${module}*" -name "*.dto.ts" 2>/dev/null | wc -l)
    if [ "$dto_count" -gt 0 ]; then
        log "Backend DTOs trouvés : $dto_count"
        find "$BACKEND_DTOS" -path "*/${module}*" -name "*.dto.ts" 2>/dev/null | while read -r f; do
            info "  📄 $(basename "$f")"
        done
    else
        warn "Aucun DTO backend trouvé pour '$module'"
    fi

    # --- Flutter Models ---
    flutter_module="${module//-/_}"
    flutter_model_name="${flutter_module}_model.dart"
    flutter_model_path=$(find "$FLUTTER_MODELS" -iname "*$flutter_model_name" 2>/dev/null | head -n 1)

    if [ -n "$flutter_model_path" ] && [ -f "$flutter_model_path" ]; then
        log "Flutter model trouvé : $(basename "$flutter_model_path")"
    else
        flutter_alt=$(find "$FLUTTER_MODELS" \( -ipath "*${module}*" -o -ipath "*${flutter_module}*" \) -name "*.dart" -not -name "*.g.dart" 2>/dev/null | head -n 5)
        if [ -n "$flutter_alt" ]; then
            log "Fichiers Flutter liés trouvés :"
            echo "$flutter_alt" | while read -r f; do
                info "  📄 $(basename "$f")"
            done
        else
            warn "Aucun model Flutter trouvé pour '$module'"
            exit_code=1
        fi
    fi

    # --- Admin Web Types ---
    admin_type_file=$(find "$ADMIN_TYPES" -path "*types*" \( -name "*${module}*" -o -name "*${flutter_module}*" -o -name "index.ts" \) 2>/dev/null | head -n 1)
    if [ -n "$admin_type_file" ] && [ -f "$admin_type_file" ]; then
        log "Admin types trouvés : $(basename "$admin_type_file")"
    else
        warn "Aucun type admin-web trouvé pour '$module'"
        # Non bloquant pour l'instant car admin-web est en cours de construction
    fi
done

echo ""
echo "===================================================="
if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Contrôle terminé sans fichier critique manquant.${NC}"
else
    echo -e "${YELLOW}${BOLD}Des fichiers liés aux contrats semblent manquer.${NC}"
    echo "   Veuillez créer les fichiers manquants ou mettre à jour les couches dépendantes."
fi

exit $exit_code
