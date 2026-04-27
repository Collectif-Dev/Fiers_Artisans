# 🔧 AUDIT INTÉGRATION — Infrastructure & Dépendances Cross-Systems

**Documents complémentaires:**  
- AUDIT_PAYMENT_SYSTEM.md (Architecture générale)  
- AUDIT_PAYMENT_SYSTEM_EDGE_CASES.md (Scénarios edge + Sécurité détaillée)

---

## 1️⃣ INTÉGRATION AVEC LES SERVICES EXISTANTS

### 1.1 PostgreSQL — Schemas & Migrations

#### **Tables à Ajouter**

```sql
-- ═══════════════════════════════════════════════════════
-- Nouveau domain pour Côte d'Ivoire seulement
-- ═══════════════════════════════════════════════════════

CREATE TYPE payment_provider_manual AS ENUM (
  'WAVE_MANUAL',
  'ORANGE_MONEY',
  'MTN_MONEY',
  'MOOV_MONEY'
);

CREATE TYPE payment_manual_status AS ENUM (
  'PENDING',           -- Juste créé
  'PENDING_ADMIN',     -- Preuve soumise, en attente validation
  'COMPLETED',         -- Validé par admin
  'REJECTED',          -- Rejeté par admin
  'EXPIRED'            -- Timeout 72h
);

-- ═══════════════════════════════════════════════════════
-- Main table for manual payments
-- ═══════════════════════════════════════════════════════

CREATE TABLE payment_manual (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Foreign keys
  subscription_id UUID NOT NULL,
  CONSTRAINT fk_payment_manual_subscription
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  -- Core data
  transaction_id VARCHAR(50) NOT NULL UNIQUE,
  amount_fcfa INT NOT NULL DEFAULT 5000,
  provider payment_provider_manual NOT NULL DEFAULT 'WAVE_MANUAL',
  status payment_manual_status NOT NULL DEFAULT 'PENDING',
  
  -- Sender info
  sender_number VARCHAR(20) NOT NULL,
  
  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at_admin TIMESTAMP NOT NULL,
  validated_at TIMESTAMP,
  rejected_at TIMESTAMP,
  
  -- Metadata
  rejection_reason TEXT,
  refund_required BOOLEAN DEFAULT FALSE,
  refund_done_at TIMESTAMP,
  attempted_refund_count INT DEFAULT 0,
  
  -- Soft delete (optional, for audit trail)
  deleted_at TIMESTAMP,
  
  -- Indexes
  CONSTRAINT check_status_rejection_consistency
    CHECK (
      (status = 'REJECTED' AND rejected_at IS NOT NULL AND rejection_reason IS NOT NULL) OR
      (status != 'REJECTED') 
    ),
  CONSTRAINT check_status_validation_consistency
    CHECK (
      (status = 'COMPLETED' AND validated_at IS NOT NULL) OR
      (status != 'COMPLETED')
    ),
  CONSTRAINT check_refund_consistency
    CHECK (
      (refund_required AND status IN ('EXPIRED', 'REJECTED')) OR
      (NOT refund_required)
    )
);

-- Index queries admin frequently uses
CREATE INDEX idx_payment_manual_status_expires 
  ON payment_manual(status, expires_at_admin);
CREATE INDEX idx_payment_manual_subscription_status_created 
  ON payment_manual(subscription_id, status, created_at);
CREATE INDEX idx_payment_manual_transaction_id 
  ON payment_manual(transaction_id);
CREATE INDEX idx_payment_manual_refund_required 
  ON payment_manual(refund_required) WHERE refund_required = TRUE;

-- ═══════════════════════════════════════════════════════
-- Proof of payment table
-- ═══════════════════════════════════════════════════════

CREATE TABLE payment_proof (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Foreign key
  payment_manual_id UUID NOT NULL,
  CONSTRAINT fk_payment_proof_payment_manual
    FOREIGN KEY (payment_manual_id) REFERENCES payment_manual(id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  -- MinIO / File data
  image_url VARCHAR(500) NOT NULL,
  image_hash_sha256 VARCHAR(64) NOT NULL UNIQUE,  -- Deduplication
  
  -- Submission info
  submitted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  declared_payment_time TIMESTAMP,
  upload_attempt_number INT NOT NULL DEFAULT 1,
  
  -- Image metadata
  file_type VARCHAR(10) NOT NULL,  -- 'jpg', 'png', 'webp'
  file_size_kb INT NOT NULL,
  file_resolution VARCHAR(20),     -- '1080x1920'
  
  -- EXIF data
  has_exif BOOLEAN DEFAULT FALSE,
  exif_capture_date TIMESTAMP,
  exif_modified_date TIMESTAMP,
  exif_device VARCHAR(100),
  exif_software VARCHAR(100),      -- Photoshop, Canva, etc
  
  -- Fraud detection
  ai_suspicion_score FLOAT,        -- 0.0 to 1.0
  is_suspected_fraud BOOLEAN DEFAULT FALSE,
  
  -- Admin
  deletion_requested BOOLEAN DEFAULT FALSE,
  deleted_at TIMESTAMP,
  
  -- Indexes
  CONSTRAINT check_upload_attempt 
    CHECK (upload_attempt_number >= 1 AND upload_attempt_number <= 3),
  CONSTRAINT check_suspicion_score 
    CHECK (ai_suspicion_score IS NULL OR (ai_suspicion_score >= 0.0 AND ai_suspicion_score <= 1.0))
);

CREATE INDEX idx_payment_proof_payment_manual_submitted 
  ON payment_proof(payment_manual_id, submitted_at);
CREATE INDEX idx_payment_proof_image_hash 
  ON payment_proof(image_hash_sha256);
CREATE INDEX idx_payment_proof_suspected 
  ON payment_proof(is_suspected_fraud) WHERE is_suspected_fraud = TRUE;
```

