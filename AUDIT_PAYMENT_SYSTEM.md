# 🔍 AUDIT COMPLET — Intégration Système Paiement Manuel Wave/Mobile Money

**Date :** Avril 2026  
**Portée :** Architecture complète (Backend NestJS, Frontend Flutter/Next.js, Infrastructure Docker)  
**Statut :** Audit technique sans modifications de code — Propositions uniquement

---

## 1️⃣ ANALYSE DE L'EXISTANT

### 1.1 Modules et Services Actuels

#### ✅ Subscription Module
**Localisation :** `backend/src/modules/subscription/`

**Entités existantes :**
- `Subscription` → liaison artisan (ArtisanProfile)
- `Payment` → transactions Wave (enum: PENDING/SUCCESS/FAILED)
- Relations : `1-1 (Subscription → ArtisanProfile)`, `1-N (Subscription → Payment[])`

**Limitations actuelles :**
- ❌ PaymentProvider enum : contient WAVE uniquement
- ❌ PaymentStatus : pas de statuts intermédiaires (ni REJECTED, ni EXPIRED, ni PROCESSING)
- ❌ Payment entity : `wave_transaction_id` et `wave_checkout_id` (Wave-specific)
- ❌ Pas de modèle pour preuve de paiement
- ❌ Pas de métadonnées image (hash, EXIF, taille, résolution)
- ❌ Pas de tracking tentatives upload
- ❌ Pas de timestamps: validated_at, rejected_at, expires_at_admin
- ❌ Pas de rejection_reason ou refund_required

#### ✅ Modules Dépendants
| Module | Usage Pertinent |
|--------|-----------------|
| **Notifications** | ✅ Notifier client/admin changements statut |
| **Media** | ⚠️ MinIO disponible mais pas lié à Payment |
| **Admin** | ⚠️ Dashboard nécessite enrichissement |
| **Analytics** | ⚠️ Peut tracker conversions paiement |

### 1.2 Infrastructure Actuelle

**Stack Base :**
```yaml
PostgreSQL 16 + PostGIS    → Données relationnelles
MongoDB 7                  → Documents + métadonnées
Redis 7                    → Cache + sessions
MinIO S3-compatible        → Stockage fichiers
Nginx (reverse proxy)      → Routage requests
```

**Capacités Existantes :**
- ✅ MinIO : buckets (portfolio, documents, media) → **peut recevoir images paiement**
- ✅ Redis : TTL keys → **peut gérer OTP, rate-limiting uploads**
- ✅ MongoDB : arbitrary documents → **peut stocker metadata images/EXIF**
- ✅ PostgreSQL : transactions ACID → **peut garantir cohérence payment workflow**
- ✅ AdminRealtime + SSE → **peut notifier admin en temps réel**

**Goulots d'étranglement :**
- ⚠️ Pas de cron/scheduler pour expirations auto (sauf @Scheduled)
- ⚠️ Pas de webhooks Image AI/suspicion tracking
- ⚠️ Pas de file d'attente (queue) pour long-running operations

### 1.3 Architecture API Existante

**Prefixe global :** `/api/v1`  
**Swagger :** `/api/docs` (hors prod)

**Routes Subscription actuelles :**
```
POST   /subscriptions                  → créer abonnement
GET    /subscriptions/:id              → consulter
PATCH  /subscriptions/:id/activate     → activer
POST   /subscriptions/:id/pay          → paiement Wave (via webhook)
GET    /admin/subscriptions            → dashboard admin
```

---

## 2️⃣ AUDIT D'INTÉGRATION POSSIBLE

### 2.1 Matrice de Compatibilité

| Aspect | Statut | Notes |
|--------|--------|-------|
| **BDD Relationnelle** | ✅ OK | PostgreSQL ACID, migrations supportées |
| **BDD Documentaire** | ✅ OK | MongoDB pour métadonnées images |
| **Stockage Fichiers** | ✅ OK | MinIO buckets existants |
| **Cache/Sessions** | ✅ OK | Redis avec TTL disponible |
| **Notifications** | ✅ OK | FCM + NotificationsModule exporté |
| **Real-time Admin** | ✅ OK | AdminRealtimeService + WebSocket |
| **Auth/Permissions** | ✅ OK | JWT Guard + Roles (ADMIN) existant |
| **Internationalization** | ✅ OK | Admin i18n + App Flutter i18n |
| **Error Handling** | ✅ OK | Global filters + exception handling |
| **Rate Limiting** | ⚠️ Partiel | ThrottlerModule présent, mais à configurer |
| **Logging** | ✅ OK | System logging existant |
| **Health Checks** | ✅ OK | HealthModule avec dépendances services |

### 2.2 Points de Tension Identifiés

