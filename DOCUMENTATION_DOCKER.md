# Documentation Docker - Fiers Artisans

Cette documentation est le runbook Docker de reference du projet.

Regles de securite a retenir avant toute commande de nettoyage :
- Toujours lancer un `--dry-run` avant un nettoyage destructeur.
- Ne jamais supprimer les volumes de donnees critiques.
- Ne jamais lancer `docker system prune -a --volumes`.
- Considerer qu'un volume "dangling" n'est pas forcement obsolete.

Volumes critiques a proteger absolument :
- `postgres_data`
- `mongo_data`
- `redis_data`
- `minio_data`
- `grafana_data`
- `prometheus_data`
- `portainer_data`

Important :
- Le script de nettoyage est `infrastructure/scripts/clean-docker.sh`.
- Le script de backup existant est `infrastructure/scripts/backup.sh`.
- Dans Docker, les volumes reels sont generalement prefixes par le nom du projet Compose.
- Dans l'etat actuel du depot, les volumes reels s'appellent typiquement `infrastructure_postgres_data`, `infrastructure_mongo_data`, etc.

## 0. Diagnostic rapide du script `clean-docker.sh`

### Reponses directes

1. En mode standard, le script supprime les images `<none>` si elles sont vraiment dangling.
   Commande utilisee : `docker image prune -f`

2. En mode `--all`, le script supprime aussi les images `<none>`, mais plus largement toutes les images inutilisees par un container.
   Commande utilisee : `docker image prune -a -f`

3. Le build cache est nettoye dans les deux cas :
   - mode standard : `docker builder prune -f`
   - mode `--all` : `docker builder prune -a -f`

4. Le script ne touche jamais aux volumes nommes critiques listes plus haut.
   En revanche, il peut supprimer les volumes anonymes orphelins, c'est-a-dire les volumes sans nom stable, typiquement representes par des IDs hexadecimaux de 64 caracteres.

5. Commandes manuelles utiles pour inspecter l'etat actuel :

Depuis la racine `~/mes_projets_dev/Fiers_Artisants/` :

```bash
docker image ls --filter dangling=true
docker builder du
docker volume ls --filter dangling=true
docker network ls --filter dangling=true
docker system df
docker system df -v
```

6. Si tu veux nettoyer plus loin sans modifier le script :

Depuis la racine `~/mes_projets_dev/Fiers_Artisants/` :

```bash
# Supprimer toutes les images dangling (<none>)
docker image prune -f

# Supprimer toutes les images inutilisees par n'importe quel container
docker image prune -a -f

# Nettoyer tout le build cache BuildKit
docker builder prune -a -f

# Nettoyer les reseaux orphelins
docker network prune -f

# Voir seulement les volumes anonymes orphelins
docker volume ls -q --filter dangling=true | grep -E '^[a-f0-9]{64}$'

# Supprimer seulement les volumes anonymes orphelins
docker volume ls -q --filter dangling=true | grep -E '^[a-f0-9]{64}$' | xargs -r docker volume rm
```

Ne pas faire :

```bash
docker volume prune
docker system prune -a --volumes
```

Ces deux commandes peuvent supprimer des volumes de donnees que tu veux conserver.

### Sequence de test demandee

Depuis la racine `~/mes_projets_dev/Fiers_Artisants/` :

```bash
# 1. Simulation aggressive
./infrastructure/scripts/clean-docker.sh --dry-run --all

# 2. Nettoyage agressif reel
./infrastructure/scripts/clean-docker.sh --all

# 3. Verifier les images <none>
docker image ls --filter dangling=true

# 4. Verifier l'etat des volumes
docker volume ls
docker volume ls --filter dangling=true

# 5. Voir uniquement les volumes anonymes orphelins
docker volume ls -q --filter dangling=true | grep -E '^[a-f0-9]{64}$'
```

Lecture correcte des volumes :
- si `docker volume ls --filter dangling=true` affiche `infrastructure_postgres_data`, `infrastructure_mongo_data`, etc., ce n'est pas un bug si la stack est arretee
- cela signifie seulement qu'aucun container ne monte ces volumes a cet instant
- ces volumes restent des volumes de donnees a conserver

## 1. Glossaire Docker

