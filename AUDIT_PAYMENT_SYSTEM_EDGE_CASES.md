# 🔐 AUDIT DÉTAILLÉ — Scénarios Edge-Cases & Sécurité

**Complément:** AUDIT_PAYMENT_SYSTEM.md  
**Focus:** Cas limites, anti-fraude, data integrity, disaster recovery

---

## 1️⃣ SCÉNARIOS EDGE-CASES CRITIQUES

### 1.1 Scénario : Utilisateur Bloqué (Banned/Suspended)

```
Timeline:
- T0: User crée PaymentManual (status=PENDING)
- T0+1m: Admin découvre user fraude, le bloque
  → User.is_active = false
- T0+2h: User upload proof
- T0+3h: Admin revient valider

Questions clés:
Q1: User bloqué peut-il continuer à soumettre preuves?
Q2: Admin doit-il pouvoir rejeter transactions d'users bloqués?
Q3: Faut-il cascade-delete ou soft-delete?

Recommandations:
A1: NON — Bloquer au niveau du guard JWT
   GET /payments/manual/:id/submit-proof 
   → vérifie User.is_active avant accept

A2: OUI — Admin peut toujours rejeter, marquer refund_required

A3: Soft-delete PaymentManual + garde l'audit trail
   UPDATE payment_manual SET deleted_at = NOW() WHERE user_id = ?
   Pas de DELETE physique
```

### 1.2 Scénario : Proof Modifiée POST-UPLOAD

```
Timeline:
- T0: Admin valide proof → status = COMPLETED
- T1: Attaquant compromise MinIO, modifie l'image
- T2: Admin télécharge image depuis /admin (signed URL expired)
- T3: Client conteste validation

Questions clés:
Q1: Comment détecter image modifiée post-storage?
Q2: Qui a eu accès (audit trail)?

Recommandations:
A1: Ajouter `stored_at_hash_check` 
   • Avant: hash = SHA256(image)
   • Quotidien: cron job vérifie hash actuels vs stored_at_hash
   • Alert si mismatch → Log incident

A2: Chaque accès à image loggé
   {
     file_access_log: [
       { admin_id, timestamp, action: 'DOWNLOAD', hash_check: 'OK' }
     ]
   }
```

### 1.3 Scénario : Montant Incorrect via Fraude Admin

```
Timeline:
- User envoie 5000 FCFA correctement
- Screenshot montre 5000 FCFA
- Admin corrompu rejette avec raison fictive
- User frustrated, crée dispute

Questions clés:
Q1: Comment dispute une décision admin?
Q2: Y a-t-il second-level approval?

Recommandations:
A1: Support escalation process
   • Client click "Contest rejection" → support ticket
   • Escalate to SUPER_ADMIN role
   • SUPER_ADMIN peut reopener + audit trail

A2: Seuil de value = 5000 FCFA
   • Si >10 rejections/jour par admin → Flag
   • Si >20% rejection rate → Manual review
   • Escalate à management

A3: Store original request in MongoDB
   {
     "contest_rejection": {
       "original_claim": "User sent 5000 FCFA",
       "screenshot_evidence": "URL to MinIO",
       "admin_rejection_reason": "Test reason",
       "user_notes": "This is correct!",
       "escalated_to": "super_admin_id",
       "resolution": "REOPENED|UPHELD"
     }
   }
```

### 1.4 Scénario : Device Spoofing (EXIF Fake)

```
Timeline:
- Attacker use EXIF tool to fake device: "iPhone 14"
- But image is clearly Photoshop
- Upload proof
- EXIF metadata says: device=iPhone14, capture_time=correct

Questions clés:
Q1: Fiabilité EXIF data?
Q2: Ai-on better heuristics?

Recommandations:
A1: EXIF NOT trustworthy alone
   • Use combination of signals:
     ✓ EXIF metadata (device, date, GPS if available)
     ✓ Image forensics (embedded Photoshop markers)
     ✓ AI suspicion score
     ✓ Human admin judgment

A2: Create suspicion_signals array
   {
     "image_hash": "...",
     "suspicion_signals": [
       { "signal": "EXIF_PHOTOSHOP", "score": 0.9 },
       { "signal": "METADATA_MISSING", "score": 0.4 },
       { "signal": "UNUSUAL_RESOLUTION", "score": 0.2 },
       { "signal": "COMPRESSION_ARTIFACTS", "score": 0.6 }
     ],
     "combined_score": 0.78,
     "admin_assessment": "APPROVED|REJECTED|FLAG_FOR_REVIEW"
   }
```

