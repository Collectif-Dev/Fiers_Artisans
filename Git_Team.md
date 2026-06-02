# 🚀 Workflow Git — Structure des Branches Équipe Fiers Artisans

> 📋 **Version** : 2.0 — 2 juin 2026
> **Responsable** : Équipe Développement — CTO
> **Référence** : Ce document doit être lu conjointement avec `SECURITY_ARCHITECTURE.md` et `RÈGLES GLOBALES.md`

---

## 📋 Vue d'ensemble

Ce document définit la structure de branches, le workflow de merge et les règles de gouvernance pour une équipe de **4 développeurs** travaillant sur le projet **Fiers Artisans**.

### Objectifs du workflow

- **Zéro conflit** sur les fichiers partagés (DTOs, contrats API, types)
- **Synchronisation multi-packages** : backend NestJS, Flutter mobile, Next.js admin, infrastructure Docker
- **Validation en cascade** : feature → develop → merge → vers_production → main
- **Traçabilité** : chaque modification est rattachée à une logique métier identifiable
- **Rollback cohérent** : versions taguées sur `main` couvrant l'ensemble du monorepo

---

## 🏗️ Architecture des Branches

### Branches principales (protégées)

```
main                    ← Production, tags versionnés (v1.2.3)
  ↑
vers_production         ← Staging, tests E2E complets, validation sécurité
  ↑
merge                   ← QA, tests d'intégration CI/CD, builds
  ↑
develop                 ← Intégration quotidienne, rebase obligatoire
```

### Branches de travail (non protégées)

```
feature/<domaine>/<description>     ← Nouvelles fonctionnalités
fix/<domaine>/<description>         ← Corrections de bugs
hotfix/<description>                ← Corrections urgentes production
release/vX.Y.Z                      ← Préparation de versions
chore/<description>                 ← Maintenance, docs, configuration
```

---

## 📦 Structure Complète des Branches par Domaine

### 🔐 AUTHENTIFICATION & AUTORISATION

```
feature/backend/auth-otp
feature/backend/auth-jwt-refresh
feature/backend/auth-register-flow
feature/backend/auth-pin-login
feature/backend/auth-guards-roles
feature/backend/auth-phone-verification

feature/flutter/auth-onboarding-ui
feature/flutter/auth-otp-screen
feature/flutter/auth-pin-setup
feature/flutter/auth-biometric
feature/flutter/auth-session-persistence

feature/admin-web/auth-login
feature/admin-web/auth-admin-guards
```

### 💳 PAIEMENT & ABONNEMENT

```
feature/backend/payment-wave-integration
feature/backend/payment-wave-webhook
feature/backend/payment-manual-lifecycle
feature/backend/payment-manual-admin-workflow
feature/backend/payment-manual-fraud-detection
feature/backend/payment-manual-exif-validation
feature/backend/payment-manual-cooldown-expiration
feature/backend/subscription-wave-activation
feature/backend/subscription-manual-sync
feature/backend/subscription-expiration-cron

feature/flutter/artisan-subscription-payment
feature/flutter/artisan-manual-payment
feature/flutter/artisan-payment-status-widget
feature/flutter/artisan-payment-proof-upload

feature/admin-web/payments-manual-validation
feature/admin-web/payments-manual-history
feature/admin-web/payments-manual-refund
feature/admin-web/payments-wave-monitoring
```

### 🎨 ARTISAN — PROFIL & PORTFOLIO

```
feature/backend/artisan-verification
feature/backend/artisan-verification-documents
feature/backend/artisan-verification-admin-moderation
feature/backend/artisan-portfolio-crud
feature/backend/artisan-portfolio-media
feature/backend/artisan-availability-geo
feature/backend/artisan-location-update
feature/backend/artisan-search-index

feature/flutter/artisan-dashboard
feature/flutter/artisan-portfolio-management
feature/flutter/artisan-verification-flow
feature/flutter/artisan-availability-toggle
feature/flutter/artisan-location-update
feature/flutter/artisan-profile-edit

feature/admin-web/artisans-list
feature/admin-web/artisans-verification-moderation
feature/admin-web/artisans-subscriptions
feature/admin-web/artisans-portfolio-review
```

