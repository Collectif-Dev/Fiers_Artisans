# 🚀 Guide Git — Développeurs Fiers Artisans (Version Opérationnelle)

> 📋 **Version** : 3.0 — 6 juin 2026  
> **Pour** : Développeurs junior et confirmé  
> **Objectif** : Workflow GitLab simple, pragmatique et sans casse-tête

---

## 📌 Périmètre de ce guide

Ce guide cible uniquement le dépôt GitLab utilisé par l'équipe :

```bash
git@gitlab.com:mellykelkun/Fiers_Artisants.git
```

Dans ce document, `origin` désigne le remote GitLab de l'équipe.

Le dépôt GitHub privé est hors workflow équipe. Il sert uniquement au lead pour maintenir une copie privée synchronisée avec GitLab. Les développeurs ne clonent pas, ne poussent pas et n'ouvrent pas de demande de fusion sur GitHub dans le cadre de ce guide.

### Synchronisation GitHub privée / GitLab équipe

Cette procédure est réservée au lead.

Objectif : garder les branches `develop` du dépôt GitHub privé et du dépôt GitLab équipe au même niveau.

Principe opérationnel :

1. travailler localement sur des branches `fix/*` côté dépôt GitHub privé
2. rebase la branche de travail sur le `develop` local GitHub
3. pousser le `develop` remote GitHub après validation
4. pousser le même `develop` vers le remote GitLab équipe
5. faire un pull du `develop` local GitLab pour réaligner l'environnement équipe

L'équipe ne doit pas appliquer cette procédure. Pour les développeurs, la source de travail reste GitLab et le flux normal reste : `develop` GitLab → branche feature/fix → MR GitLab → merge.

---

## 🎯 Règle d'Or — À RETENIR EN PRIORITÉ

```
1. ❌ JAMAIS coder directement sur develop, merge, vers_production ou main
2. ✅ Toujours créer une branche feature/fix à partir de develop
3. ✅ Toujours ouvrir une Merge Request (MR) GitLab pour fusionner
4. ✅ Toujours se synchroniser avec develop avant la MR
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
git clone git@gitlab.com:mellykelkun/Fiers_Artisants.git
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
git pull origin develop
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

### Pousser votre branche vers GitLab

```bash
git push origin feature/backend/auth-otp
```

**Ou après modification** :
```bash
git push origin
```

✅ Votre branche est maintenant sur GitLab !

---

## 4️⃣ METTRE À JOUR SA BRANCHE QUAND DEVELOP AVANCE

**Scénario** : Vous travaillez sur `feature/backend/auth-otp`, et d'autres MRs sont fusionnées dans `develop`.

### Ce qu'il faut faire AVANT d'ouvrir une MR

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

## 5️⃣ OUVRIR UNE MERGE REQUEST (MR)

### Sur GitLab

1. Allez sur le projet GitLab `mellykelkun/Fiers_Artisants`
2. Cliquez sur **Merge requests** → **New merge request**
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

4. Cliquez sur **Create merge request**

### Après ouverture de la MR

- La CI/CD se lance automatiquement
- Les reviewers sont notifiés
- Si la CI échoue → Corrigez et poussez des commits (la MR se met à jour seule)

---

## 6️⃣ APRÈS FUSION DE VOTRE MR

Une fois que votre MR est fusionnée dans `develop` :

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
# Ouvrez une MR sur GitLab
```

### Scénario B — Ma branche est en retard sur develop

```bash
git fetch origin
git rebase origin/develop
git push --force-with-lease origin
```

### Scénario C — Je dois corriger la MR après review

```bash
git add .
git commit -m "fix: address review comments"
git push origin
# La MR se met à jour automatiquement
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
| `git push origin develop` depuis votre PC | Injecte du code non revu | Ouvrir une MR GitLab |
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

### Avant chaque Merge Request

```bash
# Mettez à jour votre branche
git fetch origin
git rebase origin/develop

# Poussez
git push --force-with-lease origin

# Vérifiez que la CI passe sur GitLab
# → Puis ouvrez la MR
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
→ rebase sur origin/develop → ouvrir MR → supprime après merge
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