### 1.5 Scénario : Proof Partagé Entre Plusieurs Users

```
Timeline:
- User A upload proof → hash A1B2C3
- User B somehow obtains User A's image
- User B uploads same image → hash A1B2C3

Question clé:
Q1: Comment déterminer qui est légitime?

Recommandations:
A1: Hash uniqueness = global constraint
   CREATE UNIQUE INDEX idx_proof_hash ON payment_proofs(image_hash)

A2: Rejet automatique second user
   • Error: 409 Conflict
   • Message: "Cette preuve a déjà été utilisée"
   • Alert admin: "Possible duplicate payment attempt"

A3: Cependant, si User A's proof was REJECTED
   • User B peut réessayer (peut-être User A's friend)
   • Mais log: "image previously rejected for User_A"
   • Admin awareness lors validation User B
```

### 1.6 Scénario : Network Failure Mid-Upload

```
Timeline:
- User upload image (5 MB)
- 50% upload complète
- Network disconnected
- File partially written to MinIO

Questions clés:
Q1: État du PaymentProof?
Q2: Peut-il retry?

Recommandations:
A1: Partial uploads not stored
   • Use S3/MinIO multipart upload API
   • Incomplete parts expire automatically (24h)
   • Client doesn't create PaymentProof until complete

A2: Retry mechanism
   • Client app catches network error
   • Automatic retry with exponential backoff
   • Max 3 attempts total (including manual retries)

A3: Cleanup job
   • Cron: Delete incomplete multipart uploads >24h old
   • Prevent MinIO space leak
```

### 1.7 Scénario : Timezone Mismatch (EXIF Date)

```
Timeline:
- User in UTC+0 (Dakar) → captures at 14:00 UTC
- EXIF stores: 2025-07-01T14:00:00Z
- Transaction created: 2025-07-01T13:55:00Z (user upload 5min later)
- Admin in UTC+2 (Cairo) → views time differently

Questions clés:
Q1: EXIF date vs transaction date compatibility?
Q2: Timezone handling?

Recommandations:
A1: Always store in UTC
   • Payment.created_at = UTC
   • PaymentProof.exif_capture_date = UTC (or extract tz)
   • PaymentProof.submitted_at = UTC

A2: Validation rule
   exif_capture_date <= submitted_at + 1 hour buffer
   (buffer for timezone confusion, clock skew)

A3: Display always in user's timezone
   • Frontend converts to local
   • Admin interface shows UTC + user timezone
```

### 1.8 Scénario : Admin Mass-Validation (Bulk Action)

```
Timeline:
- 50 pending proofs accumulate
- Admin tries to validate all at once
- Some might fail (hash collision, user banned, etc)
- Partial success

Questions clés:
Q1: Bulk endpoint ou één by één?
Q2: Atomicity?

Recommandations:
A1: MVP = NO bulk operations
   • One-by-one validation only
   • Prevents cascading errors
   • Easier to audit

A2: Future = bulk operations with rollback
   PATCH /admin/bulk-actions
   {
     "action": "VALIDATE",
     "payment_ids": ["id1", "id2", ...],
     "transaction_mode": "ROLLBACK_ON_FIRST_ERROR"
   }
   • Returns: { successful: 45, failed: 5, errors: [...] }
```

### 1.9 Scénario : Subscriber Re-Subscribes Pendant Validation

```
Timeline:
- User has active subscription (expires 2025-08-01)
- User initiates manual payment (à nouveau)
- Question: Double subscription?

Questions clés:
Q1: Permettre multi-subscriptions?
Q2: Overlap handling?

Recommandations:
A1: Business rule clarification needed
   Option A: Block new payment if subscription active
   Option B: Allow overlap, extend expiry
   Option C: Allow, but mark as renewal

A2: Recommended: Option A for MVP
   POST /payments/manual/initiate
   → Check: SELECT subscription WHERE user_id = ? AND status = 'ACTIVE'
   → If found: Return 409 "Subscription already active"

A3: Renewal flow
   • If subscription expires < 30 days → allow new payment
   • Set new payment to extend existing subscription
   • Store: previous_subscription_id for audit
```

### 1.10 Scénario : Proof dans Langue Étrangère

