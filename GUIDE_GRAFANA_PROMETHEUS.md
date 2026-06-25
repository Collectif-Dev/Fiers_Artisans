# Guide Grafana + Prometheus - Fiers Artisans

Ce guide explique comment utiliser Grafana et Prometheus dans ce projet, pour une equipe junior niveau 0.

Objectif : savoir ouvrir les interfaces, verifier que la surveillance fonctionne, lire les premiers graphiques, lancer les commandes utiles et diagnostiquer les problemes les plus courants.

Lecture conseillee pour un nouveau DevOps :

1. lire les sections 1 a 3 pour comprendre les roles
2. demarrer la stack avec la section 4
3. ouvrir Grafana avec la section 5
4. faire le premier tour d'interface avec les sections 6 et 7
5. utiliser les commandes des sections 9 a 11 quand un ecran ne correspond pas a ce qui est attendu
6. lire les fichiers du projet avec la section 13 avant de modifier quoi que ce soit

## 1. A quoi servent Grafana et Prometheus

### Prometheus

Prometheus collecte des mesures techniques.

Dans ce projet, il va lire les metriques de l'API Fiers Artisans sur :

```text
http://api:3000/api/v1/metrics
```

Ce chemin est interne au reseau Docker. Prometheus utilise le nom de service Docker `api`, pas `localhost`.

Prometheus permet de repondre a des questions comme :

- est-ce que l'API expose bien ses metriques ?
- est-ce que Prometheus arrive a joindre l'API ?
- est-ce que les targets sont up ou down ?
- est-ce que la collecte est stable ?

### Grafana

Grafana affiche les donnees collectees par Prometheus sous forme de tableaux, graphiques et indicateurs.

Dans ce projet, Grafana lit Prometheus avec la datasource :

```text
http://prometheus:9090
```

Ce chemin est aussi interne au reseau Docker. Depuis le navigateur, l'equipe utilise Grafana via :

```text
http://localhost:3001
```

## 2. Services du projet

| Outil | Service Docker | Container | Role |
|---|---|---|---|
| Prometheus | `prometheus` | `fiers-prometheus` | collecte les metriques |
| Grafana | `grafana` | `fiers-grafana` | affiche les dashboards |
| API | `api` | `fiers-api` | expose `/api/v1/metrics` |

En developpement local :

| Interface | URL |
|---|---|
| Grafana | `http://localhost:3001` |
| API health | `http://localhost:3000/api/v1/health` |
| API metrics | `http://localhost:3000/api/v1/metrics` |

Prometheus n'est pas expose directement sur l'hote dans le Compose de dev actuel. Il est accessible par Grafana via le reseau Docker interne.

## 3. Fichiers importants

| Fichier | Role |
|---|---|
| `infrastructure/monitoring/prometheus.yml` | configuration Prometheus |
| `infrastructure/monitoring/grafana/provisioning/datasources/prometheus.yml` | datasource Grafana vers Prometheus |
| `infrastructure/monitoring/grafana/provisioning/dashboards/dashboards.yml` | chargement automatique des dashboards |
| `infrastructure/monitoring/grafana/provisioning/alerting/empty-rules.yaml` | provisioning alerting actuellement vide |
| `infrastructure/monitoring/grafana/dashboards/fiers-overview.json` | dashboard projet existant |
| `backend/src/modules/health/metrics.controller.ts` | endpoint backend qui expose les metriques |
| `backend/src/modules/health/metrics.service.ts` | collecte des metriques Node.js par `prom-client` |

Regle importante : ne pas modifier les dashboards directement dans l'interface Grafana pour les rendre permanents, car les dashboards sont provisionnes depuis les fichiers du depot.

## 4. Demarrer la stack avec Grafana et Prometheus

