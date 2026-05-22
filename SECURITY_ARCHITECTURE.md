# Politique De Securite Et De Preservation De L'Architecture

> ⚠️ Ce document definit la politique de gouvernance et d'execution.
> Pour l'etat technique courant du depot, se referer a `README.md` et aux runbooks racine.

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
- d'un changement de tests, de monitoring, de logs ou d'observabilite

L'objectif n'est pas seulement de "faire marcher" un changement localement.
L'objectif est de preserver l'architecture globale, la coherence inter-services,
la logique metier, les contrats techniques, les parcours UX/UI, la securite,
la qualite de test, et toutes les dependances en cascade.

## Principe Directeur

Toute modification locale doit etre consideree comme une modification potentiellement systemique.

En consequence :

- aucun changement ne doit etre traite comme isole tant que ses impacts de cascade n'ont pas ete identifies
- aucune couche ne doit etre modifiee sans verifier ses consommateurs et ses dependances
- aucune decision structurante ou irreversible ne doit etre prise sans validation explicite de l'ingenieur humain
- aucune correction rapide ne doit fragiliser l'architecture, la securite, la maintenabilite, la performance, l'observabilite ou la coherence produit
- aucun agent IA ne doit agir comme si la premiere intuition etait automatiquement correcte

## Principe De Realite Et De Verification Factuelle

L'agent ne doit jamais supposer qu'une affirmation est vraie uniquement parce qu'elle est affirmee.

Cela vaut pour :

- les demandes utilisateur
- les hypotheses de l'IA
- les commentaires dans le code
- la documentation
- les logs partiels
- les captures d'ecran
- les noms de services
- les dates
- les variables d'environnement
- les versions de dependances

Regle absolue :

- l'utilisateur peut se tromper
- l'IA peut se tromper
- la documentation peut etre en retard
- seul l'etat observe du depot, des commandes, des tests et de l'infrastructure permet de conclure

En pratique, avant toute decision importante, l'agent doit verifier autant que possible :

- le fichier reel concerne
- le chemin reel concerne
- le service reel concerne
- la commande reelle a executer
- les scripts disponibles dans le depot
- les dependances et consommateurs reels
- l'etat actuel des tests
- l'etat runtime observe si necessaire

Si l'enonce utilisateur entre en conflit avec l'etat observe :

- l'agent doit le signaler explicitement
- l'agent doit citer la preuve concrete
- l'agent doit ajuster son plan sur la base du reel, pas de l'hypothese

## Principe De Precision Chirurgicale

Chaque correction, amelioration ou refactor doit etre ultra-cible, ultra-minimal et ultra-justifie.

Cela signifie :

- modifier le moins de fichiers possible
- modifier le moins de lignes possible
- ne toucher qu'aux zones necessaires
- ne pas melanger plusieurs intentions dans le meme patch
- ne pas introduire de refactor opportuniste "tant qu'on y est"
- ne pas renommer, deplacer ou reformatter sans necessite technique claire
- ne pas modifier une architecture, un contrat ou un schema pour simplifier un correctif local

Le niveau d'exigence attendu est chirurgical :

- chaque ligne ajoutee doit avoir une raison explicite
- chaque ligne supprimee doit etre sans ambiguite
- chaque effet de bord doit etre intentionnel
- chaque risque de regression doit etre identifie

## Principe De Raisonnement Contradictoire

Avant de retenir une solution, l'agent doit resister a la premiere explication plausible.

Il doit, au minimum :

- envisager l'hypothese principale
- envisager au moins une hypothese concurrente credible
- verifier ce qui permet d'ecarter les hypotheses faibles
- retenir la solution la plus probable sur la base de preuves, pas d'intuition

Sur les sujets critiques, il doit raisonner sur plusieurs plans :

- scenario nominal
- scenario d'erreur
- scenario degrade
- scenario de concurrence
- scenario legacy
- scenario Docker / infrastructure
- scenario UI / UX

Il est interdit de confondre :

- symptome et cause racine
- correlation et causalite
- "ca compile" et "ca fonctionne"
- "ca fonctionne une fois" et "c'est robuste"
- "l'utilisateur l'a dit" et "c'est verifie"

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
  WhatsApp, Wave, Firebase/FCM, MinIO, PostgreSQL/PostGIS, MongoDB, Redis, Nginx, Prometheus, Grafana, Portainer