| Terme | Definition technique | Analogie |
|---|---|---|
| Image | Modele immuable servant a creer un container | Un moule de fabrication |
| Container | Instance en execution d'une image | Un appareil allume a partir du moule |
| Volume | Espace de stockage persistant separe du cycle de vie du container | Un disque dur externe |
| Network | Reseau virtuel Docker entre containers | Un switch prive entre machines |
| Stack | Ensemble coherent de services Docker Compose | Une mini-infrastructure complete |
| Service | Definition Compose d'un composant a executer | Un role dans une equipe |
| Host | Machine qui fait tourner Docker | Le serveur ou ton PC |
| Build | Construction d'une image a partir d'un Dockerfile | Assembler une machine piece par piece |
| Cache de build | Couches intermediaires reutilisees pour accelerer les builds | Des pieces deja pretes en atelier |
| Dangling image | Image non taguee et non referencee, souvent `<none>` | Une piece sans etiquette laissee en stock |
| Orphan | Ressource qui existe encore mais n'est plus rattachee a la stack active | Un cable branche a rien |
| Volume obsolete | Volume non utilise par aucun container | Un disque pose de cote |

Note importante sur "volume obsolete" :
- dans ce projet, un volume critique peut apparaitre "dangling" quand la stack est arretee
- "dangling" veut dire "non monte par un container maintenant", pas "sans valeur"
- il faut donc distinguer les volumes anonymes jetables des volumes nommes de donnees

## 2. Architecture de la stack Fiers Artisans

### Schema textuel des services

Mode dev local :

```text
Host
  |- :3000  -> api (NestJS)
  |- :3002  -> admin-web (Next.js)
  |- :5434  -> postgres
  |- :27018 -> mongodb
  |- :6380  -> redis
  |- :9002  -> minio API
  |- :9003  -> minio Console
  |- :3001  -> grafana
  |- :9443  -> portainer
  `- prometheus : non expose sur l'hote dans l'etat actuel du Compose

api
  |- depends_on -> postgres
  |- depends_on -> mongodb
  |- depends_on -> redis
  `- depends_on -> minio

admin-web
  `- depends_on -> api

grafana
  `- depends_on -> prometheus
```

Mode prod-like avec `COMPOSE_PROFILES=prod-only` :

```text
Host
  |- :80/:443 -> nginx
  `- :9443    -> portainer

nginx
  |- route /      -> admin-web
  `- route /api/  -> api

api
  |- postgres
  |- mongodb
  |- redis
  `- minio

grafana, prometheus, postgres, mongodb, redis, minio
  `- restent internes dans l'etat actuel des fichiers Compose de base
```

### Tableau des services et ports

| Service | Role | Ports host en dev | Ports host en prod-like | Stockage persistant |
|---|---|---|---|---|
| `api` | API NestJS | `3000 -> 3000` | non expose directement | non |
| `admin-web` | Back-office Next.js | `3002 -> 3002` | non expose directement | volumes anonymes dev |
| `postgres` | Base relationnelle | `5434 -> 5432` | non expose | `postgres_data` |
| `mongodb` | Base documentaire | `27018 -> 27017` | non expose | `mongo_data` |
| `redis` | Cache / pub-sub | `6380 -> 6379` | non expose | `redis_data` |
| `minio` | Stockage objets | `9002 -> 9000`, `9003 -> 9001` | non expose | `minio_data` |
| `nginx` | Reverse proxy | desactive en dev | `80 -> 80`, `443 -> 443` | bind mounts config/ssl |
| `prometheus` | Metrics | non expose dans l'etat actuel | non expose | `prometheus_data` |
| `grafana` | Dashboards | `3001 -> 3000` | non expose dans le Compose de base | `grafana_data` |
| `portainer` | Gestion Docker | `9443 -> 9443` | `9443 -> 9443` | `portainer_data` |

### Tableau des reseaux Docker

| Reseau Compose | Nom Docker typique | Type | Services rattaches |
|---|---|---|---|
| `fiers-network` | `infrastructure_fiers-network` | bridge | `api`, `admin-web`, `postgres`, `mongodb`, `redis`, `minio`, `prometheus`, `grafana`, `nginx` |
| `default` | `infrastructure_default` | bridge | `portainer` |

Notes :
- `portainer` n'est pas explicitement branche sur `fiers-network`
- il fonctionne via son port `9443` et le montage de `/var/run/docker.sock`

### Tableau des volumes persistants

| Cle Compose | Nom Docker typique | Role |
|---|---|---|
| `postgres_data` | `infrastructure_postgres_data` | Donnees PostgreSQL |
| `mongo_data` | `infrastructure_mongo_data` | Donnees MongoDB |
| `redis_data` | `infrastructure_redis_data` | Persistence Redis |
| `minio_data` | `infrastructure_minio_data` | Fichiers objets MinIO |
| `grafana_data` | `infrastructure_grafana_data` | Dashboards et etat Grafana |
| `prometheus_data` | `infrastructure_prometheus_data` | Donnees Prometheus |
| `portainer_data` | `infrastructure_portainer_data` | Etat Portainer |

