# Documentation Paiement Manuel

## Objectif

Ce document decrit l'etat reel du systeme de paiement manuel Mobile Money de **Fiers Artisans** apres le durcissement recent du cycle de vie des transactions :

- gestion des preuves
- cooldown progressif
- expiration avec remboursement
- desactivation d'abonnement en cas de rupture d'integrite metier
- auto-remplacement des transactions terminales eligibles
- separation admin `ACTIVE` / `HISTORY`
- temps reel mobile et admin

Le document suit le code actuellement present dans le depot.

---

## 1. Role metier

Le paiement manuel permet a un artisan de payer son abonnement via Mobile Money quand le flux automatique n'est pas utilise.

Le parcours nominal reste :

1. l'artisan initie une demande
2. l'application affiche le numero de depot selon l'operateur
3. l'artisan paie puis envoie une preuve
4. l'admin valide ou rejette
5. le backend synchronise la transaction, l'abonnement, les notifications et les evenements temps reel

La difference majeure aujourd'hui est la suivante :

- un `REJECTED` classique avant validation reste sur la **meme transaction**
- un `REJECTED` apres validation precedente devient **terminal**, desactive l'abonnement, puis la prochaine demande cree automatiquement une **nouvelle transaction**
- un `EXPIRED` non rembourse bloque strictement toute nouvelle demande
- un `EXPIRED` rembourse cree automatiquement une **nouvelle transaction**

---

## 2. Stack et fichiers clefs

## 2.1. Couche backend

| Fichier | Role |
|---|---|
| `backend/src/modules/payment-manual/entities/payment-manual.entity.ts` | entite transaction manuelle |
| `backend/src/modules/payment-manual/entities/payment-proof.entity.ts` | entite preuve |
| `backend/src/modules/payment-manual/services/payment-manual.service.ts` | logique metier |
| `backend/src/modules/payment-manual/controllers/payment-manual.controller.ts` | API artisan |
| `backend/src/modules/payment-manual/controllers/payment-manual-admin.controller.ts` | API admin |
| `backend/src/modules/payment-manual/events/payment-realtime.service.ts` | SSE/WebSocket admin et mobile |
| `backend/src/modules/subscription/subscription.service.ts` | activation et desactivation d'abonnement |
| `backend/src/database/migrations/AddPaymentManualReplacement1710000000002.ts` | migration `replaced_by_transaction_id` et garde DB anti-doublon `PENDING` |

## 2.2. Couche mobile Flutter

| Fichier | Role |
|---|---|
| `Fiers Artisans/lib/data/models/manual_payment_model.dart` | modele de transaction et etats derives |
| `Fiers Artisans/lib/providers/payment_manual_provider.dart` | orchestration client, auto-remplacement, erreurs |
| `Fiers Artisans/lib/presentation/artisan/manual_payment_page.dart` | ecran principal |
| `Fiers Artisans/lib/presentation/artisan/payment_status_widget.dart` | affichage statut, demande, cooldown |

## 2.3. Couche admin web

| Fichier | Role |
|---|---|
| `admin-web/src/app/(dashboard)/payments/manual/page-client.tsx` | liste, detail, filtres, actions |
| `admin-web/src/lib/api.ts` | appels admin |
| `admin-web/src/types/index.ts` | type `PaymentManualRecord` |

---

## 3. Modele de donnees

## 3.1. Entite `payment_manual`

La table `payment_manual` represente **une demande historique** de paiement manuel.

| Champ | Role |
|---|---|
| `subscription_id` | rattachement a l'abonnement artisan |
| `transaction_id` | ID visible par l'utilisateur |
| `provider` | operateur Mobile Money |
| `status` | statut courant |
| `validated_at` | date de validation precedente |
| `rejected_at` | date de rejet |
| `rejection_reason` | motif admin |
| `request_number` | numero historique de la demande pour cet abonnement |
| `replaced_by_transaction_id` | nouvel ID qui remplace cette transaction, si remplacement auto |
| `refund_required` | remboursement requis |
| `refund_done_at` | remboursement confirme |
| `cooldown_until` | fin du cooldown |
| `cooldown_cycle` | cycle progressif courant |
| `attempted_refund_count` | nombre d'expirations ayant necessite un remboursement |
| `timeline` | journal metier embarque |
| `deleted_at` | soft delete admin |

## 3.2. Entite `payment_proof`

Chaque preuve reste rattachee a une transaction existante.

Points importants :

- une preuve appartient toujours a un `payment_manual`
- le hash SHA-256 est unique
- le numero de tentative est calcule dans le cycle courant
- les metadonnees EXIF et les signaux anti-fraude sont conserves