Depuis la racine du depot :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  up -d api prometheus grafana
```

Pour demarrer toute la stack dev :

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

Les services attendus pour ce guide :

- `api`
- `prometheus`
- `grafana`

## 5. Ouvrir Grafana

Dans le navigateur :

```text
http://localhost:3001
```

Connexion :

- utilisateur : `admin`
- mot de passe : valeur de `GRAFANA_ADMIN_PASSWORD` dans `.env`
- si la variable n'est pas definie en local, le Compose utilise le fallback `admin`

Ne jamais documenter ni partager le vrai mot de passe de l'environnement serveur.

### Premier ecran apres connexion

Apres connexion, Grafana affiche generalement une page d'accueil avec un menu lateral.

Les zones importantes pour ce projet :

| Zone interface | A quoi ca sert dans ce projet |
|---|---|
| `Dashboards` | ouvrir les tableaux de bord Fiers Artisans |
| `Explore` | tester une requete Prometheus sans modifier un dashboard |
| `Connections` / `Data sources` | verifier que Grafana connait Prometheus |
| barre de temps en haut a droite | choisir la periode affichee, par exemple `Last 6 hours` |
| bouton refresh en haut a droite | recharger les donnees |
| menu `...` d'un panel | inspecter les donnees, la requete et le JSON du panel |

Selon la largeur d'ecran, le menu lateral peut etre reduit. Si les textes ne sont pas visibles, cliquer sur les icones ou agrandir la fenetre.

### Regler la periode d'affichage

En haut a droite d'un dashboard :

1. cliquer sur la periode, par exemple `Last 6 hours`
2. choisir une periode plus courte pour verifier un probleme recent, par exemple `Last 15 minutes`
3. choisir une periode plus longue si le graphe semble vide, par exemple `Last 24 hours`
4. cliquer sur le bouton refresh si les valeurs ne changent pas

Le dashboard projet est configure avec un refresh automatique de `10s`.

### Difference entre dashboard et Explore

`Dashboards` sert a consulter les vues deja preparees pour l'equipe.

`Explore` sert a tester une requete ponctuelle. C'est l'endroit le plus sur pour apprendre PromQL, car on ne modifie pas le dashboard projet.

## 6. Trouver le dashboard Fiers Artisans

Dans Grafana :

1. ouvrir le menu lateral
2. aller dans `Dashboards`
3. ouvrir le dossier `Fiers Artisans`
4. ouvrir `Fiers Artisans - Overview`

Ce dashboard est charge depuis :

```text
infrastructure/monitoring/grafana/dashboards/fiers-overview.json
```

Il contient notamment :

- `Prometheus UP Targets`
- `Targets Up/Down`
- `Prometheus Scrape Duration`
- `Current Targets`

### Lire le panel `Prometheus UP Targets`

Ce panel est un indicateur simple.

Il execute :

```promql
sum(up)
```

Lecture :

- valeur attendue si tout va bien : nombre de targets Prometheus joignables
- valeur trop basse : au moins une target est down
- valeur vide : Prometheus ou la datasource Grafana ne repond probablement pas

Dans le projet actuel, Prometheus surveille :

- l'API Fiers Artisans avec le job `fiers-api`
- Prometheus lui-meme avec le job `prometheus`

### Lire le panel `Targets Up/Down`

Ce panel affiche la requete :

```promql
up
```

Chaque courbe correspond a une target.

Les labels utiles :

| Label | Exemple | Signification |
|---|---|---|
| `job` | `fiers-api` | nom du job dans `prometheus.yml` |
| `instance` | `api:3000` | adresse appelee par Prometheus |
| `service` | `fiers-artisans-api` | label ajoute pour identifier le service |

Lecture :

- ligne a `1` : target joignable
- ligne a `0` : target non joignable
- ligne absente : Prometheus ne recoit pas cette serie ou la periode choisie ne contient pas de donnees

### Lire le panel `Current Targets`

Ce panel affiche `up` en mode table.

Il est utile pour les debutants, car il montre les labels sous forme de colonnes. Si un panel graphique n'est pas clair, commencer par ce tableau.

### Inspecter un panel

Pour comprendre un panel :

1. survoler le panel
2. cliquer sur le menu `...`
3. choisir `Inspect`
4. ouvrir `Data` pour voir les valeurs brutes
5. ouvrir `Query` pour voir la requete Prometheus
6. ouvrir `Panel JSON` si un dev doit comparer avec le fichier JSON du depot

Ne pas modifier et sauvegarder un panel depuis l'interface pour un changement durable. Le fichier du depot reste la source de verite.

### Tester une requete dans Explore

Dans Grafana :

1. ouvrir `Explore`
2. choisir la datasource `Prometheus`
3. entrer la requete :

```promql
up
```

4. cliquer sur `Run query`
5. passer entre vue graphique et vue table si necessaire

Autres requetes utiles pour debuter :

```promql
sum(up)
```

```promql
up{job="fiers-api"}
```

```promql
up{job="prometheus"}
```

Si `up{job="fiers-api"}` vaut `0`, le probleme est probablement cote API, reseau Docker ou endpoint `/api/v1/metrics`.

### Comprendre l'onglet Alerting

Grafana a une zone `Alerting` pour definir des alertes.

Dans ce projet, aucune regle d'alerte active n'est configuree pour l'instant. Le fichier actuel est :

```text
infrastructure/monitoring/grafana/provisioning/alerting/empty-rules.yaml
```

Son contenu declare une configuration vide :

```yaml
apiVersion: 1
groups: []
```

Conclusion :

- si l'onglet `Alerting` ne montre aucune alerte projet, c'est normal
- ne pas creer une alerte definitive uniquement depuis l'interface sans la versionner
- une future alerte doit etre documentee et testee comme un changement monitoring

### Ce qui est visible dans l'interface mais versionne dans le code

| Element | Visible dans Grafana | Source durable dans le depot |
|---|---|---|
| Datasource Prometheus | `Connections` > `Data sources` | `infrastructure/monitoring/grafana/provisioning/datasources/prometheus.yml` |
| Dossier dashboards | `Dashboards` > `Fiers Artisans` | `infrastructure/monitoring/grafana/provisioning/dashboards/dashboards.yml` |
| Dashboard overview | `Fiers Artisans - Overview` | `infrastructure/monitoring/grafana/dashboards/fiers-overview.json` |
| Alertes | `Alerting` | `infrastructure/monitoring/grafana/provisioning/alerting/empty-rules.yaml` |

## 7. Comprendre les premiers indicateurs

### `up`

Requete Prometheus :

```promql
up
```

Signification :

- `1` : Prometheus arrive a joindre la target
- `0` : Prometheus n'arrive pas a joindre la target

Dans ce projet, les jobs attendus sont :

- `fiers-api`
- `prometheus`

### `sum(up)`

Requete :

```promql
sum(up)
```

Signification : nombre total de targets actuellement joignables.

Si tout va bien, la valeur doit correspondre au nombre de targets configurees dans Prometheus.

### Duree de scrape

Requete utilisee par le dashboard :

```promql
rate(prometheus_target_interval_length_seconds_sum[5m])
```

Signification : aide a voir si la collecte Prometheus reste stable.

### Labels Prometheus a connaitre

Une metrique Prometheus peut avoir des labels. Un label est une information accrochee a la mesure.

Exemple logique :

```text
up{job="fiers-api", instance="api:3000"} 1
```

Lecture :

- `up` est le nom de la metrique
- `job="fiers-api"` indique le job Prometheus
- `instance="api:3000"` indique la cible appelee
- `1` est la valeur

Erreur classique debutant : chercher `localhost:3000` dans Prometheus. Dans Docker, Prometheus appelle l'API avec `api:3000`.

## 8. Verifier les metriques sans Grafana

### Depuis le navigateur

API health :

```text
http://localhost:3000/api/v1/health
```

API metrics :

```text
http://localhost:3000/api/v1/metrics
```

### Depuis le terminal

Verifier la sante API :

```bash
curl -i http://localhost:3000/api/v1/health
```

Verifier que l'API expose les metriques :

```bash
curl -s http://localhost:3000/api/v1/metrics | head
```

Chercher les metriques Node.js par defaut :

```bash
curl -s http://localhost:3000/api/v1/metrics | rg 'nodejs|process'
```

Si `rg` n'est pas disponible :

```bash
curl -s http://localhost:3000/api/v1/metrics | grep -E 'nodejs|process'
```

## 9. Commandes Docker utiles

Voir les containers :

```bash
docker ps --filter name=fiers-
```

Voir l'etat Compose :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  ps
```