```
Timeline:
- User in Côte d'Ivoire envoie screenshot en Spanish/English
- Admin en français

Question clé:
Q1: Impact on validation?

Recommandations:
A1: Non-blocking pour MVP
   • Admin peut lire interface opérateur étrangère
   • Tant que montant + numéro sont corrects

A2: Future: OCR pour extraction automatique
   • Utiliser Google Cloud Vision OCR
   • Extraire: amount, sender_number, date
   • Peu importe la langue
```

---

## 2️⃣ SÉCURITÉ DÉTAILLÉE

### 2.1 Matrice de Menaces

| Menace | Severity | Likelihood | Mitigation |
|--------|----------|------------|-----------|
| Hash collision | CRITICAL | Very Low | Use SHA-256 (cryptographically strong) |
| Image tampering (post-upload) | HIGH | Low | Daily hash verification cron |
| EXIF spoofing | MEDIUM | Medium | Combination of signals + AI score |
| Unauthorized access | CRITICAL | Low | JWT + RBAC guards |
| Proof reuse | HIGH | Medium | Global hash uniqueness constraint |
| Admin fraud | MEDIUM | Low | Audit logging + escalation process |
| DDoS upload endpoint | MEDIUM | Medium | Rate-limiting Redis + Nginx |
| Timezone confusion | LOW | Medium | Always UTC + display conversion |
| Concurrent validation | LOW | Low | SELECT-FOR-UPDATE or DB trigger |
| Network failure | LOW | High | Multipart upload + cleanup cron |

### 2.2 Data Integrity Rules (Invariants)

```typescript
// Must ALWAYS be true:

1. payment_manual.subscription_id → subscription exists AND subscription.status = PENDING
2. payment_proof.payment_manual_id → payment_manual exists
3. payment_proof.image_hash UNIQUE globally
4. payment_manual.status ∈ {PENDING, PENDING_ADMIN, COMPLETED, REJECTED, EXPIRED}
5. payment_manual.rejected_at != null => payment_manual.status = REJECTED
6. payment_manual.validated_at != null => payment_manual.status = COMPLETED
7. payment_manual.refund_required = true => status ∈ {EXPIRED, REJECTED}
8. payment_manual.upload_attempt_count <= 3
9. image_hash(payment_proof.image) = payment_proof.image_hash_sha256
10. MIN(payment_proof.submitted_at) <= payment_manual.expires_at_admin (for PENDING_ADMIN)

// Enforce via:
- Database constraints (UNIQUE, FK, CHECK)
- Application validation (service layer)
- Integration tests (verify invariants post-op)
```

### 2.3 SQL Injection Prevention

```typescript
// ✅ SAFE: Using TypeORM parameterized queries
const proof = await paymentProofRepository.find({
  where: {
    payment_manual_id: In(paymentIds),
    image_hash: hash,
  },
});

// ❌ UNSAFE: String concatenation
const query = `SELECT * FROM payment_proofs WHERE image_hash = '${hash}'`;

// ✅ SAFE: Explicitly parameterized
const query = 'SELECT * FROM payment_proofs WHERE image_hash = $1';
const result = await connection.query(query, [hash]);
```

### 2.4 Image Upload Security

```typescript
// Validation checklist:

1. File size
   const MAX_SIZE = 5 * 1024 * 1024; // 5 MB
   if (file.size > MAX_SIZE) throw new FileTooLargeError();

2. MIME type + extension
   const ALLOWED = ['image/jpeg', 'image/png', 'image/webp'];
   if (!ALLOWED.includes(file.mimetype)) throw new UnsupportedFileType();
   
   // Check extension matches MIME
   const ext = getExtension(file.mimetype); // 'jpg', 'png', 'webp'
   if (!filename.endsWith(ext)) throw new MalformedFile();

3. Magic bytes (file signature)
   const magic = readBytes(file.buffer, 0, 4);
   if (magic !== JPEG_MAGIC && magic !== PNG_MAGIC && ...) 
     throw new MalformedFile();

4. Image dimensions
   const img = sharp(file.buffer);
   const { width, height } = await img.metadata();
   if (width < 480 || height < 640) throw new ResolutionTooLow();

5. Hash compute
   const hash = crypto.createHash('sha256')
     .update(file.buffer)
     .digest('hex');
   
   // Check uniqueness
   const exists = await paymentProofRepo.findOne({ where: { image_hash: hash } });
   if (exists) throw new DuplicateProofError();

6. Virus scanning (optional, Phase 2)
   // Call ClamAV or Virustotal API
   const scanResult = await virusScanService.scan(file.buffer);
   if (scanResult.infected) throw new VirusDetectedError();
```

