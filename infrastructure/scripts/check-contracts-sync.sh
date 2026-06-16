# !/usr/bin/env bash
# Verifie la synchronisation des contrats entre backend, Flutter et admin-web.
#
# Controles pragmatiques avant MR:
# - modules backend, modeles Flutter et types admin-web;
# - repositories Flutter consommant les endpoints;
# - routes API Flutter/admin vs backend;
# - enums et statuts metier partages;
# - evenements WebSocket chat et SSE admin paiement.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$ROOT_DIR"

BACKEND_SRC="${ROOT_DIR}/backend/src"
BACKEND_MODULES="${BACKEND_SRC}/modules"
FLUTTER_LIB="${ROOT_DIR}/Fiers Artisans/lib"
FLUTTER_MODELS="${FLUTTER_LIB}/data/models"
FLUTTER_REPOS="${FLUTTER_LIB}/data/repositories"
FLUTTER_ENDPOINTS="${FLUTTER_LIB}/core/network/api_endpoints.dart"
ADMIN_TYPES="${ROOT_DIR}/admin-web/src/types/index.ts"
ADMIN_API="${ROOT_DIR}/admin-web/src/lib/api.ts"

issues=0

warn() {
  echo "AVERTISSEMENT: $*"
}

fail() {
  echo "ECHEC: $*"
  issues=$((issues + 1))
}

section() {
  echo
  echo "=== $* ==="
}

# module|fichiers_flutter_csv|types_admin_espace_separes
MODULE_SPECS=(
  "auth|user_model.dart|AuthResponse User"
  "payment-manual|manual_payment_model.dart|PaymentManualRecord PaymentProofRecord"
  "users|user_model.dart,artisan_model.dart|User ArtisanProfile ClientProfile"
  "chat|conversation_model.dart,message_model.dart|"
  "subscription|subscription_model.dart|SubscriptionRecord"
  "reviews|review_model.dart|ReviewRecord"
  "verification||VerificationDocument VerificationDocumentPage"
  "categories|category_model.dart|"
  "portfolio|portfolio_model.dart|"
  "search|artisan_model.dart|"
  "notifications||"
)

# module|fichier_repository_flutter
REPOSITORY_SPECS=(
  "auth|auth_repository.dart"
  "payment-manual|payment_manual_repository.dart"
  "users|artisan_repository.dart"
  "chat|chat_repository.dart"
  "subscription|subscription_repository.dart"
  "reviews|artisan_repository.dart"
  "verification|verification_repository.dart"
  "search|search_repository.dart"
  "notifications|notification_repository.dart"
)

