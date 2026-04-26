# Politique De Securite Et De Preservation De L'Architecture

## Objet

Ce document definit les regles strictes a respecter avant toute modification du projet `Fiers-Artisans`, qu'il s'agisse :

- d'une correction de bug
- d'une amelioration
- d'un refactor
- d'un changement UX/UI
- d'une evolution backend
- d'un ajustement Docker ou infrastructure
- d'une modification de configuration ou de variables d'environnement
- d'une integration ou modification d'un service externe

L'objectif n'est pas seulement de "faire marcher" un changement localement. L'objectif est de preserver l'architecture globale, la coherence inter-services, la logique metier, les contrats techniques, les parcours UX/UI, et toutes les dependances en cascade.

## Principe Directeur

Toute modification locale doit etre consideree comme une modification potentiellement systemique.

En consequence :

- aucun changement ne doit etre traite comme isole tant que ses impacts de cascade n'ont pas ete identifies
- aucune couche ne doit etre modifiee sans verifier ses consommateurs et ses dependances
- aucune decision structurante ou irreversible ne doit etre prise sans validation explicite de l'ingenieur humain
- aucune correction rapide ne doit fragiliser l'architecture, la securite, la maintenabilite ou la coherence produit

## Perimetre Concerne

Cette politique s'applique a l'ensemble du depot et a toutes ses briques :

- `backend/`
  API NestJS, modules metier, auth, OTP, verification, abonnement, paiements, chat, notifications, analytics, media, admin
- `admin-web/`
  Frontend Next.js d'administration, pages dashboard, workflows de moderation, analytics, logs, auth admin
- `fiers_artisans_app/`
  Application Flutter mobile client/artisan, routing, state management, UX, chat, verification, subscription, notifications
- `infrastructure/`
  Docker Compose, Nginx, scripts, monitoring, base de donnees, reseau, reverse proxy
- fichiers de configuration
  `.env`, `.env.local`, `.env.example`, configs framework, variables de services externes
- services externes et integrations
  WhatsApp, Wave, Firebase/FCM, MinIO, PostgreSQL/PostGIS, MongoDB, Redis, Nginx, Prometheus, Grafana

## Definition De La Preservation D'Architecture

Preserver l'architecture signifie obligatoirement :

- maintenir la compatibilite entre backend, frontend mobile, frontend admin, infra et services externes
- conserver la separation des responsabilites entre couches et modules
- respecter les contrats de donnees, contrats API, routes, schemas, evenements, tokens, permissions et etats metier
- verifier l'impact d'une modification sur les parcours UX/UI et les usages reels
- traiter toute repercussion transverse avant de considerer le travail termine

## Regles Fondamentales Non Negociables

### 1. Interdiction Des Changements Aveugles

Avant toute modification, il faut obligatoirement identifier :

- la source du probleme
- les fichiers touches directement
- les services consommateurs
- les donnees ou contrats susceptibles de casser
- les parcours utilisateurs affectes
- les impacts backend, mobile, admin, Docker, env et services externes

### 2. Interdiction Des Corrections Locales Qui Cassent Le Systeme

Une correction qui regle un point mais casse :

- un contrat API
- une integration mobile
- une page admin
- une logique de paiement
- une verification d'identite
- une notification
- une route
- un event WebSocket
- une variable d'environnement

est consideree comme invalide meme si elle corrige le symptome initial.

### 3. Obligation De Lecture En Cascade

Tout changement doit etre analyse dans ses dependances amont et aval.

Exemples obligatoires :

- modifier un DTO backend impose de verifier les repositories Flutter, les clients Next.js, les types, les parsers JSON et les ecrans concernes
- modifier une route API impose de verifier les consumers mobile, admin, docs et configs d'environnement
- modifier une logique de verification impose de verifier le statut utilisateur, l'admin moderation, le mobile artisan, les badges UI et la logique metier associee
- modifier une integration de paiement impose de verifier l'initiation, le webhook, les statuts, les ecrans, les logs et les etats d'abonnement

### 4. Obligation De Preserver Les Contrats

Les contrats suivants sont critiques et ne doivent pas etre casses sans plan global :

- routes API
- structure des payloads
- enveloppes de reponse
- noms de champs JSON
- statuts metier
- roles et permissions
- evenements WebSocket
- structure des donnees persistantes
- variables d'environnement
- ports, endpoints, URLs, buckets, topics et identifiants techniques

### 5. Obligation De Synchronisation Multi-Couches

Quand un changement impacte une couche, les couches reliees doivent etre mises a jour dans le meme travail ou explicitement signalees comme bloquees.

Sont particulierement sensibles :

- backend <-> app mobile
- backend <-> admin web
- backend <-> Docker/infrastructure
- backend <-> services externes
- UI <-> etats metier
- auth <-> guards <-> refresh tokens <-> stockage client

