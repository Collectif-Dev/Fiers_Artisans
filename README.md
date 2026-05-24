# Fiers Artisans - Source de verite projet

Ce `README.md` est le point d'entree documentaire principal du depot.
Il decrit l'etat actuel exploitable du monorepo, les commandes reelles,
la stack active, les scripts utiles, et les documents de gouvernance.

## Documents de reference

- `README.md`
  Vue d'ensemble du projet, architecture actuelle, commandes, tests, scripts
- `DOCUMENTATION_DOCKER.md`
  Runbook Docker complet : stack, nettoyage, volumes, diagnostic Portainer
- `SECURITY_ARCHITECTURE.md`
  Politique stricte de securite, preservation de l'architecture, verification factuelle, tests
- `RÈGLES GLOBALES.md`
  Pipeline IA, gouvernance multi-phases, validation humaine, anti-hallucination
- `globaliste/global_fusion.txt`
  Export fusionne du depot, genere par script, utile pour analyse externe

## Vue d'ensemble

Fiers Artisans est une marketplace multi-clients centree sur la mise en relation entre clients et artisans verifies, avec :

- recherche geolocalisee
- verification documentaire artisan
- abonnement artisan
- paiement Wave
- paiement manuel avec preuve de paiement
- chat temps reel
- notifications
- panel d'administration
- infrastructure Docker avec monitoring

## Monorepo actuel

| Dossier | Role principal | Stack |
|---|---|---|
| `backend/` | API metier, auth, realtime, paiements, admin API | NestJS 11, TypeORM, Mongoose |
| `fiers_artisans_app/` | Application mobile client + artisan | Flutter, Riverpod, Dio, GoRouter |
| `admin-web/` | Back-office d'administration | Next.js 16.2.6, React 19.2.6 |
| `infrastructure/` | Compose, Nginx, monitoring, scripts | Docker Compose, Prometheus, Grafana, Portainer |
| `globaliste/` | Exports documentaires consolides | `global_fusion.txt` genere |

## Demarrage rapide

### Mode recommande : stack dev Docker complete

Depuis la racine `~/mes_projets_dev/Fiers_Artisants/` :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  up -d --build
```

Verifier l'etat :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  ps
```

Arreter proprement :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  down --remove-orphans
```

### Mode prod-like local avec Nginx

Depuis la racine :

```bash
COMPOSE_PROFILES=prod-only docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.portainer.yml \
  up -d --build
```

### Mode hybride : infra Docker + apps lancees localement

Utiliser ce mode si tu veux debugger `backend/`, `admin-web/` ou Flutter hors conteneur tout en gardant les bases et services infra dans Docker.

Exemple :

```bash
# 1. Demarrer l'infra et les services de donnees
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  up -d postgres mongodb redis minio grafana portainer

