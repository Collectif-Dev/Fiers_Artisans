# 🚀 Guide Git — Développeurs Fiers Artisans (Version Opérationnelle)

> 📋 **Version** : 3.0 — 6 juin 2026  
> **Pour** : Développeurs junior et confirmé  
> **Objectif** : Workflow simple, pragmatique et sans casse-tête  

---

## 🎯 Règle d'Or — À RETENIR EN PRIORITÉ

```
1. ❌ JAMAIS coder directement sur develop, merge, vers_production ou main
2. ✅ Toujours créer une branche feature/fix à partir de develop
3. ✅ Toujours ouvrir une Pull Request (PR) pour fusionner
4. ✅ Toujours se synchroniser avec develop avant la PR
```

**Une seule exception** : hotfix depuis main (urgence production seulement)

---

## 🏗️ Architecture des Branches — Vue Simplifiée

```
main                    ← Production (tags versionnés)
  ↑
vers_production         ← Staging (tests avant prod)
  ↑
merge                   ← QA (tests et validations)
  ↑
develop                 ← Votre base de travail
  ↑
feature/*  fix/*  chore/*  ← Vos branches de travail
```

### Branches que vous créez

| Type | Format | Exemple | Quand |
|------|--------|---------|-------|
| **Feature** | `feature/backend/...` | `feature/backend/payment-manual-lifecycle` | Nouvelle fonctionnalité |
| | `feature/flutter/...` | `feature/flutter/artisan-manual-payment` | |
| | `feature/admin-web/...` | `feature/admin-web/payments-manual-validation` | |
| **Fix** | `fix/backend/...` | `fix/backend/auth-jwt-expiration` | Correction de bug |
| **Chore** | `chore/...` | `chore/update-dependencies` | Maintenance, docs |
| **Hotfix** | `hotfix/...` | `hotfix/payment-double-spending` | 🚨 Urgence production |

---

## 1️⃣ PREMIÈRE INSTALLATION DU PROJET

### Cloner le dépôt

```bash
git clone git@github.com:mellykelkun/Fiers_Artisants.git
cd Fiers_Artisants
```

### Vérifier la branche courante

```bash
git status
```

Vous devriez voir :
```
On branch develop
Your branch is up to date with 'mellykelkun/develop'.
```

### Voir toutes les branches disponibles

```bash
git branch -a
```

Vous verrez :
```
* develop
  main
  merge
  sauver_main_globale
  vers_production
  ...
```

✅ **C'est bon** : Git connaît toutes les branches distantes.

---

## 2️⃣ DÉMARRER UNE NOUVELLE TÂCHE

Supposons que vous devez implémenter la feature : **#101 OTP Backend Authentication**

### Étape 1 : Mettre à jour develop

```bash
git checkout develop
git pull mellykelkun develop
```

**Pourquoi** : Vous assurez que votre `develop` local est à jour avant de créer une branche.

### Étape 2 : Créer votre branche de travail

```bash
git checkout -b feature/backend/auth-otp
```

**Résultat** :
```
Switched to a new branch 'feature/backend/auth-otp'
```

### Vérification rapide

```bash
git status
```

Vous verrez :
```
On branch feature/backend/auth-otp
nothing to commit, working tree clean
```

✅ **Prêt à travailler !**

---

## 3️⃣ TRAVAILLER ET ENREGISTRER VOS CHANGEMENTS

### Voir vos modifications

```bash
git status
```

Exemple :
```
On branch feature/backend/auth-otp
Changes not staged for commit:
  modified:   backend/src/modules/auth/auth.service.ts
  modified:   backend/src/modules/auth/auth.module.ts

Untracked files:
  new file:   backend/src/modules/auth/otp.service.ts
```

### Ajouter les fichiers modifiés

**Option 1** : Ajouter tous les fichiers
```bash
git add .
```

**Option 2** : Ajouter des fichiers spécifiques
```bash
git add backend/src/modules/auth/auth.service.ts
git add backend/src/modules/auth/otp.service.ts
```

### Créer un commit clair

```bash
git commit -m "feat(auth): implement OTP generation and verification service"
```

**Conventions de commit** :

| Type | Usage | Exemple |
|------|-------|---------|
| **feat** | Nouvelle fonctionnalité | `feat(payment): add Wave webhook validation` |
| **fix** | Correction de bug | `fix(chat): prevent duplicate messages` |
| **refactor** | Refactoring sans changement fonctionnel | `refactor(auth): extract token service` |
| **test** | Ajout/modification de tests | `test(payment): add manual payment cooldown tests` |
| **docs** | Documentation | `docs(readme): update setup instructions` |
| **chore** | Maintenance, dépendances | `chore(deps): update NestJS packages` |