#### **Migration Versioning**

```typescript
// src/database/migrations/1699999999999-CreatePaymentManual.ts

import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePaymentManual1699999999999 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    // SQL DDL from above
    // Split into sections for rollback safety
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.dropTable('payment_proof');
    await queryRunner.dropTable('payment_manual');
    await queryRunner.query('DROP TYPE payment_manual_status');
    await queryRunner.query('DROP TYPE payment_provider_manual');
  }
}
```

#### **TypeORM Entities**

```typescript
// src/modules/payment-manual/entities/payment-manual.entity.ts

import { Entity, Column, ManyToOne, OneToMany, ... } from 'typeorm';

@Entity('payment_manual')
@Index('idx_payment_manual_status_expires', ['status', 'expires_at_admin'])
@Index('idx_payment_manual_subscription_status', ['subscription_id', 'status', 'created_at'])
export class PaymentManual {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => Subscription, (sub) => sub.payment_manuals)
  subscription: Subscription;

  @Column()
  subscription_id: string;

  @Column({ type: 'varchar', length: 50, unique: true })
  transaction_id: string;

  @Column({ type: 'int', default: 5000 })
  amount_fcfa: number;

  @Column({ type: 'enum', enum: PaymentProviderManual, default: 'WAVE_MANUAL' })
  provider: PaymentProviderManual;

  @Column({ type: 'enum', enum: PaymentManualStatus, default: 'PENDING' })
  status: PaymentManualStatus;

  @Column({ type: 'varchar', length: 20 })
  sender_number: string;

  @CreateDateColumn()
  created_at: Date;

  @Column({ type: 'timestamp' })
  expires_at_admin: Date;

  @Column({ type: 'timestamp', nullable: true })
  validated_at: Date;

  @Column({ type: 'timestamp', nullable: true })
  rejected_at: Date;

  @Column({ type: 'text', nullable: true })
  rejection_reason: string;

  @Column({ default: false })
  refund_required: boolean;

  @Column({ type: 'timestamp', nullable: true })
  refund_done_at: Date;

  @Column({ default: 0 })
  attempted_refund_count: number;

  @Column({ type: 'timestamp', nullable: true })
  deleted_at: Date;

  @OneToMany(() => PaymentProof, (proof) => proof.payment_manual)
  proofs: PaymentProof[];
}
```

### 1.2 MongoDB — Collections Optionnelles

#### **Collection: paymentMetadata (Optional)**

