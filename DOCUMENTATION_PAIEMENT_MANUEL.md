# Documentation Paiement Manuel

## Objectif

Ce document decrit le systeme de paiement manuel Mobile Money de **Fiers Artisans** de bout en bout :

- son role metier
- son architecture technique
- ses entites et ses statuts
- ses endpoints backend
- ses comportements mobile et admin
- ses scenarios normaux et degrades
- ses invariants de securite et d'anti-regression
- ses points d'exploitation, de test et de diagnostic

Le document decrit l'etat **reel** du depot au moment de sa generation.

---

## 1. Perimetre Fonctionnel

Le paiement manuel permet a un artisan de payer son abonnement via Mobile Money quand aucun flux de paiement automatique n'est utilise.

Le parcours metier est le suivant :

1. l'artisan initie une transaction manuelle
2. l'application lui affiche le numero de depot selon l'operateur
3. l'artisan effectue le paiement et envoie une preuve
4. un administrateur valide, rejette, rouvre ou marque le remboursement
5. le backend pilote les statuts, l'expiration, les notifications et la synchro temps reel

Le module couvre :

- `ORANGE_MONEY`
- `MTN_MOMO`
- `WAVE`
- `MOOV_MONEY` present dans le code, mais indisponible tant qu'aucun numero receveur n'est configure

Montant standard actuel :

- `5000 FCFA` par defaut, configurable via `PAYMENT_MANUAL_AMOUNT_FCFA`

Delai d'expiration admin actuel :

- `72 heures` par defaut, configurable via `PAYMENT_MANUAL_EXPIRY_HOURS`

---

## 2. Stack Technique

## 2.1. Couches impliquees

| Couche | Role |
|---|---|
| `backend/` NestJS | orchestration metier, securite, statuts, notifications, cron, anti-fraude |
| PostgreSQL | persistance des transactions et des preuves |
| MinIO | stockage binaire des captures de preuve |
| Redis | rate limiting des soumissions de preuve |
| `fiers_artisans_app/` Flutter | experience artisan |
| `admin-web/` Next.js | interface de moderation et de traitement |
| SSE + WebSocket sync | mise a jour quasi temps reel admin et mobile |

## 2.2. Fichiers backend clefs

| Fichier | Role |
|---|---|
| `backend/src/modules/payment-manual/entities/payment-manual.entity.ts` | transaction manuelle |
| `backend/src/modules/payment-manual/entities/payment-proof.entity.ts` | preuve de paiement |
| `backend/src/modules/payment-manual/services/payment-manual.service.ts` | logique metier principale |
| `backend/src/modules/payment-manual/controllers/payment-manual.controller.ts` | API artisan |
| `backend/src/modules/payment-manual/controllers/payment-manual-admin.controller.ts` | API admin |
| `backend/src/modules/payment-manual/cron/payment-expiration.cron.ts` | expiration horaire + verification d'integrite |
| `backend/src/modules/payment-manual/events/payment-realtime.service.ts` | emission des evenements temps reel |

## 2.3. Fichiers mobile clefs

| Fichier | Role |
|---|---|
| `fiers_artisans_app/lib/data/models/manual_payment_model.dart` | modele de transaction |
| `fiers_artisans_app/lib/providers/payment_manual_provider.dart` | orchestration client, mapping erreurs/statuts |
| `fiers_artisans_app/lib/presentation/artisan/manual_payment_page.dart` | ecran principal du paiement manuel |
| `fiers_artisans_app/lib/presentation/artisan/payment_status_widget.dart` | affichage du statut, demande, tentatives, cooldown |

## 2.4. Fichiers admin clefs

| Fichier | Role |
|---|---|
| `admin-web/src/app/(dashboard)/payments/manual/page-client.tsx` | liste, detail, actions admin |
| `admin-web/src/types/index.ts` | types TypeScript des paiements manuels |

---

## 3. Modele de Donnees

## 3.1. Entite `payment_manual`

La table `payment_manual` represente **une demande manuelle**.

Champs fonctionnels principaux :

