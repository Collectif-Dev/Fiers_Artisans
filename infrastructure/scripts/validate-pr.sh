#!/bin/bash
# =============================================================================
# validate-pr.sh
# Exécute les vérifications locales avant de soumettre une Pull Request.
# Usage: ./validate-pr.sh [--all] [--backend] [--flutter] [--admin] [--contracts]
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_BRANCH="${BASE_BRANCH:-develop}"
EXIT_CODE=0
FAILED_CHECKS=()

log() { echo -e "${GREEN}[PASS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }
header() { echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}\n"; }

# --- Arguments ---
RUN_BACKEND=false
RUN_FLUTTER=false
RUN_ADMIN=false
RUN_CONTRACTS=false
RUN_ALL=false

if [ $# -eq 0 ]; then
    RUN_ALL=true
else
    for arg in "$@"; do
        case $arg in
            --all) RUN_ALL=true ;;
            --backend) RUN_BACKEND=true ;;
            --flutter) RUN_FLUTTER=true ;;
            --admin) RUN_ADMIN=true ;;
            --contracts) RUN_CONTRACTS=true ;;
            *) echo "Usage: $0 [--all] [--backend] [--flutter] [--admin] [--contracts]"; exit 1 ;;
        esac
    done
fi

# --- Vérification du format des messages de commit ---
check_conventional_commits() {
    info "Vérification des messages de commit..."
    local unmerged_commits
    local base_ref="origin/${BASE_BRANCH}"

    if ! git rev-parse --verify "$base_ref" >/dev/null 2>&1; then
        base_ref="$BASE_BRANCH"
    fi

    unmerged_commits=$(git log --oneline --no-merges "$(git merge-base HEAD "$base_ref" 2>/dev/null || echo "$base_ref")"..HEAD 2>/dev/null || true)

    if [ -z "$unmerged_commits" ]; then
        warn "Impossible de déterminer les nouveaux commits (branche de base manquante ?)"
        return 0
    fi

    local invalid_commits=0
    while IFS= read -r line; do
        local msg=$(echo "$line" | sed 's/^[a-f0-9]* //')
        # Format attendu : type(scope): description ou type: description
        if ! echo "$msg" | grep -qE '^(feat|fix|docs|style|refactor|test|chore|ci|perf|revert)(\([^)]+\))?: .+'; then
            err "Commit non conforme : $line"
            invalid_commits=$((invalid_commits + 1))
        fi
    done <<< "$unmerged_commits"

    if [ $invalid_commits -gt 0 ]; then
        err "$invalid_commits commit(s) ne respectent pas Conventional Commits."
        info "Format attendu : type(scope): description"
        info "Types valides : feat, fix, docs, style, refactor, test, chore, ci, perf, revert"
        return 1
    fi
    log "Messages de commit conformes."
}

# --- Backend Checks ---
check_backend() {
    header "BACKEND (NestJS)"
    local backend_dir="${PROJECT_ROOT}/backend"

    if [ ! -d "$backend_dir" ]; then
        warn "Répertoire backend non trouvé."
        return 0
    fi

    cd "$backend_dir"

    # 1. Lint
    info "Exécution du linter..."
    if npm run lint --silent 2>/dev/null; then
        log "Lint backend OK"
    else
        err "Lint backend a échoué."
        FAILED_CHECKS+=("backend:lint")
        EXIT_CODE=1
    fi

    # 2. Build
    info "Vérification du build..."
    if npm run build --silent 2>/dev/null; then
        log "Build backend OK"
    else
        err "Build backend a échoué."
        FAILED_CHECKS+=("backend:build")
        EXIT_CODE=1
    fi

    # 3. Tests Unitaires
    info "Exécution des tests unitaires..."
    if npm run test --silent 2>/dev/null; then
        log "Tests unitaires backend OK"
    else
        err "Tests unitaires backend ont échoué."
        FAILED_CHECKS+=("backend:test")
        EXIT_CODE=1
    fi

    cd "$PROJECT_ROOT"
}

# --- Flutter Checks ---
check_flutter() {
    header "FLUTTER (Mobile)"
    local flutter_dir="${PROJECT_ROOT}/fiers_artisans_app"

    if [ ! -d "$flutter_dir" ]; then
        warn "Répertoire Flutter non trouvé."
        return 0
    fi

    cd "$flutter_dir"

    # 1. Analyse
    info "Analyse statique du code Flutter..."
    if flutter analyze --no-pub; then
        log "Flutter analyze OK"
    else
        err "Flutter analyze a détecté des problèmes."
        info "Veuillez exécuter 'flutter analyze' pour les détails."
        FAILED_CHECKS+=("flutter:analyze")
        EXIT_CODE=1
    fi

    # 2. Tests
    info "Exécution des tests Flutter..."
    if flutter test 2>/dev/null; then
        log "Tests Flutter OK"
    else
        err "Tests Flutter ont échoué."
        FAILED_CHECKS+=("flutter:test")
        EXIT_CODE=1
    fi

    cd "$PROJECT_ROOT"
}