### 6. Obligation De Preserver La Logique Metier

Les regles metier existantes ne doivent jamais etre degradees par simplification technique.

Cela inclut notamment :

- verification de telephone
- verification artisan
- statut de certification
- disponibilite artisan
- recherche geospatiale
- gestion des reviews
- abonnements et expiration
- unread counts, notifications, logs, analytics

### 7. Obligation D'Informer Avant D'Agir Sur Une Decision Drastique

Avant toute action importante, structurante, risquee, irreversible ou ambigue, l'IA doit obligatoirement informer l'ingenieur humain, expliquer la decision et attendre validation.

Cela inclut, sans s'y limiter :

- suppression de code, de fichiers, de modules ou de routes
- changement de schema de base de donnees
- changement de contrats API
- changement de noms de variables d'environnement
- changement de flux auth, OTP, paiement, verification, chat, notification
- changement de topologie Docker ou reseau
- migration d'architecture
- refactor transverse multi-services
- downgrade, upgrade majeur ou remplacement de dependance critique
- toute action destructive ou potentiellement destructive

## Regle D'Escalade Humaine Obligatoire

Quand une decision ne releve pas d'une simple correction locale et qu'elle peut modifier le comportement global, l'IA doit suspendre l'execution et presenter un point d'arret de validation.

Le message de validation doit obligatoirement contenir :

- la decision proposee
- la raison
- les composants impactes
- les effets en cascade attendus
- les risques
- les alternatives si elles existent
- ce qui ne sera pas modifie sans accord

Sans validation explicite de l'ingenieur humain, l'action ne doit pas etre executee.

## Matrice D'Impact A Verifier Avant Chaque Changement

### Backend

Verifier systematiquement :

- controllers
- services
- DTOs
- guards
- interceptors
- filters
- entities TypeORM
- schemas Mongoose
- config
- env
- health checks
- webhooks
- jobs planifies

### Frontend Mobile

Verifier systematiquement :

- repositories
- providers
- models JSON
- navigation
- parcours login/register/OTP
- dashboards client et artisan
- recherche
- profil artisan
- reviews
- verification
- subscription
- chat
- notifications
- settings
- messages d'erreur
- coherence UX et etats de chargement

### Frontend Admin

Verifier systematiquement :

- auth admin
- pages dashboard
- verifications
- artisans
- clients
- subscriptions
- reviews
- logs
- analytics
- types TypeScript
- client API
- i18n
- etats d'erreur et d'attente

### Infrastructure Et Docker

Verifier systematiquement :

- services exposes
- conflits de ports
- variables d'environnement
- health checks
- depends_on
- volumes
- accessibilite inter-services
- reverse proxy
- SSL
- endpoints de sante
- monitoring

### Services Externes

Verifier systematiquement :

- credentials
- endpoints
- callbacks/webhooks
- signature verification
- fallback behavior
- gestion d'erreur
- non regression des parcours utilisateurs

## Zones Critiques A Traitement Renforce

### Authentification Et Autorisation

Toute modification touchant l'auth doit verifier :

- login
- register
- OTP send
- OTP verify
- refresh token
- logout
- persistance client
- guards
- roles
- etats `is_phone_verified`
- redirections UX
- securite des tokens

### Verification Artisan

Toute modification doit verifier :

- types de documents
- statut des documents
- statut utilisateur
- logique `VERIFIED` vs `CERTIFIED`
- vues artisan
- vues admin
- pieces jointes
- causes de rejet
- affichage des badges et statuts UI

### Paiement Et Subscription

Toute modification doit verifier :

- initiation du paiement
- creation de la session externe
- retour checkout
- webhook
- idempotence
- statut du paiement
- statut d'abonnement
- expiration
- activation/desactivation du profil
- ecrans mobile
- ecrans admin
- env et secrets

### Chat Et Notifications

Toute modification doit verifier :

- creation de conversation
- recuperation des conversations
- messages
- ordre chronologique
- read/unread
- websocket namespace/event names
- structures des documents Mongo
- mapping mobile
- side effects sur notifications

### Recherche Et Categories

Toute modification doit verifier :

- recherche geospatiale
- filtres
- categories et sous-categories
- compatibilite UUID/slug
- dashboards clients
- ecran de recherche
- analytics associees

### Media Et Stockage

Toute modification doit verifier :

- upload
- types MIME
- tailles max
- compression
- signed URLs
- buckets
- usage mobile/admin
- compatibilite MinIO

## Interdictions Strictes

Il est interdit de :