### 2.5 Rate Limiting Strategy

```yaml
# Global rate limits (Nginx + ThrottlerModule)

# Per IP
- 100 requests/minute global API
- 10 requests/minute for auth endpoints

# Per User (JWT)
- 20 POST /payments/manual/:id/submit-proof per day
- 5 POST /payments/manual/:id/submit-proof per hour
- 1 POST /payments/manual/:id/submit-proof per 10 seconds

# Implementation:
# Redis key: PAYMENT_UPLOAD:{user_id}:{day}
# Redis key: PAYMENT_UPLOAD_HOUR:{user_id}:{hour}
# Redis key: PAYMENT_UPLOAD_THROTTLE:{user_id}

# If limit exceeded: 429 Too Many Requests
# Response: { retry_after_seconds: 600 }
```

### 2.6 MinIO Access Control

```yaml
# Bucket policy: payment-proofs

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::minio:user/api-backend"
      },
      "Action": [
        "s3:GetObject",      # Admin read signed URLs
        "s3:PutObject",      # Upload from API
        "s3:DeleteObject"    # Admin cleanup (optional)
      ],
      "Resource": "arn:aws:s3:::payment-proofs/*"
    }
  ]
}

# Signed URLs:
- Generated server-side only
- Expire in 1 hour
- Only readable (GET), not writable
- Include signature preventing tampering
```

### 2.7 Audit Logging

```typescript
// MongoDB audit collection

type AuditLog = {
  id: string;
  timestamp: Date;
  actor: {
    id: string;
    role: 'USER' | 'ADMIN';
    ip_address: string;
    user_agent: string;
  };
  action: 'PAYMENT_INITIATED' | 'PROOF_SUBMITTED' | 'PROOF_VALIDATED' | 'PAYMENT_REJECTED' | 'PAYMENT_EXPIRED';
  resource: {
    payment_manual_id: string;
    proof_id?: string;
    subscription_id: string;
  };
  changes: {
    field: string;
    old_value: any;
    new_value: any;
  }[];
  notes: string;
  success: boolean;
  error?: string;
};

// Retention policy:
// Keep for 7 years (regulatory requirement)
// Capped collection (100 GB max)
// Cannot be modified/deleted (immutable audit trail)
```

---

## 3️⃣ FAILURE MODES & RECOVERY

### 3.1 MinIO Bucket Down

```
Scenario: MinIO service crashed, payment-proofs bucket unavailable

Impact:
- Can't upload new proofs
- Can't retrieve images for admin validation
- Existing proofs are safe (data persisted)

Recovery:
1. Docker restart MinIO container
2. MinIO automatically recovers bucket state
3. API endpoints gradually become available
4. Admin dashboard SSE reconnects
5. Users see "Service temporarily unavailable" (graceful degradation)

Prevention:
- MinIO data volume persisted on host
- Health checks in docker-compose
- Monitor MinIO free space (alert if <20%)
```

### 3.2 PostgreSQL Replica Lag

```
Scenario: Multi-region deployment, read replica behind master

Impact:
- Admin queries stale data (might show "PENDING" when actually "COMPLETED")
- Misleading dashboard

Recovery:
1. Force read from master for critical queries
   // In service:
   const payment = await paymentRepo.findOne(
     { where: { id } },
     { synchronize: true } // Force master read
   )

2. Implement read-after-write consistency
   // After updating payment:
   await connection.query('SELECT 1'); // Force sync
   const updated = await paymentRepo.findOne(id);

Prevention:
- Monitor replica lag (CloudWatch/Prometheus)
- Alert if lag > 5 seconds
- Configure replication factor for priority consistency
```

### 3.3 Cron Job (Expiration) Skipped

```
Scenario: App crashed, cron job didn't run for 24 hours

Impact:
- Payments still in PENDING_ADMIN status after 72h expiry
- Users not refunded

Recovery:
1. Implement "catch-up" logic in cron
   // Check how many periods were missed
   const lastRun = await cronLogRepo.findLast();
   const missedPeriods = calculateMissed(lastRun, now);
   
   // Process all missed expirations
   await expireOldPayments();

2. Alert on missed run
   // Store in Redis: LAST_CRON_RUN timestamp
   // Health check: if missing > 1 hour, alert ops

Prevention:
- Redundant cron instances (if multiple API pods)
- Distributed lock (Redis) to prevent parallel runs
- CloudWatch events or external scheduler (ECS scheduled tasks)
```