## Definition De La Preservation D'Architecture

Preserver l'architecture signifie obligatoirement :

- maintenir la compatibilite entre backend, frontend mobile, frontend admin, infra et services externes
- conserver la separation des responsabilites entre couches et modules
- respecter les contrats de donnees, contrats API, routes, schemas, evenements, tokens, permissions et etats metier
- verifier l'impact d'une modification sur les parcours UX/UI et les usages reels
- traiter toute repercussion transverse avant de considerer le travail termine
- preserver les garde-fous de securite, la couverture de tests et l'observabilite necessaire au diagnostic futur

## Invariants Non Negociables

Les invariants suivants doivent etre preserves sauf validation humaine explicite :

- aucune perte de donnees utilisateur
- aucune exposition de secret, token, credentiel ou donnees sensibles
- aucune degradation silencieuse de securite
- aucun breaking change implicite de contrat public
- aucune regression fonctionnelle non documentee
- aucune incoherence visible entre UI, UX et etat metier reel
- aucune derive entre dev, preprod et prod qui ne soit pas comprise et documentee
- aucune modification destructive de Docker, volumes, reseaux, bases ou assets sans validation
- aucune fermeture de tache sans verification et sans test proportionne au risque

## Regles Fondamentales Non Negociables

### 1. Interdiction Des Changements Aveugles

Avant toute modification, il faut obligatoirement identifier :

- la source du probleme
- la nature exacte du symptome
- la couche source
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
- une migration de donnees
- un monitoring ou une alerting chain

est consideree comme invalide meme si elle corrige le symptome initial.

### 3. Obligation De Lecture En Cascade

Tout changement doit etre analyse dans ses dependances amont et aval.

Exemples obligatoires :

- modifier un DTO backend impose de verifier les repositories Flutter, les clients Next.js, les types, les parsers JSON et les ecrans concernes
- modifier une route API impose de verifier les consumers mobile, admin, docs et configs d'environnement
- modifier une logique de verification impose de verifier le statut utilisateur, l'admin moderation, le mobile artisan, les badges UI et la logique metier associee
- modifier une integration de paiement impose de verifier l'initiation, le webhook, les statuts, les ecrans, les logs et les etats d'abonnement
- modifier un Dockerfile impose de verifier le build, le runtime, les volumes, les variables, les healthchecks, les ports et les services dependants

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
- cache Redis <-> invalidation <-> lectures UI
- monitoring <-> logs <-> dashboards <-> alertes

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
- pieces jointes et preuves de paiement
- coherence des permissions client, artisan, admin

### 7. Obligation D'Examiner Les Scenarios Oublies

Avant de considerer un patch comme suffisant, l'agent doit explicitement evaluer les scenarios souvent oublies.

Minimum a considerer selon le contexte :

- donnees preexistantes deja en base
- anciens clients mobiles encore en circulation
- double clic / double submission
- retry reseau / timeout / duplication webhook
- concurrence entre deux utilisateurs ou deux admins
- etats partiels apres echec intermediaire
- cache stale ou invalidation manquante
- race conditions auth, paiement, chat, upload
- erreurs de timezone, horodatage, expiration
- etats vides, loading, slow network, offline, retour ecran
- permissions insuffisantes ou utilisateur non authentifie
- incoherence entre ce que l'UI affiche et l'etat serveur reel
- ecarts entre environnement local, Docker et production

### 8. Obligation De Tester Ce Qui Est Change

Aucune modification ne doit etre consideree comme terminee si les tests et verifications proportionnes au risque n'ont pas ete executes ou, si impossible, explicitement declares comme non executes avec le risque residuel associe.

### 9. Obligation D'Informer Avant D'Agir Sur Une Decision Drastique

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

### 10. Interdiction De Clore Trop Tot

Un travail n'est pas "termine" quand le symptome principal disparait.
Un travail est "termine" uniquement quand :

- le patch est coherent
- les cascades ont ete verifiees
- les tests pertinents ont ete executes
- la documentation necessaire a ete mise a jour
- les risques residuels ont ete signales

## Politique De Verification Des Affirmations Utilisateur

Quand un utilisateur affirme :

- "ce service n'existe plus"
- "ce script est ici"
- "ce bug vient de X"
- "la route a change"
- "les tests sont deja verts"
- "Portainer montre un probleme"
- "la prod fait Y"
- "tel volume est obsolete"