## 3.3. Index et garde-fous importants

| Index / contrainte | Role |
|---|---|
| `IDX_PAYMENT_MANUAL_SUB_CREATED` | ordre chronologique des demandes |
| `IDX_PAYMENT_MANUAL_SUB_REQUEST` | parcours rapide de l'historique par abonnement |
| `IDX_PAYMENT_MANUAL_STATUS_EXPIRES` | balayage des expirations |
| `IDX_PAYMENT_MANUAL_REPLACED_BY` | recherche de chaine de remplacement |
| `idx_payment_manual_one_pending_per_subscription` | empecher deux `PENDING` simultanes pour le meme abonnement |

---

## 4. Etats reels du systeme

## 4.1. Statuts persistants

| Statut | Sens |
|---|---|
| `PENDING` | transaction creee, preuve non soumise |
| `PENDING_ADMIN` | preuve soumise, attente admin |
| `COMPLETED` | paiement valide |
| `REJECTED` | rejet admin |
| `EXPIRED` | expiration admin |

## 4.2. Etats derives metier

Le code distingue des sous-cas importants qui ne sont pas des nouveaux statuts DB :

| Etat derive | Definition |
|---|---|
| `REJECTED simple` | `status=REJECTED` et `validated_at == null` |
| `REJECTED apres validation` | `status=REJECTED` et `validated_at != null` |
| `EXPIRED remboursement en attente` | `status=EXPIRED` et `refund_required=true` et `refund_done_at == null` |
| `EXPIRED remboursement traite` | `status=EXPIRED` et `refund_done_at != null` |
| `historique archive` | `EXPIRED` ou `REJECTED apres validation` ou `replaced_by_transaction_id != null` |

## 4.3. Invariants metier

- Le systeme raisonne toujours sur la **derniere demande reelle**.
- Une transaction `PENDING` ou `PENDING_ADMIN` est reutilisee, jamais dupliquee.
- Un `REJECTED` simple reste sur la **meme transaction**.
- Le cooldown ne cree jamais une nouvelle transaction.
- Un `REJECTED` apres validation precedente devient terminal et prepare un **nouveau cycle**.
- Une transaction avec remboursement en attente bloque toute nouvelle demande, quel que soit son statut terminal.
- `request_number` est monotone croissant par abonnement.
- Une transaction remplacee reste dans l'historique et reference sa remplaçante via `replaced_by_transaction_id`.

---

## 5. API

## 5.1. Endpoints artisan

Base path : `payments/manual`

| Methode | Route | Role |
|---|---|---|
| `POST` | `/initiate` | reutiliser, creer ou auto-remplacer |
| `GET` | `/current` | transaction courante la plus recente |
| `GET` | `/:transactionId` | detail d'une transaction possedee |
| `POST` | `/:transactionId/submit-proof` | soumettre une preuve |
| `GET` | `/:transactionId/proof/:proofId` | URL signee de consultation |

Champs additifs exposes aujourd'hui :

- `request_number`
- `refund_done_at`
- `validated_at`
- `replaced_by_transaction_id`
- `cooldown_until`
- `cooldown_cycle`

## 5.2. Endpoints admin

Base path : `admin`

| Methode | Route | Role |
|---|---|---|
| `GET` | `/payment-proofs` | liste paginee, avec `status` et `scope=ACTIVE|HISTORY|ALL` |
| `GET` | `/payment-proofs/:id/details` | detail complet |
| `PATCH` | `/payment-proofs/:id/validate` | validation admin |
| `PATCH` | `/payment-proofs/:id/reject` | rejet admin |
| `PATCH` | `/payment-proofs/:id/reopen` | reouverture limitee |
| `PATCH` | `/payment-proofs/:id/mark-refunded` | remboursement effectue |
| `DELETE` | `/payment-proofs/:id` | soft delete |
| `SSE` | `/payment-events` | flux temps reel admin |

---

## 6. Logique backend detaillee

## 6.1. Initiation

`initiatePayment()` suit cette matrice :

1. verifier la disponibilite de l'operateur
2. resoudre le bon profil artisan
3. bloquer si l'abonnement est deja actif
4. recuperer ou creer l'abonnement `PENDING`
5. charger **la derniere transaction de cet abonnement**

Decision sur la derniere transaction :