#### 🔴 **Tension 1 : Images Proof of Payment**
**Enjeu :** Intégrité fichiers + détection fraude + stockage sécurisé

**Problèmes potentiels :**
- MinIO buckets actuels (`portfolio`, `documents`, `media`) ne distinguent pas les preuves paiement
- Pas de URL signée avec expiration pour les images proofs
- Pas de extraction/validation EXIF
- Pas de detection Photoshop/Canva/modification

**Proposition :** 
- Créer bucket dédié `payment-proofs` dans MinIO
- Implémenter URL signées (expiration 1h) pour lectures admin
- Intégrer extraction EXIF + score suspicion IA optionnel

#### 🔴 **Tension 2 : Validation Admin Hors Delai**
**Enjeu :** Expiration automatique vs admin busy

**Problème :**
- Pas de `@Scheduled` cron job visible pour expirer transactions PENDING

**Proposition :**
- Ajouter `CronService` dans un module utilitaire
- Job horaire : `UPDATE payments SET status='EXPIRED' WHERE status='PENDING' AND expires_at_admin < NOW()`
- Notifier admin + setter `refund_required=true`

#### 🔴 **Tension 3 : Admin Dashboard Overload**
**Enjeu :** Admin web (Next.js) doit afficher 10+ colonnes + images

**Problème :**
- AdminModule backend existe mais pas de endpoint `/admin/payment-proofs`
- Pas de filtrage (PENDING/COMPLETED/REJECTED/EXPIRED/REFUND_REQUIRED)

**Proposition :**
- Étendre AdminModule avec controller PaymentProofsAdmin
- Endpoints: `GET /admin/payment-proofs?status=PENDING`, `PATCH /admin/payment-proofs/:id/validate`
- Webhook real-time pour updates frontend

#### 🔴 **Tension 4 : Communication Mobile → Admin Async**
**Enjeu :** Client upload → admin validation (24-72h) → client notification

**Problème :**
- Flux synchrone actuel (Wave webhook)
- Besoin poll/SSE pour mises à jour statut

**Proposition :**
- Implémenter SSE endpoint client : `GET /subscriptions/:id/status-stream`
- Ou polling à 30s (acceptable pour MVP)
- Admin notifié via AdminRealtime

---

## 3️⃣ PROPOSITIONS D'ARCHITECTURE

### 3.1 Entités de Base Enrichies

#### 🗂️ **Nouvelle Entity : `PaymentManual` (PostgreSQL)**

```sql
-- paymentManual entity with all requirements
id (UUID)
transaction_id (string, UNIQUE) → TX-XXXXXXXX
subscription_id (FK to Subscription)
amount_fcfa (int) → 5000
status (enum) → PENDING|PENDING_ADMIN|COMPLETED|REJECTED|EXPIRED
provider (enum) → WAVE_MANUAL|ORANGE_MONEY|MTN_MONEY|MOOV_MONEY
sender_number (string) → format brut (CI)
created_at (timestamp)
expires_at_admin (timestamp) → now + 72h
validated_at (timestamp, nullable)
rejected_at (timestamp, nullable)
rejection_reason (string, nullable)
refund_required (boolean)
refund_done_at (timestamp, nullable)
attempted_refund_count (int) → 0
INDEX: (subscription_id, status, created_at)
INDEX: (status, expires_at_admin)
```

#### 🗂️ **Nouvelle Entity : `PaymentProof` (PostgreSQL)**

```sql
id (UUID)
payment_manual_id (FK to PaymentManual)
image_url (string) → MinIO URL
image_hash_sha256 (string, UNIQUE) → déduplication globale
submitted_at (timestamp)
declared_payment_time (timestamp, nullable)
upload_attempt_number (int) → 1-3
file_type (enum) → JPG|PNG|WEBP
file_size_kb (int)
file_resolution (string) → 1080x1920
has_exif (boolean)
exif_capture_date (timestamp, nullable)
exif_modified_date (timestamp, nullable)
exif_device (string, nullable)
exif_software (string, nullable) → Photoshop|Canva|etc
ai_suspicion_score (float 0.0-1.0, nullable)
is_suspected_fraud (boolean)
deletion_requested (boolean)
INDEX: (payment_manual_id, submitted_at)
INDEX: (image_hash_sha256) → déduplication
```

#### 🗂️ **Nouvelle Collection MongoDB : `paymentMetadata` (Optionnel)**

```json
{
  "payment_manual_id": "uuid",
  "proof_count": 2,
  "last_admin_note": "...",
  "admin_decision_notes": "...",
  "device_info": {
    "device_hash": "...",
    "location_ip": "...",
    "user_agent": "..."
  },
  "timeline": [
    {
      "action": "PROOF_SUBMITTED",
      "timestamp": "...",
      "details": { ... }
    }
  ]
}
```