```typescript
// src/modules/payment-manual/schemas/payment-metadata.schema.ts

import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document } from 'mongoose';

@Schema({ collection: 'payment_metadata', timestamps: true })
export class PaymentMetadata extends Document {
  @Prop({ required: true, index: true })
  payment_manual_id: string;

  @Prop({ type: Object, default: {} })
  suspicion_signals: {
    signal: string;
    score: number;
  }[];

  @Prop({ type: String, default: 'PENDING' })
  admin_assessment: 'APPROVED' | 'REJECTED' | 'FLAG_FOR_REVIEW';

  @Prop({ type: [Object], default: [] })
  timeline: {
    action: string;
    timestamp: Date;
    details: any;
  }[];

  @Prop({ type: Object, default: {} })
  last_admin_note: {
    admin_id: string;
    notes: string;
    timestamp: Date;
  };

  @Prop({ type: Object, default: {} })
  device_info: {
    device_hash: string;
    location_ip: string;
    user_agent: string;
  };
}

export const PaymentMetadataSchema = SchemaFactory.createForClass(PaymentMetadata);
PaymentMetadataSchema.index({ payment_manual_id: 1 });
```

#### **Collection: paymentAuditLog (TTL + Capped)**

```typescript
// src/modules/payment-manual/schemas/audit-log.schema.ts

@Schema({
  collection: 'payment_audit_logs',
  capped: { size: 104857600 },  // 100 MB
  timestamps: true
})
export class PaymentAuditLog extends Document {
  @Prop({ required: true })
  payment_manual_id: string;

  @Prop({ required: true, enum: ['INITIATED', 'PROOF_SUBMITTED', 'VALIDATED', 'REJECTED', 'EXPIRED', 'REFUND_MARKED'] })
  action: string;

  @Prop({ type: Object })
  actor: {
    id: string;
    role: 'USER' | 'ADMIN' | 'SYSTEM';
    ip_address: string;
  };

  @Prop({ type: Object })
  changes: {
    field: string;
    old_value: any;
    new_value: any;
  }[];

  @Prop()
  notes: string;

  @Prop({ default: true })
  success: boolean;

  @Prop()
  error: string;
}
```

---

## 2️⃣ INTÉGRATION REDIS

### 2.1 Keys pour Rate-Limiting

```typescript
// src/modules/payment-manual/services/rate-limit.service.ts

export class RateLimitService {
  constructor(private redis: RedisClient) {}

  // Check upload attempts per transaction per day
  async checkUploadLimit(txId: string, userId: string): Promise<{ allowed: boolean; remaining: number }> {
    const key = `PAYMENT_UPLOAD:${userId}:${txId}:${this.getTodayKey()}`;
    const max = 3;
    
    const count = await this.redis.incr(key);
    if (count === 1) {
      await this.redis.expire(key, 86400); // 24 hours
    }
    
    return {
      allowed: count <= max,
      remaining: Math.max(0, max - count)
    };
  }

  // Check submission throttle per user
  async checkSubmissionThrottle(userId: string): Promise<{ allowed: boolean; retry_after: number }> {
    const key = `PAYMENT_SUBMIT_THROTTLE:${userId}`;
    const throttle_seconds = 10;
    
    const exists = await this.redis.exists(key);
    if (exists) {
      const ttl = await this.redis.ttl(key);
      return { allowed: false, retry_after: ttl };
    }
    
    await this.redis.setex(key, throttle_seconds, '1');
    return { allowed: true, retry_after: 0 };
  }

  // Global hash tracking (for deduplication)
  async trackImageHash(hash: string, txId: string): Promise<boolean> {
    const key = `PAYMENT_HASH_TRACKING:${hash}`;
    const year_seconds = 365 * 24 * 3600;
    
    const exists = await this.redis.exists(key);
    if (exists) {
      return false; // Already exists
    }
    
    await this.redis.setex(key, year_seconds, txId);
    return true;
  }
}
```

### 2.2 Keys pour Sessions & Cache

```typescript
// Session storage (existing, reuse):
SESSION:{session_id} → expires in 24 hours

// Cache admin payment list (temporary):
ADMIN_PAYMENT_CACHE:{admin_id}:{filter} → expires in 5 minutes

// Rate limit: max failed validations per admin (detect bugs):
ADMIN_VALIDATION_ERRORS:{admin_id}:{day} → alert if > 10
```