### 🔍 CLIENT — RECHERCHE & FAVORIS

```
feature/backend/client-search-geospatial
feature/backend/client-search-filters
feature/backend/client-favorites
feature/backend/client-reviews
feature/backend/client-reviews-reply

feature/flutter/client-search-map
feature/flutter/client-search-list
feature/flutter/client-artisan-profile
feature/flutter/client-favorites
feature/flutter/client-reviews

feature/admin-web/clients-list
feature/admin-web/clients-reviews-moderation
```

### 💬 CHAT & NOTIFICATIONS TEMPS RÉEL

```
feature/backend/chat-realtime-socket
feature/backend/chat-conversations
feature/backend/chat-messages-history
feature/backend/chat-read-receipts
feature/backend/notifications-push-fcm
feature/backend/notifications-realtime-bridge

feature/flutter/chat-conversations-list
feature/flutter/chat-messaging-screen
feature/flutter/chat-realtime-sync
feature/flutter/shared-notifications

feature/admin-web/notifications-admin-panel
```

### 🗺️ LOCALISATION & VISIBILITÉ MAP

```
feature/backend/location-gps-verification
feature/backend/location-reverse-geocoding
feature/backend/location-map-visibility-gateway
feature/backend/location-search-radius

feature/flutter/location-gps-capture
feature/flutter/location-permission-handling
feature/flutter/location-map-display
feature/flutter/location-artisan-visibility
```

### 📊 ADMINISTRATION & ANALYTICS

```
feature/backend/admin-moderation
feature/backend/admin-analytics
feature/backend/admin-sse-dashboard
feature/backend/admin-payment-events
feature/backend/admin-logs-audit

feature/admin-web/dashboard-overview
feature/admin-web/dashboard-analytics
feature/admin-web/dashboard-kpi
feature/admin-web/admin-settings-roles
feature/admin-web/admin-logs-viewer
```

### 📁 MÉDIA & STOCKAGE

```
feature/backend/media-upload-minio
feature/backend/media-signed-urls
feature/backend/media-compression
feature/backend/media-mime-validation
feature/backend/media-bucket-management

feature/flutter/media-image-picker
feature/flutter/media-image-cropper
feature/flutter/media-cached-display

feature/admin-web/media-admin-viewer
```

### 🔧 INFRASTRUCTURE & DEVOPS

```
feature/infra/docker-compose-optimization
feature/infra/docker-compose-dev-overrides
feature/infra/nginx-ssl-config
feature/infra/nginx-rate-limiting
feature/infra/monitoring-grafana-dashboards
feature/infra/monitoring-prometheus-metrics
feature/infra/monitoring-alerts
feature/infra/backup-automation
feature/infra/ci-cd-pipeline
feature/infra/env-secrets-management
feature/infra/scaling-api-horizontal
feature/infra/healthchecks-probes
```

### 🔗 CONTRATS & TRANSVERSES (CRITIQUES)

```
feature/contracts/api-dto-auth              ← JWT, OTP, DTOs auth partagés
feature/contracts/api-dto-payment           ← Wave, manual payment DTOs
feature/contracts/api-dto-users             ← Profiles, location DTOs
feature/contracts/api-dto-chat              ← Messages, conversations DTOs
feature/contracts/websocket-events          ← Chat, map visibility events
feature/contracts/websocket-namespaces      ← /ws/chat, /ws/map-visibility
feature/contracts/database-migrations       ← TypeORM, PostgreSQL
feature/contracts/database-mongo-schemas    ← Mongoose schemas
feature/contracts/shared-types               ← Types partagés backend/admin
feature/contracts/env-variables              ← .env.example, variables critiques
```

### 🔥 HOTFIXES (production uniquement)

```
hotfix/auth-bypass-critical
hotfix/payment-double-spending
hotfix/chat-security-leak
hotfix/docker-volume-loss
hotfix/env-secret-exposure
```

### 🏷️ RELEASES (coordination versions)

```
release/v1.0.0
release/v1.1.0
release/v1.2.0
```

---