### 3.2 Modules à Créer ou Enrichir

#### **Nouveau Module : `payment-manual/`**

**Structure proposée :**
```
src/modules/payment-manual/
├── entities/
│   ├── payment-manual.entity.ts
│   └── payment-proof.entity.ts
├── schemas/
│   └── payment-metadata.schema.ts (MongoDB)
├── dto/
│   ├── create-payment-manual.dto.ts
│   ├── submit-proof.dto.ts
│   ├── validate-proof.dto.ts
│   └── admin-filter.dto.ts
├── controllers/
│   ├── payment-manual.controller.ts (client)
│   └── payment-manual-admin.controller.ts
├── services/
│   ├── payment-manual.service.ts
│   ├── proof-validation.service.ts
│   ├── exif-extractor.service.ts
│   └── fraud-detection.service.ts
├── guards/
│   ├── payment-ownership.guard.ts
│   └── upload-rate-limit.guard.ts
├── interceptors/
│   └── payment-hash.interceptor.ts
├── cron/
│   └── payment-expiration.cron.ts
├── events/
│   ├── payment-proof.events.ts
│   └── payment.events.ts
└── payment-manual.module.ts
```

#### **Enrichissements Existants**

| Module | Changements |
|--------|-------------|
| **SubscriptionModule** | Importer PaymentManualModule + méthodes transition ACTIVE→COMPLETED |
| **AdminModule** | Ajouter routes admin gestion preuves + dashboard filters |
| **NotificationsModule** | Templates SMS/FCM pour paiements manuels |
| **MediaModule** | Intégrer comme option upload (ou créer séparé) |

### 3.3 API Endpoints Proposés

#### **Client Endpoints (Artisan/Client)**

```yaml
POST /api/v1/payments/manual/initiate
  Desc: Créer transaction manuelle
  Auth: JWT
  Body: { provider: WAVE_MANUAL }
  Return: { transaction_id, expires_at_admin, instructions }
  
GET /api/v1/payments/manual/:transaction_id
  Desc: Consulter statut transaction
  Auth: JWT (propriétaire)
  Return: { status, rejection_reason, refund_required }

POST /api/v1/payments/manual/:transaction_id/submit-proof
  Desc: Uploader preuve paiement
  Auth: JWT (propriétaire)
  Content-Type: multipart/form-data
  Body: { image, sender_number, declared_time }
  Validation: max 3 uploads
  Return: { proof_id, submitted_at, hash }

GET /api/v1/payments/manual/:transaction_id/proof/:proof_id
  Desc: Récupérer URL signée image (expiration 1h)
  Auth: JWT
  Return: { signed_url, expires_at }

GET /api/v1/subscriptions/:id/status-stream (SSE)
  Desc: Stream real-time statut abonnement
  Auth: JWT
  Keep-alive: 30s avec heartbeat
```

#### **Admin Endpoints**

```yaml
GET /api/v1/admin/payment-proofs
  Desc: Lister preuves (filtrage statut)
  Auth: JWT + ADMIN
  Query: ?status=PENDING&sort=created_at&limit=20
  Return: [{transaction_id, user, amount, submitted_at, proof, ...}]

GET /api/v1/admin/payment-proofs/:id/details
  Desc: Détails complets (image + EXIF + metadata)
  Auth: JWT + ADMIN
  Return: { payment, proof, exif, metadata, timeline }

PATCH /api/v1/admin/payment-proofs/:id/validate
  Desc: Valider paiement → COMPLETED
  Auth: JWT + ADMIN
  Body: { validated_notes: string }
  Side-effect: Activer abonnement + notifier client

PATCH /api/v1/admin/payment-proofs/:id/reject
  Desc: Rejeter preuve → REJECTED
  Auth: JWT + ADMIN
  Body: { reason: string }
  Side-effect: Status REJECTED + notifier client

PATCH /api/v1/admin/payment-proofs/:id/mark-refunded
  Desc: Marquer remboursement fait
  Auth: JWT + ADMIN
  Body: { refund_date, refund_details }

GET /api/v1/admin/payment-analytics
  Desc: Stats conversions, moyennes delai, taux rejet
  Auth: JWT + ADMIN
  Return: { total_pending, avg_validation_time, rejection_rate, ... }
```

---

## 4️⃣ FLUX ET SCÉNARIOS MÉTIER

### 4.1 Flux Nominal (Happy Path)

