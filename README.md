# Fiers Artisans - Source de verite projet

Ce `README.md` est l'unique source de verite documentaire du depot.

Document critique conserve a part (ne pas supprimer/deplacer):
- `SECURITY_ARCHITECTURE.md`

## Vue d'ensemble

Fiers Artisans est une marketplace mobile qui met en relation des clients avec des artisans verifies/certifies, avec recherche geolocalisee, messagerie temps reel, verification documentaire et abonnement artisan.

Composants du monorepo:
- `backend/` : API NestJS (REST + WebSocket + SSE admin)
- `fiers_artisans_app/` : app Flutter (client + artisan)
- `admin-web/` : panel admin Next.js
- `infrastructure/` : Docker Compose, Nginx, monitoring, scripts de deploiement

## Architecture globale

### Stack principale

- Backend: NestJS 11, TypeScript, TypeORM, Mongoose
- BDD relationnelle: PostgreSQL 16 + PostGIS
- BDD documentaire: MongoDB 7
- Cache/pub-sub: Redis 7
- Stockage objets: MinIO (S3-compatible)
- Front mobile: Flutter 3.41+, Riverpod, Dio, GoRouter
- Front admin: Next.js 16, React 19, Axios
- Infra: Docker Compose, Nginx, Prometheus, Grafana

### Repartition des donnees

- PostgreSQL: users, profils, categories, verification, reviews, subscriptions, payments
- MongoDB: chat, conversations, notifications (TTL), analytics (TTL), portfolio, metadonnees media
- Redis: OTP (TTL), anti brute-force OTP/PIN, sessions, pub/sub temps reel
- MinIO:
	- `portfolio` : images portfolio artisans (public)
	- `profiles` : photos de profil utilisateurs (public)
	- `media` : pieces jointes de chat, medias conversations (prive - JWT)
	- `documents` : pieces d'identite, diplomes (prive - JWT + admin)
	- `payment-proofs` : preuves de paiement manuel (prive - JWT + admin)

Regle de coherence cross-bases:
- toute reference PostgreSQL stockee en MongoDB doit etre validee cote backend avant insertion.

## Backend

### Cible technique

- Prefixe global API: `/api/v1`
- Swagger (hors prod): `/api/docs`
- `rawBody: true` active pour verification webhook Wave
- Intercepteurs globaux: logging + format standard des reponses
- Filtre global: format standard des erreurs
- CORS configurable via `CORS_ORIGINS`

### Modules fonctionnels

- `health`, `metrics`
- `auth` (register/login/send-otp/verify-otp/refresh/logout)
- `users`
- `categories`
- `search`
- `verification`
- `reviews`
- `subscription` (initiation + webhook Wave)
- `portfolio`
- `media`
- `notifications` (interne)
- `analytics` (interne)
- `chat` (REST + gateway Socket.IO)
- `admin` (dashboard, moderation, analytics + flux SSE)

### Routes majeures

