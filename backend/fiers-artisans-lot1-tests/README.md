# Fiers Artisans — Lot 1 : tests préalables de confidentialité

## Référence
- Dépôt : `Collectif-Dev/Fiers_Artisans`
- Branche lue : `develop`
- Commit lu : `b55fccba060ea42c1f30b17f501052121a0fb23c`
- Mode : audit / tests dans un espace isolé, aucune écriture GitHub.
- Données : 100 % fictives, aucun secret réel.

## Contenu
- `backend/test/artisan-public.e2e-spec.ts` : **test Jest/NestJS à exécuter sur une copie locale complète du dépôt** ; contient quatre tests de caractérisation de l'existant et trois tests de conformité cible volontairement rouges avant correction.
- `simulation/comportement-actuel.cjs` : reproduction autonome des **conditions de la méthode `getArtisanPublicProfile`** et de l'enveloppe JSON de l'intercepteur, à partir de la lecture du code distant. Ce n'est pas le serveur HTTP du projet.
- `simulation/contrats-securite.test.cjs` : six tests Node `node:test` exécutés dans l'espace isolé.
- `resultats-simulation.txt` : sortie de test réellement obtenue, 3 réussites et 3 échecs attendus.

## Résultats exécutés
- `node --test simulation/contrats-securite.test.cjs` : 6 tests ; 3 OK ; 3 échecs attendus ; code de sortie 1.
- Vérification de syntaxe de `artisan-public.e2e-spec.ts` par `typescript.transpileModule` : aucun diagnostic de syntaxe.
- NestJS/Jest et la vraie API HTTP : **non exécutés**. Le bac à sable n'a pas de dépendances NestJS et ne peut pas résoudre github.com pour cloner le projet.

## Exécution sur une COPIE LOCALE du dépôt (aucun push)
1. Vérifier une copie de travail propre et sa branche : `git status --short` puis `git branch --show-current` ; mettre à jour uniquement selon votre politique d'équipe.
2. Contrôler la référence Git avant d'ajouter le fichier : `git rev-parse HEAD` ; le test a été préparé pour le commit ci-dessus.
3. Copier le fichier `backend/test/artisan-public.e2e-spec.ts` dans le `backend/test/` de cette copie locale.
4. Utiliser Node.js >=22 <23. Dans `backend/`, installer avec `npm ci` sur cette copie de travail isolée.
5. Lancer : `npm run test:e2e -- --runInBand artisan-public.e2e-spec.ts`
6. Résultat attendu AVANT correction : quatre tests de base devraient réussir et trois tests de conformité devraient échouer (risque de divulgation, compte désactivé, abonnement payant). Ce résultat reste **à confirmer réellement** avec NestJS. Ne pas réécrire une assertion de sécurité pour la faire passer.
7. Ne pas exécuter de migration, ne pas utiliser la base ou les secrets de production. Le module de test injecte des repositories simulés.
8. Ne pas committer ni pousser avant validation des essais locaux et instruction explicite, conformément à `AGENTS.md` et `codex-chat.md`.

## Interprétation / limites
- Les trois échecs dans la simulation suggèrent fortement des défauts, mais la reproduction n'inclut ni les décorateurs TypeORM ni l'ensemble du pipeline NestJS, ni une base PostgreSQL.
- Le test HTTP proposé constitue la preuve pratique à obtenir : il instanciera le contrôleur réel, `UsersService`, `TransformInterceptor` et `GlobalExceptionFilter`, avec repositories factices.
- L'assertion « 404 compte désactivé » correspond à la règle cible. Le comportement actuel de l'endpoint peut être différent : c'est précisément l'écart à mesurer.
- Aucune règle de certification, de GPS ou d'OTP n'a été modifiée.