Volumes non critiques mais frequents en dev :
- `admin-web` cree des volumes anonymes pour `/app/node_modules` et `/app/.next`
- ce sont eux qui s'accumulent le plus souvent dans Portainer sous forme d'IDs hexadecimaux

### Dependances `depends_on`

| Service | Dependances |
|---|---|
| `api` | `postgres`, `mongodb`, `redis`, `minio` |
| `admin-web` | `api` |
| `nginx` | `api`, `admin-web` |
| `grafana` | `prometheus` |
| `postgres` | aucune |
| `mongodb` | aucune |
| `redis` | aucune |
| `minio` | aucune |
| `prometheus` | aucune |
| `portainer` | aucune |

## 3. Commandes essentielles par chemin d'execution

### Depuis la racine `~/mes_projets_dev/Fiers_Artisants/`

| Action | Commande exacte |
|---|---|
| Demarrer la stack dev complete | `docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml up -d --build` |
| Demarrer la stack prod-like complete avec nginx | `COMPOSE_PROFILES=prod-only docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.portainer.yml up -d --build` |
| Voir l'etat des services dev | `docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml ps` |
| Arreter la stack dev proprement | `docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml down --remove-orphans` |
| Arreter la stack prod-like proprement | `COMPOSE_PROFILES=prod-only docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.portainer.yml down --remove-orphans` |
| Redemarrer un service sans rebuild | `docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml restart api` |
| Rebuild un service apres modification | `docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml up -d --build api` |
| Rebuild complet sans cache d'un service | `docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml build --no-cache api` |
| Voir les logs d'un service | `docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml logs -f api` |
| Nettoyage standard | `./infrastructure/scripts/clean-docker.sh` |
| Simulation standard | `./infrastructure/scripts/clean-docker.sh --dry-run` |
| Nettoyage agressif | `./infrastructure/scripts/clean-docker.sh --all` |
| Simulation agressive | `./infrastructure/scripts/clean-docker.sh --dry-run --all` |

### Depuis le dossier `~/mes_projets_dev/Fiers_Artisants/infrastructure/`

| Action | Commande exacte |
|---|---|
| Demarrer la stack dev complete | `docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml up -d --build` |
| Demarrer la stack prod-like complete avec nginx | `COMPOSE_PROFILES=prod-only docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.portainer.yml up -d --build` |
| Voir l'etat des services dev | `docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml ps` |
| Arreter la stack dev proprement | `docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml down --remove-orphans` |
| Arreter la stack prod-like proprement | `COMPOSE_PROFILES=prod-only docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.portainer.yml down --remove-orphans` |
| Redemarrer un service sans rebuild | `docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml restart api` |
| Rebuild un service apres modification | `docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml up -d --build api` |
| Rebuild complet sans cache d'un service | `docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml build --no-cache api` |
| Voir les logs d'un service | `docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.portainer.yml logs -f api` |
| Nettoyage standard | `./scripts/clean-docker.sh` |
| Simulation standard | `./scripts/clean-docker.sh --dry-run` |
| Nettoyage agressif | `./scripts/clean-docker.sh --all` |
| Simulation agressive | `./scripts/clean-docker.sh --dry-run --all` |

## 4. Gestion du cycle de vie complet

### Difference entre `down`, `stop`, `rm`, `prune`

| Commande | Effet | Donnees des volumes |
|---|---|---|
| `docker compose stop` | Arrete les containers sans les supprimer | conservees |
| `docker compose down` | Arrete et supprime containers + reseaux Compose | conservees si pas de `-v` |
| `docker compose rm` | Supprime des containers deja arretes | conservees |
| `docker container prune` | Supprime tous les containers arretes | conservees |
| `docker image prune` | Supprime les images inutilisees selon les options | sans effet |
| `docker builder prune` | Supprime le cache de build | sans effet |
| `docker network prune` | Supprime les reseaux inutilises | sans effet |
| `docker volume prune` | Supprime tous les volumes dangling | dangereux pour ce projet |

### Comment arreter proprement

Scenario recommande en dev :
1. Verifier la stack :

```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml ps
```

2. Si besoin, suivre les logs :

```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml logs -f api admin-web
```

3. Arreter proprement :

```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml down --remove-orphans
```

### Sauvegarde des donnees

Le depot contient `infrastructure/scripts/backup.sh`, mais ce script est oriente serveur :
- il ecrit dans `/opt/fierartisans/backups`
- il suppose que les variables d'environnement sont deja chargees