### 3.4 Admin Real-time Connection Lost

```
Scenario: WebSocket connection between admin and API drops

Impact:
- Admin doesn't see live updates
- Might miss new proofs submitted

Recovery:
1. Automatic reconnection with exponential backoff
   // Frontend:
   socket.on('disconnect', () => {
     setTimeout(() => socket.connect(), 1000); // 1s
     // then 2s, 4s, 8s...
   });

2. Poll fallback
   // If WebSocket fails, switch to polling every 30s
   const fallbackPoll = setInterval(() => {
     await fetchPendingProofs();
   }, 30 * 1000);

3. Unread badge
   // Show "X new proofs" even if connection was down
   // On reconnect, fetch missed updates

Prevention:
- Server-side ping/pong every 30s (keep-alive)
- Client timeout: 60s no heartbeat → reconnect
```

### 3.5 EXIF Parser Crashes

```
Scenario: Malformed image crashes piexifjs

Impact:
- 500 error when uploading
- User can't submit proof

Recovery:
1. Try-catch with graceful degradation
   try {
     const exif = piexifjs.load(file.buffer);
     // process exif
   } catch (e) {
     logger.warn(`EXIF parsing failed: ${e.message}`);
     // Continue without EXIF
     proof.exif_capture_date = null;
     proof.has_exif = false;
   }

2. Flag for review
   // Set suspicion_score higher if EXIF unavailable
   proof.ai_suspicion_score = 0.4; // Medium caution

Prevention:
- Validate image before EXIF parsing
- Use sandbox for EXIF extraction (optional)
- Timeout limit for EXIF parsing (e.g., 5 seconds)
```

---

## 4️⃣ COMPLIANCE & REGULATORY

### 4.1 Data Protection (Côte d'Ivoire & RGPD)

```
Handling of personal data in PaymentManual:

Fields containing PII:
- sender_number → GDPR-regulated in EU context
- exif_device → Potentially identifies device owner
- exif_gps → Location data (if present)

Compliance measures:
1. Consent
   - User consent before image upload (checkbox in UI)
   - Consent stored with payment

2. Data minimization
   - Only extract necessary EXIF fields
   - Delete GPS if present

3. Retention
   - Delete images after 1 year if payment completed
   - Delete images after 90 days if rejected
   - Keep audit logs for 7 years (regulatory)

4. Encryption
   - Images in transit: HTTPS/TLS
   - Images at rest: MinIO encryption enabled
   - Keys managed by infrastructure team

5. Right to deletion
   - User can request deletion of their proofs
   - Admin marks for deletion (soft delete)
   - Cron job purges after 30-day grace period

Implementation:
DELETE /api/v1/payments/manual/:id/proof/:proof_id/request-deletion
→ Set payment_proof.deletion_requested = true
→ Cron after 30 days → hard delete
```

### 4.2 KYC/AML Considerations

```
Note: This system is simplified for MVP and assumes:
- Users are already KYC'd at sign-up
- Payment manual is only for subscription, not high-value transfers

If future expansion to payments > 100k FCFA:
- Implement enhanced KYC checks
- IP geolocation validation
- Device fingerprinting
- Velocity checks (same user multiple payments)

Current scoping:
- payment_manual.amount_fcfa = 5000 (fixed)
- So below AML thresholds for most jurisdictions
```

---

## 5️⃣ MONITORING & ALERTING

### 5.1 Key Metrics to Track

```yaml
# Business metrics
payment_manual_initiated_total{provider}        # By provider (WAVE_MANUAL, ORANGE_MONEY, etc)
payment_manual_completed_total                  # Conversions
payment_manual_rejected_total{reason}           # By rejection reason
payment_manual_expired_total                    # Timeout expirations
payment_manual_refund_required_total            # Refunds owed

# Performance metrics
payment_proof_upload_duration_seconds           # Upload time (p50, p99)
payment_proof_validation_duration_hours         # Admin time to validate
payment_manual_exif_extraction_duration_ms      # EXIF parsing time
fraud_score_calculation_duration_ms             # AI/scoring time

# Error metrics
payment_proof_upload_errors_total{error_type}   # By type (dup, size, format)
exif_parsing_failures_total                     # Fallback cases
minio_access_errors_total                       # Storage failures

# SLA metrics
admin_pending_queue_size                        # Backlog
admin_validation_sla_breaches                   # Missed 72h deadline
fraud_detection_accuracy                        # % of flagged items actually fraud

# Security metrics
duplicate_proof_attempts_total                  # Hash collision attempts
rate_limit_blocks_total{endpoint}               # Throttling
unauthorized_access_attempts                    # JWT failures
```