l'agent ne doit pas le prendre comme une preuve.

Il doit verifier autant que possible par :

- lecture du depot
- recherche de references
- lecture des scripts
- verification des Compose
- verification des package scripts
- commandes de diagnostic
- tests
- comparaison entre documentation et implementation

Si l'utilisateur se trompe, l'agent doit :

- le dire calmement
- donner la preuve
- proposer la correction precise

## Politique D'Enrichissement Des Prompts Utilisateur

L'agent ne doit pas executer un prompt brut de maniere litterale si ce prompt est incomplet, ambigu ou sous-specifie.

Avant d'agir, il doit reconstruire mentalement une version plus precise du besoin, en clarifiant :

- l'objectif reel
- le perimetre reel
- les contraintes non negociables
- les hypotheses a verifier
- les risques de cascade
- les invariants a proteger
- les criteres d'acceptation
- les tests minimaux obligatoires

Le prompt reconstruit doit repondre implicitement ou explicitement a ces questions :

- quel est le probleme exact ?
- quelle est la preuve ?
- quelle est la couche source ?
- quelle est la solution minimale ?
- qu'est-ce qu'on ne doit surtout pas casser ?
- quels consommateurs dependent de cette zone ?
- quels scenarios limites doivent etre verifies ?
- quels tests doivent etre lances ?

Si le prompt est encore ambigu apres lecture du depot :

- poser la question la plus precise possible
- limiter la question au point bloquant
- ne pas demander des clarifications paresseuses que le depot permet deja d'obtenir

Si le prompt utilisateur est exploitable mais faible, l'agent doit l'ameliorer mentalement avant execution.

Il doit reformuler pour lui-meme ou explicitement :

- le vrai objectif
- le scope reel
- les risques critiques
- les verifications necessaires
- les tests minimaux
- la definition du termine

## Regle D'Escalade Humaine Obligatoire

Quand une decision ne releve pas d'une simple correction locale et qu'elle peut modifier le comportement global, l'IA doit suspendre l'execution et presenter un point d'arret de validation.

Le message de validation doit obligatoirement contenir :

- la decision proposee
- la raison
- les composants impactes
- les effets en cascade attendus
- les risques
- les alternatives si elles existent
- les tests envisages
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
- invalidation cache
- compatibilite ascendante des donnees

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
- retours arriere, deep links, offline et reprise d'etat

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
- comportement de moderation concurrente

### UI Et UX

Verifier systematiquement :

- etats loading
- etats vides
- etats erreur
- etats succes
- feedback utilisateur
- prevention des doubles actions
- coherence des labels, statuts, badges et CTA
- accessibilite minimale
- responsive / petits ecrans
- dark/light si applicable
- FR/EN si la zone est traduite

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
- ecarts dev/prod
- ressources orphanes
- persistence des donnees
- permissions des mounts

### Services Externes

Verifier systematiquement :

- credentials
- endpoints
- callbacks/webhooks
- signature verification
- fallback behavior
- gestion d'erreur
- non regression des parcours utilisateurs
- idempotence
- timeouts / retries
- journalisation sans fuite de secrets

## Scenarios Potentiellement Oublies A Toujours Evaluer

### Scenarios Infra / Docker / Ops

- image rebuild qui casse seulement en container et pas en local natif
- volume anonyme orphelin qui s'accumule
- volume nomme critique faussement considere obsolete
- profil Compose non charge
- env locale differente de l'env Docker
- healthcheck vert mais service fonctionnellement casse
- service qui boot plus lentement que `depends_on`
- conteneur qui restart en boucle
- port deja pris par un autre process
- reseau Docker deja existant mais attache au mauvais projet
- cache de build qui masque une vraie regression
- nettoyage Docker trop aggressif qui supprime un artefact encore utile
- dashboard/alerting non mis a jour apres changement de nom, route ou metrique

### Scenarios Backend / Donnees

- schema de reponse modifie mais client ancien encore deploye
- valeurs nulles ou legacy non prevues
- migration partielle
- relation de donnees incoherente entre PostgreSQL, MongoDB et Redis
- idempotence manquante sur webhook ou callback
- duplication d'operation de paiement
- statut metier mis a jour sans synchroniser l'ecran qui le consomme
- invalidation cache oubliee
- course condition sur tokens, sessions, conversation ou abonnement
- fuseau horaire / date d'expiration incorrects