En consequence :
- sur un poste local, ne pas l'utiliser tel quel sans adapter `BACKUP_DIR`
- sur un serveur, il peut servir de base pour les sauvegardes avant maintenance

### Comment eteindre completement

Si l'objectif est de supprimer les containers mais pas les donnees :

```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml down --remove-orphans
./infrastructure/scripts/clean-docker.sh
```

### Comment rebuild apres modification du code ou du Dockerfile

Si tu modifies le code d'un service :

```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml up -d --build api
```

Si tu modifies le Dockerfile ou des dependencies sensibles :

```bash
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml build --no-cache api
docker compose --env-file .env -f infrastructure/docker-compose.yml -f infrastructure/docker-compose.dev.yml -f infrastructure/docker-compose.portainer.yml up -d api
```

## 5. Nettoyage et maintenance Docker

### Les 4 modes du script `clean-docker.sh`

| Mode | Effet |
|---|---|
| `./infrastructure/scripts/clean-docker.sh --dry-run` | Simulation du nettoyage standard |
| `./infrastructure/scripts/clean-docker.sh` | Nettoyage standard reel |
| `./infrastructure/scripts/clean-docker.sh --dry-run --all` | Simulation du nettoyage agressif |
| `./infrastructure/scripts/clean-docker.sh --all` | Nettoyage agressif reel |

### Ce que chaque mode supprime reellement

| Mode | Conteneurs arretes | Images dangling | Toutes les images inutilisees | Build cache partiel | Build cache complet | Reseaux orphelins | Volumes anonymes orphelins | Volumes nommes critiques |
|---|---|---|---|---|---|---|---|---|
| `--dry-run` | simulation | simulation | non | simulation | non | simulation | simulation | preserves |
| standard | oui | oui | non | oui | non | oui | oui | preserves |
| `--dry-run --all` | simulation | simulation indirecte | simulation | non | simulation | simulation | simulation | preserves |
| `--all` | oui | oui | oui | non | oui | oui | oui | preserves |

### Commandes exactes utilisees par le script

Mode standard :

```bash
docker container prune -f
docker image prune -f
docker builder prune -f
docker network prune -f
docker volume rm <volume_id_hexadecimal_uniquement>
```

Mode `--all` :

```bash
docker container prune -f
docker image prune -a -f
docker builder prune -a -f
docker network prune -f
docker volume rm <volume_id_hexadecimal_uniquement>
```

### Ce qui est protege

Le script ne supprime jamais :
- `postgres_data`
- `mongo_data`
- `redis_data`
- `minio_data`
- `grafana_data`
- `prometheus_data`
- `portainer_data`

### Lecture correcte des "volumes obsoletes"

Dans ce projet, il faut distinguer deux familles :

1. Volumes nommes critiques
- exemples : `infrastructure_postgres_data`, `infrastructure_minio_data`
- ils sont normaux et doivent rester
- ils peuvent apparaitre dangling si la stack est arretee

2. Volumes anonymes orphelins
- exemples : `1fa625a08f17d8bde5c84cded9d8c820e948af209f8a6afa421042d668b3bcc5`
- ils proviennent typiquement des mounts anonymes en dev
- ils sont les vrais candidats au nettoyage sans risque

## 6. Verifications post-nettoyage

Depuis la racine `~/mes_projets_dev/Fiers_Artisants/` :

```bash
docker system df
docker system df -v
docker image ls --filter dangling=true
docker builder du
docker volume ls --filter dangling=true
docker volume ls -q --filter dangling=true | grep -E '^[a-f0-9]{64}$'
docker network ls --filter dangling=true
```

Comment lire ces commandes :
- `docker system df` donne une vue globale de l'espace utilise
- `docker system df -v` donne le detail par image, container et volume
- `docker image ls --filter dangling=true` doit etre vide si les `<none>` ont disparu
- `docker builder du` est la mesure la plus fiable du cache BuildKit
- `docker volume ls --filter dangling=true` peut afficher des volumes critiques si la stack est down
- `docker volume ls -q --filter dangling=true | grep -E '^[a-f0-9]{64}$'` isole seulement les volumes anonymes

Pour verifier les volumes critiques explicitement :

```bash
docker volume ls | grep -E '(^|_)(postgres|mongo|redis|minio|grafana|prometheus|portainer)_data$'
```

## 7. Depannage courant