| Dernier etat | Comportement |
|---|---|
| `PENDING` | retour de la meme transaction |
| `PENDING_ADMIN` | retour de la meme transaction |
| `REJECTED simple` | retour de la meme transaction |
| remboursement en attente | blocage `PAYMENT_MANUAL_REFUND_PENDING` |
| `REJECTED apres validation` | creation automatique d'une nouvelle transaction |
| `EXPIRED` avec remboursement deja leve | creation automatique d'une nouvelle transaction |
| aucun cas precedent | creation normale d'une nouvelle transaction |

## 6.2. Auto-remplacement

Quand une transaction est eligible a un remplacement automatique :

- le backend cree un nouveau `PENDING`
- il reutilise **le provider de l'ancienne transaction**
- il incremente `request_number`
- il renseigne `replaced_by_transaction_id` sur l'ancienne transaction
- il ajoute un evenement timeline `PAYMENT_MANUAL_AUTO_REPLACED`
- il notifie l'artisan via `PAYMENT_MANUAL_AUTO_REPLACED`
- il emet un evenement admin `PAYMENT_MANUAL_TIMELINE_UPDATED`

Deux cas ouvrent ce flux :

- `REJECTED` avec `validated_at != null`
- `EXPIRED` dont le remboursement a deja ete leve

## 6.3. Soumission de preuve

`submitProof()` :

- autorise seulement `PENDING` et `REJECTED`
- bloque si `cooldown_until` est encore dans le futur
- applique le rate limiting
- refuse les doublons exacts
- cree une preuve
- remet la transaction en `PENDING_ADMIN`
- vide le cooldown actif

## 6.4. Validation admin

`validateProof()` :

- exige `PENDING_ADMIN`
- active l'abonnement via `SubscriptionService`
- passe la transaction en `COMPLETED`
- renseigne `validated_at`
- notifie l'artisan avec `PAYMENT_MANUAL_VALIDATED`

## 6.5. Rejet admin

`rejectProof()` a maintenant **deux branches metier**.

### Rejet simple, avant validation precedente

- statut -> `REJECTED`
- motif enregistre
- cooldown progressif tous les 3 envois
- l'artisan reste sur la **meme transaction**
- notifications :
  - `PAYMENT_MANUAL_REJECTED`
  - ou `PAYMENT_MANUAL_COOLDOWN`

### Rejet apres validation precedente

Condition :

- `status` courant a rejeter = `PENDING_ADMIN`
- `validated_at != null`

Effets :

- statut -> `REJECTED`
- desactivation de l'abonnement associe si encore actif
- aucun cooldown metier ouvert pour redemarrer sur la meme transaction
- la transaction devient un candidat a **auto-remplacement**

Desactivation d'abonnement :

- raison `TRANSACTION_REJECTED`
- `SubscriptionStatus -> CANCELLED`
- `artisan_profile.is_subscription_active -> false`
- log structure avec `correlation_id`
- evenement admin `SUBSCRIPTION_UPDATED`

## 6.6. Cooldown progressif

Regle :

- base = `5h`
- formule = `5h * 2^(cycle - 1)`

Exemples :

| `cooldown_cycle` | Duree |
|---|---|
| `1` | 5h |
| `2` | 10h |
| `3` | 20h |

Pendant ce cooldown :

- sender bloque
- selection d'image bloquee
- soumission bloquee
- la transaction reste identique

## 6.7. Expiration

`expirePayments()` balaye les `PENDING_ADMIN` depasses.

Pour chaque transaction expiree :

1. si l'abonnement est encore actif, il est desactive avec raison `TRANSACTION_EXPIRED`
2. la transaction passe en `EXPIRED`
3. `refund_required = true`
4. `attempted_refund_count += 1`
5. timeline `PAYMENT_MANUAL_EXPIRED`
6. notification artisan `PAYMENT_MANUAL_EXPIRED`
7. evenement admin `PAYMENT_MANUAL_TIMELINE_UPDATED`

Desactivation d'abonnement :

- status abonnement -> `EXPIRED`
- `is_subscription_active -> false`
- no-op journalise si deja inactif

## 6.8. Remboursement

`markRefundDone()` :

- renseigne `refund_done_at`
- leve `refund_required`
- ajoute timeline `REFUND_PROCESSED`
- envoie `REFUND_PROCESSED`

Effet metier :

- la transaction reste dans l'historique
- le prochain chargement mobile ou le prochain `initiatePayment()` peut declencher l'auto-remplacement si la transaction etait `EXPIRED`

## 6.9. Reouverture admin

`reopenProof()` reste possible seulement sur les paiements encore reouvrables.

Important :

- un paiement **historique archive** ne doit plus etre rouvert
- donc les `EXPIRED`
- les `REJECTED apres validation`
- et les transactions deja remplacees