# label|fichier_backend_relatif_modules|motif_decorateur_handler
BACKEND_HANDLER_SPECS=(
  "Flutter POST /auth/login|auth/auth.controller.ts|@Post('login')"
  "Flutter POST /auth/register/artisan|auth/auth.controller.ts|@Post('register/artisan')"
  "Flutter POST /auth/register/client|auth/auth.controller.ts|@Post('register/client')"
  "Flutter POST /auth/refresh|auth/auth.controller.ts|@Post('refresh')"
  "Flutter POST /auth/send-otp|auth/auth.controller.ts|@Post('send-otp')"
  "Flutter POST /auth/verify-otp|auth/auth.controller.ts|@Post('verify-otp')"
  "Flutter POST /auth/setup-pin|auth/auth.controller.ts|@Post('setup-pin')"
  "Flutter GET /artisan/profile|users/users.controller.ts|@Get('artisan/profile')"
  "Flutter GET /client/profile|users/users.controller.ts|@Get('client/profile')"
  "Flutter GET /client/favorites|users/users.controller.ts|@Get('client/favorites')"
  "Flutter GET /categories|categories/categories.controller.ts|@Get()"
  "Flutter GET /search/artisans|search/search.controller.ts|@Get('artisans')"
  "Flutter POST /reviews|reviews/reviews.controller.ts|@Post()"
  "Flutter GET /portfolio|portfolio/portfolio.controller.ts|@Get()"
  "Flutter POST /subscription/initiate|subscription/subscription.controller.ts|@Post('initiate')"
  "Flutter GET /subscription/status|subscription/subscription.controller.ts|@Get('status')"
  "Flutter POST /payments/manual/initiate|payment-manual/controllers/payment-manual.controller.ts|@Post('initiate')"
  "Flutter GET /payments/manual/current|payment-manual/controllers/payment-manual.controller.ts|@Get('current')"
  "Flutter POST /verification/submit|verification/verification.controller.ts|@Post('submit')"
  "Flutter GET /verification/status|verification/verification.controller.ts|@Get('status')"
  "Flutter GET /chat/conversations|chat/chat.controller.ts|@Get('conversations')"
  "Flutter GET /notifications|notifications/notifications.controller.ts|@Get()"
  "Flutter GET /notifications/unread-count|notifications/notifications.controller.ts|@Get('unread-count')"
  "Flutter POST /media/upload|media/media.controller.ts|@Post('upload')"
  "Flutter POST /analytics/log|analytics/analytics.controller.ts|@Post('log')"
  "Flutter PUT /users/fcm-token|users/users.controller.ts|@Put('users/fcm-token')"
  "Flutter PUT /users/location|users/users.controller.ts|@Put('users/location')"
  "Flutter GET /health|health/health.controller.ts|@Get()"
  "Admin POST /auth/login|auth/auth.controller.ts|@Post('login')"
  "Admin POST /auth/refresh|auth/auth.controller.ts|@Post('refresh')"
  "Admin GET /admin/dashboard|admin/admin.controller.ts|@Get('dashboard')"
  "Admin GET /admin/verifications/pending|admin/admin.controller.ts|@Get('verifications/pending')"
  "Admin PUT /admin/verifications/:id|admin/admin.controller.ts|@Put('verifications/:id')"
  "Admin GET /admin/artisans|admin/admin.controller.ts|@Get('artisans')"
  "Admin GET /admin/analytics|admin/admin.controller.ts|@Get('analytics')"
  "Admin GET /admin/clients|admin/admin.controller.ts|@Get('clients')"
  "Admin GET /admin/subscriptions|admin/admin.controller.ts|@Get('subscriptions')"
  "Admin GET /admin/reviews|admin/admin.controller.ts|@Get('reviews')"
  "Admin GET /admin/logs|admin/admin.controller.ts|@Get('logs')"
  "Admin GET /admin/payment-proofs|payment-manual/controllers/payment-manual-admin.controller.ts|@Get('payment-proofs')"
  "Admin GET /media/file/:bucket/:objectKey|media/media.controller.ts|@Get('file/:bucket/:objectKey')"
)

# label|fichier_backend_relatif_modules|nom_enum|fichiers_admin_csv|fichiers_flutter_csv|mode
# mode: strict = admin + flutter obligatoires; admin = admin seulement; warn-flutter = admin strict, flutter en avertissement
ENUM_SPECS=(
  "Statuts paiement manuel|payment-manual/entities/payment-manual.entity.ts|PaymentManualStatus|${ADMIN_TYPES}|${FLUTTER_MODELS}/manual_payment_model.dart|strict"
  "Fournisseurs paiement manuel|payment-manual/entities/payment-manual.entity.ts|PaymentProviderManual|${ADMIN_TYPES}||admin"
  "Statuts abonnement|subscription/entities/subscription.entity.ts|SubscriptionStatus|${ADMIN_TYPES}|${FLUTTER_MODELS}/subscription_model.dart|warn-flutter"
  "Roles utilisateur|users/entities/user.entity.ts|UserRole|${ADMIN_TYPES}||admin"
  "Statuts verification utilisateur|users/entities/user.entity.ts|VerificationStatus|${ADMIN_TYPES}|${FLUTTER_MODELS}/artisan_model.dart|warn-flutter"
  "Statuts document verification|verification/entities/verification-document.entity.ts|DocumentStatus|${ADMIN_TYPES}||admin"
)

CHAT_WS_EVENTS=(
  "joinConversation"
  "newMessage"
  "messagesRead"
  "participantAvailabilityUpdated"
)

PAYMENT_SSE_EVENTS=(
  "PAYMENT_MANUAL_NEW_PROOF"
  "PAYMENT_MANUAL_UPDATED"
  "PAYMENT_MANUAL_TIMELINE_UPDATED"
)