### 5.2 Alerting Rules

```yaml
alerts:
  - name: PaymentProofsQueueTooLarge
    condition: admin_pending_queue_size > 50
    threshold: 5 minutes
    severity: WARNING
    action: Page on-call admin

  - name: UploadErrorRate
    condition: rate(payment_proof_upload_errors_total[5m]) > 0.1
    severity: WARNING
    action: Create incident, check MinIO

  - name: ExifParsingFailureSpike
    condition: rate(exif_parsing_failures[5m]) > 0.2
    severity: INFO
    action: Log for investigation

  - name: ValidationTimeExceeded
    condition: histogram_quantile(0.95, payment_manual_validation_duration_hours) > 24
    severity: WARNING
    action: Notify ops team

  - name: DuplicateProofAttacks
    condition: rate(duplicate_proof_attempts_total[1h]) > 10
    severity: CRITICAL
    action: Page security team, rate-limit source IPs

  - name: UnauthorizedAccessSpike
    condition: rate(unauthorized_access_attempts[5m]) > 50
    severity: HIGH
    action: Trigger DDoS/brute-force protection
```

---

## 6️⃣ DISASTER RECOVERY PLAN

### 6.1 Backup Strategy

```yaml
# PaymentManual & PaymentProof tables

Backup frequency: Daily at 02:00 UTC
Retention: 90 days
Location: S3 (AWS) or another cloud provider

Procedure:
1. pg_dump payment_manual, payment_proof tables
2. Compress + encrypt
3. Upload to S3 with versioning
4. Test restore monthly

# MinIO payment-proofs bucket

Backup: S3 replication (in real-time)
Sync to secondary MinIO cluster
Retention: Same as images (1 year completed, 90 days rejected)

# MongoDB audit logs

Backup: Mongodump weekly
Compress + upload to S3
Retention: 7 years (regulatory)
```

### 6.2 Recovery Procedures

```
Scenario 1: Single PaymentProof lost

Action:
1. Contact user: "Image deleted, please resubmit"
2. Reset upload_attempt_count
3. Reopen payment: PATCH /admin/payments/:id/reopen
4. User retries upload

Time to recovery: <1 hour

Scenario 2: Entire payment_proofs bucket lost

Action:
1. Restore from S3 backup
2. Run consistency check: hash verification on all images
3. Notify admins of potential data loss window
4. Alert affected users

Time to recovery: 4-6 hours

Scenario 3: PostgreSQL database corrupted

Action:
1. Stop API server
2. Restore from latest backup
3. Identify lost transactions (since last backup)
4. Notify affected users
5. Manually reconcile if needed

Time to recovery: 2-4 hours
Data loss: Up to 24 hours
```

---

## 7️⃣ TESTING STRATEGY

### 7.1 Unit Tests

```typescript
// service: payment-manual.service.spec.ts

describe('PaymentManualService', () => {
  describe('initiatePayment', () => {
    it('should create PaymentManual with correct defaults', async () => {
      // Arrange
      const user = createMockUser();
      
      // Act
      const payment = await service.initiatePayment(user.id, 'WAVE_MANUAL');
      
      // Assert
      expect(payment.status).toBe('PENDING');
      expect(payment.amount_fcfa).toBe(5000);
      expect(payment.expires_at_admin).toBeAfter(now);
      expect(payment.transaction_id).toMatch(/^TX-[A-F0-9]{8}$/);
    });
    
    it('should reject if user already has active subscription', async () => {
      // Arrange
      const activeSubscription = createActiveSubscription();
      
      // Act & Assert
      await expect(service.initiatePayment(activeSubscription.user_id))
        .rejects.toThrow(ConflictException);
    });
  });
  
  describe('submitProof', () => {
    it('should validate image before storing', async () => {
      // Test file size, MIME type, magic bytes
    });
    
    it('should reject duplicate hash', async () => {
      // Create proof 1, compute hash
      // Try to create proof 2 with same image
      // Should throw DuplicateError
    });
    
    it('should extract EXIF gracefully', async () => {
      // Test with valid EXIF
      // Test with missing EXIF (iOS)
      // Test with malformed EXIF (corrupted)
    });
  });
  
  describe('validateProof', () => {
    it('should update status and activate subscription', async () => {
      // Arrange
      const payment = createPendingPayment();
      const admin = createMockAdmin();
      
      // Act
      await service.validateProof(payment.id, admin.id, 'Valid amount');
      
      // Assert
      const updated = await paymentRepo.findOne(payment.id);
      expect(updated.status).toBe('COMPLETED');
      expect(updated.validated_at).toBeDefined();
      
      const subscription = await subscriptionRepo.findOne(payment.subscription_id);
      expect(subscription.status).toBe('ACTIVE');
    });
  });
});
```