| Champ | Role |
|---|---|
| `id` | identifiant technique UUID |
| `subscription_id` | rattachement a l'abonnement artisan |
| `transaction_id` | identifiant metier visible a l'utilisateur |
| `amount_fcfa` | montant de la demande |
| `provider` | operateur Mobile Money |
| `status` | statut courant de la demande |
| `sender_number` | numero expediteur saisi par l'artisan |
| `expires_at_admin` | deadline de traitement admin |
| `validated_at` | date de validation |
| `rejected_at` | date de rejet |
| `rejection_reason` | motif de rejet |
| `request_number` | numero historique de la demande pour l'abonnement |
| `refund_required` | remboursement requis ou non |
| `refund_done_at` | date de remboursement confirme |
| `cooldown_until` | fin du blocage temporaire apres rejets multiples |
| `cooldown_cycle` | cycle de blocage courant |
| `attempted_refund_count` | nombre de fois ou un remboursement a ete necessaire |
| `timeline` | journal metier embarque dans la ligne |
| `deleted_at` | soft delete admin |

## 3.2. Entite `payment_proof`

La table `payment_proof` represente **une preuve envoyee pour une transaction existante**.

Champs fonctionnels principaux :

| Champ | Role |
|---|---|
| `payment_manual_id` | rattachement a la transaction |
| `image_url` | reference de stockage MinIO |
| `image_hash_sha256` | hash anti-duplicat / integrite |
| `submitted_at` | date d'envoi |
| `declared_payment_time` | date/heure declaree par l'artisan |
| `upload_attempt_number` | tentative dans le cycle courant |
| `file_type` | type de fichier |
| `file_size_kb` | poids |
| `file_resolution` | resolution |
| `has_exif` | EXIF present ou non |
| `exif_capture_date` | date EXIF capture |
| `exif_modified_date` | date EXIF modification |
| `exif_device` | appareil |
| `exif_software` | logiciel d'edition eventuel |
| `ai_suspicion_score` | score de suspicion |
| `is_suspected_fraud` | drapeau de fraude potentielle |
| `deletion_requested` | reserve pour traitements ulterieurs |

## 3.3. Index importants

| Index | Role |
|---|---|
| `IDX_PAYMENT_MANUAL_SUB_CREATED` | retrouver rapidement les demandes d'un abonnement par anciennete |
| `IDX_PAYMENT_MANUAL_SUB_REQUEST` | retrouver rapidement l'historique de demandes par abonnement |
| `IDX_PAYMENT_MANUAL_STATUS_EXPIRES` | scanner les paiements a expiration |
| `IDX_PAYMENT_PROOF_PAYMENT_SUBMITTED` | parcourir les preuves par transaction |

---

## 4. Statuts et Invariants

## 4.1. Statuts `PaymentManualStatus`

| Statut | Signification |
|---|---|
| `PENDING` | transaction creee, preuve pas encore soumise |
| `PENDING_ADMIN` | preuve soumise, attente de traitement admin |
| `COMPLETED` | paiement valide, abonnement active |
| `REJECTED` | preuve rejetee |
| `EXPIRED` | preuve non traitee dans les delais admin |

## 4.2. Invariants metier critiques

- Une transaction manuelle est rattachee a un abonnement artisan.
- Une **nouvelle transaction** n'est creee que si la derniere demande ne peut pas etre reutilisee.
- En cas de rejet, l'artisan **reste sur la meme transaction**.
- En cas de cooldown, l'artisan **reste sur la meme transaction**, sans creation d'un nouveau `transaction_id`.
- En cas d'expiration avec remboursement en attente, **aucune nouvelle demande** ne peut etre creee.
- En cas d'expiration remboursee, une **nouvelle demande** peut etre creee, avec `request_number` incremente.
- Le backend et le mobile doivent toujours raisonner sur la **demande la plus recente**.
- Le statut `COMPLETED` ne bloque une nouvelle initiation que si l'abonnement artisan est encore actif.

## 4.3. Compteurs a ne pas confondre

| Compteur | Signification |
|---|---|
| `request_number` | numero global de la demande historique |
| `upload_attempt_number` | tentative d'envoi de preuve dans le cycle courant |
| `cooldown_cycle` | numero du cycle de blocage progressif |