# 2. Lancer les apps localement selon le besoin
cd backend && npm ci && npm run start:dev
cd admin-web && npm ci && npm run dev
cd fiers_artisans_app && flutter pub get && flutter run
```

## Stack technique actuelle

### Backend

- NestJS `^11.0.1`
- TypeORM `^0.3.28`
- Mongoose `^9.3.3`
- PostgreSQL 16 + PostGIS
- MongoDB 7
- Redis 7
- MinIO
- JWT + refresh tokens
- WebSocket + SSE admin

### Mobile Flutter

- Flutter SDK `^3.11`
- Riverpod
- GoRouter
- Dio
- EasyLocalization
- FlutterSecureStorage
- SharedPreferences
- Firebase Messaging

### Admin Web

- Next.js `16.2.6`
- React `19.2.6`
- Axios
- next-intl
- next-themes
- Recharts

### Infrastructure

- Docker Compose
- Nginx
- Prometheus
- Grafana
- Portainer

## Architecture fonctionnelle

### Roles metier principaux

- `CLIENT`
  recherche, consultation profil artisan, reviews, conversations
- `ARTISAN`
  verification, portfolio, abonnement, paiement, statut de visibilite
- `ADMIN`
  moderation, verifications, reviews, analytics, paiements manuels, logs

### Flux majeurs

- Authentification et verification telephone
- Verification artisan et moderation admin
- Abonnement artisan via Wave
- Paiement manuel avec upload de preuve et validation admin
- Chat temps reel et notifications
- Recherche geolocalisee et navigation profil artisan

## Repartition des donnees

| Systeme | Donnees principales |
|---|---|
| PostgreSQL | users, profils, categories, verification, reviews, subscriptions, payment_manual, payment_proofs |
| MongoDB | chat, conversations, notifications, analytics TTL, portfolio metadata, media metadata |
| Redis | OTP TTL, anti brute-force, sessions, pub/sub, rate limit, cache et synchronisations |
| MinIO | `portfolio`, `profiles`, `media`, `documents`, `payment-proofs` |

Regle de coherence :

- toute reference croisee entre PostgreSQL, MongoDB, Redis et MinIO doit etre validee cote backend
- aucun client ne doit considerer une action comme reussie sans confirmation du backend

## Backend

### Cible technique

- Prefixe API global : `/api/v1`
- Swagger : `/api/docs` hors prod
- `rawBody: true` pour verification webhook Wave
- Logging + format standard des reponses
- Filtre global d'erreurs
- Metriques Prometheus
- WebSocket + SSE admin

### Modules backend actuellement presents

- `health`
- `metrics`
- `auth`
- `users`
- `categories`
- `search`
- `verification`
- `reviews`
- `subscription`
- `payment-manual`
- `portfolio`
- `media`
- `notifications`
- `analytics`
- `chat`
- `admin`
- `dev`

### Endpoints backend majeurs

Auth :

- `POST /api/v1/auth/register/artisan`
- `POST /api/v1/auth/register/client`
- `POST /api/v1/auth/send-otp`
- `POST /api/v1/auth/verify-otp`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`

Recherche et catalogue :

- `GET /api/v1/search/artisans`
- `GET /api/v1/categories`
- `GET /api/v1/categories/:slug`

Verification, portfolio, reviews :

- `POST /api/v1/verification/submit`
- `GET /api/v1/verification/status`
- `GET /api/v1/portfolio`
- `POST /api/v1/portfolio`
- `PUT /api/v1/portfolio/:id`
- `DELETE /api/v1/portfolio/:id`
- `GET /api/v1/artisan/:id/portfolio`
- `POST /api/v1/reviews`
- `GET /api/v1/artisan/:id/reviews`

Subscription et paiement Wave :

- `POST /api/v1/subscription/initiate`
- `POST /api/v1/subscription/wave/webhook`
- `GET /api/v1/subscription/status`
- `GET /api/v1/subscription/providers`

Paiement manuel artisan :

- `POST /api/v1/payments/manual/initiate`
- `GET /api/v1/payments/manual/current`
- `GET /api/v1/payments/manual/:transactionId`
- `POST /api/v1/payments/manual/:transactionId/submit-proof`
- `GET /api/v1/payments/manual/:transactionId/proof/:proofId`

Paiement manuel admin :

- `GET /api/v1/admin/payment-proofs`
- `GET /api/v1/admin/payment-proofs/:id/details`
- `PATCH /api/v1/admin/payment-proofs/:id/validate`
- `PATCH /api/v1/admin/payment-proofs/:id/reject`
- `PATCH /api/v1/admin/payment-proofs/:id/reopen`
- `PATCH /api/v1/admin/payment-proofs/:id/mark-refunded`
- `DELETE /api/v1/admin/payment-proofs/:id`
- `GET /api/v1/admin/events`
- `GET /api/v1/admin/verifications/events`
- `GET /api/v1/admin/payment-events`

Temps reel :

- chat Socket.IO : namespace `/ws/chat`
- visibilite map : namespace `/ws/map-visibility`
- SSE admin pour dashboards, moderation et paiements

### Variables backend critiques