# 4. MR vers main + signalement URGENCE
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
- **Pas sûr(e)** → Ouvrez une MR en draft et demandez review

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

### 4️⃣ Rebase avant MR (OBLIGATOIRE)

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

### 5️⃣ Créer une Merge Request (MR)

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
Dev_2: feature/flutter/artisan-manual-payment       ├──→ develop (rebase + MR)
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
develop ────→ merge (MR + CI/CD complet)
```
**Checks obligatoires** :
- Backend : `npm run build && npm run test && npm run test:e2e`
- Flutter : `flutter analyze && flutter test`
- Admin-web : `npm run lint && npm run build`
- Infrastructure : `docker compose config` + `docker compose up -d`

### Phase 3 : QA & Tests (merge → vers_production)

```
merge ────→ vers_production (MR + tests E2E + charge + sécurité)
```
**Checks obligatoires** :
- Tests E2E end-to-end (auth + payment + chat + search)
- Tests de charge API (rate limiting, concurrent users)
- Scan sécurité (secrets, dépendances vulnérables)
- Validation manuelle QA lead

### Phase 4 : Production (vers_production → main)

```
vers_production ────→ main (MR + tag + déploiement)
```
**Actions automatiques** :
- Tag version : `git tag -a v1.2.3 -m "Release v1.2.3"`
- Déploiement CI/CD
- Notification équipe

---

## ⚠️ Règles de Gouvernance — À NE JAMAIS VIOLER

### ✅ À FAIRE

- [ ] **Toujours** créer une MR avant de merger vers `develop`
- [ ] **Toujours** rebase sur `develop` avant MR (jamais merge de develop dans feature)
- [ ] **Toujours** attendre l'approval avant de merger
- [ ] **Toujours** faire des commits atomiques et descriptifs (conventional commits)
- [ ] **Toujours** mettre à jour `develop` avant de créer une branche feature
- [ ] **Toujours** supprimer sa branche après merge
- [ ] **Toujours** vérifier que les contrats sont mergés avant les features métier
- [ ] **Toujours** exécuter les tests locaux avant de push (`npm run test`, `flutter analyze`)
- [ ] **Toujours** mettre à jour `.env.example` si nouvelle variable d'environnement
- [ ] **Toujours** créer une migration DB si schéma modifié

### ❌ À NE JAMAIS FAIRE

- [ ] **JAMAIS** merger directement sur `develop` sans MR
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
2. **Synchronisation** : Modifier `.env.example` ET les fichiers Compose sources concernes (`infrastructure/docker-compose*.yml`)
3. **Portainer** : Regenerer `infrastructure/stack.portainer-managed.yml` avec `infrastructure/scripts/generate-portainer-stack.sh` si une stack Portainer doit etre livree. Ne pas editer ce fichier genere a la main.
4. **Documentation** : Mettre a jour `README.md` et, si Docker est impacte, `infrastructure/FORMATION_DOCKER_POUR_EQUIPE.md`
5. **Notification** : Informer tous les développeurs du changement

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

### Configuration GitLab

- [ ] Protection de `main` : MR obligatoire, 2 approvals, signed commits
- [ ] Protection de `vers_production` : MR obligatoire, 1 approval QA
- [ ] Protection de `merge` : MR obligatoire, CI/CD passé
- [ ] Protection de `develop` : MR obligatoire, 1 approval, build passé
- [ ] Configuration des status checks (CI/CD)
- [ ] Configuration des webhooks (Slack/Teams notifications)
- [ ] Templates de MR (feature, fix, hotfix, release)
- [ ] Templates d'issues (bug, feature, technical debt)

### Configuration Locale (chaque développeur)

- [ ] Cloner le repo avec `develop` par défaut
- [ ] Configurer git hooks (pre-commit lint)
- [ ] Verifier les scripts disponibles dans `infrastructure/scripts/`
- [ ] Configurer l'éditeur (ESLint, Prettier, Flutter analyze)
- [ ] Tester le workflow : créer une branche test → MR → merge → supprimer

### Scripts et Outils

- [ ] `infrastructure/scripts/check-contracts-sync.sh` ✅
- [ ] `infrastructure/scripts/validate-mr.sh` ✅
- [ ] `infrastructure/scripts/clean-docker.sh` ✅
- [ ] `infrastructure/scripts/generate-portainer-stack.sh` ✅
- [ ] Pipeline GitLab CI
- [ ] Pre-commit hooks (husky + lint-staged)

---

## 📚 Scripts Utilitaires

### Creation de branche

Aucun script `create-feature-branch.sh` n'est present dans le depot actuel. Creer les branches manuellement:

```bash
git checkout develop
git pull origin develop
git checkout -b feature/backend/payment-manual-lifecycle
```

### `check-contracts-sync.sh`

```bash
./infrastructure/scripts/check-contracts-sync.sh
```

Verifie les contrats sensibles entre backend, Flutter et admin-web: modules metier, modeles, types, routes, enums, evenements WebSocket et SSE.

### `validate-mr.sh`

```bash
./infrastructure/scripts/validate-mr.sh
```

Quality gate local avant MR. Le script lance les controles disponibles sans installer automatiquement les dependances:
- contrats multi-couches
- tests et build backend si `backend/node_modules` existe
- lint et build admin-web si `admin-web/node_modules` existe
- `flutter analyze` et `flutter test` si Flutter est disponible

### Scripts Docker et serveur

```bash
./infrastructure/scripts/clean-docker.sh
./infrastructure/scripts/clean-docker.sh --all
./infrastructure/scripts/generate-portainer-stack.sh
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
6. Création de la release GitLab avec changelog

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