| Erreur | Cause probable | Solution |
|---|---|---|
| `port is already allocated` / `address already in use` | un autre process ou un ancien container occupe le port | `docker ps`, puis `docker compose ... down --remove-orphans`, ou changer le port local |
| `Container exits immediately` | commande invalide, env manquante, healthcheck en echec | `docker compose ... logs -f <service>` puis verifier `.env` et la commande du service |
| `permission denied` sur un volume | UID/GID ou droits de fichiers host incorrects | verifier les permissions du bind mount ou reconstruire avec les bons droits |
| `network already exists` | ancien reseau non supprime ou projet Compose concurrent | `docker network ls`, puis `docker network prune -f` si le reseau est vraiment orphelin |
| `Cannot connect to service` | service down, port non expose, mauvais host interne/externe | verifier `docker compose ps`, `docker compose logs`, et le mapping de ports |
| Grafana ou Prometheus inaccessibles | port non expose dans la variante Compose utilisee | en dev utiliser `docker-compose.dev.yml`; en prod-like, noter que Prometheus et Grafana ne sont pas exposes dans le Compose de base actuel |
| Portainer montre encore des volumes "dangling" | stack arretee ou volumes anonymes non nettoyes | distinguer volumes nommes critiques et volumes anonymes; lancer `clean-docker.sh --dry-run` puis `--all` si besoin |

## 8. Prompt reutilisable pour l'IA

Copier/coller ce prompt :

```text
Tu interviens sur le monorepo Fiers Artisans.

Contexte :
- backend/ = NestJS
- admin-web/ = Next.js
- fiers_artisans_app/ = Flutter
- infrastructure/ = Docker Compose, Nginx, monitoring, scripts

Contraintes absolues :
- Ne jamais supprimer les volumes de donnees suivants :
  postgres_data, mongo_data, redis_data, minio_data, grafana_data, prometheus_data, portainer_data
- Toujours commencer par un dry-run
- Toujours preciser si la commande doit etre lancee depuis la racine ou depuis infrastructure/

Ta mission :
1. Inspecter l'etat Docker avec :
   - docker compose ps
   - docker system df
   - docker image ls --filter dangling=true
   - docker builder du
   - docker volume ls --filter dangling=true
   - docker network ls --filter dangling=true
2. Expliquer ce qui est sur de nettoyer et ce qui doit etre preserve
3. Proposer d'abord les commandes de simulation
4. Proposer ensuite les commandes reelles
5. Si Portainer affiche encore des ressources obsoletes, expliquer precisement pourquoi
6. Ne jamais recommander docker volume prune ni docker system prune -a --volumes
```

## 9. Diagnostic final si Portainer montre encore des couches obsoletes

### Causes possibles

1. Les volumes critiques sont preserves et la stack est arretee.
- Portainer peut alors les marquer comme non utilises.
- Ce n'est pas une anomalie.

2. Des volumes anonymes s'accumulent en dev.
- C'est tres probable ici a cause de `admin-web`.
- Les mounts `/app/node_modules` et `/app/.next` sont des volumes anonymes.
- A chaque recreation, d'anciens volumes peuvent rester.

3. Des images sont encore referencees par des containers d'autres projets.
- `docker image prune -a` ne supprime pas une image encore liee a un container.

4. Le cache BuildKit n'est pas la meme chose qu'une image dangling.
- Portainer peut montrer des couches alors que `docker image ls --filter dangling=true` est vide.

5. Portainer n'a pas encore rafraichi sa vue.
- Toujours verifier avec la CLI avant de conclure.

### Comment identifier precisement

Depuis la racine `~/mes_projets_dev/Fiers_Artisants/` :

```bash
docker ps -a --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}'
docker image ls --filter dangling=true
docker image ls -a
docker builder du
docker system df -v
docker volume ls --filter dangling=true
docker volume ls -q --filter dangling=true | grep -E '^[a-f0-9]{64}$'
docker volume inspect <nom_ou_id_du_volume>
docker network ls --filter dangling=true
```

### Nettoyer sans risque

Toujours commencer par :

```bash
./infrastructure/scripts/clean-docker.sh --dry-run --all
```

Puis si le resultat est conforme :

```bash
./infrastructure/scripts/clean-docker.sh --all
```

Si tu veux aller plus loin manuellement sans toucher aux volumes nommes critiques :

```bash
# Images <none>
docker image prune -f

# Toutes les images inutilisees
docker image prune -a -f

# Build cache complet
docker builder prune -a -f

# Reseaux orphelins
docker network prune -f

# Volumes anonymes orphelins uniquement
docker volume ls -q --filter dangling=true | grep -E '^[a-f0-9]{64}$' | xargs -r docker volume rm
```

### Regle finale

Si Portainer montre encore :
- des volumes nommes `*_postgres_data`, `*_mongo_data`, `*_minio_data`, etc. alors que la stack est down
- ou des volumes critiques de monitoring

alors ne rien supprimer.

Ce sont probablement des volumes de donnees preserves volontairement, pas des dechets.