Logs Grafana :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  logs -f grafana
```

Logs Prometheus :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  logs -f prometheus
```

Logs API :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  logs -f api
```

Redemarrer Grafana :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  restart grafana
```

Redemarrer Prometheus :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  restart prometheus
```

Verifier la configuration Compose :

```bash
cd infrastructure
docker compose --env-file ../.env \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  -f docker-compose.portainer.yml \
  config
```

## 10. Tester Prometheus depuis le container

Prometheus n'est pas expose directement sur l'hote en dev. Pour tester son endpoint de sante :

```bash
docker exec fiers-prometheus wget -qO- http://localhost:9090/-/healthy
```

Tester une requete Prometheus sans interface :

```bash
docker exec fiers-prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=up'
```

Tester `sum(up)` sans interface :

```bash
docker exec fiers-prometheus wget -qO- 'http://localhost:9090/api/v1/query?query=sum%28up%29'
```

Ces commandes sont utiles quand Grafana ne s'ouvre pas mais que l'on veut savoir si Prometheus fonctionne encore.

Pour verifier que Grafana voit Prometheus, le plus simple est d'utiliser l'interface Grafana :

1. ouvrir `http://localhost:3001`
2. aller dans `Connections`
3. ouvrir `Data sources`
4. choisir `Prometheus`
5. verifier que l'URL est `http://prometheus:9090`