L'admin ne peut rouvrir que les transactions encore coherentes avec un cycle actif de moderation.

## 6.10. Soft delete

Le soft delete reste reserve aux transactions terminales ou remboursees.

Il :

- renseigne `deleted_at`
- conserve la ligne
- ajoute un evenement timeline

---

## 7. Temps reel et notifications

## 7.1. Notifications artisan

| Type | Role |
|---|---|
| `PAYMENT_MANUAL_VALIDATED` | validation |
| `PAYMENT_MANUAL_REJECTED` | rejet simple |
| `PAYMENT_MANUAL_COOLDOWN` | rejet avec blocage temporaire |
| `PAYMENT_MANUAL_REOPENED` | reouverture admin |
| `PAYMENT_MANUAL_EXPIRED` | expiration |
| `PAYMENT_MANUAL_AUTO_REPLACED` | remplacement automatique |
| `REFUND_PROCESSED` | remboursement confirme |

## 7.2. Temps reel admin

Evenements admin :

- `PAYMENT_MANUAL_NEW_PROOF`
- `PAYMENT_MANUAL_UPDATED`
- `PAYMENT_MANUAL_TIMELINE_UPDATED`

## 7.3. Temps reel mobile

Le mobile recoit `manualPaymentUpdated` avec :

- `paymentId`
- `transactionId`
- `status`
- `rejectionReason`
- `refundRequired`
- `refundDone`
- `updatedAt`

---

## 8. Mobile Flutter

## 8.1. Comportement general

Le provider Flutter ne se contente plus d'afficher un etat statique.

Il sait maintenant :

- charger la transaction courante
- detecter les cas d'auto-remplacement
- rappeler `POST /payments/manual/initiate` avec le `previous_provider`
- afficher un message transitoire a l'utilisateur

## 8.2. Etats UI importants

### `PENDING`

- bouton principal bloque
- sender editable
- soumission possible

### `PENDING_ADMIN`

- sender bloque
- image bloque
- soumission bloque

### `REJECTED simple`

- meme transaction
- motif visible
- nouvelle preuve possible
- cooldown eventuel visible

### `REJECTED apres validation`

Ce cas est en pratique **court cote mobile** :

- le backend remonte la transaction historique
- le provider detecte l'eligibilite
- il lance automatiquement une **nouvelle demande**
- l'utilisateur bascule vers le nouvel ID avec un message de transition

### `EXPIRED` remboursement en attente

- bloc rouge dedie
- transaction, montant et date visibles
- bouton WhatsApp actif
- aucune nouvelle demande

### `EXPIRED` remboursement leve

- auto-remplacement au chargement
- nouvel ID cree automatiquement
- message transitoire affiche

## 8.3. WhatsApp support

Le message pre-rempli contient :

- `transaction_id`
- `amount_fcfa`
- date d'expiration

Le numero cible est toujours derive du provider affiche.

---

## 9. Admin web

## 9.1. Vue principale

L'admin dispose maintenant de deux scopes :

- `ACTIVE`
- `HISTORY`

`ACTIVE` contient :

- `PENDING`
- `PENDING_ADMIN`
- `COMPLETED`
- `REJECTED` simples non archives

`HISTORY` contient :

- `EXPIRED`
- `REJECTED` apres validation
- transactions avec `replaced_by_transaction_id != null`

## 9.2. Informations visibles

La liste et le detail exposent notamment :

- `request_number`
- etat remboursement
- cooldown
- `validated_at`
- `rejected_at`
- `replaced_by_transaction_id`

## 9.3. Regles d'action admin

| Action | Paiement actif | Paiement historique |
|---|---|---|
| valider | oui si `PENDING_ADMIN` | non |
| rejeter | oui si `PENDING_ADMIN` | non |
| rouvrir | seulement si encore reouvrable | non |
| marquer rembourse | oui si `refund_required` | oui si remboursement encore requis |
| supprimer | selon regles de terminalite | oui |

Le badge `Remplace par TX-...` doit permettre de suivre visuellement la chaine de remplacement.

---

## 10. Scenarios metier

## Scenario 1. Parcours nominal

1. artisan sans abonnement actif
2. creation -> `PENDING`
3. preuve -> `PENDING_ADMIN`
4. validation -> `COMPLETED`
5. abonnement actif

## Scenario 2. Rejet simple

1. transaction `PENDING`
2. preuve soumise
3. rejet admin
4. statut `REJECTED`
5. meme ID conserve
6. l'artisan renvoie une preuve sur la meme transaction

## Scenario 3. Troisieme rejet et cooldown