---

## 3️⃣ INTÉGRATION MINIO

### 3.1 Bucket Configuration

```yaml
# docker-compose.yml update

minio:
  image: minio/minio:latest
  environment:
    - MINIO_ROOT_USER=${MINIO_ROOT_USER}
    - MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
  volumes:
    - minio_data:/data
    - ./minio/init-buckets.sh:/minio-init-buckets.sh
  entrypoint: >
    sh -c "
    /usr/bin/docker-entrypoint.sh minio server /data &
    sleep 10
    /minio-init-buckets.sh
    wait
    "
```

#### **Init Script: minio/init-buckets.sh**

```bash
#!/bin/sh

# Create payment-proofs bucket
/usr/bin/mc mb minio/payment-proofs --region ci 2>/dev/null || true

# Policy: upload-only (write but not delete/list)
/usr/bin/mc policy set upload-only minio/payment-proofs

# Versioning: keep history
/usr/bin/mc version enable minio/payment-proofs

# Lifecycle: auto-delete old versions after 1 year
/usr/bin/mc ilm import minio/payment-proofs << EOF
{
  "Rules": [
    {
      "ID": "delete-old-versions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 365
      }
    }
  ]
}
EOF

echo "MinIO setup complete"
```

### 3.2 Service Integration

```typescript
// src/modules/payment-manual/services/minio.service.ts

import { Injectable } from '@nestjs/common';
import * as Minio from 'minio';

@Injectable()
export class PaymentMinioService {
  private minioClient: Minio.Client;

  constructor(config: MinioConfig) {
    this.minioClient = new Minio.Client({
      endPoint: config.endpoint,
      port: config.port,
      useSSL: config.useSSL,
      accessKey: config.accessKey,
      secretKey: config.secretKey,
    });
  }

  async uploadProof(
    proofId: string,
    fileBuffer: Buffer,
    fileMime: string,
    fileSize: number,
  ): Promise<{ url: string; etag: string }> {
    const objectName = `${proofId}.${this.getExtension(fileMime)}`;

    try {
      const result = await this.minioClient.putObject(
        'payment-proofs',
        objectName,
        fileBuffer,
        fileSize,
        {
          'Content-Type': fileMime,
          'X-Amz-Meta-uploaded-by': 'payment-manual-api',
          'X-Amz-Meta-uploaded-at': new Date().toISOString(),
        },
      );

      // Construct URL
      const url = await this.getSignedUrl(objectName, 'GET', 3600);
      return { url, etag: result.etag };
    } catch (error) {
      this.logger.error(`MinIO upload failed: ${error.message}`);
      throw new StorageException('Upload failed');
    }
  }

  async getSignedUrl(objectName: string, method: string = 'GET', expires: number = 3600): Promise<string> {
    try {
      const url = await this.minioClient.presignedUrl(method, 'payment-proofs', objectName, expires);
      return url;
    } catch (error) {
      this.logger.error(`Signed URL generation failed: ${error.message}`);
      throw new StorageException('URL generation failed');
    }
  }

  async deleteProof(proofId: string): Promise<void> {
    const objectName = `${proofId}.jpg`; // or detect extension
    try {
      await this.minioClient.removeObject('payment-proofs', objectName);
    } catch (error) {
      this.logger.warn(`Failed to delete MinIO object: ${error.message}`);
      // Don't throw — soft failures acceptable for cleanup
    }
  }

  private getExtension(mime: string): string {
    const map = {
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
    };
    return map[mime] || 'bin';
  }
}
```

---

## 4️⃣ INTÉGRATION NOTIFICATIONS

### 4.1 FCM Templates

