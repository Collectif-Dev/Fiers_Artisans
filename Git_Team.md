# 🚀 Workflow Git - Structure des Branches Équipe

## 📋 Vue d'ensemble

Ce document définit la structure de branches et le workflow pour une équipe de **4 développeurs** travaillant sur le projet **Fiers Artisants**.

---

## 📦 Structure Complète des Branches par Domaine

### AUTHENTICATION
```
├── feature/auth/login-oauth (Dev_1)
├── feature/auth/jwt-refresh (Dev_2)
└── feature/auth/2fa-setup (Dev_3)
```

### PAYMENT
```
├── feature/payment/stripe-integration (Dev_1)
├── fix/payment/refund-logic (Dev_2)
└── feature/payment/manual-payment (Dev_3)
```

### UI FRONTEND
```
├── feature/ui/responsive-mobile (Dev_1)
├── feature/ui/dark-mode (Dev_2)
└── fix/ui/button-accessibility (Dev_3)
```

### BACKEND/API
```
├── feature/api/search-optimization (Dev_1)
├── fix/api/rate-limiting (Dev_2)
└── feature/api/webhook-events (Dev_3)
```

### DATABASE
```
├── feature/db/mongodb-migration (Dev_1)
└── fix/db/query-performance (Dev_2)
```

### DOCKER
```
├── feature/docker/multi-stage-build (Dev_1)
├── fix/docker/image-optimization (Dev_2)
└── feature/docker/compose-services (Dev_3)
```

### RÉSEAU
```
├── feature/network/load-balancer (Dev_2)
├── fix/network/nginx-config (Dev_3)
└── feature/network/ssl-cert-automation (Dev_1)
```

### DEVOPS
```
├── feature/devops/ci-cd-github-actions (Dev_1)
├── fix/devops/deployment-script (Dev_2)
└── feature/devops/monitoring-setup (Dev_3)
```

---

## 🔄 Workflow Pyramidal - Flux des Merges

```
TOUTES LES BRANCHES feature/* et fix/*
        ↓
        ↓ (PR + Code Review)
        ↓
    develop (INTÉGRATION)
        ↓
        ↓ (Tests QA)
        ↓
    merge (QA/TESTS)
        ↓
        ↓ (Validation Staging)
        ↓
    vers_production (STAGING)
        ↓
        ↓ (Déploiement Production)
        ↓
    main (PRODUCTION) 🚀
```

---

## 📌 Conventions de Nommage

### Branches Feature
```
feature/<domaine>/<description-en-kebab-case>
```
**Exemples** :
- `feature/auth/login-oauth`
- `feature/payment/stripe-integration`
- `feature/ui/responsive-mobile`

### Branches Fix
```
fix/<domaine>/<description-en-kebab-case>
```
**Exemples** :
- `fix/payment/refund-logic`
- `fix/api/rate-limiting`
- `fix/ui/button-accessibility`

---

## 🛠️ Hiérarchie des Branches

| Branche | Rôle | Protégée | Merges autorisés depuis |
|---------|------|---------|------------------------|
| `main` | 🚀 Production | ✅ Oui | `vers_production` uniquement |
| `vers_production` | 🔍 Staging | ✅ Oui | `merge` uniquement |
| `merge` | 🧪 QA/Tests | ✅ Oui | `develop` uniquement |
| `develop` | 🔄 Intégration | ✅ Oui | `feature/*` et `fix/*` uniquement |
| `feature/*` | 👨‍💻 Dev | ❌ Non | Ouvert (chaque dev) |
| `fix/*` | 🔧 Dev | ❌ Non | Ouvert (chaque dev) |

---

## 📝 Processus de Travail - Par Développeur

### 1️⃣ Créer sa branche feature/fix
```bash
git checkout develop
git pull origin develop
git checkout -b feature/auth/login-oauth
```

### 2️⃣ Travailler et commiter
```bash
git add .
git commit -m "feat(auth): add OAuth login flow"
git push origin feature/auth/login-oauth
```

### 3️⃣ Créer une Pull Request (PR)
- Vers : `develop`
- Titre : `[FEATURE] Auth: Add OAuth login`
- Description : Détails des changements

### 4️⃣ Code Review & Merge
- Minimum 1 approval requis
- ✅ Merger vers `develop` une fois approuvé
- 🗑️ Supprimer la branche après merge

---

## 🔀 Flux de Promotion des Branches

### Phase 1 : Développement
```
Dev_1: feature/auth/login-oauth ────┐
Dev_2: feature/payment/stripe       ├──→ develop
Dev_3: fix/ui/button-access         │
Dev_4: feature/db/mongodb           ┘
```

### Phase 2 : Intégration & Tests
```
develop ────→ merge (Intégration + Tests QA)
```

### Phase 3 : Staging
```
merge ────→ vers_production (Validation Staging)
```

### Phase 4 : Production
```
vers_production ────→ main 🚀 (Déploiement Production)
```

---

## ⚠️ Règles Importantes

✅ **À FAIRE** :
- Créer une PR avant de merger vers `develop`
- Attendre l'approval avant de merger
- Faire des commits atomiques et descriptifs
- Mettre à jour `develop` avant de créer une branche feature
- Supprimer sa branche après merge

❌ **À NE PAS FAIRE** :
- Merger directement sur `develop` sans PR
- Pusher directement sur `main` ou `vers_production`
- Créer des branches hors de la structure définie
- Commiter sur `develop` ou `main` directement
- Oublier de synchroniser sa branche

---

## 📊 Assignation des Domaines (Exemple)

| Domaine | Dev_1 | Dev_2 | Dev_3 | Dev_4 |
|---------|-------|-------|-------|-------|
| Authentication | ✅ | | | |
| Payment | ✅ | ✅ | ✅ | |
| UI Frontend | ✅ | ✅ | ✅ | |
| Backend/API | ✅ | ✅ | ✅ | |
| Database | ✅ | ✅ | | |
| Docker | ✅ | ✅ | ✅ | |
| Réseau | ✅ | ✅ | ✅ | |
| DevOps | ✅ | ✅ | ✅ | |

---

## 🚀 Checklist de Mise en Place

- [ ] Tous les devs clonent le repo avec la branche `develop`
- [ ] Chaque dev crée ses branches feature/fix personnelles
- [ ] Configurer la protection des branches (`main`, `vers_production`, `merge`, `develop`)
- [ ] Mettre en place les code reviews sur GitHub/GitLab
- [ ] Documenter les règles de commit (type, format)
- [ ] Mettre en place des tests automatisés (CI/CD)
- [ ] Former l'équipe au workflow

---

## 📚 Ressources Complémentaires

- [Git Flow Documentation](https://git-flow.readthedocs.io/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)

---

**Dernière mise à jour** : 2 juin 2026  
**Responsable** : Équipe Développement