1. plusieurs preuves soumises sur le meme ID
2. au 3e rejet du cycle, `cooldown_until` est renseigne
3. l'utilisateur voit le temps restant
4. apres expiration, il renvoie une preuve sur le meme ID

## Scenario 4. Expiration et remboursement en attente

1. transaction `PENDING_ADMIN`
2. cron -> `EXPIRED`
3. abonnement desactive si encore actif
4. `refund_required = true`
5. blocage total de nouvelle demande

## Scenario 5. Expiration remboursee puis remplacement auto

1. `EXPIRED`
2. admin marque `REFUND_PROCESSED`
3. le mobile recharge
4. nouvelle transaction `PENDING` creee automatiquement
5. l'ancienne transaction reference `replaced_by_transaction_id`

## Scenario 6. Rejet apres validation

1. transaction validee -> `COMPLETED`
2. admin rouvre
3. verification complementaire
4. admin rejette
5. abonnement desactive
6. transaction archivee
7. la prochaine ouverture mobile cree automatiquement un nouvel ID

## Scenario 7. Historique multiple

Exemple :

- demande 1 -> `COMPLETED`
- demande 2 -> `REJECTED` simple
- demande 3 -> `EXPIRED` remboursee
- demande 4 -> auto-creee

Invariant :

- l'application doit toujours afficher la **plus recente**
- jamais une ancienne transaction ne doit masquer un blocage ou un remplacement plus recent

---

## 11. Regles metier a ne pas casser

- Ne jamais creer un nouveau `transaction_id` s'il existe un `PENDING` ou `PENDING_ADMIN` reutilisable.
- Ne jamais ouvrir une nouvelle demande quand un remboursement est encore en attente.
- Ne jamais transformer un `REJECTED` simple en nouvelle transaction.
- Toujours creer une nouvelle transaction pour un `REJECTED` apres validation.
- Toujours utiliser le `previous_provider` lors d'un auto-remplacement.
- Toujours conserver la tracabilite via `replaced_by_transaction_id`.
- Ne jamais laisser un abonnement actif si la transaction support qui le justifie est devenue invalide (`REJECTED apres validation` ou `EXPIRED`).
- Ne jamais permettre a l'admin de muter une transaction historique archivee comme si elle etait encore active.

---

## 12. Runbook de verification

## 12.1. Commandes

Depuis `backend/` :

```bash
npm run test
npm run test:e2e
```

Depuis `Fiers Artisans/` :

```bash
flutter analyze
flutter test
```

Depuis `admin-web/` :

```bash
npm run lint
npm run build
```

## 12.2. Checklist manuelle

- creer une transaction
- verifier le blocage du bouton principal
- soumettre une preuve
- verifier le verrou `sender_number`
- simuler 3 rejets et verifier le cooldown
- laisser expirer une transaction et verifier le bloc remboursement
- marquer le remboursement et verifier le remplacement automatique
- simuler un `COMPLETED` rouvert puis rejete et verifier :
  - desactivation d'abonnement
  - archivage admin
  - auto-remplacement mobile
- verifier le badge `Remplace par TX-...` dans l'admin

---

## 13. Diagnostic rapide

## 13.1. Si l'utilisateur dit "je suis bloque"

Verifier dans cet ordre :

1. derniere transaction reelle
2. `status`
3. `validated_at`
4. `refund_required`
5. `refund_done_at`
6. `cooldown_until`
7. `replaced_by_transaction_id`
8. `is_subscription_active`

## 13.2. Si l'utilisateur dit "je vois un ancien ID"

Verifier :

- `GET /payments/manual/current`
- `request_number`
- `replaced_by_transaction_id`
- presence d'un `EXPIRED` ou `REJECTED apres validation` plus recent

## 13.3. Si l'admin dit "je ne peux plus rouvrir"

Verifier si la transaction est archivee :

- `status=EXPIRED`
- ou `status=REJECTED` avec `validated_at != null`
- ou `replaced_by_transaction_id != null`

Dans ce cas, le comportement est normal.

## 13.4. Si l'admin dit "je ne vois pas la bonne liste"

Verifier :

- `scope=ACTIVE|HISTORY|ALL`
- `status`
- `refund_required`

---

## 14. Conclusion

Le paiement manuel de Fiers Artisans est un flux stateful strict qui relie :

- la transaction
- la preuve
- l'abonnement
- le remboursement
- la vue mobile
- la vue admin

Le point critique a retenir est le suivant :

> la verite metier ne repose pas seulement sur `status`, mais sur la combinaison `status + validated_at + refund_required + refund_done_at + replaced_by_transaction_id`.