- modifier un contrat API sans verifier tous les consommateurs
- renommer des champs JSON sans mettre a jour les parsers et types associes
- changer une route sans mettre a jour tous les clients qui l'appellent
- introduire des hardcodes temporaires qui contournent l'architecture
- contourner les validations metier pour "faire passer" une feature
- supprimer une logique de securite sans justification et validation humaine
- changer une variable d'environnement sans mettre a jour documentation, exemples, Docker et consommateurs
- casser une compatibilite existante sans plan de transition
- changer des etats metier sans audit des parcours impactes
- appliquer un refactor de confort si le cout de cascade n'a pas ete traite
- prendre une decision irreversible sans validation humaine

## Workflow Obligatoire Avant Toute Modification

### Etape 1. Cartographier

Identifier :

- le probleme exact
- la couche source
- les dependances directes
- les dependances indirectes
- les parcours utilisateurs affectes

### Etape 2. Evaluer La Cascade

Pour chaque modification, evaluer son impact sur :

- backend
- app mobile
- admin web
- infrastructure
- env
- services externes
- UX/UI
- logique metier
- securite

### Etape 3. Informer

Avant les modifications non triviales, presenter :

- ce qui va etre change
- pourquoi
- ce qui risque d'etre impacte
- ce qui sera verifie

### Etape 4. Implementer De Facon Minimale Et Sure

La modification doit :

- etre la plus petite possible
- rester coherente avec l'architecture existante
- ne pas dupliquer inutilement la logique
- ne pas introduire de dette cachee

### Etape 5. Propager Les Ajustements Necessaires

Si un changement en entraine d'autres, ils doivent etre traites dans la meme chaine de travail ou explicitement listes comme impacts restants.

### Etape 6. Valider

Verifier :

- compatibilite des contrats
- coherence des etats metier
- coherence UX/UI
- coherence env/Docker
- coherence inter-services
- absence de regression evidente

### Etape 7. Documenter

Si la modification change un contrat, une regle metier, une config ou un flux important, la documentation associee doit etre mise a jour.

## Checklist De Validation Avant Cloture D'Une Modification

Une modification n'est pas consideree comme terminee tant que les points suivants n'ont pas ete verifies si applicables :

- le backend compile ou reste structurellement coherent
- les contrats JSON restent compatibles ou ont ete propages
- les pages admin concernees restent coherentes
- les ecrans mobile concernes restent coherents
- les routes, events, statuts et noms de champs sont alignes
- les variables d'environnement restent coherentes entre code, exemples et Docker
- les integrations externes ne sont pas cassees
- l'UX/UI ne promet pas une action non connectee
- les side effects et cascades ont ete identifies et traites
- aucune decision de produit ou d'architecture n'a ete prise sans validation humaine

## Regles Specifiques Pour L'IA Ou Tout Agent De Modification

Avant d'agir, l'agent doit toujours :

- lire l'architecture existante
- identifier les consommateurs en cascade
- annoncer le plan avant les changements substantiels
- faire des hypotheses explicites
- signaler les risques
- demander validation avant les decisions drastiques
- ne jamais masquer une incoherence importante
- ne jamais presenter comme "termine" un changement qui laisse des ruptures inter-services

L'agent doit refuser de considerer une tache comme purement locale si elle touche :

- auth
- paiement
- verification
- chat
- notifications
- contrats API
- stockage
- Docker
- env
- secrets
- logique metier transverse

## Politique De Decision Humaine Prioritaire

Les decisions suivantes appartiennent obligatoirement a l'ingenieur humain et ne peuvent etre executees sans validation :

- suppression ou remplacement d'un module
- migration d'architecture
- changement de modele de donnees
- changement de contrat public
- changement irreversible de workflow metier
- compromis securite vs rapidite
- changement des integrations externes critiques
- arbitrage entre compatibilite et refonte
- action destructive sur donnees, code ou configuration

## Conditions De Blocage Obligatoire

Le travail doit etre stoppe et remonte pour validation si :

- plusieurs interpretations techniques plausibles existent
- une modification peut casser un autre service
- une decision de produit est implicite
- le code existant contient une incoherence structurelle importante
- la solution impose un breaking change
- un secret, une infra ou un flux critique doit etre altere
- la correction necessite de choisir entre plusieurs architectures

## Niveau D'Exigence Attendu

La qualite attendue n'est pas seulement :

- "ca marche"

La qualite attendue est :

- "ca marche sans casser le reste"
- "c'est coherent avec l'architecture"
- "la cascade a ete prise en compte"
- "les consommateurs ont ete verifies"
- "les decisions importantes ont ete validees par l'humain"

## Clause Finale

Dans ce projet, toute modification doit proteger en priorite :

- la coherence globale du systeme
- la compatibilite entre services
- la logique metier
- la stabilite des parcours utilisateur
- la maintenabilite
- la securite
- la lisibilite des impacts

Si un doute existe, la regle est simple :

1. ne pas agir en aveugle
2. informer
3. faire valider par l'ingenieur humain
4. seulement ensuite executer

---

Document de reference a respecter pour toute intervention future sur `Fiers-Artisans`.