```typescript
// src/modules/notifications/templates/payment-manual.templates.ts

export const paymentManualTemplates = {
  PROOF_SUBMITTED: {
    title: 'Preuve reçue',
    body: 'Votre preuve a été reçue. Admin validera dans 48-72h.',
    data: {
      action: 'PAYMENT_STATUS',
      payment_id: '{{transaction_id}}',
    },
  },

  PAYMENT_APPROVED: {
    title: '✅ Paiement validé',
    body: 'Votre abonnement est maintenant actif. Merci!',
    data: {
      action: 'SUBSCRIPTION_ACTIVATED',
      subscription_id: '{{subscription_id}}',
    },
  },

  PAYMENT_REJECTED: {
    title: '❌ Paiement rejeté',
    body: 'Raison: {{rejection_reason}}. Vous pouvez réessayer.',
    data: {
      action: 'PAYMENT_REJECTED',
      payment_id: '{{transaction_id}}',
    },
  },

  PAYMENT_EXPIRED: {
    title: '⏰ Délai dépassé',
    body: 'Votre demande a expiré. Un remboursement est en cours.',
    data: {
      action: 'PAYMENT_EXPIRED',
      payment_id: '{{transaction_id}}',
    },
  },

  ADMIN_NEW_PROOF: {
    title: 'Nouvelle preuve à valider',
    body: 'TX-{{short_id}} · {{amount}} FCFA · {{provider}}',
    data: {
      action: 'ADMIN_NEW_PROOF',
      payment_id: '{{transaction_id}}',
    },
  },
};
```

### 4.2 Sending Service

```typescript
// src/modules/notifications/services/fcm-payment.service.ts

@Injectable()
export class FcmPaymentService {
  constructor(
    private fcmProvider: FcmProvider,
    private notificationsService: NotificationsService,
  ) {}

  async notifyProofSubmitted(paymentManual: PaymentManual, user: User): Promise<void> {
    const template = paymentManualTemplates.PROOF_SUBMITTED;
    const message = {
      notification: {
        title: template.title,
        body: template.body,
      },
      data: {
        ...template.data,
        transaction_id: paymentManual.transaction_id,
      },
      token: user.fcm_token,
    };

    try {
      await this.fcmProvider.send(message);
      await this.notificationsService.log({
        user_id: user.id,
        type: 'PAYMENT_PROOF_SUBMITTED',
        title: template.title,
        body: template.body,
      });
    } catch (error) {
      this.logger.warn(`FCM send failed: ${error.message}`);
      // Don't throw — notification is best-effort
    }
  }

  async notifyPaymentApproved(paymentManual: PaymentManual, user: User): Promise<void> {
    // Similar pattern
  }

  async notifyAdminNewProof(paymentManual: PaymentManual, admins: User[]): Promise<void> {
    // Notify all admin users with FCM token
    for (const admin of admins) {
      if (admin.fcm_token) {
        const message = {
          notification: {
            title: 'Nouvelle preuve à valider',
            body: `TX-${paymentManual.transaction_id.slice(-8)} · ${paymentManual.amount_fcfa} FCFA`,
          },
          data: {
            action: 'ADMIN_NEW_PROOF',
            payment_id: paymentManual.id,
          },
          token: admin.fcm_token,
        };
        await this.fcmProvider.send(message);
      }
    }
  }
}
```

---

## 5️⃣ INTÉGRATION ADMIN REALTIME

### 5.1 WebSocket Events

```typescript
// src/modules/payment-manual/events/payment-manual.events.ts

// Emitted when payment proof validated
export const PAYMENT_VALIDATED = 'payment.validated';

// Emitted when new proof submitted (for admin dashboard)
export const PROOF_SUBMITTED = 'proof.submitted';

// Emitted when proof rejected
export const PAYMENT_REJECTED = 'payment.rejected';

// Emitted when payment expired
export const PAYMENT_EXPIRED = 'payment.expired';
```

### 5.2 Admin Realtime Service Integration

```typescript
// src/modules/payment-manual/services/payment-realtime.service.ts

@Injectable()
export class PaymentRealtimeService {
  constructor(
    private adminRealtime: AdminRealtimeService,
    private logger: Logger,
  ) {}

  async broadcastProofSubmitted(paymentManual: PaymentManual): Promise<void> {
    this.adminRealtime.broadcast('payment:proof_submitted', {
      transaction_id: paymentManual.transaction_id,
      amount: paymentManual.amount_fcfa,
      provider: paymentManual.provider,
      submitted_at: new Date(),
    });
  }

  async broadcastValidation(paymentManual: PaymentManual, adminId: string): Promise<void> {
    this.adminRealtime.broadcast('payment:validated', {
      transaction_id: paymentManual.transaction_id,
      validated_by: adminId,
      timestamp: new Date(),
    });
  }

  async broadcastRejection(paymentManual: PaymentManual, reason: string): Promise<void> {
    this.adminRealtime.broadcast('payment:rejected', {
      transaction_id: paymentManual.transaction_id,
      reason,
      timestamp: new Date(),
    });
  }
}
```