- PostgreSQL : `POSTGRES_*`, `DATABASE_POSTGRES_URL`
- MongoDB : `MONGO_*`, `DATABASE_MONGO_URL`
- Redis : `REDIS_*`, `REDIS_URL`
- MinIO : `MINIO_*`, `MINIO_BUCKET_*`, `MINIO_PAYMENT_PROOF_BUCKET`, `MINIO_PROFILES_BUCKET`
- JWT : `JWT_SECRET`, `JWT_REFRESH_SECRET`, `JWT_ACCESS_EXPIRATION`, `JWT_REFRESH_EXPIRATION`
- WhatsApp OTP : `WHATSAPP_API_*`, `WHATSAPP_OTP_TEMPLATE_NAME`
- Wave : `WAVE_API_*`, `WAVE_WEBHOOK_SECRET`, `WAVE_MERCHANT_ID`
- Paiement manuel : `PAYMENT_MANUAL_*`
- App : `NODE_ENV`, `APP_PORT`, `APP_URL`, `CORS_*`

### Commandes backend

```bash
cd backend
npm ci
npm run build
npm run start:dev
```

Tests backend :

```bash
cd backend
npm run build
npm run test
npm run test:e2e
```

## Frontend App (Flutter)

### Architecture Flutter

- `lib/config`
- `lib/core`
- `lib/data/models`
- `lib/data/repositories`
- `lib/providers`
- `lib/presentation/auth`
- `lib/presentation/client`
- `lib/presentation/artisan`
- `lib/presentation/chat`
- `lib/presentation/shared`

### Parcours et ecrans actuellement visibles dans le depot

- Auth : onboarding, login, register client, register artisan, OTP
- Client : recherche, detail artisan, reviews
- Artisan : dashboard, portfolio, verification, subscription, paiement manuel
- Shared : chat, notifications, settings

### Configuration reseau Flutter

Valeurs usuelles en emulateur Android :

- API : `http://10.0.2.2:3000/api/v1`
- WebSocket : `ws://10.0.2.2:3000`

Variables utilisees :

- `API_HOST`
- `API_PORT`
- `API_SCHEME`
- `WS_SCHEME`
- `API_BASE_PATH`

### Commandes Flutter

```bash
cd fiers_artisans_app
flutter pub get
flutter analyze
flutter test
flutter run
```

Build debug :

```bash
cd fiers_artisans_app
flutter build apk --debug
```

## Admin Web

### Architecture admin

- App Router Next.js
- `src/app/(dashboard)`
- `src/components`
- `src/lib`
- `src/providers`
- `src/messages`
- `src/types`

### Ecrans admin actuellement presents

- login
- dashboard
- analytics
- artisans
- clients
- logs
- payments
- reviews
- subscriptions
- verifications

### Commandes admin-web

```bash
cd admin-web
npm ci
npm run lint
npm run build
npm run dev
```

## Infrastructure

### Fichiers Compose utilises

- `infrastructure/docker-compose.yml`
- `infrastructure/docker-compose.dev.yml`
- `infrastructure/docker-compose.portainer.yml`

### Services Docker

| Service | Role | Ports host en dev |
|---|---|---|
| `api` | API NestJS | `3000` |
| `admin-web` | Back-office Next.js | `3002` |
| `postgres` | Base relationnelle | `5434` |
| `mongodb` | Base documentaire | `27018` |
| `redis` | Cache / pub-sub | `6380` |
| `minio` | Stockage objets | `9002` API, `9003` Console |
| `grafana` | Dashboards | `3001` |
| `portainer` | Gestion Docker | `9443` |
| `nginx` | Reverse proxy | desactive en dev, actif en `prod-only` |
| `prometheus` | Metrics | non expose sur l'hote dans le Compose actuel |

### Volumes persistants critiques

Ces volumes ne doivent jamais etre supprimes dans un nettoyage normal :

- `postgres_data`
- `mongo_data`
- `redis_data`
- `minio_data`
- `grafana_data`
- `prometheus_data`
- `portainer_data`

### Nettoyage Docker

Script principal :