# --- Admin Web Checks ---
check_admin() {
    header "ADMIN WEB (Next.js)"
    local admin_dir="${PROJECT_ROOT}/admin-web"

    if [ ! -d "$admin_dir" ]; then
        warn "Répertoire admin-web non trouvé."
        return 0
    fi

    cd "$admin_dir"

    # 1. Lint
    info "Exécution du linter..."
    if npm run lint --silent 2>/dev/null; then
        log "Lint admin-web OK"
    else
        err "Lint admin-web a échoué."
        FAILED_CHECKS+=("admin:lint")
        EXIT_CODE=1
    fi

    # 2. Build
    info "Vérification du build..."
    if npm run build --silent 2>/dev/null; then
        log "Build admin-web OK"
    else
        err "Build admin-web a échoué."
        FAILED_CHECKS+=("admin:build")
        EXIT_CODE=1
    fi

    cd "$PROJECT_ROOT"
}

# --- Contracts Check ---
check_contracts() {
    header "CONTRATS API"
    local contracts_script="${PROJECT_ROOT}/infrastructure/scripts/check-contracts-sync.sh"

    if [ ! -x "$contracts_script" ]; then
        warn "Script de vérification des contrats introuvable ou non exécutable."
        return 0
    fi

    if "$contracts_script"; then
        log "Contrôle des contrats OK"
    else
        err "Des écarts de contrats ont été détectés."
        FAILED_CHECKS+=("contracts:sync")
        EXIT_CODE=1
    fi
}

# --- Docker Compose Check ---
check_docker() {
    header "DOCKER COMPOSE"
    if [ -f "${PROJECT_ROOT}/infrastructure/docker-compose.yml" ]; then
        info "Vérification de la validité du docker-compose.yml..."
        if docker compose -f "${PROJECT_ROOT}/infrastructure/docker-compose.yml" config > /dev/null 2>&1; then
            log "Docker Compose YAML valide."
        else
            err "Le fichier docker-compose.yml est invalide."
            FAILED_CHECKS+=("docker:config")
            EXIT_CODE=1
        fi
    else
        warn "Aucun docker-compose.yml trouvé."
    fi
}

# --- Git Clean Check ---
check_git_clean() {
    header "GIT STATE"
    if git diff --cached --quiet; then
        warn "Aucun changement n'est actuellement indexé (staged)."
        info "N'oubliez pas de faire 'git add' sur vos fichiers avant de committer."
    else
        log "Des changements sont indexés et prêts pour le commit."
    fi

    local branch_name
    branch_name=$(git rev-parse --abbrev-ref HEAD)
    info "Branche actuelle : ${BOLD}${branch_name}${NC}"

    if [ "$branch_name" = "$BASE_BRANCH" ]; then
        err "Vous êtes sur '${BASE_BRANCH}'. Créez une branche de travail avant une PR."
        EXIT_CODE=1
    fi
}

# =============================================================================
# MAIN
# =============================================================================

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          VALIDATION PR - WORKFLOW 'FIERS ARTISANS'           ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
info "Ce script valide votre travail avant de créer une Pull Request."
info "Branche de base : ${BOLD}${BASE_BRANCH}${NC} (modifiable avec BASE_BRANCH=nom_de_branche)"

# Exécution des checks
if [ "$RUN_ALL" = true ] || [ "$RUN_BACKEND" = true ]; then check_backend; fi
if [ "$RUN_ALL" = true ] || [ "$RUN_FLUTTER" = true ]; then check_flutter; fi
if [ "$RUN_ALL" = true ] || [ "$RUN_ADMIN" = true ]; then check_admin; fi
if [ "$RUN_ALL" = true ] || [ "$RUN_CONTRACTS" = true ]; then check_contracts; fi
if [ "$RUN_ALL" = true ]; then check_docker; fi
check_git_clean
check_conventional_commits

# --- Résumé ---
echo ""
echo "=================================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✅ TOUTES LES VÉRIFICATIONS ONT RÉUSSI !${NC}"
    echo "   Vous pouvez maintenant pousser votre branche et créer une Pull Request."
    echo "   Commande suggérée : git push -u origin $(git rev-parse --abbrev-ref HEAD)"
else
    echo -e "${RED}${BOLD}❌ CERTAINS CONTRÔLES ONT ÉCHOUÉ.${NC}"
    echo "   Vérifiez les erreurs ci-dessus et corrigez-les avant de soumettre votre PR."
    echo ""
    echo "Checks en échec :"
    for check in "${FAILED_CHECKS[@]}"; do
        echo "   - $check"
    done
fi
echo "=================================================="

exit $EXIT_CODE