# 4. MR vers main (URGENT — contacter CTO)
# 5. MR vers develop (backport — même jour)
```

### Règles

- **Durée max** : 4 heures (création → merge)
- **Approval** : 1 approval + CTO (peut bypass en urgence)
- **Backport** : Obligatoire vers `develop` dans les 24h
- **Documentation** : Post-mortem dans les 48h

---

## 📋 Templates de Merge Request

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

## 📘 Dictionnaire Git/GitLab — Débutant à Pro

Cette section sert d'anti-sèche pédagogique. Elle explique les commandes Git les plus fréquentes, leur usage, les scénarios typiques et les réflexes de sécurité.

### 🔰 Niveau 1 — Les fondamentaux

#### 1. `git init`

**Fonction** : créer un dépôt Git local dans un dossier existant.

**Scénario** : tu commences un nouveau projet from scratch.

```text
mon-projet/  -- git init -->  mon-projet/.git/
dossier normal                depot Git local
```

```bash
mkdir mon-super-projet
cd mon-super-projet
git init
```

#### 2. `git clone`

**Fonction** : copier un dépôt distant en local.

**Scénario** : tu arrives sur un projet existant et tu dois le récupérer.

```text
GitLab distant  -- git clone -->  copie locale avec .git
```

```bash
git clone https://gitlab.com/user/repo.git
git clone git@gitlab.com:user/repo.git
```

#### 3. `git status`

**Fonction** : voir l'état des fichiers.

**Scénario** : tu ne sais plus où tu en es.

```text
modifie -- git add --> stage -- git commit --> historique
```

```bash
git status
```

#### 4. `git add`

**Fonction** : ajouter des modifications dans la zone de staging.

**Scénario** : tu as modifié des fichiers et tu veux préparer un commit.

```bash
git add index.html
git add .
git add '*.js'
git add -p
```

`git add -p` permet de choisir les changements morceau par morceau.

#### 5. `git commit`

**Fonction** : enregistrer les modifications stagées dans l'historique.

**Scénario** : ta correction ou ta feature est prête.

```bash
git commit -m "feat: ajout du formulaire de connexion"
git commit -am "fix: correction typo"
```

Convention recommandée :

```text
type(scope): description courte
```

Types fréquents :

- `feat` : nouvelle fonctionnalité
- `fix` : correction de bug
- `docs` : documentation
- `refactor` : réorganisation sans changement fonctionnel
- `test` : tests
- `chore` : maintenance

#### 6. `git push`

**Fonction** : envoyer les commits locaux vers le dépôt distant.

**Scénario** : tu as commité en local et tu veux partager avec l'équipe.

```bash
git push origin main
git push
git push -u origin feature/login
```

`-u` configure le lien entre la branche locale et la branche distante pour les prochains `git push`.

#### 7. `git pull`

**Fonction** : récupérer les commits distants et les intégrer au local.

**Scénario** : un collègue a poussé du travail, tu veux le récupérer.

```bash
git pull origin main
git pull --rebase
```

Réflexe avant de commencer une tâche :

```bash
git checkout main
git pull origin main
git checkout -b ma-feature
```

#### 8. `git branch`

**Fonction** : gérer les branches.

**Scénario** : tu veux isoler ton travail.

```bash
git branch
git branch -a
git branch feature/paiement
git branch -d feature/login
git branch -D feature/login
```

`-d` supprime une branche déjà fusionnée. `-D` force la suppression.

#### 9. `git checkout` / `git switch`

**Fonction** : changer de branche.

**Scénario** : tu dois passer sur une autre branche ou créer une branche.

```bash
git checkout feature/login
git switch feature/login
git switch -c nouvelle-branche
git checkout -b nouvelle-branche
```

`git switch` est la syntaxe moderne pour changer de branche.

#### 10. `git merge`

**Fonction** : fusionner une branche dans une autre.

**Scénario** : ta feature est terminée et doit être intégrée.

```bash
git checkout main
git merge feature/login
```

En cas de conflit :

```bash
git add .
git commit
```

### 🟡 Niveau 2 — Intermédiaire

#### 11. `git stash`

**Fonction** : mettre de côté des modifications non commitées.

**Scénario** : tu travailles sur une feature, mais un hotfix urgent arrive.

```bash
git stash
git stash list
git stash pop
git stash apply stash@{1}
git stash drop stash@{0}
```

#### 12. `git rebase`

**Fonction** : rejouer des commits sur une nouvelle base.

**Scénario** : ta branche a divergé et tu veux un historique linéaire.

```bash
git checkout feature/login
git rebase main
git rebase --continue
git rebase --abort
```

Règle de prudence : ne pas rebase une branche partagée sans coordination. Après un rebase d'une branche déjà poussée, utiliser `--force-with-lease`, jamais `--force` brut.

#### 13. `git reset`

**Fonction** : revenir en arrière dans l'historique local.

**Scénario** : tu as fait un mauvais commit local.

```bash
git reset --soft HEAD~1
git reset --mixed HEAD~1
git reset --hard HEAD~1
```

- `--soft` : annule le commit, garde les fichiers stagés
- `--mixed` : annule le commit et le staging
- `--hard` : annule tout, y compris les modifications locales

`--hard` est destructeur. Ne pas l'utiliser sans être certain de ce qui sera perdu.

#### 14. `git revert`

**Fonction** : créer un nouveau commit qui annule un commit précédent.

**Scénario** : tu dois annuler un commit déjà poussé.

```bash
git revert abc123
git revert HEAD
```

`revert` est plus sûr que `reset` pour du travail partagé.

#### 15. `git log`

**Fonction** : voir l'historique des commits.

```bash
git log --oneline
git log --graph --oneline --all
git log --author="Jean"
git log --since="2024-01-01"
git log -p
git log --grep="fix"
```

#### 16. `git cherry-pick`

**Fonction** : appliquer un commit précis sur ta branche.

**Scénario** : un fix existe déjà ailleurs et tu en as besoin ici.

```bash
git checkout feature/ma-branche
git cherry-pick abc123
```

#### 17. `git diff`

**Fonction** : voir les différences entre versions.

```bash
git diff
git diff --staged
git diff main..feature
git diff abc123..def456
```

### 🔴 Niveau 3 — Pro

#### 18. Merge Request

**Fonction** : demander la revue et l'intégration d'une branche.

Workflow type :

```bash
git checkout main
git pull origin main
git checkout -b feature/mon-truc
git add .
git commit -m "feat: ma super feature"
git push -u origin feature/mon-truc
```

Ensuite, créer la Merge Request sur GitLab, faire relire, corriger si nécessaire, puis fusionner via l'interface.

#### 19. `git fetch` + `git merge`

**Fonction** : récupérer les changements distants sans les intégrer automatiquement.

**Scénario** : tu veux voir ce qui a changé avant de fusionner.

```bash
git fetch origin
git diff main..origin/main
git merge origin/main
```

#### 20. Squash de commits

**Fonction** : fusionner plusieurs commits en un seul avant merge.

**Scénario** : ta branche contient beaucoup de commits temporaires.

```bash
git rebase -i HEAD~4
```

Dans l'éditeur :

```text
pick abc123 feat: ma feature
squash def456 wip
squash ghi789 fix typo
squash jkl012 wip final
```

#### 21. `git bisect`

**Fonction** : trouver le commit qui a introduit un bug.

```bash
git bisect start
git bisect bad HEAD
git bisect good v1.0
git bisect good
git bisect bad
git bisect reset
```

Git teste par dichotomie jusqu'à identifier le commit suspect.

#### 22. `git reflog`

**Fonction** : voir les mouvements récents de `HEAD`, même ceux qui ne sont plus visibles dans l'historique classique.

**Scénario** : tu as fait un reset et tu veux récupérer un commit.

```bash
git reflog
git checkout def456
git switch -c recuperation
```

`reflog` est une commande de sauvetage locale très utile.

#### 23. Submodules

**Fonction** : inclure un autre dépôt Git dans ton projet.

```bash
git submodule add git@gitlab.com:team/lib.git libs/ma-lib
git submodule update --init --recursive
```

À utiliser avec prudence : les submodules ajoutent une dépendance Git à maintenir explicitement.

#### 24. Hooks Git

**Fonction** : automatiser des vérifications avant commit ou push.

Exemple de hook `pre-commit` :

```bash
#!/bin/sh
npm run lint
if [ $? -ne 0 ]; then
  echo "Lint failed, commit annule"
  exit 1