```
┌─ Artisan initiates payment ────────────────────────────┐
│                                                         │
├─→ [1] POST /manual/initiate                           │
│         ↓ Create PaymentManual (PENDING)              │
│         ↓ Generate TX-XXXXXXXX                        │
│         ↓ Set expires_at_admin = now + 72h            │
│         ↓ Return transaction_id + instructions        │
│         ↓ Notify: "Show recipient number + 5000 FCFA" │
│                                                         │
├─→ [2] Client sends money externally (Wave/etc)        │
│         ↓ Client saves proof screenshot               │
│                                                         │
├─→ [3] POST /manual/{txid}/submit-proof                │
│         ↓ Multipart upload image                      │
│         ↓ Validate: format, size, hash                │
│         ↓ Extract EXIF metadata                       │
│         ↓ Store in MinIO bucket:payment-proofs        │
│         ↓ Create PaymentProof (upload_attempt=1)      │
│         ↓ Check hash uniqueness (reject if duplicate) │
│         ↓ Status: PENDING_ADMIN                       │
│         ↓ Notify admin: "New proof to validate"       │
│                                                         │
├─→ [4] Admin reviews (real-time SSE/AdminPanel)        │
│         ↓ GET /admin/payment-proofs?status=PENDING    │
│         ↓ Display: thumbnail + metadata + EXIF        │
│         ↓ Admin checks amount + sender_number         │
│         ↓ Admin clicks "Validate"                     │
│                                                         │
├─→ [5] PATCH /admin/payment-proofs/{id}/validate       │
│         ↓ Update PaymentManual: status=COMPLETED      │
│         ↓ Set validated_at = now                      │
│         ↓ Trigger UpdateSubscriptionStatus event      │
│         ↓ Subscription: status=ACTIVE, starts_at=now  │
│         ↓ Notify client: "Paiement validé"            │
│         ↓ Log to MongoDB timeline                     │
│                                                         │
└─ Artisan subscription active ─────────────────────────┘
```

### 4.2 Scénario : Preuve Modifiée (Anti-fraude)

```
[Client uploads photoshopped image]
      ↓
[EXIF exif_software = "Photoshop"]
      ↓
[ai_suspicion_score = 0.87 (high)]
      ↓
[PaymentProof.is_suspected_fraud = true]
      ↓
[Admin sees warning: "Suspicion: Photoshop + AI score 0.87"]
      ↓
[Admin rejects with reason: "Image modifiée détectée"]
      ↓
[Status = REJECTED, rejection_reason populated]
      ↓
[Client notified: "Preuve rejetée — image non authentique"]
      ↓
[Client can retry (max 3 attempts)]
```

### 4.3 Scénario : Image Dupliquée

```
[Client 1 uploads image → hash A1B2C3D4]
      ↓
[Client 2 uploads same image → hash A1B2C3D4]
      ↓
[Backend: SELECT * FROM payment_proofs WHERE image_hash = 'A1B2C3D4']
      ↓
[Found existing! Is active?]
      ├─ YES → Reject immediately (409 Conflict, "Preuve déjà utilisée")
      └─ NO → Allow (previous proof failed)
      ↓
[Prevent fraud loop]
```

### 4.4 Scénario : Timeout Admin (72h)

```
[Transaction created at T0]
[expires_at_admin = T0 + 72h]
[Admin gone / busy]
      ↓
[Cron job @Scheduled runs hourly]
[Checks: WHERE status='PENDING_ADMIN' AND expires_at_admin < NOW()]
      ↓
[Updates PaymentManual: status=EXPIRED, refund_required=true]
      ↓
[Send notification admin: "Transaction expired: TX-XXXX — refund required"]
      ↓
[Dashboard shows in "REFUND_REQUIRED" tab]
      ↓
[Admin clicks "Mark as Refunded" → refund_done_at=now]
      ↓
[Client notified: "Délai dépassé — remboursement en cours"]
```

### 4.5 Scénario : Montant Insuffisant (Frais Opérateur)

```
[Client receives 4500 FCFA (expected 5000, perdus 500 aux frais)]
[Client naively submits proof showing 4500]
      ↓
[Admin sees screenshot: 4500 FCFA]
      ↓
[Admin rejects with reason: "Montant insuffisant (4500 < 5000)"]
      ↓
[Client notified: "Montant insuffisant — envoyer 5000 FCFA"]
      ↓
[Client can resubmit proof with correct amount (retry 2/3)]
```

### 4.6 Scénario : 3 Tentatives Uploads Dépassées

```
[User uploads proof 1 → Invalid image format]
[User uploads proof 2 → Photoshop detected]
[User uploads proof 3 → Duplicate hash]
      ↓
[POST /submit-proof (4th attempt)]
      ↓
[Backend: upload_attempt >= 3 → 429 Too Many Requests]
      ↓
[Response: "Max tentatives atteint — contact support"]
      ↓
[Admin notified: "User {id} blocked from uploads — TX-XXXX"]
      ↓
[Admin can manually reopen: PATCH /unblock-payment /:id]
```