```bash
./infrastructure/scripts/clean-docker.sh
./infrastructure/scripts/clean-docker.sh --all
```

Ce script :

- supprime les conteneurs arretes
- supprime les images dangling et, en `--all`, les images inutilisees
- purge completement le build cache inutilise
- supprime les reseaux orphelins
- supprime les volumes anonymes orphelins
- preserve les volumes nommes critiques

Ne jamais utiliser :

```bash
docker system prune -a --volumes
docker volume prune
```

Pour le runbook complet, voir `DOCUMENTATION_DOCKER.md`.

### Commandes infrastructure frequentes

Depuis la racine :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  logs -f api admin-web
```

Validation de configuration Compose :

```bash
cd infrastructure
docker compose --env-file ../.env \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  -f docker-compose.portainer.yml \
  config
```

## Observabilite et acces utiles

En dev local :

- API health : `http://localhost:3000/api/v1/health`
- API base : `http://localhost:3000/api/v1`
- Admin web : `http://localhost:3002`
- Grafana : `http://localhost:3001`
- MinIO API : `http://localhost:9002`
- MinIO Console : `http://localhost:9003`
- Portainer : `https://localhost:9443`

Prometheus :

- non expose directement sur l'hote dans les fichiers Compose actuels
- accessible via le reseau Docker interne

## Tests et quality gates

### Minimum attendu par zone

Backend :

```bash
cd backend
npm run build
npm run test
```

Backend critique ou contrat :

```bash
cd backend
npm run test:e2e
```

Admin web :

```bash
cd admin-web
npm run lint
npm run build
```

Flutter :

```bash
cd fiers_artisans_app
flutter analyze
flutter test
```

Infrastructure :

```bash
cd infrastructure
docker compose --env-file ../.env \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  -f docker-compose.portainer.yml \
  config
```

### Regle transverse

Si une modification touche plusieurs couches, ne pas s'arreter au test local de la couche modifiee.

Cas typiques exigeant une validation plus large :

- auth
- OTP
- paiement Wave
- paiement manuel
- verification artisan
- chat / notifications
- contrats API
- Docker / variables d'environnement

## Scripts utiles

Dans `infrastructure/scripts/` :

- `clean-docker.sh`
  nettoyage Docker securise, sans suppression des volumes critiques
- `backup.sh`
  script de backup oriente serveur
- `deploy.sh`
  script de deploiement oriente serveur
- `generate-portainer-stack.sh`
  generation d'une stack cible Portainer
- `generate_global_fusion.py`
  regeneration de `globaliste/global_fusion.txt`
- `reset_clean_environment.sh`
  reset de donnees dynamique avec garde-fous
- `setup_dev_stack_root.sh`
  aide setup stack dev
- `setup_dev_stack_user.sh`
  aide setup stack dev user

## Gouvernance IA et modification du code

Ce depot impose une gouvernance stricte pour toute intervention IA ou humaine outillee :

- `SECURITY_ARCHITECTURE.md`
  politique de securite, verification des affirmations, evaluation multi-scenarios, obligation de tests
- `RÈGLES GLOBALES.md`
  pipeline IA multi-phases, validation humaine, anti-hallucination, QA, CTO validation

Regles resumes :

- patch minimal uniquement
- jamais de refactor hors scope
- verification factuelle avant decision
- l'utilisateur peut se tromper
- tests proportionnes au risque obligatoires
- aucune decision d'architecture sans validation humaine

## Politique documentaire

- `README.md` doit rester la vue operationnelle actuelle du projet
- `DOCUMENTATION_DOCKER.md` porte le detail infra et nettoyage
- `SECURITY_ARCHITECTURE.md` porte la politique de preservation
- `RÈGLES GLOBALES.md` porte le pipeline IA
- `globaliste/global_fusion.txt` est genere automatiquement et ne doit pas etre edite a la main

Si tu modifies :

- un flux metier
- un contrat API
- une commande d'execution
- une topologie Docker
- un script critique
- une regle de gouvernance

alors la documentation associee doit etre mise a jour dans la meme chaine de travail.