Auth:
- `POST /api/v1/auth/register/artisan`
- `POST /api/v1/auth/register/client`
- `POST /api/v1/auth/send-otp`
- `POST /api/v1/auth/verify-otp`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`

Recherche / metier:
- `GET /api/v1/search/artisans`
- `GET /api/v1/categories`
- `GET /api/v1/categories/:slug`

Verification / portfolio / reviews:
- `POST /api/v1/verification/submit`
- `GET /api/v1/verification/status`
- `GET /api/v1/portfolio`
- `POST /api/v1/portfolio`
- `PUT /api/v1/portfolio/:id`
- `DELETE /api/v1/portfolio/:id`
- `GET /api/v1/artisan/:id/portfolio`
- `POST /api/v1/reviews`
- `GET /api/v1/artisan/:id/reviews`

Subscription / paiement:
- `POST /api/v1/subscription/initiate`
- `POST /api/v1/subscription/wave/webhook`
- `GET /api/v1/subscription/status`
- `GET /api/v1/subscription/providers`

Admin:
- `GET /api/v1/admin/dashboard`
- `GET /api/v1/admin/verifications/pending`
- `PUT /api/v1/admin/verifications/:id`
- `GET /api/v1/admin/artisans`
- `GET /api/v1/admin/analytics`
- `GET /api/v1/admin/events` (SSE)
- `GET /api/v1/admin/verifications/events` (fallback SSE)

### Temps reel

- Chat Socket.IO: namespace `/ws/chat`
- Visibilite map: namespace `/ws/map-visibility`
- Admin SSE: dashboard + moderation
- Notifications push: FCM (service interne, pas d'endpoint public dedie)

### Config et variables d'environnement (backend)

Namespaces de config:
- `app`, `database.postgres`, `database.mongo`, `redis`, `jwt`, `minio`, `whatsapp`, `wave`, `providers`

Variables critiques:
- PostgreSQL: `POSTGRES_*`, `DATABASE_POSTGRES_URL`
- MongoDB: `MONGO_*`, `DATABASE_MONGO_URL`
- Redis: `REDIS_*`, `REDIS_URL`
- MinIO: `MINIO_*` + buckets (`MINIO_BUCKET_PORTFOLIO`, `MINIO_BUCKET_DOCUMENTS`, `MINIO_BUCKET_MEDIA`, `MINIO_PAYMENT_PROOF_BUCKET`)
- JWT: `JWT_SECRET`, `JWT_REFRESH_SECRET`, `JWT_ACCESS_EXPIRATION`, `JWT_REFRESH_EXPIRATION`
- OTP WhatsApp: `WHATSAPP_API_*`, `WHATSAPP_OTP_TEMPLATE_NAME`
- Paiement Wave: `WAVE_API_*`, `WAVE_WEBHOOK_SECRET`, `WAVE_MERCHANT_ID`
- Paiement manuel MVP: `PAYMENT_MANUAL_AMOUNT_FCFA`, `PAYMENT_MANUAL_EXPIRY_HOURS`, `PAYMENT_MANUAL_RECIPIENT_NUMBER`, `PAYMENT_MANUAL_UPLOADS_PER_DAY_LIMIT`, `PAYMENT_MANUAL_SUBMIT_BURST_LIMIT`, `PAYMENT_MANUAL_SUBMIT_BURST_TTL_SECONDS`, `PAYMENT_MANUAL_EXPIRE_BATCH_LOOPS`, `PAYMENT_MANUAL_DISABLE_REDIS_RATE_LIMIT`
- Application: `NODE_ENV`, `APP_PORT`, `APP_URL`, `CORS_ORIGINS`

Flags providers documentes:
- OTP: `WHATSAPP` actif, `SMS_TWILIO` optionnel (feature flag)
- Paiement: `WAVE` actif, `ORANGE_MONEY` et `MTN_MOMO` prepares mais desactives

### Securite backend

- JWT access token: 15 min
- JWT refresh token: 30 jours (secret distinct)
- OTP: code 6 chiffres, TTL 5 min, anti brute-force
- Wave webhook: signature HMAC obligatoire + idempotence transaction
- Validation DTO stricte (`whitelist` + `forbidNonWhitelisted`)
- Helmet + CORS restrictif + rate limit (30 req / 60s)
- MinIO non expose en prod (signed URLs via backend)

### Donnees de seed

Commande:
```bash
cd backend
npx ts-node src/database/seeds/run-seed.ts
```

Le seed insere 16 categories / 48 sous-categories:
- Batiment/Construction, Menuiserie/Ebenisterie, Electricite, Plomberie
- Peinture/Decoration, Architecture/Ingenierie, Textile/Mode, Metallurgie
- Fleuriste/Paysagisme, Automobile, Services creatifs, Services domestiques
- Beaute/Bien-etre, Restauration, Tech/Numerique, Ameublement

### Lancement backend local

```bash
cd backend
npm ci
npm run start:dev
```

Scripts utiles:
- `npm run start`
- `npm run start:dev`
- `npm run start:debug`
- `npm run build`
- `npm run test`
- `npm run test:e2e`
- `npm run lint`

## Frontend App (Flutter)

### Stack et architecture

- Flutter 3.41.4+, Dart 3.11+
- Riverpod (state management)
- GoRouter (navigation)
- Dio (HTTP + refresh token automatique)
- EasyLocalization (FR/EN)
- FlutterSecureStorage + SharedPreferences
- CachedNetworkImage, Geolocator, animations (Lottie/Shimmer)

Structure logique:
- `config/`
- `core/` (network, storage, utils)
- `data/` (models, repositories)
- `providers/`
- `presentation/`

### Parcours et ecrans couverts

- Auth: splash, onboarding, login, register artisan/client, OTP
- Client: dashboard, recherche, profil artisan, avis
- Artisan: dashboard, portfolio, verification, abonnement
- Shared: conversations, chat, notifications, settings

### Navigation principale

Routes auth:
- `/`, `/onboarding`, `/login`, `/register`, `/register/artisan`, `/register/client`, `/otp`

Shell client:
- `/client`, `/client/search`, `/client/artisan/:userId`, `/client/review/:artisanId`

Shell artisan:
- `/artisan`, `/artisan/portfolio`, `/artisan/verification`, `/artisan/subscription`

Routes partagees:
- `/chat`, `/chat/:conversationId`, `/notifications`, `/settings`

Bottom navigation (app):
- Accueil/Dashboard, Messages, Notifications, Parametres

### Theme et i18n

- Theme sombre et clair (palette noire/doree en priorite)
- Police principale: Inter
- Locales: FR (`fr.json`) et EN (`en.json`)
- Changement langue/theme accessible onboarding + settings

### Configuration reseau Flutter

- Base attendue en emulateur Android: `http://10.0.2.2:3000/api/v1`
- WebSocket: `ws://10.0.2.2:3000`
- Variables utilisees: `API_HOST`, `API_PORT`, `API_SCHEME`, `WS_SCHEME`, `API_BASE_PATH`

