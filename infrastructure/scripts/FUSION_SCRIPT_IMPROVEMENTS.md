# Script de fusion globale — guide rapide

## À quoi ça sert

`generate_global_fusion.py` agrège le code du dépôt dans `globaliste/global_fusion.txt` pour donner une vue complète à un outil externe ou une IA.

## Commandes

```bash
# Depuis la racine du projet
python3 infrastructure/scripts/generate_global_fusion.py --report

# Mode strict (CI) — échoue si fichier critique manquant
python3 infrastructure/scripts/generate_global_fusion.py --strict
```

**Sorties :**
- `globaliste/global_fusion.txt` — snapshot fusionné (UTF-8 pur)
- `globaliste/fusion_report.log` — rapport (avec `--report`)

## Quand lancer le script

- Après un gros merge ou un patch sécurité
- Avant de partager le contexte complet du projet
- En CI avec `--strict` si tu veux bloquer une fusion incomplète

## Ce qui est inclus / exclu

**Inclus :** code source, configs, `.md`, `.env.example`  
**Exclu :** binaires, images, `node_modules`, `__pycache__`, `.pyc`, `.env` secrets, `globaliste/` lui-même

## Fichiers critiques validés

Le script vérifie la présence de 15 fichiers sensibles (JWT, WebSocket, paiement, mobile, audit interne). Les docs dans `taches_et_problemes/` sont inclus si elles existent localement même si gitignorées.

## Problème connu résolu (2026-06-19)

**Symptôme :** Cursor/VS Code refusait d'ouvrir `global_fusion.txt` (« caractères invalides »).

**Cause :** un fichier `.pyc` binaire avait été fusionné en texte (octets NUL `\x00`).

**Correctifs appliqués :**
- exclusion `__pycache__` et `.pyc`
- rejet des fichiers binaires (détection NUL)
- nettoyage des caractères de contrôle dans la sortie
- plus de dump hex de binaires dans la fusion

## En cas de problème

```bash
# Vérifier qu'il n'y a pas d'octets NUL
python3 -c "d=open('globaliste/global_fusion.txt','rb').read(); print(d.count(b'\\x00'))"
# Doit afficher 0

# Lire le rapport
cat globaliste/fusion_report.log
```
