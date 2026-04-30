# Global Fusion - Documentation

## Date de generation
2026-04-30 11:43:37 CEST

## Objectif
Creer un fichier unique contenant l'integralite du code source utile et de la configuration utile du projet, sans modifier ni supprimer les fichiers du projet source.

## Fichier genere
- `globaliste/global_fusion.txt`

## Nombre de fichiers fusionnes
- 394 fichiers

## Methode utilisee
- Scan recursif du projet avec `find`
- Tri des chemins par ordre alphabetique
- Filtrage des fichiers binaires et temporaires
- Validation texte via `grep -Iq`
- Injection dans un fichier unique avec separateurs structures
- Format de bloc: `PATH: /chemin/du/fichier`

## Exclusions appliquees
### Dossiers exclus
- `.git`
- `admin-web/node_modules`
- `backend/node_modules`
- `fiers_artisans_app/.dart_tool`
- `fiers_artisans_app/build`
- `admin-web/.next`
- `admin-web/.next-local`
- `fiers_artisans_app/.idea`
- `GlobalList`
- `globaliste` (evite l'auto-inclusion)
- Dossiers generiques: `dist`, `build`, `vendor`, `venv`, `.venv`, `.cache`

### Fichiers exclus
- Fichiers systeme/non pertinents: `.gitignore`, `.dockerignore`
- Fichiers lock: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `composer.lock`, `Pipfile.lock`, `poetry.lock`, `Cargo.lock`
- Fichier secret local: `.env`
- Fichiers generes/temporaires: `*.log`, `*.tmp`, `*.temp`, `*.cache`
- Binaires/assets lourds: `*.png`, `*.jpg`, `*.jpeg`, `*.gif`, `*.webp`, `*.ico`, `*.pdf`, `*.zip`, `*.tar`, `*.gz`, `*.7z`, `*.apk`, `*.aab`, `*.keystore`, `*.otf`, `*.ttf`

## Structure du fichier fusionne
Le fichier `global_fusion.txt` est organise par blocs:
1. Separateur visuel
2. Ligne `PATH: /...`
3. Contenu brut du fichier

Cette structure garantit la lisibilite, la tracabilite et la reutilisation du contenu.