ACTIVITY_LOG_ACTIONS=(
  "PROFILE_VIEW"
  "SEARCH"
  "CONTACT_CLICK"
  "LOGIN"
  "PAYMENT_ATTEMPT"
  "REGISTRATION"
  "SUBSCRIPTION_UPDATED"
  "PAYMENT_MANUAL_INITIATED"
  "PROOF_SUBMITTED"
  "PROOF_VALIDATED"
  "PAYMENT_MANUAL_REJECTED"
  "PAYMENT_MANUAL_REOPENED"
  "PAYMENT_MANUAL_EXPIRED"
  "PAYMENT_MANUAL_SOFT_DELETED"
  "REFUND_PROCESSED"
)

extract_enum_values() {
  local entity_file="$1"
  local enum_name="$2"

  awk -v enum="${enum_name}" '
    $0 ~ "export enum " enum " {" { capture=1; next }
    capture && $0 ~ /^}/ { exit }
    capture && match($0, /[[:space:]]*[A-Z_0-9]+[[:space:]]*=/) {
      value=$0
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*=.*/, "", value)
      print value
    }
  ' "${entity_file}"
}

check_enum_values_in_file() {
  local value="$1"
  local file="$2"
  local label="$3"

  if [[ ! -f "${file}" ]]; then
    fail "${label}: fichier consommateur absent (${file})"
    return
  fi

  if grep -q "${value}" "${file}"; then
    return
  fi

  local lower_value
  lower_value="$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${lower_value}" != "${value}" ]] && grep -qi "${lower_value}" "${file}"; then
    return
  fi

  fail "${label}: valeur enum '${value}' absente de ${file#"${ROOT_DIR}/"}"
}

check_backend_handler() {
  local label="$1"
  local backend_rel="$2"
  local pattern="$3"
  local handler_file="${BACKEND_MODULES}/${backend_rel}"

  if [[ -f "${handler_file}" ]] && grep -q "${pattern}" "${handler_file}"; then
    echo "OK Handler ${label}"
  else
    fail "Handler backend manquant: ${label} (${backend_rel}, ${pattern})"
  fi
}

echo "Verification des contrats multi-couches..."

if [[ ! -f "${ADMIN_TYPES}" ]]; then
  fail "Fichier admin-web manquant: admin-web/src/types/index.ts"
fi

if [[ ! -d "${FLUTTER_MODELS}" ]]; then
  fail "Repertoire Flutter manquant: Fiers Artisans/lib/data/models"
fi

if [[ ! -f "${FLUTTER_ENDPOINTS}" ]]; then
  fail "Fichier Flutter manquant: Fiers Artisans/lib/core/network/api_endpoints.dart"
fi

if [[ ! -f "${ADMIN_API}" ]]; then
  fail "Fichier admin-web manquant: admin-web/src/lib/api.ts"
fi

section "Modules metier"
for spec in "${MODULE_SPECS[@]}"; do
  IFS='|' read -r module flutter_spec admin_spec <<< "${spec}"

  echo
  echo "==> Module: ${module}"

  backend_dir="${BACKEND_MODULES}/${module}"
  if [[ ! -d "${backend_dir}" ]]; then
    fail "Module backend absent: backend/src/modules/${module}"
    continue
  fi

  dto_count="$(find "${backend_dir}" -name '*.dto.ts' 2>/dev/null | wc -l | tr -d ' ')"
  echo "Backend DTOs: ${dto_count}"
  if [[ "${dto_count}" -eq 0 ]]; then
    warn "Aucun DTO trouve dans backend/src/modules/${module}"
  fi

  if [[ -z "${flutter_spec// /}" ]]; then
    echo "Flutter models: non requis ou couvert par d'autres modules"
  else
    IFS=',' read -r -a flutter_files <<< "${flutter_spec}"
    for flutter_file in "${flutter_files[@]}"; do
      flutter_path="${FLUTTER_MODELS}/${flutter_file}"
      if [[ -f "${flutter_path}" ]]; then
        echo "OK Flutter: ${flutter_file}"
      else
        fail "Modele Flutter manquant: Fiers Artisans/lib/data/models/${flutter_file}"
      fi
    done
  fi

  if [[ -z "${admin_spec// /}" ]]; then
    echo "Admin-web: non applicable pour ce module"
    continue
  fi

  for admin_type in ${admin_spec}; do
    if grep -q "export interface ${admin_type}" "${ADMIN_TYPES}"; then
      echo "OK Admin-web: ${admin_type}"
    else
      fail "Type admin-web manquant: ${admin_type} (admin-web/src/types/index.ts)"
    fi
  done
done