### Pousser votre branche vers GitHub

```bash
git push origin feature/backend/auth-otp
```

**Ou après modification** :
```bash
git push origin
```

✅ Votre branche est maintenant sur GitHub !

---

## 4️⃣ METTRE À JOUR SA BRANCHE QUAND DEVELOP AVANCE

**Scénario** : Vous travaillez sur `feature/backend/auth-otp`, et d'autres PRs sont fusionnées dans `develop`.

### Ce qu'il faut faire AVANT d'ouvrir une PR

```bash
git fetch origin
git rebase origin/develop
```

**Ce que Git fait** :
1. Télécharge les derniers commits de `develop`
2. Rejoue vos commits par-dessus les nouveaux

### Si Git trouve des conflits

```
CONFLICT (content): Merge conflict in backend/src/modules/auth/auth.service.ts
error: could not apply 1234567... feat(auth): implement OTP
hint: Resolve all conflicts manually, then run "git rebase --continue"
```

**Solution** :
1. Ouvrez le fichier en conflit
2. Résolvez les conflits (cherchez `<<<<<<<` et `>>>>>>>`)
3. Sauvegardez et continuez

```bash
git add .
git rebase --continue
```

**Si ça devient trop compliqué** :
```bash
git rebase --abort
```
(Revient à l'état avant le rebase)

### Pousser après rebase

```bash
git push --force-with-lease origin feature/backend/auth-otp
```

⚠️ **Important** : Utilisez `--force-with-lease` (pas `--force` brut). Cela protège votre travail et celui des autres.

---

## 5️⃣ OUVRIR UNE PULL REQUEST (PR)

### Sur GitHub

1. Allez sur [github.com/mellykelkun/Fiers_Artisants](https://github.com/mellykelkun/Fiers_Artisants)
2. Cliquez sur **Pull Requests** → **New Pull Request**
3. Configurez :
   - **Base (cible)** : `develop`
   - **Compare (source)** : `feature/backend/auth-otp`

### Remplissez le template

```markdown
## 📋 Description
Implémentation du service OTP pour l'authentification des utilisateurs.
- Génération de codes OTP 6 chiffres
- Validation avec TTL (5 minutes)
- Rate limiting : max 5 tentatives

## 🔗 Issue liée
Closes #101

## ✅ Tests effectués
- [x] Tests unitaires passés (`npm run test`)
- [x] Build OK (`npm run build`)
- [x] Lint OK (`npm run lint`)
- [x] Docker compose up OK

## 📦 Dépendances
Dépend de : feature/contracts/api-dto-auth (MERGÉE ✅)

## ⚠️ Points d'attention
- OTP stocké en Redis avec TTL
- Nécessite variable d'environnement : OTP_TTL_SECONDS
```

4. Cliquez sur **Create Pull Request**

### Après ouverture de la PR

- La CI/CD se lance automatiquement
- Les reviewers sont notifiés
- Si la CI échoue → Corrigez et poussez des commits (la PR se met à jour seule)

---

## 6️⃣ APRÈS FUSION DE VOTRE PR

Une fois que votre PR est fusionnée dans `develop` :

### Nettoyer sa branche locale

```bash
git checkout develop
git pull origin develop
git branch -d feature/backend/auth-otp
```

✅ C'est fait ! Prêt pour la prochaine tâche.

---

## 7️⃣ SCÉNARIOS FRÉQUENTS

### Scénario A — Je commence une nouvelle feature

```bash
git checkout develop
git pull origin develop
git checkout -b feature/backend/mon-feature
# Développez...
git add .
git commit -m "feat(backend): ma nouvelle feature"
git push origin
# Ouvrez une PR sur GitHub
```

### Scénario B — Ma branche est en retard sur develop

```bash
git fetch origin
git rebase origin/develop
git push --force-with-lease origin
```

### Scénario C — Je dois corriger la PR après review

```bash
git add .
git commit -m "fix: address review comments"
git push origin
# La PR se met à jour automatiquement
```

### Scénario D — J'ai modifié des fichiers que je veux abandonner

**Abandonner tous les changements** :
```bash
git checkout .
```

**Abandonner un fichier spécifique** :
```bash
git checkout -- backend/src/modules/auth/wrong-file.ts
```

### Scénario E — Mon rebase est devenu ingérable

```bash
git rebase --abort
```

Demandez de l'aide à l'équipe avant de recommencer.

### Scénario F — Je veux juste récupérer les derniers changements de develop

```bash
git checkout develop
git pull origin develop
```

---

## ❌ CE QU'IL NE FAUT JAMAIS FAIRE

| ❌ À NE JAMAIS FAIRE | ❌ Pourquoi | ✅ À LA PLACE |
|---------------------|-----------|-------------|
| Coder directement sur `develop` ou `main` | Bypass des reviews, casse l'intégration | Créer une branche `feature/*` |
| `git push origin develop` depuis votre PC | Injecte du code non revu | Ouvrir une PR (fusion depuis GitHub) |
| `git merge develop` dans votre feature | Historique sale, incohérent | `git rebase origin/develop` |
| `git push --force` (sans lease) | Écrase le travail d'un autre | `git push --force-with-lease` |
| Créer une branche `feature/otp` (sans domaine) | Non respecte la convention | `feature/backend/auth-otp` |
| Laisser une feature oubliée des mois | Polluent la liste des branches | Supprimer après fusion : `git branch -d` |

---

## 🎯 ROUTINE QUOTIDIENNE

### Chaque matin

```bash
# Allez sur develop
git checkout develop

# Mettez-la à jour
git pull origin develop

# Créez ou continuez votre branche
git checkout feature/backend/ma-feature
```

### Avant chaque push important

```bash
# Vérifiez vos changements
git status

# Exécutez les tests
npm run test          # (backend)
flutter test          # (Flutter)
npm run lint          # (admin-web)
npm run build         # (vérifier la build)

# Si tout est OK, poussez
git push origin
```

### Avant chaque Pull Request

```bash
# Mettez à jour votre branche
git fetch origin
git rebase origin/develop

# Poussez
git push --force-with-lease origin

# Vérifiez que la CI passe sur GitHub
# → Puis ouvrez la PR
```

---

## 🆘 COMMANDES DE SECOURS (Copier/Coller)

| But | Commande |
|-----|----------|
| Voir la branche courante | `git status` ou `git branch` |
| Voir toutes les branches | `git branch -a` |
| Mettre à jour develop | `git checkout develop && git pull origin develop` |
| Créer une feature | `git checkout -b feature/backend/nom-feature` |
| Voir vos modifications | `git status` |
| Ajouter tous les fichiers | `git add .` |
| Créer un commit | `git commit -m "feat(scope): description"` |
| Pousser une branche | `git push origin` |
| Synchroniser avec develop | `git fetch origin && git rebase origin/develop` |
| Continuer après conflit | `git add . && git rebase --continue` |
| Annuler un rebase | `git rebase --abort` |
| Pousser après rebase | `git push --force-with-lease origin` |
| Supprimer branche locale | `git branch -d feature/backend/nom` |
| Annuler tous les changements | `git checkout .` |
| Annuler un fichier spécifique | `git checkout -- chemin/fichier.ts` |

---

## 📝 RÉSUMÉ EN UNE PHRASE

```
Clone → develop à jour → feature branche → commit/push régulier 
→ rebase sur origin/develop → ouvrir PR → supprime après merge
```

---

## 🚨 URGENCE PRODUCTION ? (Hotfix)

**SEULEMENT si** : Bug critique en production (sécurité, paiement, auth)

```bash
# 1. Créer depuis main
git checkout main
git pull origin main
git checkout -b hotfix/payment-double-spending

# 2. Corriger (patch minimal !)
git commit -m "fix(payment): prevent double spending"

# 3. Tester
npm run test

# 4. PR vers main + ouvrir URGENCE
# 5. Après merge → backport vers develop (même jour)
git checkout develop
git pull origin develop
git cherry-pick <commit-hash>
git push origin
```

---

## 📞 BESOIN D'AIDE ?

- **Conflit Git** → Demandez à un senior
- **Rebase cassé** → `git rebase --abort` + demandez de l'aide
- **Branche supprimée par erreur** → Reflex : `git reflog`
- **Pas sûr(e)** → Ouvrez une PR en draft et demandez review

---

**Dernière mise à jour** : 6 juin 2026  
**Pour les juniors** : Ce guide est votre bible quotidienne. Gardez-le à portée de main ! 🚀

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
- `Fiers Artisans/lib/data/models/*`
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
FLUTTER_MODELS="Fiers Artisans/lib/data/models"
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