### 5.3 Admin Web Dashboard Integration

```typescript
// admin-web/src/hooks/use-payment-realtime.ts

export function usePaymentRealtime() {
  const [events, setEvents] = useState<PaymentEvent[]>([]);

  useEffect(() => {
    const ws = new WebSocket(`wss://${API_URL}/admin/realtime`);

    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      
      if (message.type === 'payment:proof_submitted') {
        setEvents(prev => [message.payload, ...prev]);
        // Refetch pending list
        refetchPendingProofs();
      }
    };

    return () => ws.close();
  }, []);

  return { events };
}
```

---

## 6️⃣ INTÉGRATION SUBSCRIPTION MODULE

### 6.1 Modifications Subscription Entity

```typescript
// src/modules/subscription/entities/subscription.entity.ts

@Entity('subscriptions')
export class Subscription {
  // ... existing fields ...

  @OneToMany(() => PaymentManual, (pm) => pm.subscription)
  payment_manuals: PaymentManual[];  // NEW

  // Status transitions:
  // PENDING → ACTIVE (when Payment.status = SUCCESS OR PaymentManual.status = COMPLETED)
  // ACTIVE → EXPIRED (when expires_at < now)
}
```

### 6.2 Activation Logic

```typescript
// src/modules/subscription/subscription.service.ts

async activateSubscriptionFromManualPayment(paymentManual: PaymentManual): Promise<Subscription> {
  const subscription = await this.subscriptionRepository.findOne({
    where: { id: paymentManual.subscription_id },
  });

  if (!subscription) {
    throw new NotFoundException('Subscription not found');
  }

  subscription.status = SubscriptionStatus.ACTIVE;
  subscription.starts_at = new Date();
  subscription.expires_at = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

  await this.subscriptionRepository.save(subscription);

  // Trigger analytics event
  await this.analyticsService.trackSubscriptionActivated(subscription);

  return subscription;
}
```

---

## 7️⃣ INTÉGRATION CRON JOBS

### 7.1 Payment Expiration Scheduler

```typescript
// src/modules/payment-manual/jobs/payment-expiration.cron.ts

import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

@Injectable()
export class PaymentExpirationCron {
  private readonly logger = new Logger(PaymentExpirationCron.name);

  constructor(
    private paymentManualService: PaymentManualService,
    private notificationsService: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_HOUR)
  async expireOldPayments(): Promise<void> {
    this.logger.debug('Running payment expiration cron job');

    try {
      const expiredCount = await this.paymentManualService.expireOldPayments();
      
      if (expiredCount > 0) {
        this.logger.log(`Expired ${expiredCount} payments`);
        
        // Notify admins if backlog exists
        const refundBacklog = await this.paymentManualService.getRefundBacklog();
        if (refundBacklog.length > 0) {
          await this.notificationsService.alertAdminsRefundRequired(refundBacklog);
        }
      }
    } catch (error) {
      this.logger.error(`Payment expiration cron failed: ${error.message}`);
      // Alert OPS — this is critical
      await this.notificationsService.alertOpsError('payment-expiration-cron', error);
    }
  }

  // Service implementation
  async expireOldPayments(): Promise<number> {
    const result = await this.paymentManualRepository.update(
      {
        status: PaymentManualStatus.PENDING_ADMIN,
        expires_at_admin: LessThan(new Date()),
      },
      {
        status: PaymentManualStatus.EXPIRED,
        refund_required: true,
      },
    );

    return result.affected || 0;
  }
}
```

### 7.2 Hash Verification Cron

```typescript
// src/modules/payment-manual/jobs/hash-verification.cron.ts