### Scenarios UI / UX

- bouton actif deux fois
- spinner infini
- message de succes trompeur
- erreur silencieuse
- ecran qui ne se rafraichit pas apres mutation
- back navigation qui re-affiche un etat stale
- texte traduit dans une langue mais pas l'autre
- badge, statut ou couleur incoherents avec le back
- fichier uploadable dans un ecran mais rejete ensuite par le serveur
- parcours casse pour petit ecran ou faible connectivite

### Scenarios Securite

- IDOR
- escalation de privilege
- secret expose dans logs, code, capture ou documentation
- validation insuffisante des inputs
- bypass auth/guard
- token mal verifie ou mal invalide
- URL signee trop permissive
- MIME spoofing ou extension trompeuse
- rate limit oublie
- webhook sans verification de signature ni idempotence

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
- invalidation des sessions et etats stale

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
- effets de retries et callbacks dupliques

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
- gestion des doublons, retries et desynchronisation client

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
- conservation des permissions et de la confidentialite des assets

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
- marquer une tache comme terminee sans tests pertinents
- "faire confiance" a une affirmation sans verification quand le depot ou les commandes permettent de confirmer

## Workflow Obligatoire Avant Toute Modification

### Etape 1. Reformuler Le Probleme

Identifier :

- le probleme exact
- le symptome observable
- la preuve disponible
- l'hypothese la plus probable
- ce qui reste a verifier

### Etape 2. Cartographier

Identifier :

- la couche source
- les dependances directes
- les dependances indirectes
- les parcours utilisateurs affectes
- les contrats touches
- les donnees touchees

### Etape 3. Evaluer La Cascade

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
- observabilite
- tests

### Etape 4. Evaluer Les Scenarios Limites

Au minimum verifier mentalement ou concretement :

- succes nominal
- erreur nominale
- etat vide
- permission refusee
- timeout / retry
- duplication
- donnees legacy
- environnement dev
- environnement Docker
- non regression evidente

### Etape 5. Informer

Avant les modifications non triviales, presenter :

- ce qui va etre change
- pourquoi
- ce qui risque d'etre impacte
- ce qui sera verifie
- quels tests seront executes

### Etape 6. Implementer De Facon Minimale Et Sure

La modification doit :

- etre la plus petite possible
- rester coherente avec l'architecture existante
- ne pas dupliquer inutilement la logique
- ne pas introduire de dette cachee
- ne pas etendre le scope sans justification

### Etape 7. Propager Les Ajustements Necessaires

Si un changement en entraine d'autres, ils doivent etre traites dans la meme chaine de travail ou explicitement listes comme impacts restants.

### Etape 8. Tester

Executer les validations pertinentes selon la zone modifiee.

### Etape 9. Valider

Verifier :

- compatibilite des contrats
- coherence des etats metier
- coherence UX/UI
- coherence env/Docker
- coherence inter-services
- absence de regression evidente
- couverture de tests suffisante au regard du risque

### Etape 10. Documenter

Si la modification change un contrat, une regle metier, une config, une procedure, un flux important ou une regle de gouvernance, la documentation associee doit etre mise a jour.

## Politique De Tests Obligatoire

### Regle Generale

Tout agent doit executer les tests et verifications proportionnes a la nature du changement.

Ordre logique :

1. verifier statiquement
2. tester localement la zone modifiee
3. tester la frontiere inter-couches si le changement depasse une seule couche
4. declarer explicitement ce qui n'a pas pu etre teste

### Backend

Pour une modification backend, executer selon le scope :

```bash
cd backend
npm run build
npm run test
```

Executer aussi si applicable :

```bash
cd backend
npm run test:e2e
```

Cas ou `test:e2e` doit etre privilegie si possible :

- auth
- OTP
- paiement
- webhook
- subscription
- routes REST
- contrats inter-services

### Admin Web

Pour une modification `admin-web/`, executer au minimum :

```bash
cd admin-web
npm run lint
npm run build
```

### Flutter

Pour une modification `fiers_artisans_app/`, executer au minimum :

```bash
cd fiers_artisans_app
flutter analyze
flutter test
```

### Infrastructure / Docker

Pour une modification `infrastructure/`, executer au minimum :

```bash
cd infrastructure
docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml config
```

Et si applicable verifier :

```bash
cd infrastructure
docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml ps
```

Pour les scripts de nettoyage Docker, verifier aussi selon le besoin :