La datasource est provisionnee par fichier et n'est pas editable depuis l'interface.

### Verifier une datasource dans Grafana

Dans l'interface :

1. ouvrir `Connections`
2. ouvrir `Data sources`
3. cliquer sur `Prometheus`
4. verifier le champ `URL`

Valeur attendue :

```text
http://prometheus:9090
```

Si la datasource apparait en lecture seule, c'est normal. Elle vient du fichier :

```text
infrastructure/monitoring/grafana/provisioning/datasources/prometheus.yml
```

## 11. Diagnostic rapide

### Probleme : Grafana ne s'ouvre pas

Verifier :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  ps grafana
```

Puis :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  logs --tail 100 grafana
```

Causes frequentes :

- le service `grafana` n'est pas lance
- le port `3001` est deja utilise
- Prometheus n'est pas healthy, donc Grafana attend
- le volume Grafana contient un ancien etat local

Ne pas supprimer le volume `grafana_data` sans validation humaine, car il peut contenir des donnees utiles.

### Probleme : dashboard vide

Verifier :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  ps prometheus api
```

Verifier l'API metrics :

```bash
curl -i http://localhost:3000/api/v1/metrics
```

Verifier les logs Prometheus :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  logs --tail 100 prometheus
```

Causes frequentes :

- l'API n'est pas lancee
- `/api/v1/metrics` ne repond pas
- Prometheus ne rejoint pas `api:3000`
- la datasource Grafana ne pointe pas vers Prometheus
- la plage de temps Grafana est trop courte

### Probleme : target `fiers-api` down

Verifier que l'API est healthy :

```bash
curl -i http://localhost:3000/api/v1/health
```

Verifier les logs API :

