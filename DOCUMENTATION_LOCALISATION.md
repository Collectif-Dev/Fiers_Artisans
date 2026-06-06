# Documentation Localisation Et Visibilite Map

Ce document decrit le fonctionnement reel de la geolocalisation dans Fiers Artisans apres durcissement du flux mobile et backend.

## Objectif

Garantir qu'un artisan ou un client n'entre jamais dans le systeme avec une localisation incoherente entre :

- la position GPS stockee
- la ville affichee
- la commune affichee
- la visibilite map et recherche

La source de verite fonctionnelle est maintenant :

- `latitude/longitude` capturees depuis le terminal

`city` et `commune` restent des champs affiches dans les profils, mais ils sont derives de la position GPS et ne sont plus saisissables manuellement a l'inscription.

## Regles produit

### Inscription artisan

- l'utilisateur doit utiliser `Utiliser ma position`
- `ville` et `commune` sont remplies automatiquement
- les champs restent visibles mais non editables
- si les coordonnees GPS sont absentes : inscription refusee
- si la ville ou la commune n'ont pas pu etre resolues automatiquement : inscription bloquee avec message utilisateur

### Inscription client

- meme logique que l'inscription artisan
- GPS obligatoire pour terminer l'inscription
- `ville` et `commune` sont derivees de la position detectee

### Visibilite artisan

Un artisan ne peut pas devenir visible sur la map ou dans la recherche si sa position GPS stockee est absente.

Blocage backend :

- tentative `is_available = true` sans `user.location`
- reponse : erreur metier `PROFILE_LOCATION_REQUIRED_FOR_AVAILABILITY`

UX mobile :

- message d'erreur explicite
- carte d'alerte visible sur le dashboard si l'artisan est disponible ou abonne actif mais sans localisation synchronisee
- CTA vers les parametres pour corriger la situation

### Mise a jour de localisation

Un bouton `Mettre a jour ma localisation` est disponible dans les parametres, pour :

- `ARTISAN`
- `CLIENT`

Comportement :

1. affichage de la localisation actuellement connue
2. capture GPS a la demande
3. reverse geocoding pour resoudre `ville` et `commune`
4. mise a jour de `latitude/longitude`
5. mise a jour de `city/commune`
6. feedback utilisateur de succes, echec ou position deja a jour

## Invariants backend

### Inscriptions

Les routes suivantes refusent toute inscription sans coordonnees valides :

- `POST /api/v1/auth/register/artisan`
- `POST /api/v1/auth/register/client`

Erreur metier :

- `AUTH_LOCATION_REQUIRED`

### Position utilisateur

La route :

- `PUT /api/v1/users/location`

met a jour :

- `users.location`
- `users.location_updated_at`
- et, si fournis dans la meme requete, `city/commune` du profil associe

Puis reemet les evenements temps reel deja existants pour ne pas casser les consommateurs.

Cette route peut donc servir de point de synchronisation unique pour :

- `latitude`
- `longitude`
- `city`
- `commune`

### Profils exposes

Les lectures de profils remontent maintenant de facon additive :

- `latitude`
- `longitude`
- `location_updated_at`
- `locationUpdatedAt`

Sans breaking change sur les routes existantes.

## Synchronisation temps reel

La mise a jour de position reutilise les contrats existants :

- `ARTISAN_UPDATED`
- `CLIENT_UPDATED`
- `userProfileUpdated`
- `artisanProfileUpdated`
- `artisanVisibilityUpdated`

Consequence :

- les ecrans artisan/client deja relies au realtime sont rafraichis sans ajout de nouvelle route ni nouveau protocole
- la map peut recevoir une visibilite artisan avec position fraiche
- l'admin web continue a recevoir les mises a jour sur les profils

## Impact sur la recherche geolocalisee

La recherche client ne peut retourner un artisan que si les conditions metier suivantes sont vraies en meme temps :

- abonnement actif
- utilisateur actif
- artisan disponible
- position GPS artisan presente
- distance dans le rayon demande

En pratique, un artisan avec `location = null` ne peut pas apparaitre sur la map, meme s'il a paye et meme s'il est disponible.

Ce correctif empeche desormais cet etat incoherent d'entrer ou de persister silencieusement.

## Scenarios de reference

### Scenario A - inscription normale

1. l'utilisateur appuie sur `Utiliser ma position`
2. l'app recupere GPS + ville + commune
3. les champs visibles se remplissent automatiquement
4. l'inscription est autorisee

### Scenario B - GPS detecte mais ville/commune non resolues

1. l'utilisateur appuie sur `Utiliser ma position`
2. le GPS remonte une position mais le reverse geocoding est incomplet
3. la ville ou la commune restent vides
4. l'inscription est refusee
5. message explicite affiche a l'utilisateur

### Scenario C - artisan historique sans localisation

1. artisan deja inscrit avant le durcissement
2. abonnement actif ou disponibilite active
3. pas de coordonnees en base
4. dashboard affiche une alerte de synchronisation
5. l'artisan ouvre `Parametres > Mettre a jour ma localisation`
6. la position est capturee et synchronisee
7. l'artisan redevient eligible a la map

### Scenario D - changement de position

1. l'utilisateur ouvre les parametres
2. il clique `Mettre a jour ma localisation`
3. le systeme capture la nouvelle position GPS
4. ville/commune sont remises a jour
5. les flux relies a la localisation recoivent les mises a jour temps reel

## Fichiers principaux impliques

Backend :

- `backend/src/modules/auth/auth.service.ts`
- `backend/src/modules/users/users.service.ts`

Mobile Flutter :

- `Fiers Artisans/lib/presentation/auth/register_artisan_screen.dart`
- `Fiers Artisans/lib/presentation/auth/register_client_screen.dart`
- `Fiers Artisans/lib/presentation/artisan/artisan_dashboard.dart`
- `Fiers Artisans/lib/presentation/shared/settings_screen.dart`
- `Fiers Artisans/lib/presentation/common/app_text_field.dart`

## Checklist de verification manuelle

- inscription artisan sans `Utiliser ma position` : refusee
- inscription client sans `Utiliser ma position` : refusee
- inscription artisan avec GPS resolu : OK
- inscription client avec GPS resolu : OK
- artisan actif sans position : alerte dashboard visible
- activation disponibilite artisan sans position : refusee avec message explicite
- mise a jour depuis `Parametres > Mettre a jour ma localisation` : OK
- apres mise a jour de localisation artisan : la recherche client et la map peuvent le retrouver si les autres conditions metier sont valides

## Points volontairement non modifies

- aucune nouvelle variable d'environnement
- aucun changement de route
- aucune modification du protocole WebSocket existant
- aucun geocodage manuel texte -> carte sans GPS
- aucune suppression de logique de synchronisation existante