---

## 5. API Backend

## 5.1. Endpoints artisan

Base path : `payments/manual`

| Methode | Route | Role |
|---|---|---|
| `POST` | `/initiate` | creer une demande ou retourner la transaction reutilisable |
| `GET` | `/current` | recuperer la transaction courante de l'artisan |
| `GET` | `/:transactionId` | recuperer le detail d'une transaction possedee |
| `POST` | `/:transactionId/submit-proof` | envoyer une preuve |
| `GET` | `/:transactionId/proof/:proofId` | obtenir une URL signee de consultation |

Contraintes d'acces :

- JWT requis
- role `ARTISAN`
- telephone verifie
- controle d'ownership sur chaque transaction

## 5.2. Endpoints admin

Base path : `admin`

| Methode | Route | Role |
|---|---|---|
| `GET` | `/payment-proofs` | liste paginee des paiements manuels |
| `GET` | `/payment-proofs/:id/details` | detail complet |
| `PATCH` | `/payment-proofs/:id/validate` | valider la preuve |
| `PATCH` | `/payment-proofs/:id/reject` | rejeter la preuve |
| `PATCH` | `/payment-proofs/:id/reopen` | rouvrir la transaction |
| `PATCH` | `/payment-proofs/:id/mark-refunded` | marquer le remboursement effectue |
| `DELETE` | `/payment-proofs/:id` | soft delete |
| `SSE` | `/payment-events` | flux temps reel admin |

Contraintes d'acces :

- JWT requis
- role `ADMIN`

---

## 6. Comportement Backend Detaille

## 6.1. Initiation d'une demande

La methode `initiatePayment()` :

1. verifie si l'operateur est disponible
2. resout le profil artisan preferentiel
3. bloque si l'abonnement est deja actif
4. recupere ou cree la souscription artisan associee
5. charge la **derniere transaction seulement**
6. bloque si cette derniere transaction est `EXPIRED + refund_required + refund_done_at == null`
7. reutilise la transaction si elle est `PENDING`, `PENDING_ADMIN` ou `REJECTED`
8. sinon cree une nouvelle transaction avec :
   - nouveau `transaction_id`
   - `request_number = count + 1`
   - `expires_at_admin = now + 72h`

Codes metier importants :

- `PAYMENT_MANUAL_PROVIDER_UNAVAILABLE`
- `PAYMENT_MANUAL_ALREADY_ACTIVE`
- `PAYMENT_MANUAL_REFUND_PENDING`

## 6.2. Soumission d'une preuve

La methode `submitProof()` :

1. verifie que l'utilisateur possede la transaction
2. n'autorise l'envoi qu'en `PENDING` ou `REJECTED`
3. bloque si un cooldown `REJECTED` est encore actif
4. applique un rate limit Redis
5. valide techniquement l'image
6. calcule un hash SHA-256
7. refuse un doublon exact de preuve
8. extrait les metadonnees EXIF
9. calcule un score de suspicion
10. stocke le binaire dans MinIO
11. cree la ligne `payment_proof`
12. remet la transaction en `PENDING_ADMIN`
13. vide `cooldown_until`
14. notifie les temps reels admin et mobile

Codes metier et blocages :

- `PAYMENT_MANUAL_INVALID_STATUS`
- `PAYMENT_MANUAL_COOLDOWN_ACTIVE`
- `PAYMENT_MANUAL_DAILY_UPLOAD_LIMIT`
- `PAYMENT_MANUAL_SUBMIT_RATE_LIMIT`

## 6.3. Validation admin

La methode `validateProof()` :

1. exige un paiement en `PENDING_ADMIN`
2. active l'abonnement via `SubscriptionService`
3. passe la transaction en `COMPLETED`
4. renseigne `validated_at`
5. pousse une notification `PAYMENT_MANUAL_VALIDATED`
6. pousse la synchro temps reel

## 6.4. Rejet admin

La methode `rejectProof()` :