section "Repositories Flutter"
for spec in "${REPOSITORY_SPECS[@]}"; do
  IFS='|' read -r module repo_file <<< "${spec}"
  repo_path="${FLUTTER_REPOS}/${repo_file}"

  if [[ -f "${repo_path}" ]]; then
    echo "OK Repository ${module}: ${repo_file}"
  else
    fail "Repository Flutter manquant pour ${module}: Fiers Artisans/lib/data/repositories/${repo_file}"
  fi
done

section "Handlers API Flutter et admin vs backend"
for spec in "${BACKEND_HANDLER_SPECS[@]}"; do
  IFS='|' read -r label backend_rel pattern <<< "${spec}"
  check_backend_handler "${label}" "${backend_rel}" "${pattern}"
done

section "Enums et statuts metier"
for spec in "${ENUM_SPECS[@]}"; do
  IFS='|' read -r label backend_rel enum_name admin_files flutter_files mode <<< "${spec}"
  entity_file="${BACKEND_MODULES}/${backend_rel}"

  echo
  echo "==> ${label} (${enum_name})"

  if [[ ! -f "${entity_file}" ]]; then
    fail "Fichier enum backend absent: backend/src/modules/${backend_rel}"
    continue
  fi

  mapfile -t enum_values < <(extract_enum_values "${entity_file}" "${enum_name}")
  if [[ "${#enum_values[@]}" -eq 0 ]]; then
    fail "Enum backend introuvable ou vide: ${enum_name}"
    continue
  fi

  if [[ -n "${admin_files// /}" ]]; then
    IFS=',' read -r -a admin_file_list <<< "${admin_files}"
    for value in "${enum_values[@]}"; do
      for admin_file in "${admin_file_list[@]}"; do
        check_enum_values_in_file "${value}" "${admin_file}" "${label}"
      done
    done
  fi

  if [[ -n "${flutter_files// /}" ]]; then
    IFS=',' read -r -a flutter_file_list <<< "${flutter_files}"
    for value in "${enum_values[@]}"; do
      for flutter_file in "${flutter_file_list[@]}"; do
        if [[ "${mode}" == "warn-flutter" ]]; then
          if [[ -f "${flutter_file}" ]] \
            && ! grep -q "${value}" "${flutter_file}" \
            && ! grep -qi "$(printf '%s' "${value}" | tr '[:upper:]' '[:lower:]')" "${flutter_file}"; then
            warn "${label}: valeur '${value}' non referencee explicitement dans ${flutter_file#"${ROOT_DIR}/"}"
          fi
        else
          check_enum_values_in_file "${value}" "${flutter_file}" "${label}"
        fi
      done
    done
  fi

  echo "OK Valeurs ${enum_name}: ${enum_values[*]}"
done

section "WebSocket chat"
chat_gateway="${BACKEND_MODULES}/chat/chat.gateway.ts"
chat_service="${FLUTTER_LIB}/services/chat_realtime_service.dart"

for event in "${CHAT_WS_EVENTS[@]}"; do
  if grep -q "'${event}'" "${chat_gateway}" && grep -q "'${event}'" "${chat_service}"; then
    echo "OK WebSocket: ${event}"
  else
    fail "Evenement WebSocket chat desynchronise: ${event}"
  fi
done

section "SSE admin paiement manuel"
payment_events="${BACKEND_MODULES}/payment-manual/events/payment.events.ts"

for event in "${PAYMENT_SSE_EVENTS[@]}"; do
  if grep -q "${event}" "${payment_events}" \
    && grep -rq "${event}" "${ROOT_DIR}/admin-web/src"; then
    echo "OK SSE paiement: ${event}"
  else
    fail "Evenement SSE paiement desynchronise: ${event}"
  fi
done

section "Journal d'activite admin"
activity_schema="${BACKEND_MODULES}/analytics/schemas/activity-log.schema.ts"

for action in "${ACTIVITY_LOG_ACTIONS[@]}"; do
  if grep -q "'${action}'" "${activity_schema}" \
    && grep -q "'${action}'" "${ADMIN_TYPES}"; then
    echo "OK ActivityLog: ${action}"
  else
    fail "Action ActivityLog desynchronisee: ${action}"
  fi
done

echo
if [[ "${issues}" -gt 0 ]]; then
  echo "Verification des contrats terminee avec ${issues} probleme(s)."
  exit 1
fi

echo "Verification des contrats terminee sans probleme detecte."