```bash
docker compose --env-file .env \
  -f infrastructure/docker-compose.yml \
  -f infrastructure/docker-compose.dev.yml \
  -f infrastructure/docker-compose.portainer.yml \
  logs --tail 100 api
```

Verifier la configuration Prometheus :

```bash
sed -n '1,120p' infrastructure/monitoring/prometheus.yml
```

La target attendue doit rester :

```yaml
targets: ['api:3000']
```

## 12. Modifier un dashboard proprement

Les dashboards sont provisionnes depuis le depot. Dans ce projet :

```text
infrastructure/monitoring/grafana/dashboards/
```

Regle d'equipe :

- ne pas faire une modification definitive uniquement dans l'interface Grafana
- exporter le dashboard JSON si une modification est testee dans l'interface
- commiter le JSON dans le depot apres review
- redemarrer Grafana ou attendre le rechargement automatique

Le provider Grafana recharge les dashboards toutes les 30 secondes.

## 13. Lire les fichiers de code du projet

Cette section explique ou Grafana et Prometheus sont branches dans le projet. Elle est importante pour un DevOps nouveau sur la stack.

### Vue globale du chemin des donnees

```text
backend prom-client
  -> /api/v1/metrics
  -> Prometheus scrape api:3000
  -> Grafana datasource prometheus:9090
  -> dashboard Fiers Artisans - Overview
```

### `backend/src/main.ts`

Role : demarrage global de l'API.

Point important :

```ts
app.setGlobalPrefix('api/v1', {
  exclude: ['api/docs', 'api/docs-json'],
});
```

Ce prefixe explique pourquoi le controller `metrics` devient accessible sur :

```text
/api/v1/metrics
```

Sans ce prefixe global, le controller serait seulement sur :

```text
/metrics
```

Conclusion pour l'equipe :

- ne pas changer `api/v1` sans verifier Prometheus
- ne pas changer le controller `metrics` sans verifier `prometheus.yml`
- si l'URL `/api/v1/metrics` ne repond plus, verifier d'abord `main.ts` et `metrics.controller.ts`

### `backend/src/modules/health/health.module.ts`

Role : declarer les controllers et services de health/metrics.

Elements importants :

```ts
controllers: [HealthController, MetricsController],
providers: [MetricsService, PaymentMinioIndicator],
```

Ce fichier relie :

- `HealthController` pour `/api/v1/health`
- `MetricsController` pour `/api/v1/metrics`
- `MetricsService` pour produire les donnees Prometheus

Si `MetricsController` est retire de ce module, `/api/v1/metrics` ne sera plus expose.

### `backend/src/modules/health/metrics.controller.ts`

Role : exposer les metriques en HTTP.

Points importants :

```ts
@Controller('metrics')
```

Ce decorateur cree la route `metrics`.

Avec le prefixe global `api/v1`, l'URL complete devient :

```text
http://localhost:3000/api/v1/metrics
```

Autres points importants :

```ts
@SkipThrottle()
```

La route metrics evite le rate limit applicatif. C'est utile car Prometheus vient lire cette route regulierement.

```ts
response.setHeader('Content-Type', this.metricsService.getContentType());
response.setHeader('Cache-Control', 'no-store');
```

Le `Content-Type` doit etre celui attendu par Prometheus.

`Cache-Control: no-store` evite de servir une ancienne version des metriques.

Conclusion pour l'equipe :

- ne pas retirer `@SkipThrottle()` sans reflechir au scrape Prometheus
- ne pas changer le `Content-Type`
- ne pas envelopper cette reponse dans un format JSON applicatif classique

### `backend/src/modules/health/metrics.service.ts`

Role : creer le registre Prometheus et collecter les metriques Node.js par defaut.

Point important :

```ts
collectDefaultMetrics({ register: this.registry });
```

Cette ligne active les metriques par defaut de `prom-client`, par exemple :

- metriques process
- metriques memoire
- metriques event loop
- metriques Node.js