1. exige un paiement en `PENDING_ADMIN`
2. compte les preuves deja soumises
3. passe la transaction en `REJECTED`
4. enregistre le motif
5. declenche un cooldown tous les 3 envois de preuve
6. envoie :
   - `PAYMENT_MANUAL_REJECTED` s'il n'y a pas de cooldown
   - `PAYMENT_MANUAL_COOLDOWN` s'il y a un cooldown

## 6.5. Cooldown progressif

Regle actuelle :

- base = `5 heures`
- progression = `5h -> 10h -> 20h -> 40h ...`

Formule :

- `5h * 2^(cooldown_cycle - 1)`

Exemples :

| `cooldown_cycle` | Duree |
|---|---|
| `1` | 5h |
| `2` | 10h |
| `3` | 20h |
| `4` | 40h |

Pendant un cooldown actif :

- l'artisan ne peut pas soumettre de nouvelle preuve
- le champ expediteur est verrouille cote mobile
- la selection d'image est verrouillee
- le bouton de soumission est verrouille
- la transaction reste la meme

## 6.6. Expiration

Le cron `PaymentExpirationCron` lance `expirePayments()` toutes les heures.

Une transaction expire si :

- `status == PENDING_ADMIN`
- `expires_at_admin < now`

Lors de l'expiration :

- statut -> `EXPIRED`
- `refund_required = true`
- `attempted_refund_count += 1`
- ajout timeline `PAYMENT_MANUAL_EXPIRED`
- notification artisan `PAYMENT_MANUAL_EXPIRED`
- synchro temps reel

## 6.7. Remboursement

Quand l'admin marque un remboursement :

- `refund_done_at = now`
- `refund_required = false`
- timeline `REFUND_PROCESSED`
- notification artisan `REFUND_PROCESSED`
- synchro temps reel mobile/admin

Effet metier :

- l'ancienne transaction reste dans l'historique
- l'utilisateur peut ensuite creer une **nouvelle demande**

## 6.8. Reouverture admin

L'admin peut rouvrir une transaction `REJECTED`, `EXPIRED` ou `COMPLETED`.

Comportement :

- si des preuves sont conservees, retour en `PENDING_ADMIN`
- sinon retour en `PENDING`
- remise a zero du remboursement courant
- remise a zero du cooldown courant
- nouvelle expiration admin a `now + 72h`

## 6.9. Soft delete

Le soft delete admin :

- ne supprime pas physiquement la ligne
- remplit `deleted_at`
- ajoute un evenement timeline

Une transaction ne peut etre supprimee que si elle est :

- `COMPLETED`
- `REJECTED`
- `EXPIRED`
- ou remboursee

---

## 7. Mobile Flutter

## 7.1. Ecran principal

L'ecran principal est `ManualPaymentPage`.

Il affiche :

- guide utilisateur
- politique de remboursement
- selection d'operateur
- numero de depot
- bouton d'initiation
- statut de la transaction
- zone de soumission de preuve
- bloc remboursement si la transaction a expire

## 7.2. Logique UI principale

### Aucun paiement courant

- bouton actif : `Generer une transaction manuelle`
- champ expediteur inactif tant que la transaction n'existe pas

### `PENDING`

- transaction creee
- bouton d'initiation desactive
- numero expediteur editable
- preuve selectionnable et soumission possible

### `PENDING_ADMIN`

- transaction en attente admin
- bouton d'initiation desactive
- champ expediteur verrouille
- image et soumission verrouillees

### `REJECTED` sans cooldown

- meme transaction conservee
- motif visible
- nouvelle preuve autorisee
- tentative courante visible

### `REJECTED` avec cooldown actif

- meme transaction conservee
- soumission bloquee
- compteur temps restant visible
- texte de blocage dedie

### `EXPIRED` avec remboursement en attente

- bloc d'alerte dedie
- affichage transaction, montant, date d'expiration
- bouton WhatsApp support actif
- nouvelle demande verrouillee

### `EXPIRED` remboursee

- bloc de confirmation remboursement
- bouton principal devient reactivable
- la prochaine initiation cree une nouvelle demande

### `COMPLETED`

- si l'abonnement est actif, la transaction peut rester visible
- si l'abonnement n'est plus actif, l'API `current` renvoie `null` et l'utilisateur peut recreer une demande