@Injectable()
export class HashVerificationCron {
  @Cron('0 3 * * *') // Daily at 3 AM
  async verifyStoredHashes(): Promise<void> {
    const allProofs = await this.paymentProofRepository.find();

    for (const proof of allProofs) {
      const signedUrl = await this.minioService.getSignedUrl(proof.image_hash_sha256);
      const response = await fetch(signedUrl);
      const buffer = await response.arrayBuffer();

      const currentHash = crypto
        .createHash('sha256')
        .update(buffer)
        .digest('hex');

      if (currentHash !== proof.image_hash_sha256) {
        // Alert security team
        await this.alertSecurityTeam({
          proof_id: proof.id,
          message: 'Image hash mismatch detected',
          severity: 'CRITICAL',
        });
      }
    }
  }
}
```

---

## 8️⃣ INTÉGRATION HEALTH CHECKS

### 8.1 HealthModule Extension

```typescript
// src/modules/health/indicators/payment-minio.indicator.ts

import { Injectable } from '@nestjs/common';
import { HealthIndicator, HealthIndicatorResult } from '@nestjs/terminus';

@Injectable()
export class PaymentMinioIndicator extends HealthIndicator {
  constructor(private paymentMinioService: PaymentMinioService) {
    super();
  }

  async isHealthy(): Promise<HealthIndicatorResult> {
    try {
      // Try to list buckets
      const buckets = await this.paymentMinioService.listBuckets();
      const hasPaymentProofsBucket = buckets.some(b => b.name === 'payment-proofs');

      return this.getStatus('minio-payment-proofs', hasPaymentProofsBucket, {
        bucket_exists: hasPaymentProofsBucket,
      });
    } catch (error) {
      return this.getStatus('minio-payment-proofs', false, {
        error: error.message,
      });
    }
  }
}
```

### 8.2 Register in HealthModule

```typescript
// src/modules/health/health.module.ts

@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
  providers: [
    PaymentMinioIndicator,
    // ... existing indicators ...
  ],
})
export class HealthModule {}
```

---

## 9️⃣ INTÉGRATION ANALYTICS

### 9.1 Events to Track

```typescript
// src/modules/analytics/events/payment-analytics.events.ts

// Events to log in analytics/MongoDB
export const PAYMENT_ANALYTICS_EVENTS = {
  PAYMENT_INITIATED: 'payment_manual:initiated',
  PROOF_SUBMITTED: 'payment_manual:proof_submitted',
  PROOF_VALIDATED: 'payment_manual:proof_validated',
  PAYMENT_REJECTED: 'payment_manual:rejected',
  PAYMENT_EXPIRED: 'payment_manual:expired',
  REFUND_PROCESSED: 'payment_manual:refund_processed',
};
```

### 9.2 Analytics Service Integration

```typescript
// src/modules/analytics/services/payment-analytics.service.ts

@Injectable()
export class PaymentAnalyticsService {
  async trackProofSubmitted(payment: PaymentManual, proof: PaymentProof): Promise<void> {
    await this.analyticsRepository.create({
      event: PAYMENT_ANALYTICS_EVENTS.PROOF_SUBMITTED,
      user_id: payment.subscription.artisan_profile.user_id,
      payment_id: payment.id,
      provider: payment.provider,
      timestamp: new Date(),
      metadata: {
        attempt_number: proof.upload_attempt_number,
        file_size: proof.file_size_kb,
        has_exif: proof.has_exif,
      },
    });
  }

  async getConversionStats(startDate: Date, endDate: Date) {
    const initiated = await this.countEvent('PAYMENT_INITIATED', startDate, endDate);
    const completed = await this.countEvent('PROOF_VALIDATED', startDate, endDate);

    return {
      initiated,
      completed,
      conversion_rate: (completed / initiated) * 100,
      avg_days_to_completion: await this.avgDaysToCompletion(startDate, endDate),
    };
  }
}
```

---

## 🔟 GESTION DES ERREURS CROSS-SYSTEM

### 10.1 Error Handling Matrix

```typescript
// src/modules/payment-manual/filters/payment-manual-exception.filter.ts

