# Formation Docker pratique pour l'equipe (basee sur votre infra)

## 1) Vision simple: comment Docker fonctionne

Pense Docker comme un immeuble:
- Image = le plan de construction (template)
- Container = un appartement en cours d'utilisation (instance active)
- Volume = la cave de stockage durable (donnees persistantes)
- Network = le couloir prive entre appartements (communication interne)
- Stack = tout l'immeuble organise (ensemble de services)
- Host = le terrain et l'immeuble physique (machine qui fait tourner Docker)

Dans votre projet, la stack contient notamment:
- api
- admin-web
- postgres
- mongodb
- redis
- minio
- prometheus
- grafana
- portainer
- nginx (en prod, pas forcement en dev)

## 2) Ce que tu vois dans Portainer / Docker Desktop

### Images (ex: 15 images, 10.6 GB)
Une image est un package pret a lancer.
- Elle contient le code, les dependances, et la commande de demarrage.
- Plusieurs containers peuvent utiliser la meme image.
- 10.6 GB = espace disque total consomme par toutes les images presentes localement.

Exemples de votre infra:
- infrastructure-api
- infrastructure-admin-web
- mongo:7
- redis:7-alpine
- minio/minio
- grafana/grafana

Pourquoi ca grossit:
- Rebuild frequents
- Anciennes versions d'images non nettoyees
- Couches intermediaires de build

### Containers
Un container est un processus isole qui tourne a partir d'une image.
- Statut possible: running, exited, restarting, unhealthy
- Un container peut etre supprime puis recree sans perdre les donnees si les volumes sont bien utilises.

### Volumes (ex: 56)
Un volume stocke les donnees persistantes.
- Si tu supprimes un container, le volume peut rester.
- C'est souvent normal d'en voir beaucoup apres des essais/rebuilds.

Exemples utiles:
- postgres_data
- mongo_data
- redis_data
- minio_data
- grafana_data

Regle d'or:
- Supprimer un volume = potentiellement perdre des donnees.

### Networks (ex: 5)
Un network est un reseau virtuel Docker.
- Il permet aux services de se parler via nom de service (postgres, redis, mongodb, etc.).
- Plusieurs networks peuvent exister apres des tests/stacks differents.

Exemple:
- fiers-network (reseau principal de votre stack)

### Stack
Une stack est un ensemble coherent de services deploie ensemble (souvent via docker compose).
- Une stack = votre application complete.
- Demarrer une stack = demarrer tous les services necessaires.

### Events
Docker events = journal des actions en temps reel:
- start, stop, die, health_status, pull, etc.
- Tres utile pour diagnostiquer un service qui redemarre en boucle.

### Host
Le host est la machine qui execute Docker:
- CPU, RAM, disque
- Configuration du moteur Docker
- Capacite limite qui impacte les containers

## 3) Inspection: commandes essentielles a connaitre

### Etat global
    docker ps
    docker ps -a
    docker compose ps

### Logs et diagnostic
    docker logs -f fiers-api
    docker compose logs -f api
    docker inspect fiers-api

### Ressources
    docker stats
    docker system df

### Inventaire
    docker images
    docker volume ls
    docker network ls

### Sante API/Admin
    curl -s -o /dev/null -w 'API %{http_code}\n' http://localhost:3000/api/v1/health
    curl -s -o /dev/null -w 'ADMIN %{http_code}\n' http://localhost:3002

## 4) Nettoyage intelligent (sans casser)

Objectif: supprimer ce qui est inutilise, sans casser la stack active.

### Etape A: verifier avant suppression
    docker ps
    docker compose ps
    docker system df

### Etape B: nettoyages cibles
- Containers arretes:

    docker container prune

- Images non utilisees:

    docker image prune -a

- Networks non utilises:

    docker network prune

- Volumes non utilises (attention donnees):

    docker volume prune

### Etape C: grand nettoyage (danger si mal utilise)
    docker system prune -a --volumes

A utiliser seulement si:
- tu es sur de ne rien vouloir garder hors stack active
- tu as des sauvegardes
- tu as confirme les volumes critiques