Le fichier utilise aussi un registre partage :

```ts
const metricsRegistry = new Registry();
```

Conclusion pour l'equipe :

- ajouter de nouvelles metriques backend dans ou autour de ce service
- eviter de creer plusieurs registres sans raison
- eviter les labels contenant des donnees sensibles

### `infrastructure/monitoring/prometheus.yml`

Role : dire a Prometheus quoi collecter.

Configuration projet :

```yaml
scrape_configs:
  - job_name: 'fiers-api'
    metrics_path: '/api/v1/metrics'
    static_configs:
      - targets: ['api:3000']
        labels:
          service: 'fiers-artisans-api'
```

Lecture :

- `job_name` donne le nom visible dans Grafana avec le label `job`
- `metrics_path` doit rester aligne avec le backend
- `targets: ['api:3000']` utilise le nom du service Docker `api`
- `service: 'fiers-artisans-api'` ajoute un label lisible pour les dashboards

Il y a aussi un job Prometheus :

```yaml
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']
```

Ce job permet a Prometheus de se surveiller lui-meme.

### `infrastructure/docker-compose.yml`

Role : declarer les services `prometheus` et `grafana`.

Pour Prometheus :

- container : `fiers-prometheus`
- fichier de config monte en lecture seule
- volume persistant : `prometheus_data`
- healthcheck sur `http://localhost:9090/-/healthy`

Pour Grafana :

- container : `fiers-grafana`
- mot de passe admin via `GRAFANA_ADMIN_PASSWORD`
- volume persistant : `grafana_data`
- provisioning monte depuis `infrastructure/monitoring/grafana/provisioning`
- dashboards montes depuis `infrastructure/monitoring/grafana/dashboards`
- depend de Prometheus healthy

Conclusion pour l'equipe :

- Grafana demarre apres Prometheus
- les dashboards viennent du depot
- les donnees Grafana et Prometheus sont dans des volumes nommes
- ne pas supprimer ces volumes sans validation humaine

### `infrastructure/docker-compose.dev.yml`

Role : exposer Grafana sur la machine locale en developpement.

Configuration importante :

```yaml
grafana:
  ports:
    - "3001:3000"
```

Lecture :

- `3001` est le port sur la machine du dev
- `3000` est le port interne du container Grafana
- donc le navigateur utilise `http://localhost:3001`

### `infrastructure/monitoring/grafana/provisioning/datasources/prometheus.yml`

Role : declarer automatiquement Prometheus comme datasource Grafana.

Configuration importante :

```yaml
name: Prometheus
uid: prometheus
type: prometheus
url: http://prometheus:9090
isDefault: true
editable: false
```

Lecture :

- `uid: prometheus` est utilise dans le dashboard JSON
- `url` utilise le nom de service Docker `prometheus`
- `isDefault: true` rend cette datasource disponible par defaut
- `editable: false` empeche les modifications manuelles depuis l'interface

### `infrastructure/monitoring/grafana/provisioning/dashboards/dashboards.yml`

Role : dire a Grafana ou lire les dashboards.

Configuration importante :

```yaml
folder: 'Fiers Artisans'
allowUiUpdates: false
path: /var/lib/grafana/dashboards
```

Lecture :

- le dashboard apparait dans le dossier `Fiers Artisans`
- les modifications definitives doivent passer par les fichiers JSON
- Grafana lit les dashboards depuis le dossier monte dans le container

### `infrastructure/monitoring/grafana/dashboards/fiers-overview.json`

Role : dashboard actuel du projet.

Informations importantes :

- `uid`: `fiers-overview`
- `title`: `Fiers Artisans - Overview`
- `refresh`: `10s`
- periode par defaut : `now-6h`
- datasource utilisee : `uid: prometheus`

Panels actuels :