### 4.7 Scénario : Rejet Admin (Erreur Manuelle)

```
[Admin accidentally rejects valid proof]
[Status: REJECTED, rejection_reason="Test"
      ↓
[Client sees: "Paiement rejeté — Test"]
[Client frustrated, contacts support]
      ↓
[Admin realizes mistake]
[Admin action: PATCH /reopen-payment /:id]
      ↓
[Status: PENDING_ADMIN, reset upload_attempt_count]
      ↓
[Client can retry submission]
```

### 4.8 Scénario : Plusieurs Preuve pour Une Transaction

```
[Client submits proof 1 → PENDING_ADMIN]
[Client submits proof 2 (different screenshot) → ?]
      ↓
[Design decision needed: Allow or reject?]
      ├─ Option A: Reject (max 1 active proof per payment)
      │           New submission = error "Proof already submitted"
      │
      └─ Option B: Allow parallel proofs
                   Admin sees all 3, decides which is most reliable
```

**Recommandation :** Option A (stricte) pour MVP → facilite validation admin

### 4.9 Scénario : Notification Failure (FCM Offline)

```
[Admin validates payment]
[Trigger: Send FCM to client]
[FCM service down]
      ↓
[Log error: "FCM delivery failed for user {id}"]
[Status COMPLETED stored in DB ✓]
[Client notified on next login via /subscriptions/:id check]
      ↓
[Fallback: Polling every 30s shows ACTIVE subscription]
[No data loss]
```

### 4.10 Scénario : Concurrent Requests (Race Condition)

```
[Admin clicks "Validate" at 14:00:00.001]
[Admin clicks "Validate" again at 14:00:00.002]
[Both requests reach backend simultaneously]
      ↓
[Database trigger: UNIQUE constraint or SELECT-FOR-UPDATE]
      ├─ Request 1: Succeeds
      └─ Request 2: Fails (payment already COMPLETED)
      ↓
[Response 409: "Paiement déjà validé"]
[No double-validation]
```

---

## 5️⃣ PROPOSITIONS D'AMÉLIORATION

### 5.1 Infrastructure & DevOps

#### **Création MinIO Bucket Dédié**
```yaml
# Dans docker-compose.yml
minio:
  # Existing config...
  # Add bucket creation script:
  volumes:
    - ./scripts/minio-init-buckets.sh:/minio-init-buckets.sh
  entrypoint: >
    sh -c "
    minio server /data &
    # Attendre startup (5s)
    sleep 5
    # Créer buckets
    mc mb minio/payment-proofs 2>/dev/null || true
    # Politiques d'accès
    mc policy set upload-only minio/payment-proofs
    wait
    "
```

#### **Cron Service pour Expirations**
```typescript
// src/common/services/cron.service.ts
@Injectable()
export class CronService {
  @Scheduled(CronExpression.EVERY_HOUR)
  async expireOldPayments() {
    // Logic: expire PENDING_ADMIN paymentManuals older than 72h
  }
}
```

#### **Redis Keys pour Rate-Limiting Uploads**
```typescript
// Clés Redis:
PAYMENT_UPLOAD_ATTEMPTS:{transaction_id}:{user_id} → TTL 48h, max 3
PAYMENT_HASH_TRACKING:{hash} → TTL 1 year (forever basically)
```

#### **Monitoring & Alerts**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'payment_manual'
    static_configs:
      - targets: ['api:3000']
    metrics_path: '/api/v1/metrics'
    # Metrics à tracker:
    # - payment_manual_status_total{status="PENDING",provider="WAVE_MANUAL"}
    # - payment_manual_validation_duration_seconds
    # - payment_proof_upload_errors_total
    # - payment_proof_fraud_detected_total
```

### 5.2 Sécurité Renforcée

#### **Signature des URLs MinIO**
```typescript
// service: payment-manual.service.ts
async getSignedProofUrl(proofId: string): Promise<string> {
  const objectName = `${proofId}.jpg`;
  
  const presignedUrl = await this.minioClient.presignedGetObject(
    'payment-proofs',
    objectName,
    1 * 60 * 60, // 1 hour expiration
  );
  
  return presignedUrl;
}
```

#### **EXIF Extraction & Validation**
```bash
# Ajouter à backend package.json:
{
  "dependencies": {
    "piexifjs": "^0.6.0",  // EXIF parsing
    "sharp": "^0.34.5"     // Image processing (already exists)
  }
}
```

#### **IA Suspicion Scoring (Optionnel Phase 2)**
```typescript
// Services.fraud-detection.service.ts
// Integration point for ML model:
// - Utiliser API tierce (ex: AWS Rekognition, Google Cloud Vision)
// - Ou modèle local (TensorFlow.js)
// - Score 0.0-1.0 → 0.7+ = flag admin
```

#### **Logs Immuables pour Audit**
```typescript
// Create MongoDB collection:
db.createCollection("payment_audit_logs", {
  capped: true,
  size: 104857600  // 100MB
})