```bash
docker system df
docker builder du
docker image ls --filter dangling=true
docker volume ls --filter dangling=true
```

### Si Les Tests Ne Peuvent Pas Etre Lances

L'agent doit l'indiquer explicitement avec :

- la commande non executee
- la raison exacte
- le risque residuel
- ce qu'il recommande a l'humain d'executer ensuite

## Checklist De Validation Avant Cloture D'Une Modification

Une modification n'est pas consideree comme terminee tant que les points suivants n'ont pas ete verifies si applicables :

- le probleme de depart est bien compris et prouve
- l'affirmation utilisateur a ete verifiee quand c'etait possible
- le backend compile ou reste structurellement coherent
- les contrats JSON restent compatibles ou ont ete propages
- les pages admin concernees restent coherentes
- les ecrans mobile concernes restent coherents
- les routes, events, statuts et noms de champs sont alignes
- les variables d'environnement restent coherentes entre code, exemples et Docker
- les integrations externes ne sont pas cassees
- l'UX/UI ne promet pas une action non connectee
- les side effects et cascades ont ete identifies et traites
- les tests pertinents ont ete executes
- les limites de validation ont ete declarees
- aucune decision de produit ou d'architecture n'a ete prise sans validation humaine

## Regles Specifiques Pour L'IA Ou Tout Agent De Modification

Avant d'agir, l'agent doit toujours :

- lire l'architecture existante
- identifier les consommateurs en cascade
- annoncer le plan avant les changements substantiels
- faire des hypotheses explicites
- signaler les risques
- demander validation avant les decisions drastiques
- verifier les affirmations de l'utilisateur si le depot ou les commandes permettent de le faire
- ne jamais masquer une incoherence importante
- ne jamais presenter comme "termine" un changement qui laisse des ruptures inter-services
- ne jamais s'arreter au premier diagnostic plausible sans evaluation des scenarios concurrents

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
- monitoring ou dashboards

## Format De Restitution Obligatoire De L'Agent

Quand un agent termine une tache substantielle, sa restitution doit permettre a l'ingenieur humain de verifier vite la qualite de la decision.

La restitution doit preciser quand c'est applicable :

- le diagnostic retenu
- la preuve principale
- les fichiers modifies
- les impacts de cascade traites
- les tests executes
- les tests non executes
- les risques residuels
- les points a surveiller apres merge ou deploy

Il est interdit de conclure par un simple equivalent de :

- "c'est bon"
- "corrige"
- "fait"

sans indiquer au minimum :

- ce qui a ete change
- ce qui a ete verifie
- ce qui reste incertain

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
- changement sensible d'UX ou de logique produit

## Conditions De Blocage Obligatoire

Le travail doit etre stoppe et remonte pour validation si :

- plusieurs interpretations techniques plausibles existent
- une modification peut casser un autre service
- une decision de produit est implicite
- le code existant contient une incoherence structurelle importante
- la solution impose un breaking change
- un secret, une infra ou un flux critique doit etre altere
- la correction necessite de choisir entre plusieurs architectures
- les tests disponibles contredisent l'hypothese de depart
- l'utilisateur demande une action qui met en risque la securite, les donnees ou l'architecture

## Niveau D'Exigence Attendu

La qualite attendue n'est pas seulement :

- "ca marche"

La qualite attendue est :

- "ca marche sans casser le reste"
- "c'est coherent avec l'architecture"
- "la cascade a ete prise en compte"
- "les consommateurs ont ete verifies"
- "les tests pertinents ont ete executes"
- "les scenarios oublies ont ete evalues"
- "les decisions importantes ont ete validees par l'humain"
- "la solution est suffisamment precise pour etre maintenable plus tard"

## Clause Finale

Dans ce projet, toute modification doit proteger en priorite :

- la coherence globale du systeme
- la compatibilite entre services
- la logique metier
- la stabilite des parcours utilisateur
- la maintenabilite
- la securite
- la lisibilite des impacts
- la qualite des tests
- la precision de diagnostic

Si un doute existe, la regle est simple :

1. ne pas agir en aveugle
2. verifier les faits
3. evaluer plusieurs scenarios
4. informer
5. faire valider par l'ingenieur humain si necessaire
6. executer de maniere minimale, precise et testee

---

Document de reference a respecter pour toute intervention future sur `Fiers-Artisans`.