@Catch()
export class PaymentManualExceptionFilter implements ExceptionFilter {
  catch(exception: Error, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest();

    let status = 500;
    let message = 'Internal server error';
    let code = 'INTERNAL_ERROR';

    if (exception instanceof ValidationException) {
      status = 400;
      code = 'VALIDATION_ERROR';
    } else if (exception instanceof DuplicateProofError) {
      status = 409;
      code = 'DUPLICATE_PROOF';
      message = 'Cette preuve a déjà été utilisée';
    } else if (exception instanceof RateLimitException) {
      status = 429;
      code = 'RATE_LIMIT_EXCEEDED';
      message = 'Max tentatives atteint';
    } else if (exception instanceof StorageException) {
      status = 503;
      code = 'STORAGE_UNAVAILABLE';
      message = 'Service de stockage indisponible';
    }

    response.status(status).json({
      statusCode: status,
      code,
      message,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}
```

---

## 1️⃣1️⃣ CONFIGURATION ENV

### 11.1 .env.example Update

```bash
# ═══════════════════════════════════════════════════════
# Payment Manual System
# ═══════════════════════════════════════════════════════

# MinIO
MINIO_PAYMENT_PROOF_BUCKET=payment-proofs
MINIO_SIGNED_URL_EXPIRY_SECONDS=3600

# Payment Manual
PAYMENT_MANUAL_AMOUNT_FCFA=5000
PAYMENT_MANUAL_EXPIRY_HOURS=72
PAYMENT_MANUAL_MAX_PROOF_SIZE_MB=5
PAYMENT_MANUAL_MAX_UPLOAD_ATTEMPTS=3

# Rate Limiting
PAYMENT_UPLOAD_RATE_LIMIT_PER_DAY=3
PAYMENT_UPLOAD_RATE_LIMIT_PER_HOUR=1
PAYMENT_UPLOAD_THROTTLE_SECONDS=10

# AI Fraud Detection (optional)
FRAUD_DETECTION_ENABLED=false
FRAUD_DETECTION_API_URL=
FRAUD_DETECTION_API_KEY=
FRAUD_DETECTION_THRESHOLD=0.7

# Notifications
PAYMENT_APPROVED_SMS_TEMPLATE_ID=
PAYMENT_REJECTED_SMS_TEMPLATE_ID=
PAYMENT_EXPIRED_SMS_TEMPLATE_ID=

# Cron
PAYMENT_EXPIRATION_CRON_EXPRESSION=0 * * * *  # hourly
HASH_VERIFICATION_CRON_EXPRESSION=0 3 * * *   # daily 3am

# Admin Realtime
ADMIN_REALTIME_ENABLED=true
ADMIN_REALTIME_PING_INTERVAL_MS=30000
```

---

## 1️⃣2️⃣ VALIDATION & TESTING

### 12.1 Integration Test Setup

```typescript
// test/integration/payment-manual.e2e.spec.ts

describe('Payment Manual E2E', () => {
  let app: INestApplication;
  let paymentRepo: Repository<PaymentManual>;
  let minioService: PaymentMinioService;
  let redisClient: Redis;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    })
      .overrideProvider('MinioService')
      .useValue(createMockMinioService())
      .overrideProvider('RedisClient')
      .useValue(createMockRedisClient())
      .compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('should complete payment flow with manual proof', async () => {
    // Full E2E test
  });
});
```

### 12.2 Docker Compose Validation

```bash
# Verify all services healthy
docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps
# Result: All services = "healthy" or "up"

# Check MinIO bucket
docker exec fiers-minio mc ls minio/payment-proofs

# Check PostgreSQL tables
docker exec fiers-postgres psql -U fiers_artisans -d fiers_artisans -c "\dt payment_*"
```

---

## 📋 FINAL CHECKLIST

**Pre-Implementation:**
- [ ] All SQL migrations reviewed by DBA
- [ ] Environment variables documented
- [ ] MinIO setup script tested
- [ ] Cron job scheduling verified
- [ ] Redis keys documented
- [ ] FCM templates approved

**Implementation:**
- [ ] Database migrations applied
- [ ] TypeORM entities synced
- [ ] MongoDB collections created (optional)
- [ ] MinIO bucket provisioned
- [ ] Cron jobs registered
- [ ] Health checks integrated

**Post-Implementation:**
- [ ] Health check endpoint returns OK
- [ ] Monitoring alerts firing correctly
- [ ] Load testing passed
- [ ] Admin dashboard receiving realtime events
- [ ] Notifications delivering correctly