// Log every state change:
{
  payment_manual_id: "uuid",
  action: "VALIDATE" | "REJECT" | "EXPIRE",
  admin_id: "uuid",
  timestamp: ISODate(),
  old_status: "PENDING_ADMIN",
  new_status: "COMPLETED",
  notes: "Montant correct, numéro valide",
  ip_address: "...",
  user_agent: "..."
}
```

### 5.3 UX/Frontend Improvements

#### **Flutter App — Pages à Créer/Enrichir**

```
lib/presentation/
├── features/
│   ├── subscription/
│   │   ├── pages/
│   │   │   ├── subscription_page.dart
│   │   │   └── manual_payment_page.dart (NEW)
│   │   ├── widgets/
│   │   │   ├── payment_method_selector.dart (existing Wave)
│   │   │   ├── manual_payment_instructions.dart (NEW)
│   │   │   ├── proof_upload_widget.dart (NEW)
│   │   │   ├── upload_progress_indicator.dart (NEW)
│   │   │   └── proof_validation_status.dart (NEW)
│   │   ├── providers/
│   │   │   ├── subscription_provider.dart (existing)
│   │   │   ├── manual_payment_provider.dart (NEW)
│   │   │   └── upload_stream_provider.dart (NEW)
│   │   └── models/
│   │       ├── payment_manual_model.dart (NEW)
│   │       └── payment_proof_model.dart (NEW)
```

**Key Features:**
- ✅ Selection Wave API vs Manual Payment methods
- ✅ Show recipient number + 5000 FCFA with warning about fees
- ✅ Camera capture OR gallery selection (image_picker plugin)
- ✅ Auto-extract sender_number field + declared time
- ✅ Real-time upload progress bar
- ✅ SSE stream for status polling (30s interval fallback)
- ✅ Notification badge when proof validated/rejected

#### **Admin Web (Next.js) — Pages à Créer/Enrichir**

```
admin-web/src/app/
├── (dashboard)/
│   ├── payments/
│   │   ├── manual/
│   │   │   ├── page.tsx (NEW — Dashboard)
│   │   │   ├── [id]/
│   │   │   │   └── page.tsx (NEW — Details + action)
│   │   │   └── layout.tsx (NEW)
│   ├── components/
│   │   └── payments/
│   │       ├── payment-manual-table.tsx (NEW)
│   │       ├── proof-image-viewer.tsx (NEW)
│   │       ├── metadata-panel.tsx (NEW)
│   │       ├── exif-details.tsx (NEW)
│   │       └── action-buttons.tsx (NEW — Validate/Reject)
│   └── hooks/
│       ├── use-payment-manual.ts (NEW)
│       └── use-proof-validation.ts (NEW)
```

**Key Features:**
- ✅ Real-time filterable table (PENDING/COMPLETED/REJECTED/EXPIRED/REFUND_REQUIRED)
- ✅ Click row → modal with full details + image preview
- ✅ EXIF metadata displayed (camera, date, location if available)
- ✅ Fraud score badge + AI warning
- ✅ Inline Validate / Reject buttons
- ✅ Notes/comments textarea
- ✅ Timeline of actions (submitted, validated, rejected)
- ✅ Bulk actions (mark as refunded, etc.)

### 5.4 Documentation & Guidelines

#### **Fichiers à Créer**

```
docs/
├── PAYMENT_MANUAL_ARCHITECTURE.md (this audit detail)
├── PAYMENT_MANUAL_API.md (endpoint specs + curl examples)
├── PAYMENT_MANUAL_SECURITY.md (anti-fraud rules + hash validation)
├── PAYMENT_MANUAL_DEVOPS.md (MinIO setup, cron monitoring)
└── PAYMENT_MANUAL_TROUBLESHOOTING.md (common issues + fixes)
```

---

## 6️⃣ IMPACT CROSS-SYSTEMS

### 6.1 Impacts Backend

| Module | Changement | Effort | Risque |
|--------|-----------|--------|--------|
| **SubscriptionModule** | Import PaymentManual, update entity status transitions | Bas | Bas |
| **AuthModule** | No change needed (JWT guards existing) | N/A | N/A |
| **NotificationsModule** | Add templates for manual payment events | Bas | Bas |
| **AdminModule** | Add payment-manual routes + controller | Moyen | Moyen |
| **MediaModule** | Optional — reference or create payment-specific upload | Bas | Bas |
| **HealthModule** | Add MinIO bucket health check | Bas | Bas |
| **New: PaymentManualModule** | All entities/services/controllers | Haut | Haut |

### 6.2 Impacts Frontend Mobile

| Écran | Changement | Effort | Risque |
|-------|-----------|--------|--------|
| **Subscription chooser** | Add manual payment option | Bas | Bas |
| **Payment methods** | Show Wave API + Manual methods | Bas | Moyen |
| **Manual payment form** | Proof upload + capture | Moyen | Moyen |
| **Status tracking** | SSE stream or polling | Moyen | Moyen |
| **Notifications** | FCM handlers for payment events | Bas | Bas |

### 6.3 Impacts Frontend Admin

| Page | Changement | Effort | Risque |
|------|-----------|--------|--------|
| **Dashboard** | Add payment-manual tab/section | Bas | Bas |
| **New: Payment proofs list** | Table + filters | Moyen | Moyen |
| **New: Proof details modal** | Image viewer + metadata + actions | Moyen | Moyen |
| **New: Analytics** | Conversion stats, avg time, rejection rate | Bas | Bas |

### 6.4 Impacts Infrastructure

| Composant | Changement | Effort |
|-----------|-----------|--------|
| **PostgreSQL** | Add 2 tables, 4 indexes | Bas |
| **MongoDB** | Add collection (optional) | Bas |
| **Redis** | Use existing keys for rate-limit | Bas |
| **MinIO** | Create bucket `payment-proofs` | Très bas |
| **Nginx** | No config change (routes under /api/v1) | N/A |
| **Cron** | Add @Scheduled job in backend | Bas |
| **Monitoring** | Add metrics in Prometheus | Bas |
| **Docker-Compose** | Bucket init script, health checks update | Bas |

### 6.5 Impacts Data Flow

```
┌─────────────────────────────────────────────────────┐
│ BEFORE: Wave API only                               │
│                                                     │
│  Client → Wave API → Webhook → Payment.status=OK  │
│  (Automatic, no human intervention)                │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ AFTER: Wave API + Manual Paiement                  │
│                                                     │
│  ┌─ Wave path (unchanged)                         │
│  │  Client → Wave API → Webhook → Payment.status │
│  │                                                 │
│  └─ Manual path (new)                             │
│     Client → Upload proof → PaymentManual created │
│     → Admin reviews → Validation/Rejection        │
│     → PaymentManual.status updated                │
│     → Subscription activated OR retry             │
│                                                     │
│  Both converge to: Subscription.status = ACTIVE   │
└─────────────────────────────────────────────────────┘
```

---

## 7️⃣ CHECKLIST PRÉ-IMPLÉMENTATION

### 7.1 Architecture

- [ ] Approuver design entités (PaymentManual, PaymentProof)
- [ ] Décider : 1 proof par payment ou N proofs en parallèle?
- [ ] Décider : AI fraud detection (Phase 1 ou Phase 2)?
- [ ] Valider index PostgreSQL pour perf queries
- [ ] Valider structure MinIO buckets + politiques d'accès

### 7.2 API & Contrats

- [ ] Valider liste endpoints complets
- [ ] Définir pagination (limit/offset) pour admin list
- [ ] Définir format errors (codes 400/409/429/etc)
- [ ] Générer Swagger documentation
- [ ] Tests d'intégration endpoint à endpoint

### 7.3 Sécurité

- [ ] Configurer rate-limiting uploads (Redis)
- [ ] Valider signature MinIO URLs
- [ ] Tests d'audit logging (MongoDB)
- [ ] Pen testing: hash collision, EXIF injection, etc
- [ ] Validation CORS si cross-origin

### 7.4 Infra & DevOps

- [ ] Script MinIO bucket creation
- [ ] Cron job expiration implémenté + testé
- [ ] Monitoring metrics en place
- [ ] Backup strategy pour images proof
- [ ] Test failover MinIO (réplication?)

### 7.5 Frontend

- [ ] Designs UI/UX approuvés (mobile + admin)
- [ ] Composants réutilisables identifiés
- [ ] Real-time mechanism décidé (SSE vs Polling)
- [ ] i18n strings pour messages paiement
- [ ] Tests d'upload large fichiers

### 7.6 Tests & QA

- [ ] Test scenarios 4.1-4.10 en détail
- [ ] Stress test uploads (concurrency)
- [ ] Test expirations timeout
- [ ] Test doublon hashes
- [ ] Test rollback admin (reopen payment)
- [ ] E2E tests mobile + admin

---

## 8️⃣ ÉVOLUTIONS FUTURES (Phase 2+)

### 8.1 Phase 2 : Automatisation Partielle

```
- Wave API integration complète (phase 1 = désactivée)
- Vérification automatique montant reçu (via API Wave)
- Détection IA fraude (AWS Rekognition ou local model)
- SMS/Email confirmations automatiques
- Webhook intégration (Wave → backend payment status)
```

### 8.2 Phase 3 : Expansion Géographique

```
- Support Orange Money (Senegal, Mali, etc)
- Support Stripe/PayPal pour zones hors CI
- Multi-devise (CFA, USD, EUR)
- Local payment methods par région
```

### 8.3 Phase 3+ : Intelligence

```
- Dashboard prédictif (risque rejet par provider)
- Détection patterns fraude (géolocalisation, device)
- Recommendation engine (meilleur payment method par user)
- Auto-flagging des cas suspects pour audit
```

---

## 9️⃣ DÉPENDANCES EXTERNES

### 9.1 Services Existants à Réutiliser

| Service | Usage | Config |
|---------|-------|--------|
| **MinIO** | Storage preuves | Bucket `payment-proofs` |
| **Redis** | Rate-limit uploads | TTL keys |
| **PostgreSQL** | Entités transactionnelles | 2 tables + indexes |
| **MongoDB** | Metadata + logs audit | Collection `paymentMetadata` |
| **FCM** | Notifications clients | Templates new |
| **Nginx** | Reverse proxy | No config change |

### 9.2 Packages npm/pub à Ajouter

#### **Backend (NestJS)**
```json
{
  "piexifjs": "^0.6.0",          // EXIF parsing
  "sharp": "^0.34.5",            // Already present
  "uuid": "^13.0.0",             // Already present
  "typeorm": "^0.3.28",          // Already present
  "minio": "^8.0.7"              // Already present
}
```

#### **Frontend Flutter**
```yaml
dependencies:
  # Image handling
  image_picker: ^1.0.0
  cached_network_image: ^3.3.0
  
  # Upload tracking
  http: ^1.1.0
  dio: ^5.3.0  # Already present
  
  # Real-time
  web_socket_channel: ^2.4.0
  
  # Notifications
  firebase_messaging: ^14.0.0  # Already present