## 5) Distinguer "inutilise" vs "important"

Inutilise probable:
- container exited depuis longtemps
- image sans container associe
- network orphan sans service
- volume cree par des tests temporaires

Important probable:
- volumes postgres_data, mongo_data, minio_data
- image actuellement utilisee par un service running
- network de la stack active

Bon reflexe:
- faire un export/snapshot avant gros nettoyage
- nettoyer par categorie, pas tout d'un coup

## 6) Dupliquer une stack: oui, possible, et utile

Tu peux dupliquer une stack pour:
- environnement de test parallele
- reproduction de bug sans toucher l'environnement principal
- demonstration/formation interne

Exemple compose avec nom de projet different:
    docker compose -p fiers-dev2 --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml up -d

Important pour la duplication:
- ports differents (sinon conflit)
- volumes differents (sinon partage de donnees non voulu)
- variables d'environnement dediees

## 7) Stack Docker vs Cluster Kubernetes

Ce n'est pas la meme chose.

Stack Docker Compose:
- simple et rapide
- ideal dev, preprod legere, petites equipes
- plutot sur une machine (ou quelques machines manuellement gerees)

Cluster Kubernetes:
- orchestration avancee multi-noeuds
- haute disponibilite
- auto-healing, autoscaling, rolling updates robustes
- plus complexe a operer

Quand aller vers Kubernetes:
- besoin fort de scalabilite horizontale
- exigences HA strictes (SLA elevé)
- plusieurs environnements et charges importantes

## 8) Scalabilite et maintenabilite: lecture simple

Scalabilite = capacite a encaisser plus de charge.
- Verticale: plus de CPU/RAM sur la meme machine
- Horizontale: plus d'instances/services

Maintenabilite = facilite de maintenir et faire evoluer.
- conventions claires (noms services, volumes, env)
- separation dev/preprod/prod
- scripts d'exploitation (start, stop, backup, reset)
- observabilite (logs + metrics + alertes)

Dans votre cas:
- vous avez deja de bonnes briques (Prometheus, Grafana, Portainer)
- prochaine etape utile: procedures d'exploitation standardisees (runbooks)

## 9) Scenarios concrets (votre contexte)

### Scenario 1: pages inacessibles en dev
1. Verifier stack dev:

    docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml ps

2. Verifier API health et Admin:

    curl http://localhost:3000/api/v1/health
    curl -I http://localhost:3002

3. Lire logs service qui bloque:

    docker compose logs --tail 200 api
    docker compose logs --tail 200 admin-web

### Scenario 2: manque d'espace disque
1. Mesurer:

    docker system df

2. Nettoyer progressivement:

    docker container prune
    docker image prune -a
    docker network prune

3. Volumes: seulement apres verification:

    docker volume prune

### Scenario 3: besoin d'un second environnement de test
1. Dupliquer stack avec nom de projet dedie
2. Changer ports
3. Changer volumes et variables
4. Verifier acces et isolation

## 10) Checklist d'exploitation hebdomadaire

- Verifier containers unhealthy/restarting
- Verifier espace disque docker system df
- Verifier volumes orphelins
- Verifier logs d'erreurs repetitives
- Verifier backups de donnees persistantes
- Nettoyer ressources inutilisees de facon ciblee

## 11) Glossaire express (a partager a l'equipe)

- Image: modele immutable pour lancer un container
- Container: instance en execution d'une image
- Volume: stockage persistant
- Network: reseau virtuel entre containers
- Stack: groupe de services deploies ensemble
- Host: machine qui execute Docker
- Cluster: groupe de machines/noeuds orchestras (Kubernetes, Swarm)

## 12) Conclusion simple

Pour votre infra actuelle:
- Docker Compose + Portainer est tres adapte
- vous pouvez dupliquer les stacks pour tester sans risquer la principale
- nettoyez regulierement, mais prudemment sur les volumes
- passez a Kubernetes seulement quand la complexite/charge justifie l'investissement