## 7.3. WhatsApp support

En cas de remboursement en attente, le mobile peut ouvrir WhatsApp avec un message pre-rempli contenant :

- `transaction_id`
- `amount_fcfa`
- date d'expiration

Le numero cible utilise aujourd'hui le numero receveur du provider affiche.

---

## 8. Admin Web

## 8.1. Liste

L'ecran admin des paiements manuels expose :

- liste paginee
- statut
- numero de demande `request_number`
- etat de remboursement
- badges de remboursement requis
- badge de cooldown actif

## 8.2. Detail

Le detail affiche notamment :

- transaction
- artisan
- historique des preuves
- `request_number`
- `refund_required`
- `refund_done_at`
- `cooldown_until`
- `cooldown_cycle`

## 8.3. Actions admin

Depuis l'interface admin, il est possible de :

- valider
- rejeter
- rouvrir
- marquer rembourse
- supprimer logiquement

---

## 9. Scenarios Metier de A a Z

## Scenario 1. Parcours nominal

1. artisan sans transaction
2. creation -> `PENDING`
3. soumission preuve -> `PENDING_ADMIN`
4. validation admin -> `COMPLETED`
5. abonnement actif

## Scenario 2. Rejet simple

1. transaction `PENDING`
2. preuve soumise
3. admin rejette
4. transaction -> `REJECTED`
5. l'artisan renvoie une preuve sur la **meme transaction**

## Scenario 3. Trois rejets et cooldown

1. meme transaction rejete plusieurs fois
2. apres le 3e envoi du cycle, cooldown
3. `cooldown_until` rempli
4. mobile bloque l'envoi
5. l'utilisateur voit le temps restant
6. a l'expiration du cooldown, il renvoie une preuve sur la **meme transaction**

## Scenario 4. Expiration sans traitement admin

1. preuve soumise
2. admin ne traite pas dans les 72h
3. cron -> `EXPIRED`
4. `refund_required = true`
5. l'utilisateur voit un bloc rouge et le bouton WhatsApp
6. aucune nouvelle demande n'est autorisee

## Scenario 5. Remboursement effectue

1. admin clique `mark refunded`
2. `refund_done_at` est renseigne
3. l'utilisateur recoit `REFUND_PROCESSED`
4. l'ancienne transaction reste visible
5. l'utilisateur peut creer une **nouvelle demande**

## Scenario 6. Historique multiple

Exemple :

- demande 1 -> `COMPLETED`
- demande 2 -> `REJECTED`
- demande 3 -> `EXPIRED` remboursement en attente

Invariant :

- l'app doit presenter **la demande 3**
- jamais une demande ancienne qui masquerait un blocage plus recent

## Scenario 7. Reouverture admin

1. un paiement est `REJECTED`, `EXPIRED` ou `COMPLETED`
2. l'admin le rouvre
3. s'il reste une preuve valide en stockage, retour `PENDING_ADMIN`
4. sinon retour `PENDING`

## Scenario 8. Abonnement expire apres ancien paiement valide

1. ancien paiement `COMPLETED`
2. abonnement devenu inactif
3. `GET /payments/manual/current` renvoie `null`
4. l'artisan peut lancer une nouvelle demande

---

## 10. Notifications et Temps Reel

## 10.1. Notifications artisan

| Type | Emission |
|---|---|
| `PAYMENT_MANUAL_VALIDATED` | validation admin |
| `PAYMENT_MANUAL_REJECTED` | rejet sans cooldown |
| `PAYMENT_MANUAL_COOLDOWN` | rejet avec blocage temporaire |
| `PAYMENT_MANUAL_REOPENED` | reouverture admin |
| `PAYMENT_MANUAL_EXPIRED` | expiration |
| `REFUND_PROCESSED` | remboursement confirme |

## 10.2. Temps reel admin

Evenements admin :

- `PAYMENT_MANUAL_NEW_PROOF`
- `PAYMENT_MANUAL_UPDATED`

## 10.3. Temps reel mobile

Le backend emet un evenement de sync utilisateur `manualPaymentUpdated` avec :

