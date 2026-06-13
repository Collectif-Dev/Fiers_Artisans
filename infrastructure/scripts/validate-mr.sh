#!/usr/bin/env bash
# Lance les controles locaux recommandes avant une Merge Request GitLab.
#
# Le script est volontairement pragmatique:
# - il lance les controles disponibles quand les dependances sont installees;
# - il signale clairement quoi installer quand elles manquent;
# - il n'installe rien automatiquement pour eviter les effets de bord.

set -euo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "${ROOT_DIR}"

failures=0

run_check() {
  local label="$1"
  shift

  echo
  echo "==> ${label}"
  if "$@"; then
    echo "OK: ${label}"
  else
    echo "ECHEC: ${label}"
    failures=$((failures + 1))
  fi
}

require_node_modules() {
  local dir="$1"
  if [[ ! -d "${dir}/node_modules" ]]; then
    echo "Dependances absentes dans ${dir}. Lancez: (cd ${dir} && npm ci)"
    return 1
  fi
}

run_check "Contrats multi-couches" ./infrastructure/scripts/check-contracts-sync.sh

if require_node_modules "backend"; then
  run_check "Backend tests unitaires" bash -lc "cd backend && npm run test -- --runInBand"
  run_check "Backend build" bash -lc "cd backend && npm run build"
else
  failures=$((failures + 1))
fi

if require_node_modules "admin-web"; then
  run_check "Admin-web lint" bash -lc "cd admin-web && npm run lint"
  run_check "Admin-web build" bash -lc "cd admin-web && npm run build"
else
  failures=$((failures + 1))
fi

if command -v flutter >/dev/null 2>&1; then
  run_check "Flutter analyze" bash -lc "cd 'Fiers Artisans' && flutter analyze"
  run_check "Flutter tests" bash -lc "cd 'Fiers Artisans' && flutter test"
else
  echo
  echo "Flutter non disponible dans PATH. Installez Flutter ou lancez les tests mobile sur une machine equipee."
  failures=$((failures + 1))
fi

echo
if [[ "${failures}" -gt 0 ]]; then
  echo "Validation MR terminee avec ${failures} probleme(s)."
  exit 1
fi

echo "Validation MR terminee sans probleme detecte."