### Lancement Flutter local

```bash
cd fiers_artisans_app
flutter pub get
flutter analyze
flutter run
```

Build debug APK:
```bash
flutter build apk --debug
```

## Admin Web

### Stack et principes

- Next.js 16 (App Router) + React 19
- Port application: `3002`
- Client API centralise: `src/lib/api.ts`
- Auth admin: token + refresh token en `localStorage`
- Dashboard temps reel: SSE puis fallback polling 30s

### Ecrans admin

- `/login`
- `/` (dashboard)
- `/verifications`
- `/artisans`
- `/clients`
- `/subscriptions`
- `/reviews`
- `/logs`
- `/analytics`

### Variables utiles admin-web

- `NEXT_PUBLIC_API_URL`
- `NEXT_PUBLIC_API_PORT` (defaut `3000`)
- `NEXT_PUBLIC_API_BASE_PATH` (defaut `/api/v1`)
- `NEXT_PUBLIC_DEFAULT_LOCALE` (defaut `fr`)

### Lancement admin-web local

```bash
cd admin-web
npm ci
npm run dev
```

URL locale: `http://localhost:3002`

## Infrastructure

### Compose et services

Fichiers utilises:
- `infrastructure/docker-compose.yml`
- `infrastructure/docker-compose.dev.yml`

Demarrage complet dev (depuis racine):
```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml up -d --build
```

Services et acces dev:
- API: `http://localhost:3000/api/v1`
- Health API: `http://localhost:3000/api/v1/health`
- Admin web: `http://localhost:3002`
- Grafana: `http://localhost:3001`
- MinIO API (dev): `http://localhost:9002`
- MinIO Console (dev): `http://localhost:9003`

Isolation de ports documentee pour eviter conflits locaux:
- PostgreSQL `5434:5432`
- MongoDB `27018:27017`
- Redis `6380:6379`

En production:
- Exposition hote limitee a Nginx (`80/443`)
- MinIO reste interne au reseau Docker
- Nginx route `/` -> `admin-web` et `/api/` -> backend
- conserver `ADMIN_WEB_API_URL=/api/v1` pour eviter CORS

### Logs et verification rapide

Logs stack:
```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml logs -f api admin-web nginx
```

Logs cibles:
```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml logs -f admin-web
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml logs -f api
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml logs -f nginx
```

Etat des conteneurs:
```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml ps
```

### Portainer (option)

Demarrage:
```bash
docker compose -f infrastructure/docker-compose.portainer.yml up -d
```

Acces:
- `https://localhost:9443`

Migration vers stack Portainer native:
1. `infrastructure/scripts/generate-portainer-stack.sh`
2. `docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml down --remove-orphans`
3. Importer `infrastructure/stack.portainer-managed.yml` dans Portainer (`Stacks -> Add stack`)

## Flux metier essentiels

### Inscription artisan

1. Flutter -> `POST /auth/register/artisan`
2. Backend cree `User` + `ArtisanProfile` (PostgreSQL)
3. Event admin temps reel `ARTISAN_REGISTERED`

### Verification artisan

1. Artisan soumet documents
2. Backend stocke metadonnees + fichiers
3. Admin valide/rejette via `/admin/verifications/*`
4. Notifications + events temps reel

### Abonnement

1. `POST /subscription/initiate`
2. Checkout Wave
3. `POST /subscription/wave/webhook`
4. Verification signature + idempotence
5. Activation abonnement et visibilite profil

### Chat

1. REST pour conversation/historique
2. Socket `/ws/chat` pour echanges live
3. Redis pub/sub pour diffusion multi-instance

## Vision produit et roadmap (consolidation implementation_plan.md)

Cette section reprend les informations structurantes issues du plan historique.

### Positionnement

- Acteurs: Artisan, Client, Admin
- Modele economique: abonnement artisan `5 000 FCFA / mois` (Wave)
- Regle business cle: sans abonnement actif, profil non visible dans les recherches
- Perimetre geographique: Phase 1 Cote d'Ivoire, extension Afrique de l'Ouest ensuite

### Fonctionnalites a valeur ajoutee (historique)