- `paymentId`
- `transactionId`
- `status`
- `rejectionReason`
- `refundRequired`
- `refundDone`
- `updatedAt`

---

## 11. Securite, Integrite et Anti-Fraude

## 11.1. Controles d'acces

- verification JWT
- role `ARTISAN` ou `ADMIN`
- garde telephone verifie cote artisan
- verification stricte de possession d'une transaction

## 11.2. Integrite des preuves

- hash SHA-256 unique
- detection de doublon exact
- verification periodique d'integrite des hashes via cron quotidien
- alerte admin si mismatch detecte

## 11.3. Validation technique des images

- taille max API : `5 Mo`
- validation mime/type
- lecture EXIF
- score de suspicion anti-fraude
- detection de logiciels suspects

## 11.4. Rate limiting

Deux protections existent :

- limite journaliere d'uploads
- burst limit court via Redis

Si Redis est indisponible, le service degrade proprement et journalise le probleme.

---

## 12. Regles Metier a Ne Pas Casser

- Ne jamais creer un nouveau `transaction_id` si une transaction reutilisable existe deja.
- Ne jamais autoriser une nouvelle demande quand la derniere transaction est `EXPIRED` avec remboursement en attente.
- Ne jamais autoriser une nouvelle demande simplement parce qu'une ancienne transaction `REJECTED` existe.
- Toujours raisonner sur la **demande la plus recente**.
- En cas de rejet, rester sur la **meme transaction**.
- En cas de cooldown, rester sur la **meme transaction**.
- `request_number` doit etre monotone croissant par abonnement.
- `refund_done_at` ne doit pas etre renseigne sans lever le blocage de remboursement.
- Une transaction soft-delete ne doit plus remonter dans les endpoints courants.

---

## 13. Runbook de Verification

## 13.1. Backend

Depuis `backend/` :

```bash
npm run test
npm run test:e2e
```

## 13.2. Flutter

Depuis `fiers_artisans_app/` :

```bash
flutter analyze
flutter test
```

## 13.3. Admin

Depuis `admin-web/` :

```bash
npm run lint
npm run build
```

## 13.4. Checklist manuelle utile

- creer une transaction
- verifier que le bouton principal se bloque
- envoyer une preuve
- verifier que `sender_number` se verrouille en `PENDING_ADMIN`
- simuler 3 rejets et verifier le cooldown
- verifier le decompte du cooldown
- laisser expirer une transaction et verifier le bloc remboursement
- marquer le remboursement et verifier la reouverture d'une nouvelle demande
- verifier que `request_number` augmente seulement lors d'une vraie nouvelle demande

---

## 14. Diagnostic Rapide

## 14.1. Si l'utilisateur dit "je suis bloque"

Verifier dans cet ordre :

1. derniere transaction reelle
2. `status`
3. `refund_required`
4. `refund_done_at`
5. `cooldown_until`
6. nombre de preuves associees
7. `is_subscription_active`

## 14.2. Si l'utilisateur dit "le systeme m'affiche la mauvaise transaction"

Verifier :

- que `GET /payments/manual/current` renvoie bien la demande la plus recente
- qu'aucune transaction plus ancienne ne masque un `EXPIRED` plus recent

## 14.3. Si l'admin dit "je ne vois pas le remboursement"

Verifier :

- `refund_required`
- `refund_done_at`
- statut `EXPIRED`
- eventuels filtres admin actifs

## 14.4. Si l'admin dit "l'utilisateur ne peut toujours pas recreer"

Verifier :

- remboursement effectivement marque
- `refund_done_at` non nul
- que la transaction courante n'est plus un `EXPIRED` non rembourse
- que l'abonnement n'est pas encore actif

---

## 15. Conclusion

Le systeme de paiement manuel de Fiers Artisans n'est pas un simple upload de capture. C'est un flux complet, stateful, avec :

- orchestration backend stricte
- anti-spam et anti-fraude
- moderation admin
- remboursement controle
- synchro mobile/admin en temps reel
- conservation de l'historique metier

Le point le plus critique a retenir est le suivant :

> la verite du systeme repose toujours sur la **derniere demande reelle**, jamais sur une transaction plus ancienne retrouvee par hasard.