### 7.2 Integration Tests

```typescript
// Controller-to-database

describe('PaymentManualController E2E', () => {
  it('should complete full happy path', async () => {
    const user = await createTestUser();
    const admin = await createTestAdmin();
    
    // 1. Initiate
    const initiateRes = await request(app)
      .post('/api/v1/payments/manual/initiate')
      .set('Authorization', `Bearer ${user.token}`)
      .expect(201);
    
    const txId = initiateRes.body.transaction_id;
    
    // 2. Submit proof
    const proofRes = await request(app)
      .post(`/api/v1/payments/manual/${txId}/submit-proof`)
      .set('Authorization', `Bearer ${user.token}`)
      .attach('image', 'test-files/receipt.jpg')
      .field('sender_number', '0701234567')
      .expect(201);
    
    const proofId = proofRes.body.proof_id;
    
    // 3. Admin validate
    const validateRes = await request(app)
      .patch(`/api/v1/admin/payment-proofs/${txId}/validate`)
      .set('Authorization', `Bearer ${admin.token}`)
      .send({ validated_notes: 'Montant correct' })
      .expect(200);
    
    // 4. Verify subscription activated
    const subscription = await subscriptionRepo.findOne(/* ... */);
    expect(subscription.status).toBe('ACTIVE');
  });
  
  it('should handle timeout and mark refund required', async () => {
    // Create payment 73 hours ago
    // Run cron job
    // Verify status = EXPIRED, refund_required = true
  });
});
```

### 7.3 Load Testing

```bash
# artillery.yml
config:
  target: http://localhost:3000
  phases:
    - duration: 60
      arrivalRate: 10    # 10 users/sec
      ramp: 20           # Ramp up over 60s
    - duration: 300
      arrivalRate: 50    # 50 users/sec sustained
    - duration: 60
      arrivalRate: 10    # Ramp down

scenarios:
  - name: Payment Proof Upload
    flow:
      - post:
          url: /api/v1/payments/manual/initiate
          auth: {bearer: token}
          expect: 201
      
      - post:
          url: /api/v1/payments/manual/{{transaction_id}}/submit-proof
          formData:
            image@: test-files/receipt.jpg
            sender_number: 0701234567
          expect: 201
          
  - name: Admin Validation
    flow:
      - patch:
          url: /api/v1/admin/payment-proofs/{{payment_id}}/validate
          auth: {bearer: admin_token}
          json: {validated_notes: Test}
          expect: 200

# Run: artillery run artillery.yml
# Results: Check response times, error rates, throughput
```

---

## 🎯 CONCLUSION — CRITICAL CHECKLISTS

### Pre-Launch Checklist

- [ ] All invariants documented & enforced in DB
- [ ] SQL injection tests passed
- [ ] Rate limiting configured & tested
- [ ] Audit logging implemented
- [ ] Backup/recovery tested
- [ ] Disaster recovery plan reviewed
- [ ] Security review completed (pen test)
- [ ] Load testing passed (50 req/sec)
- [ ] Monitoring alerts configured
- [ ] GDPR/Compliance review done
- [ ] Admin double-validation workflow defined
- [ ] User documentation completed
- [ ] Support runbook created

### Post-Launch Monitoring (First 30 Days)

- [ ] Daily check: fraud detection accuracy
- [ ] Daily check: validation queue size
- [ ] Weekly: Audit log consistency
- [ ] Weekly: MinIO bucket health
- [ ] Weekly: Admin feedback on UX
- [ ] Incident response: Log all issues
- [ ] Metrics: Track all KPIs baseline