## 🔄 Workflow Pyramidal — Flux des Merges

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PRODUCTION (main)                                  │
│  • Tags versionnés : v1.2.3                                                │
│  • Hotfixes uniquement (branches hotfix/*)                                   │
│  • Déploiement automatique via CI/CD                                         │
│  • Signed commits obligatoires                                               │
│  • 2 approbations requises + QA lead + CTO                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↑
                                    │ merge PR (squash + tag)
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                        STAGING (vers_production)                             │
│  • Tests E2E complets (backend + Flutter + admin-web)                        │
│  • Tests de charge (k6 / Artillery)                                        │
│  • Vérification des contrats API (backend ↔ Flutter ↔ admin)                 │
│  • Scan sécurité (Snyk, Trivy)                                               │
│  • Validation manuelle QA lead                                               │
│  • Durée minimale : 2 jours ouvrés                                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↑
                                    │ merge PR (rebase + merge commit)
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                           QA (merge)                                         │
│  • CI/CD complet : build + test + lint + type-check + docker-compose up      │
│  • Tests unitaires backend (npm run test)                                    │
│  • Tests unitaires Flutter (flutter test)                                    │
│  • Tests E2E backend critiques (npm run test:e2e)                           │
│  • Lint admin-web (npm run lint)                                            │
│  • Build admin-web (npm run build)                                          │
│  • Validation Docker compose config                                         │
│  • Durée minimale : 1 jour ouvré                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↑
                                    │ merge PR (rebase + fast-forward)
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DÉVELOPPEMENT (develop)                               │
│  • Intégration quotidienne des features                                       │
│  • Rebase obligatoire avant merge de feature                                  │
│  • Builds doivent passer (npm run build, flutter analyze)                    │
│  • 1 approbation requise par peer du même domaine                             │
│  • Pas de merge direct — PR obligatoire                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↑
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
              ↓                     ↓                     ↓
        ┌─────────┐           ┌─────────┐           ┌─────────┐
        │feature/*│           │  fix/*  │           │ chore/* │
        └─────────┘           └─────────┘           └─────────┘
              ↑                     ↑                     ↑
              │                     │                     │
        ┌─────────┐           ┌─────────┐           ┌─────────┐
        │ hotfix/*│           │release/*│           │contracts│
        │(depuis   │           │(depuis  │           │(depuis  │
        │ main)   │           │develop) │           │develop) │
        └─────────┘           └─────────┘           └─────────┘
```

---

## 📌 Conventions de Nommage

### Branches Feature
```
feature/<domaine>/<description-en-kebab-case>
```
**Domaines autorisés** :
- `backend` — API NestJS, services, controllers, DTOs
- `flutter` — Application mobile
- `admin-web` — Back-office Next.js
- `infra` — Docker, Nginx, monitoring, CI/CD
- `contracts` — DTOs partagés, WebSocket events, migrations, schemas

**Exemples valides** :
- `feature/backend/payment-manual-lifecycle`
- `feature/flutter/artisan-manual-payment`
- `feature/admin-web/payments-manual-validation`
- `feature/contracts/api-dto-payment`
- `feature/infra/docker-compose-optimization`

**Exemples INVALIDES** :
- `feature/payment` ❌ (domaine manquant)
- `feature/backend/paymentManual` ❌ (camelCase interdit)
- `feature/backend/payment_manual` ❌ (underscore interdit)
- `feature/backend/payment-manual-lifecycle-and-webhook` ❌ (trop long, scinder)

### Branches Fix
```
fix/<domaine>/<description-en-kebab-case>
```
**Exemples** :
- `fix/backend/auth-jwt-expiration`
- `fix/flutter/chat-message-order`
- `fix/admin-web/dashboard-loading-state`
- `fix/infra/nginx-websocket-timeout`

### Branches Hotfix
```
hotfix/<description-en-kebab-case>
```
**Règle** : Pas de domaine — hotfix = urgence production, peut toucher plusieurs couches.

**Exemples** :
- `hotfix/payment-double-spending`
- `hotfix/auth-token-leak`
- `hotfix/docker-volume-loss`

### Branches Release
```
release/v<MAJOR>.<MINOR>.<PATCH>
```
**Exemples** :
- `release/v1.0.0`
- `release/v1.2.3`
- `release/v2.0.0-beta`

### Branches Chore
```
chore/<description-en-kebab-case>
```
**Exemples** :
- `chore/update-dependencies`
- `chore/documentation-git-team`
- `chore/cleanup-dead-code`
- `chore/env-variables-update`

---

## 🛠️ Hiérarchie des Branches et Protection

| Branche | Rôle | Protégée | Merges autorisés depuis | Approbations requises | Status checks |
|---------|------|---------|------------------------|----------------------|---------------|
| `main` | 🚀 Production | ✅ Oui | `vers_production` uniquement | 2 (dont QA lead + CTO) | CI/CD + sécurité + E2E |
| `vers_production` | 🔍 Staging | ✅ Oui | `merge` ou `release/*` | 1 (QA lead) | E2E + charge + scan |
| `merge` | 🧪 QA/Tests | ✅ Oui | `develop` ou `release/*` | 1 (peer review) | Build + test + lint |
| `develop` | 🔄 Intégration | ✅ Oui | `feature/*`, `fix/*`, `chore/*`, `contracts/*` | 1 (peer du domaine) | Build + tests unitaires |
| `feature/*` | 👨‍💻 Développement | ❌ Non | — (création depuis develop) | — | — |
| `fix/*` | 🔧 Correction | ❌ Non | — (création depuis develop ou main) | — | — |
| `hotfix/*` | 🚨 Urgence | ❌ Non | — (création depuis main) | — | — |
| `release/*` | 🏷️ Version | ✅ Oui | — (création depuis develop) | 1 (CTO) | Tous les checks |
| `chore/*` | 🧹 Maintenance | ❌ Non | — (création depuis develop) | — | — |

---

## 📝 Processus de Travail — Par Développeur

### 1️⃣ Avant de créer une branche

```bash
# S'assurer d'être sur develop à jour
git checkout develop
git pull origin develop

# Vérifier que les contrats sont à jour (si feature métier)
git log --oneline --grep="contracts" -10
```

### 2️⃣ Créer sa branche feature

```bash
# Utiliser le script helper (recommandé)
./infrastructure/scripts/create-feature-branch.sh payment-manual-lifecycle backend

# Ou manuellement
git checkout -b feature/backend/payment-manual-lifecycle
```

### 3️⃣ Travailler et commiter

```bash
# Commits atomiques avec convention
# Format : <type>(<scope>): <description>
# Types : feat, fix, docs, style, refactor, test, chore
git add .
git commit -m "feat(payment-manual): add cooldown progressif logic"
git commit -m "fix(payment-manual): prevent double submit proof"
git commit -m "refactor(payment-manual): extract validation service"

# Push régulier
git push origin feature/backend/payment-manual-lifecycle
```

### 4️⃣ Rebase avant PR (OBLIGATOIRE)

```bash
git checkout feature/backend/payment-manual-lifecycle
git fetch origin
git rebase origin/develop

# Résoudre les conflits si nécessaire
git add .
git rebase --continue

# Push force avec lease (sécurisé)
git push --force-with-lease origin feature/backend/payment-manual-lifecycle
```

**Règle absolue** : `rebase` sur develop, jamais `merge` de develop dans une feature.

### 5️⃣ Créer une Pull Request (PR)

**Vers** : `develop`
**Titre** : `[FEATURE] Backend: Add payment manual lifecycle with cooldown`
**Template obligatoire** :

```markdown
## 📋 Description
Ajout du cycle de vie complet du paiement manuel avec cooldown progressif.

## 🔗 Issue liée
Closes #123

## 🧪 Tests effectués
- [ ] Tests unitaires passés (`npm run test`)
- [ ] Tests E2E passés (`npm run test:e2e`)
- [ ] Build OK (`npm run build`)
- [ ] Docker compose up OK

## 📦 Dépendances
- Dépend de `feature/contracts/api-dto-payment` (MERGÉE ✅)
- Impacte `feature/flutter/artisan-manual-payment` (en cours)

## 🔄 Changements de contrats
- [ ] DTO modifié → Mis à jour dans Flutter et admin-web
- [ ] Route API modifiée → Documentée dans Swagger
- [ ] WebSocket event modifié → Mis à jour dans le bridge
- [ ] Variable d'environnement ajoutée → Ajoutée dans `.env.example`

## ⚠️ Points d'attention
- Cooldown calculé : `5h * 2^(cycle - 1)`
- Nécessite migration DB : `AddPaymentManualCooldown1710000000000`
```

### 6️⃣ Code Review & Merge

- **Minimum 1 approval** par un peer du **même domaine**
- **Si `contracts/*` modifié** : 1 approval par un développeur de **chaque couche** (backend + Flutter + admin)
- **Tous les status checks** doivent passer
- **Supprimer la branche** après merge

---

## 🔀 Flux de Promotion des Branches

### Phase 1 : Développement (feature/* → develop)

```
Dev_1: feature/backend/payment-manual-lifecycle ────┐
Dev_2: feature/flutter/artisan-manual-payment       ├──→ develop (rebase + PR)
Dev_3: feature/admin-web/payments-manual-validation   │
Dev_4: feature/contracts/api-dto-payment             ───┘ (doit être mergée EN PREMIER)
```

**Ordre de merge obligatoire** :
1. `feature/contracts/api-dto-payment` → develop
2. `feature/backend/payment-manual-lifecycle` → develop (rebase)
3. `feature/flutter/artisan-manual-payment` → develop (rebase)
4. `feature/admin-web/payments-manual-validation` → develop (rebase)

### Phase 2 : Intégration (develop → merge)

```
develop ────→ merge (PR + CI/CD complet)
```
**Checks obligatoires** :
- Backend : `npm run build && npm run test && npm run test:e2e`
- Flutter : `flutter analyze && flutter test`
- Admin-web : `npm run lint && npm run build`
- Infrastructure : `docker compose config` + `docker compose up -d`

### Phase 3 : QA & Tests (merge → vers_production)

```
merge ────→ vers_production (PR + tests E2E + charge + sécurité)
```
**Checks obligatoires** :
- Tests E2E end-to-end (auth + payment + chat + search)
- Tests de charge API (rate limiting, concurrent users)
- Scan sécurité (secrets, dépendances vulnérables)
- Validation manuelle QA lead

### Phase 4 : Production (vers_production → main)

```
vers_production ────→ main (PR + tag + déploiement)
```
**Actions automatiques** :
- Tag version : `git tag -a v1.2.3 -m "Release v1.2.3"`
- Déploiement CI/CD
- Notification équipe

---

## ⚠️ Règles de Gouvernance — À NE JAMAIS VIOLER

### ✅ À FAIRE

- [ ] **Toujours** créer une PR avant de merger vers `develop`
- [ ] **Toujours** rebase sur `develop` avant PR (jamais merge de develop dans feature)
- [ ] **Toujours** attendre l'approval avant de merger
- [ ] **Toujours** faire des commits atomiques et descriptifs (conventional commits)
- [ ] **Toujours** mettre à jour `develop` avant de créer une branche feature
- [ ] **Toujours** supprimer sa branche après merge
- [ ] **Toujours** vérifier que les contrats sont mergés avant les features métier
- [ ] **Toujours** exécuter les tests locaux avant de push (`npm run test`, `flutter analyze`)
- [ ] **Toujours** mettre à jour `.env.example` si nouvelle variable d'environnement
- [ ] **Toujours** créer une migration DB si schéma modifié

### ❌ À NE JAMAIS FAIRE

- [ ] **JAMAIS** merger directement sur `develop` sans PR
- [ ] **JAMAIS** pusher directement sur `main`, `vers_production`, `merge`
- [ ] **JAMAIS** créer des branches hors de la structure définie (`feature/payment` ❌)
- [ ] **JAMAIS** commiter sur `develop` ou `main` directement
- [ ] **JAMAIS** oublier de synchroniser sa branche (`git pull origin develop`)
- [ ] **JAMAIS** merger une feature métier avant sa branche `contracts` associée
- [ ] **JAMAIS** modifier un DTO partagé sans mettre à jour Flutter ET admin-web
- [ ] **JAMAIS** renommer une route API sans mettre à jour tous les consumers
- [ ] **JAMAIS** supprimer une logique métier sans validation humaine (CTO)
- [ ] **JAMAIS** laisser un hotfix sans backport vers `develop`

---

## 🔄 Gestion des Conflits — Stratégies

### A. Conflits sur les fichiers partagés (DTOs, types, contrats)

**Fichiers à risque élevé** :
- `backend/src/common/dto/*`
- `backend/src/modules/*/dto/*`
- `fiers_artisans_app/lib/data/models/*`
- `admin-web/src/types/index.ts`
- `.env.example`
- `infrastructure/docker-compose*.yml`

**Stratégie** :
1. **Branche `contracts` dédiée** : Toute modification de DTO/type partagé passe par `feature/contracts/*`
2. **Merge contracts en premier** : Toujours merger la branche contracts avant les features métier
3. **Rebase obligatoire** : Les features métier doivent rebase sur `develop` après merge de contracts
4. **Review croisée** : 1 approval par développeur de chaque couche (backend + Flutter + admin)

### B. Conflits sur les migrations DB

**Stratégie** :
1. **Timestamp unique** : Nommer les migrations avec timestamp précis (`YYYYMMDDHHMMSS`)
2. **Ordre strict** : Les migrations sont appliquées dans l'ordre alphabétique
3. **Rebase obligatoire** : Si 2 développeurs créent des migrations, le second doit rebase et renommer
4. **Rollback testé** : Chaque migration doit avoir un script de rollback

### C. Conflits sur les variables d'environnement

**Stratégie** :
1. **Branche dédiée** : `chore/env-variables-update`
2. **Synchronisation** : Modifier `.env.example` ET `infrastructure/stack.portainer-managed.yml` ET `docker-compose*.yml`
3. **Documentation** : Mettre à jour `README.md` et `DOCUMENTATION_DOCKER.md`
4. **Notification** : Informer tous les développeurs du changement

---

## 📊 Assignation des Domaines par Développeur

| Domaine | Dev_1 (Backend Lead) | Dev_2 (Flutter Lead) | Dev_3 (Admin/DevOps) | Dev_4 (Backend/QA) |
|---------|:------------------:|:--------------------:|:--------------------:|:------------------:|
| **Authentication** | ✅ Lead | ✅ Mobile | ✅ Admin | ✅ Tests E2E |
| **Payment & Subscription** | ✅ Lead | ✅ Mobile | ✅ Admin | ✅ Tests E2E |
| **Artisan Profile** | ✅ API | ✅ Mobile | ✅ Admin | ✅ Tests E2E |
| **Client Search** | ✅ API | ✅ Mobile | — | ✅ Tests E2E |
| **Chat & Notifications** | ✅ API | ✅ Mobile | ✅ Admin | ✅ Tests E2E |
| **Location & Map** | ✅ API | ✅ Mobile | — | ✅ Tests E2E |
| **Admin Dashboard** | ✅ API | — | ✅ Lead | ✅ Tests E2E |
| **Media & Storage** | ✅ API | ✅ Mobile | ✅ Admin | — |
| **Infrastructure** | — | — | ✅ Lead | ✅ Support |
| **Contracts/Transverses** | ✅ Review | ✅ Review | ✅ Review | ✅ Coordination |

### Responsabilités par rôle

| Rôle | Responsabilités |
|------|-----------------|
| **Dev_1 — Backend Lead** | Architecture API, code review backend, performance, sécurité API |
| **Dev_2 — Flutter Lead** | UX mobile, state management, offline mode, performance UI |
| **Dev_3 — Admin & DevOps** | CI/CD, Docker, monitoring, admin-web, déploiement |
| **Dev_4 — Backend & QA** | Tests E2E, QA automation, quality gates, documentation tests |

---

## 🚀 Checklist de Mise en Place

### Configuration GitHub/GitLab

- [ ] Protection de `main` : PR obligatoire, 2 approvals, signed commits
- [ ] Protection de `vers_production` : PR obligatoire, 1 approval QA
- [ ] Protection de `merge` : PR obligatoire, CI/CD passé
- [ ] Protection de `develop` : PR obligatoire, 1 approval, build passé
- [ ] Configuration des status checks (CI/CD)
- [ ] Configuration des webhooks (Slack/Teams notifications)
- [ ] Templates de PR (feature, fix, hotfix, release)
- [ ] Templates d'issues (bug, feature, technical debt)

### Configuration Locale (chaque développeur)

- [ ] Cloner le repo avec `develop` par défaut
- [ ] Configurer git hooks (pre-commit lint)
- [ ] Installer les scripts helpers (`create-feature-branch.sh`)
- [ ] Configurer l'éditeur (ESLint, Prettier, Flutter analyze)
- [ ] Tester le workflow : créer une branche test → PR → merge → supprimer

### Scripts et Outils

- [ ] `infrastructure/scripts/create-feature-branch.sh` ✅
- [ ] `infrastructure/scripts/check-contracts-sync.sh` ✅
- [ ] `infrastructure/scripts/validate-pr.sh` (lint + test + build)
- [ ] CI/CD pipeline (GitHub Actions / GitLab CI)
- [ ] Pre-commit hooks (husky + lint-staged)

---

## 📚 Scripts Utilitaires

### `create-feature-branch.sh`

```bash
#!/bin/bash
# Usage: ./infrastructure/scripts/create-feature-branch.sh <feature-name> <domain>
# Example: ./infrastructure/scripts/create-feature-branch.sh payment-manual-lifecycle backend

set -euo pipefail

DOMAINS=("backend" "flutter" "admin-web" "infra" "contracts")
FEATURE_NAME="${1:-}"
DOMAIN="${2:-}"

if [[ -z "$FEATURE_NAME" || -z "$DOMAIN" ]]; then
  echo "Usage: $0 <feature-name> <domain>"
  echo "Domains: ${DOMAINS[*]}"
  exit 1
fi

if [[ ! " ${DOMAINS[*]} " =~ " ${DOMAIN} " ]]; then
  echo "❌ Domaine invalide. Choix: ${DOMAINS[*]}"
  exit 1
fi

echo "🔄 Mise à jour de develop..."
git checkout develop
git pull origin develop

echo "🌿 Création de la branche..."
git checkout -b "feature/${DOMAIN}/${FEATURE_NAME}"

echo "✅ Branche créée: feature/${DOMAIN}/${FEATURE_NAME}"
echo ""
echo "📋 Prochaines étapes:"
echo "   1. Développer votre feature"
echo "   2. Commits atomiques avec conventional commits"
echo "   3. Tests locaux : npm run test / flutter analyze"
echo "   4. Rebase sur develop avant PR : git fetch origin && git rebase origin/develop"
echo "   5. Créer la PR vers develop avec le template"
echo ""
echo "⚠️  Si votre feature dépend d'un contrat:"
echo "   - Vérifier que feature/contracts/* est mergée"
echo "   - Rebase sur develop après merge de contracts"
```

### `check-contracts-sync.sh`

```bash
#!/bin/bash
# Vérifie la synchronisation des contrats entre backend, Flutter et admin-web

set -euo pipefail

echo "🔍 Vérification des contrats..."

# Vérifier que les DTOs backend ont des équivalents Flutter et admin
BACKEND_DTOS="backend/src/modules"
FLUTTER_MODELS="fiers_artisans_app/lib/data/models"
ADMIN_TYPES="admin-web/src/types"

# Liste des modules critiques
MODULES=("auth" "payment-manual" "users" "chat" "subscription")

for module in "${MODULES[@]}"; do
  echo ""
  echo "📦 Module: $module"

  # Compter les DTOs backend
  backend_count=$(find "$BACKEND_DTOS/$module" -name "*.dto.ts" 2>/dev/null | wc -l)
  echo "   Backend DTOs: $backend_count"

  # Vérifier présence dans Flutter
  flutter_file="$FLUTTER_MODELS/${module//-/_}_model.dart"
  if [[ -f "$flutter_file" ]]; then
    echo "   ✅ Flutter model: $(basename $flutter_file)"
  else
    echo "   ⚠️  Flutter model manquant: ${module//-/_}_model.dart"
  fi

  # Vérifier présence dans admin-web
  # (simplifié — à adapter selon la structure réelle)
done

echo ""
echo "✅ Vérification terminée"
```

---

## 🏷️ Gestion des Versions (Semantic Versioning)

### Format des tags

```
v<MAJOR>.<MINOR>.<PATCH>[-<prerelease>]
```

| Composant | Signification |
|-----------|---------------|
| **MAJOR** | Breaking change (contrat API, DB migration non rétrocompatible) |
| **MINOR** | Nouvelle feature (rétrocompatible) |
| **PATCH** | Correction de bug (rétrocompatible) |
| **prerelease** | `beta`, `alpha`, `rc` (release candidate) |

### Exemples

- `v1.0.0` — Première version stable
- `v1.1.0` — Ajout du paiement manuel
- `v1.1.1` — Fix du cooldown progressif
- `v1.2.0-beta` — Beta de la recherche géospatiale
- `v2.0.0` — Breaking change : nouvelle auth JWT v2

### Processus de release

1. Créer `release/vX.Y.Z` depuis `develop`
2. Tests finaux, corrections si nécessaire
3. Merge `release/vX.Y.Z` → `merge` → `vers_production` → `main`
4. Tag sur `main` : `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
5. Push du tag : `git push origin vX.Y.Z`
6. Création de la release GitHub avec changelog

---

## 🚨 Procédure Hotfix (Urgence Production)

### Quand utiliser un hotfix

- Bug critique en production (sécurité, paiement, auth)
- Data loss potentiel
- Service indisponible

### Étapes

```bash
# 1. Créer depuis main
git checkout main
git pull origin main
git checkout -b hotfix/payment-double-spending

# 2. Corriger (patch minimal !)
git commit -m "fix(payment): prevent double spending in manual payment"

# 3. Tests rapides
npm run test

# 4. PR vers main (URGENT — contacter CTO)
# 5. PR vers develop (backport — même jour)
```

### Règles

- **Durée max** : 4 heures (création → merge)
- **Approval** : 1 approval + CTO (peut bypass en urgence)
- **Backport** : Obligatoire vers `develop` dans les 24h
- **Documentation** : Post-mortem dans les 48h

---

## 📋 Templates de Pull Request

### Template Feature

```markdown
## 📋 Type
- [ ] Feature
- [ ] Fix
- [ ] Hotfix
- [ ] Release
- [ ] Chore

## 🎯 Description
<!-- Décrire le changement -->

## 🔗 Issue liée
Closes #

## 🧪 Tests
- [ ] Tests unitaires passés
- [ ] Tests E2E passés
- [ ] Build OK
- [ ] Docker compose OK

## 📦 Dépendances
<!-- Lister les branches dépendantes -->
- Dépend de : 
- Impacte : 

## 🔄 Contrats
- [ ] DTO modifié → Flutter OK → Admin OK
- [ ] Route API modifiée → Documentée
- [ ] WebSocket event modifié → Bridge OK
- [ ] Env variable ajoutée → .env.example OK
- [ ] Migration DB → Rollback testé

## ⚠️ Risques
<!-- Points d'attention pour les reviewers -->
```

---

## 📚 Ressources Complémentaires

- [Git Flow Documentation](https://git-flow.readthedocs.io/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Semantic Versioning](https://semver.org/)
- `SECURITY_ARCHITECTURE.md` — Politique de sécurité et préservation
- `RÈGLES GLOBALES.md` — Pipeline IA et gouvernance

---

## 📝 Journal des Modifications

| Version | Date | Auteur | Changements |
|---------|------|--------|-------------|
| 1.0 | 2026-06-02 | Équipe Développement | Version initiale — workflow pyramidal basique |
| 2.0 | 2026-06-02 | CTO | Architecture complète — branches par domaine — règles de gouvernance — gestion des conflits — scripts utilitaires — procédure hotfix |

---

**Dernière mise à jour** : 2 juin 2026
**Responsable** : CTO — Équipe Développement Fiers Artisans