```

#### **Admin Web (Next.js)**
```json
{
  "react-image-lightbox": "^5.1.1",
  "exif-parser": "^0.1.12",
  "recharts": "^2.10.0",           // Already present
  "framer-motion": "^10.0.0"       // Already present
}
```

---

## 🔟 ESTIMATIONS EFFORT (Rough)

### Par Phase

| Phase | Composant | Story Points | Temps réel |
|-------|-----------|--------------|-----------|
| **Design** | Architecture + DB + API contracts | 8 | 1-2 days |
| **Backend** | Module payment-manual complet | 21 | 1 week |
| **Frontend Mobile** | Pages + upload + streaming | 16 | 4-5 days |
| **Admin Web** | Dashboard + validation flow | 13 | 3-4 days |
| **Testing** | E2E + scenarios 4.1-4.10 | 13 | 3-4 days |
| **DevOps** | MinIO, Cron, monitoring, alerts | 8 | 1-2 days |
| **Documentation** | Guides + troubleshooting | 5 | 0.5-1 day |
| **Buffer/Review** | Code review + fixes | 8 | 1 day |
| | **TOTAL** | **92 SP** | **~3 weeks** |

---

## 🎯 CONCLUSION

### ✅ Statut d'Intégrabilité : **VIABLE**

**Raisons :**
1. ✅ Infrastructure existante (PostgreSQL, MongoDB, Redis, MinIO) couvre 100% des besoins
2. ✅ Architecture modulaire NestJS permet ajout propre sans breaking changes
3. ✅ Admin/Notifications déjà présents, juste enrichissement requis
4. ✅ Flutter + Next.js architecture flexible pour nouveaux écrans

### ⚠️ Risques Mitigés

| Risque | Mitigation |
|--------|-----------|
| Image storage/authenticity | SHA-256 unique hash + EXIF + AI score + admin verification |
| Timeout admin (72h) | Cron job automatique + notifications |
| Fraude (photoshop, doublon) | EXIF detection + hash dedup + ai_suspicion_score |
| Concurrency race conditions | SELECT-FOR-UPDATE + DB triggers |
| Performance uploads | Redis rate-limiting + async processing |

### 🚀 Next Steps Recommandés

1. **Validation stakeholder** : Approuver design entités + API contracts
2. **Spike**: Proof-of-concept MinIO bucket + EXIF extraction (1-2 days)
3. **Itération 1** : Backend module + admin routes basiques
4. **Itération 2** : Flutter pages + upload UI
5. **Itération 3** : Admin validation dashboard + real-time
6. **Itération 4** : Testing + monitoring + documentation

---

**Document Review:** ✅ Audit complet sans modification de code  
**Prochaine étape:** Approbation design pour lancement implémentation  
**Validé par:** [À remplir]