fi
```

#### 25. Workflow GitFlow simplifié

```text
main      -----o-----------o----- releases stables
             \           /
develop      o--o--o--o--o--o--- integration continue
               \    \    /
feature/a       o--o ----
feature/b             o--
hotfix    ----------------o------ urgence depuis main
```

Principes :

- `main` garde les versions stables
- `develop` centralise l'intégration
- `feature/*` isole les nouvelles fonctionnalités
- `hotfix/*` part de `main` pour corriger une urgence

#### 26. GitLab CLI (`glab`)

```bash
glab auth login
glab mr create --title "feat: ..."
glab mr checkout 45
glab mr merge 45
glab ci status
glab ci trace
```

### 📊 Cycle de vie d'un fichier

```text
                    git add             git commit
modifie ----------------------------> stage ----------------> historique
  ^                                     |                       |
  |                                     | git reset --mixed     | git reset --soft
  |                                     v                       v
  +-------------------------- fichiers modifies <--------- commit annule

modifications -- git stash --> stash -- git stash pop --> restaure
```

### 🎯 Anti-sèche rapide

| Action | Commande |
|--------|----------|
| Nouveau projet | `git init` |
| Récupérer un projet | `git clone URL` |
| Voir l'état | `git status` |
| Préparer un commit | `git add .` |
| Commit | `git commit -m "message"` |
| Envoyer | `git push origin main` |
| Récupérer | `git pull` |
| Nouvelle branche | `git switch -c nom` |
| Changer de branche | `git switch nom` |
| Fusionner | `git merge branche` |
| Mettre de côté | `git stash` |
| Restaurer stash | `git stash pop` |
| Annuler dernier commit local | `git reset --soft HEAD~1` |
| Historique compact | `git log --oneline` |
| Sauvetage | `git reflog` |

---

## 📚 Ressources Complémentaires

- [Git Flow Documentation](https://git-flow.readthedocs.io/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- `SECURITY_ARCHITECTURE.md` — Politique de sécurité et préservation
- `instructions-agent-ia-v2.md` — Guide operationnel agent IA

---

## 📝 Journal des Modifications

| Version | Date | Auteur | Changements |
|---------|------|--------|-------------|
| 1.0 | 2026-06-02 | Équipe Développement | Version initiale — workflow pyramidal basique |
| 2.0 | 2026-06-02 | CTO | Architecture complète — branches par domaine — règles de gouvernance — gestion des conflits — scripts utilitaires — procédure hotfix |

---

**Dernière mise à jour** : 2 juin 2026
**Responsable** : CTO — Équipe Développement Fiers Artisans