- Mode urgence
- Badges de confiance (Verifie, Certifie, Top Artisan)
- Dashboard artisan KPI
- Zones de couverture
- Alertes de proximite
- Futures extensions: Orange Money, MTN MoMo, prise de rendez-vous, paiement in-app client, devis en ligne

### Planning de reference (historique)

- Phase 1 Fondations (2-3 semaines): infra + auth OTP
- Phase 2 Core (3-4 semaines): profils, verification, categories, portfolio, recherche
- Phase 3 Monetisation (1-2 semaines): Wave + webhook
- Phase 4 Communication (2-3 semaines): chat + notifications
- Phase 5 Mobile (4-6 semaines): app complete
- Phase 6 Admin & Launch (3-4 semaines): panel admin, tests, CI/CD, deploy
- Phase 7 HA (post-launch): warm standby
- Phase 8 Extensions: features futures

### Strategie tests (historique)

- Unit tests backend (Jest)
- Integration REST critiques (Supertest)
- Tests Flutter widgets/providers
- E2E parcours artisan + client
- Priorite de test: `auth`, `otp`, `subscription`, `wave provider`, puis `verification/search/reviews`

### CI/CD cible (historique)

Pipeline GitHub Actions documente:
1. lint/type-check
2. tests (services postgres/mongo/redis)
3. build image docker
4. deploy SSH sur VPS (branche `main`)

### Haute disponibilite (historique)

Strategie warm standby progressive:
- Phase initiale: backups auto
- Ensuite: PostgreSQL replication, Mongo replica set, Redis Sentinel
- Bascule via floating IP/keepalived
- Objectif: failover auto <30s a maturite

## Strategie communication video (consolidation plan_pub.md)

Objectif: produire 2 pubs video verticales (9:16) basees sur captures reelles de l'app.

### Video 1 - Session Artisan

But: conversion artisans (inscription -> verification -> abonnement -> usage quotidien).

Scenes obligatoires:
- onboarding + role artisan
- inscription complete + OTP/PIN
- dashboard (disponibilite + KPI)
- portfolio (ajout realisation)
- verification documents + statuts
- abonnement Wave `5000 FCFA/mois`
- avis/reputation
- messagerie
- CTA final clair

### Video 2 - Session Client

But: conversion clients (telechargement -> recherche -> contact -> avis/favoris).

Scenes obligatoires:
- onboarding + inscription/login client
- dashboard client
- recherche multi-criteres + carte/liste
- profil artisan (badges/portfolio/avis)
- contact direct (appel/WhatsApp/chat)
- favoris + depot d'avis
- notifications
- CTA final clair

### Regles creatives communes

- UI reelle uniquement (pas de redesign)
- smartphone visible avec interactions naturelles
- voix-off FR + sous-titres FR synchronises
- musique motivante sous la voix
- duree cible: 45 a 75 secondes par video
- inclure une mini transition "ameliorations a venir"

### Preparation assets captures

Classement recommande:
- `artisan/auth`, `artisan/dashboard`, `artisan/portfolio`, `artisan/verification`, `artisan/subscription`, `artisan/reviews`
- `client/auth`, `client/home-search`, `client/profile-contact`, `client/favorites-reviews`
- `common/chat-notifs-settings`

Convention nommage conseillee:
- `A01_splash.png`, `A02_register_artisan.png`, `C11_search_map.png`, etc.

## Journal incidents (consolidation implementation_news.txt)

Incident constate (log Flutter):
- Type: `RenderFlex overflowed by 14 pixels on the right`
- Ecran/source: `fiers_artisans_app/lib/presentation/common/app_button.dart:104`
- Contexte de contrainte: largeur max ~`208.9`
- Effet: debordement horizontal de `Row` sur certains layouts etroits

Action recommande:
- reviser le composant bouton (`Row`) avec `Expanded/Flexible` ou ajustement layout/typo pour petits ecrans.

## Demarrage rapide global

Prerequis:
- Node.js 20+
- npm 10+
- Flutter SDK 3.41+
- Docker + Docker Compose

Preparation:
1. Copier `.env.example` vers `.env`
2. Copier `fiers_artisans_app/.env.example` vers `fiers_artisans_app/.env`
3. Completer toutes les valeurs sensibles

Lancer stack dev:
```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml up -d --build
```

Puis lancer les apps:
```bash
# backend
cd backend && npm ci && npm run start:dev

# admin web
cd admin-web && npm ci && npm run dev

# flutter
cd fiers_artisans_app && flutter pub get && flutter run
```

## Politique documentaire

- Ce fichier `README.md` est la reference unique.
- Les informations anciennes ont ete consolidees ici (architecture, roadmap, plan pub, incidents).
- `SECURITY_ARCHITECTURE.md` reste volontairement separe et intact.