| Panel | Requete | Role |
|---|---|---|
| `Prometheus UP Targets` | `sum(up)` | nombre de targets up |
| `Targets Up/Down` | `up` | etat de chaque target |
| `Prometheus Scrape Duration` | `rate(prometheus_target_interval_length_seconds_sum[5m])` | stabilite de collecte |
| `Current Targets` | `up` en table | lecture detaillee des targets |

Si un dev change `uid: prometheus` dans la datasource, ce dashboard peut casser.

## 14. Ajouter une nouvelle metrique backend

Le backend utilise `prom-client`.

Avant d'ajouter une metrique :

1. verifier que le besoin est reel
2. choisir un nom clair
3. eviter toute donnee personnelle ou sensible dans les labels
4. eviter les labels qui peuvent creer trop de valeurs differentes
5. ajouter un dashboard seulement si la metrique est utile a l'equipe

Exemples de labels a eviter :

- numero de telephone
- email
- nom complet
- token
- identifiant de paiement externe
- contenu de message

Exemples de labels acceptables :

- nom de service
- statut technique limite
- type d'operation
- environnement

### Methode prudente pour ajouter une metrique

Avant de coder :

1. definir la question a laquelle la metrique doit repondre
2. verifier si une metrique existante suffit
3. choisir le type de metrique : compteur, jauge ou histogramme
4. definir les labels autorises
5. verifier que les labels ne peuvent pas exploser en nombre de valeurs
6. ajouter un test ou une verification manuelle de `/api/v1/metrics`
7. ajouter ou modifier un panel Grafana si la metrique doit etre visible

Types simples :

| Type | Usage |
|---|---|
| Counter | compter des evenements qui montent toujours |
| Gauge | mesurer une valeur qui monte et descend |
| Histogram | mesurer des durees ou tailles avec distribution |

Exemples de mauvaises idees :

- label par numero de telephone
- label par utilisateur
- label par message
- label par transaction externe

Ces labels creent trop de series et peuvent rendre Prometheus lourd.

## 15. Ce qu'il ne faut pas faire

- Ne pas exposer Prometheus publiquement sans validation.
- Ne pas commiter de mot de passe Grafana.
- Ne pas supprimer `grafana_data` ou `prometheus_data` sans validation.
- Ne pas modifier `prometheus.yml` sans verifier les impacts Docker.
- Ne pas renommer un job Prometheus sans mettre a jour les dashboards.
- Ne pas mettre de donnees utilisateur sensibles dans les metriques.
- Ne pas considerer un dashboard vert comme preuve que le parcours utilisateur fonctionne.

## 16. Checklist equipe avant merge d'un changement monitoring

- [ ] `docker compose config` passe.
- [ ] `api` demarre.
- [ ] `prometheus` est healthy.
- [ ] `grafana` est accessible sur `http://localhost:3001`.
- [ ] `/api/v1/metrics` repond.
- [ ] Le dashboard `Fiers Artisans - Overview` s'ouvre.
- [ ] Les panels `up` montrent les targets attendues.
- [ ] Aucune metrique n'expose de donnee sensible.
- [ ] Les requetes Grafana utilisent la datasource `prometheus`.
- [ ] Les changements de route backend sont repercutes dans `prometheus.yml`.
- [ ] Les fichiers modifies sont limites au besoin.

## 17. Resume niveau zero

- Prometheus collecte.
- Grafana affiche.
- L'API expose les metriques sur `/api/v1/metrics`.
- Grafana local s'ouvre sur `http://localhost:3001`.
- La datasource Grafana vers Prometheus est deja configuree.
- Le dashboard projet est dans le dossier Grafana `Fiers Artisans`.
- `main.ts` ajoute le prefixe global `api/v1`.
- `metrics.controller.ts` expose la route `metrics`.
- `prometheus.yml` relie Prometheus a `api:3000/api/v1/metrics`.
- Si un graphe est vide, verifier dans l'ordre : `api`, `/metrics`, `prometheus`, `grafana`.
