import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, LessThan, Repository } from 'typeorm';
import { randomBytes, createHash, randomUUID } from 'node:crypto';
import { PaymentManual, PaymentManualStatus, PaymentProviderManual } from '../entities/payment-manual.entity';
import { PaymentProof } from '../entities/payment-proof.entity';
import { Subscription, SubscriptionStatus } from '../../subscription/entities/subscription.entity';
import { ArtisanProfile } from '../../users/entities/artisan-profile.entity';
import { MediaService } from '../../media/media.service';
import { SubscriptionService } from '../../subscription/subscription.service';
import { NotificationsService } from '../../notifications/notifications.service';
import { AnalyticsService } from '../../analytics/analytics.service';
import { ProofValidationService } from './proof-validation.service';
import { ExifExtractorService } from './exif-extractor.service';
import { FraudDetectionService } from './fraud-detection.service';
import { PaymentRealtimeService } from '../events/payment-realtime.service';
import { BusinessException } from '../../../common/exceptions/business.exception';

interface AdminListFilters {
  status?: PaymentManualStatus | 'REFUND_REQUIRED';
  page?: number;
  limit?: number;
  sort?: 'asc' | 'desc' | string;
}

@Injectable()
export class PaymentManualService {
  private readonly logger = new Logger(PaymentManualService.name);
  private readonly amountFcfa: number;
  private readonly expiryHours: number;
  private readonly bucket: string;
  private readonly recipientNumber: string;

  constructor(
    @InjectRepository(PaymentManual)
    private readonly paymentManualRepository: Repository<PaymentManual>,
    @InjectRepository(PaymentProof)
    private readonly paymentProofRepository: Repository<PaymentProof>,
    @InjectRepository(Subscription)
    private readonly subscriptionRepository: Repository<Subscription>,
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    private readonly mediaService: MediaService,
    private readonly subscriptionService: SubscriptionService,
    private readonly notificationsService: NotificationsService,
    private readonly analyticsService: AnalyticsService,
    private readonly proofValidationService: ProofValidationService,
    private readonly exifExtractorService: ExifExtractorService,
    private readonly fraudDetectionService: FraudDetectionService,
    private readonly paymentRealtimeService: PaymentRealtimeService,
    private readonly configService: ConfigService,
  ) {
    this.amountFcfa = Number(this.configService.get('PAYMENT_MANUAL_AMOUNT_FCFA') || 5000);
    this.expiryHours = Number(this.configService.get('PAYMENT_MANUAL_EXPIRY_HOURS') || 72);
    this.bucket =
      this.configService.get<string>('minio.buckets.paymentProofs') ||
      this.configService.get<string>('MINIO_PAYMENT_PROOF_BUCKET') ||
      'payment-proofs';
    this.recipientNumber =
      this.configService.get<string>('PAYMENT_MANUAL_RECIPIENT_NUMBER') ||
      this.configService.get<string>('WAVE_MERCHANT_ID') ||
      'N/A';
  }

  async initiatePayment(userId: string, provider: PaymentProviderManual): Promise<PaymentManual> {
    const artisanProfile = await this.artisanProfileRepository.findOne({
      where: { user_id: userId },
      select: ['id', 'user_id', 'is_subscription_active'],
    });

    if (!artisanProfile) {
      throw new BusinessException(
        'PAYMENT_MANUAL_ARTISAN_REQUIRED',
        'Seuls les artisans peuvent initier un paiement manuel.',
      );
    }

    if (artisanProfile.is_subscription_active) {
      throw new BusinessException(
        'PAYMENT_MANUAL_ALREADY_ACTIVE',
        'Votre abonnement est deja actif.',
      );
    }

    let subscription = await this.subscriptionRepository.findOne({
      where: { artisan_profile_id: artisanProfile.id },
      select: ['id', 'status', 'artisan_profile_id', 'amount_fcfa'],
    });

    if (subscription?.status === SubscriptionStatus.ACTIVE) {
      throw new BusinessException(
        'PAYMENT_MANUAL_ALREADY_ACTIVE',
        'Votre abonnement est deja actif.',
      );
    }

    if (!subscription) {
      subscription = await this.subscriptionRepository.save(
        this.subscriptionRepository.create({
          artisan_profile_id: artisanProfile.id,
          amount_fcfa: this.amountFcfa,
          status: SubscriptionStatus.PENDING,
        }),
      );
    }

    const openPayment = await this.paymentManualRepository.findOne({
      where: {
        subscription_id: subscription.id,
        status: In([
          PaymentManualStatus.PENDING,
          PaymentManualStatus.PENDING_ADMIN,
          PaymentManualStatus.REJECTED,
        ]),
        deleted_at: IsNull(),
      },
      order: { created_at: 'DESC' },
      relations: ['proofs'],
    });

    if (openPayment) {
      if (openPayment.status === PaymentManualStatus.REJECTED) {
        const attempts = openPayment.proofs?.length || 0;
        if (attempts < 3) {
          return openPayment;
        }
      }

      if (
        openPayment.status === PaymentManualStatus.PENDING ||
        openPayment.status === PaymentManualStatus.PENDING_ADMIN
      ) {
        return openPayment;
      }

      throw new ConflictException('Aucune tentative supplementaire autorisee pour ce paiement.');
    }

    const now = new Date();
    const expiresAtAdmin = new Date(now.getTime() + this.expiryHours * 60 * 60 * 1000);

    const payment = await this.paymentManualRepository.save(
      this.paymentManualRepository.create({
        subscription_id: subscription.id,
        transaction_id: this.generateTransactionId(),
        amount_fcfa: subscription.amount_fcfa || this.amountFcfa,
        provider,
        status: PaymentManualStatus.PENDING,
        expires_at_admin: expiresAtAdmin,
        timeline: [
          this.timelineEvent('PAYMENT_MANUAL_INITIATED', {
            byUserId: userId,
            provider,
            amountFcfa: subscription.amount_fcfa || this.amountFcfa,
          }),
        ],
      }),
    );

    this.analyticsService.logActivity({
      actorId: userId,
      action: 'PAYMENT_MANUAL_INITIATED',
      targetId: payment.id,
      metadata: {
        transactionId: payment.transaction_id,
        provider,
      },
    }).catch(() => {});

    return payment;
  }

  async submitProof(params: {
    transactionId: string;
    userId: string;
    file: Express.Multer.File;
    senderNumber: string;
    declaredTime?: Date;
  }): Promise<PaymentProof> {
    const payment = await this.findOwnedPaymentByTransactionId(params.userId, params.transactionId);

    if (![PaymentManualStatus.PENDING, PaymentManualStatus.REJECTED].includes(payment.status)) {
      throw new BusinessException(
        'PAYMENT_MANUAL_INVALID_STATUS',
        'La transaction ne peut pas recevoir de nouvelle preuve.',
      );
    }

    const attempts = await this.paymentProofRepository.count({
      where: { payment_manual_id: payment.id, deleted_at: IsNull() },
    });

    if (attempts >= 3) {
      throw new BusinessException(
        'PAYMENT_MANUAL_MAX_ATTEMPTS',
        'Limite de 3 tentatives atteinte pour cette transaction.',
      );
    }

    const validation = await this.proofValidationService.validateImage(params.file);
    const imageHash = createHash('sha256').update(params.file.buffer).digest('hex');

    const existingHash = await this.paymentProofRepository.findOne({
      where: { image_hash_sha256: imageHash },
      select: ['id'],
    });
    if (existingHash) {
      throw new ConflictException('Cette preuve a deja ete soumise.');
    }

    const exif = await this.exifExtractorService.extract(params.file.buffer);
    const suspiciousSoftware = this.exifExtractorService.detectSuspiciousSoftware(exif);
    const aiScore = this.fraudDetectionService.scoreImage(imageHash, exif, {
      width: validation.width,
      height: validation.height,
      bytesPerPixel: validation.bytesPerPixel,
      suspiciousCompression: validation.suspiciousCompression,
    });

    const uploaded = await this.mediaService.uploadRaw(
      params.userId,
      this.bucket,
      params.file,
      `payment-proof-${payment.transaction_id}-${randomUUID()}.bin`,
    );

    const proof = this.paymentProofRepository.create({
      payment_manual_id: payment.id,
      image_url: `${uploaded.bucket}/${uploaded.objectKey}`,
      image_hash_sha256: imageHash,
      declared_payment_time: params.declaredTime ?? null,
      upload_attempt_number: attempts + 1,
      file_type: validation.mimeType,
      file_size_kb: Math.max(1, Math.round(validation.sizeBytes / 1024)),
      file_resolution: `${validation.width}x${validation.height}`,
      has_exif: exif.hasExif,
      exif_capture_date: exif.captureDate,
      exif_modified_date: exif.modifiedDate,
      exif_device: exif.device,
      exif_software: exif.software,
      ai_suspicion_score: aiScore,
      is_suspected_fraud: suspiciousSoftware || validation.suspiciousCompression || aiScore >= 0.7,
    });

    let savedProof: PaymentProof;
    try {
      savedProof = await this.paymentProofRepository.save(proof);
    } catch (error) {
      const isUniqueViolation =
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as { code?: string }).code === '23505';
      if (isUniqueViolation) {
        throw new ConflictException('Cette preuve a deja ete soumise.');
      }
      throw error;
    }

    payment.status = PaymentManualStatus.PENDING_ADMIN;
    payment.sender_number = params.senderNumber;
    payment.rejected_at = null;
    payment.rejection_reason = null;
    payment.timeline = [
      ...(payment.timeline || []),
      this.timelineEvent('PROOF_SUBMITTED', {
        byUserId: params.userId,
        proofId: savedProof.id,
        attempt: attempts + 1,
      }),
    ];
    await this.paymentManualRepository.save(payment);

    this.analyticsService.logActivity({
      actorId: params.userId,
      action: 'PROOF_SUBMITTED',
      targetId: payment.id,
      metadata: {
        transactionId: payment.transaction_id,
        proofId: savedProof.id,
      },
    }).catch(() => {});

    await this.paymentRealtimeService.emitNewProof({
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      submittedAt: savedProof.submitted_at?.toISOString?.() || new Date().toISOString(),
      provider: payment.provider,
      amountFcfa: payment.amount_fcfa,
      suspectedFraud: savedProof.is_suspected_fraud,
    });

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: params.userId,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      updatedAt: new Date().toISOString(),
    });

    return savedProof;
  }

  async validateProof(paymentId: string, adminId: string, notes?: string): Promise<void> {
    const payment = await this.paymentManualRepository.findOne({
      where: { id: paymentId, deleted_at: IsNull() },
      relations: ['subscription', 'subscription.artisan_profile'],
    });

    if (!payment) {
      throw new NotFoundException('Paiement manuel introuvable.');
    }

    if (payment.status !== PaymentManualStatus.PENDING_ADMIN) {
      throw new BadRequestException('Le paiement doit etre en attente admin.');
    }

    await this.subscriptionService.activateSubscriptionFromManualPayment(
      payment.subscription_id,
      adminId,
      payment.id,
    );

    payment.status = PaymentManualStatus.COMPLETED;
    payment.validated_at = new Date();
    payment.refund_required = false;
    payment.timeline = [
      ...(payment.timeline || []),
      this.timelineEvent('PROOF_VALIDATED', {
        byAdminId: adminId,
        notes: notes || null,
      }),
    ];
    await this.paymentManualRepository.save(payment);

    const artisanUserId = payment.subscription?.artisan_profile?.user_id;
    if (artisanUserId) {
      await this.notificationsService.create({
        userId: artisanUserId,
        type: 'PAYMENT_MANUAL_VALIDATED',
        title: 'Paiement valide',
        body: 'Votre paiement manuel a ete valide. Abonnement actif pour 30 jours.',
        data: {
          paymentId: payment.id,
          transactionId: payment.transaction_id,
          status: payment.status,
        },
      });
    }

    this.analyticsService.logActivity({
      actorId: adminId,
      action: 'PROOF_VALIDATED',
      targetId: payment.id,
      metadata: {
        transactionId: payment.transaction_id,
        notes: notes || null,
      },
    }).catch(() => {});

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: artisanUserId,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      updatedAt: new Date().toISOString(),
    });
  }

  async rejectProof(paymentId: string, adminId: string, reason: string): Promise<void> {
    const payment = await this.paymentManualRepository.findOne({
      where: { id: paymentId, deleted_at: IsNull() },
      relations: ['subscription', 'subscription.artisan_profile'],
    });

    if (!payment) {
      throw new NotFoundException('Paiement manuel introuvable.');
    }

    if (payment.status !== PaymentManualStatus.PENDING_ADMIN) {
      throw new BadRequestException('Le paiement doit etre en attente admin.');
    }

    payment.status = PaymentManualStatus.REJECTED;
    payment.rejected_at = new Date();
    payment.rejection_reason = reason;
    payment.timeline = [
      ...(payment.timeline || []),
      this.timelineEvent('PAYMENT_MANUAL_REJECTED', {
        byAdminId: adminId,
        reason,
      }),
    ];
    await this.paymentManualRepository.save(payment);

    const artisanUserId = payment.subscription?.artisan_profile?.user_id;
    if (artisanUserId) {
      await this.notificationsService.create({
        userId: artisanUserId,
        type: 'PAYMENT_MANUAL_REJECTED',
        title: 'Preuve rejetee',
        body: 'Votre preuve de paiement a ete rejetee. Vous pouvez en soumettre une nouvelle.',
        data: {
          paymentId: payment.id,
          transactionId: payment.transaction_id,
          reason,
        },
      });
    }

    this.analyticsService.logActivity({
      actorId: adminId,
      action: 'PAYMENT_MANUAL_REJECTED',
      targetId: payment.id,
      metadata: {
        transactionId: payment.transaction_id,
      },
    }).catch(() => {});

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: artisanUserId,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      updatedAt: new Date().toISOString(),
    });
  }

  async expirePayments(): Promise<number> {
    const now = new Date();

    const stale = await this.paymentManualRepository.find({
      where: {
        status: PaymentManualStatus.PENDING_ADMIN,
        expires_at_admin: LessThan(now),
        deleted_at: IsNull(),
      },
      relations: ['subscription', 'subscription.artisan_profile'],
      take: 200,
    });

    for (const payment of stale) {
      payment.status = PaymentManualStatus.EXPIRED;
      payment.refund_required = true;
      payment.attempted_refund_count = (payment.attempted_refund_count || 0) + 1;
      payment.timeline = [
        ...(payment.timeline || []),
        this.timelineEvent('PAYMENT_MANUAL_EXPIRED', {
          reason: 'PENDING_ADMIN_TIMEOUT',
        }),
      ];
      await this.paymentManualRepository.save(payment);

      const artisanUserId = payment.subscription?.artisan_profile?.user_id;
      if (artisanUserId) {
        await this.notificationsService.create({
          userId: artisanUserId,
          type: 'PAYMENT_MANUAL_EXPIRED',
          title: 'Paiement expire',
          body: 'Votre preuve n\'a pas ete traitee a temps. Un remboursement est requis.',
          data: {
            paymentId: payment.id,
            transactionId: payment.transaction_id,
            refundRequired: true,
          },
        });
      }

      await this.paymentRealtimeService.emitPaymentUpdated({
        userId: artisanUserId,
        paymentId: payment.id,
        transactionId: payment.transaction_id,
        status: payment.status,
        refundRequired: true,
        updatedAt: new Date().toISOString(),
      });

      this.analyticsService.logActivity({
        actorId: 'system',
        action: 'PAYMENT_MANUAL_EXPIRED',
        targetId: payment.id,
        metadata: { transactionId: payment.transaction_id },
      }).catch(() => {});
    }

    return stale.length;
  }

  async markRefundDone(paymentId: string, adminId: string): Promise<void> {
    const payment = await this.paymentManualRepository.findOne({
      where: { id: paymentId, deleted_at: IsNull() },
      relations: ['subscription', 'subscription.artisan_profile'],
    });

    if (!payment) {
      throw new NotFoundException('Paiement manuel introuvable.');
    }

    if (!payment.refund_required && payment.refund_done_at) {
      return;
    }

    payment.refund_done_at = new Date();
    payment.refund_required = false;
    payment.timeline = [
      ...(payment.timeline || []),
      this.timelineEvent('REFUND_PROCESSED', { byAdminId: adminId }),
    ];
    await this.paymentManualRepository.save(payment);

    const artisanUserId = payment.subscription?.artisan_profile?.user_id;
    if (artisanUserId) {
      await this.notificationsService.create({
        userId: artisanUserId,
        type: 'REFUND_PROCESSED',
        title: 'Remboursement effectue',
        body: 'Le remboursement de votre paiement manuel a ete confirme.',
        data: {
          paymentId: payment.id,
          transactionId: payment.transaction_id,
        },
      });
    }

    this.analyticsService.logActivity({
      actorId: adminId,
      action: 'REFUND_PROCESSED',
      targetId: payment.id,
      metadata: {
        transactionId: payment.transaction_id,
      },
    }).catch(() => {});

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: artisanUserId,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      refundRequired: false,
      updatedAt: new Date().toISOString(),
    });
  }

  async getAdminList(filters: AdminListFilters) {
    const page = Math.max(1, Number(filters.page || 1));
    const limit = Math.min(100, Math.max(1, Number(filters.limit || 20)));
    const sortDirection = (filters.sort || 'desc').toLowerCase() === 'asc' ? 'ASC' : 'DESC';

    const qb = this.paymentManualRepository
      .createQueryBuilder('pm')
      .leftJoinAndSelect('pm.subscription', 's')
      .leftJoinAndSelect('s.artisan_profile', 'artisan')
      .leftJoinAndSelect('artisan.user', 'user')
      .where('pm.deleted_at IS NULL');

    if (filters.status) {
      if (filters.status === 'REFUND_REQUIRED') {
        qb.andWhere('pm.refund_required = true');
      } else {
        qb.andWhere('pm.status = :status', { status: filters.status });
      }
    }

    const [data, total] = await qb
      .orderBy('pm.created_at', sortDirection as 'ASC' | 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    return {
      data,
      total,
      page,
      limit,
    };
  }

  async getDetailed(paymentId: string): Promise<PaymentManual> {
    const payment = await this.paymentManualRepository.findOne({
      where: { id: paymentId, deleted_at: IsNull() },
      relations: ['proofs', 'subscription', 'subscription.artisan_profile', 'subscription.artisan_profile.user'],
      order: { proofs: { submitted_at: 'DESC' } },
    });

    if (!payment) {
      throw new NotFoundException('Paiement manuel introuvable.');
    }

    return payment;
  }

  async getStatus(transactionId: string, userId: string): Promise<PaymentManual> {
    return this.findOwnedPaymentByTransactionId(userId, transactionId, true);
  }

  async getProofSignedUrl(
    transactionId: string,
    proofId: string,
    userId: string,
  ): Promise<{ url: string; expiresInSeconds: number }> {
    const payment = await this.findOwnedPaymentByTransactionId(userId, transactionId);

    const proof = await this.paymentProofRepository.findOne({
      where: {
        id: proofId,
        payment_manual_id: payment.id,
        deleted_at: IsNull(),
      },
      select: ['id', 'image_url'],
    });

    if (!proof) {
      throw new NotFoundException('Preuve introuvable.');
    }

    const parsed = this.parseImageRef(proof.image_url);
    const url = await this.mediaService.getSignedUrl(parsed.bucket, parsed.objectKey);

    return { url, expiresInSeconds: 3600 };
  }

  async verifyProofHashesIntegrity(): Promise<{ checked: number; mismatches: number }> {
    const proofs = await this.paymentProofRepository.find({
      where: { deleted_at: IsNull() },
      select: ['id', 'image_url', 'image_hash_sha256'],
      take: 1000,
    });

    let mismatches = 0;

    for (const proof of proofs) {
      try {
        const parsed = this.parseImageRef(proof.image_url);
        const { stream } = await this.mediaService.streamFile(parsed.bucket, parsed.objectKey);
        const buffer = await this.streamToBuffer(stream);
        const currentHash = createHash('sha256').update(buffer).digest('hex');

        if (currentHash !== proof.image_hash_sha256) {
          mismatches += 1;
          this.logger.error(`Hash mismatch for payment proof ${proof.id}`);
        }
      } catch (error) {
        mismatches += 1;
        this.logger.error(`Hash verification failed for proof ${proof.id}: ${error}`);
      }
    }

    return {
      checked: proofs.length,
      mismatches,
    };
  }

  private async findOwnedPaymentByTransactionId(
    userId: string,
    transactionId: string,
    includeProofs = false,
  ): Promise<PaymentManual> {
    const payment = await this.paymentManualRepository.findOne({
      where: {
        transaction_id: transactionId,
        deleted_at: IsNull(),
      },
      relations: includeProofs
        ? ['proofs', 'subscription', 'subscription.artisan_profile']
        : ['subscription', 'subscription.artisan_profile'],
      order: includeProofs ? { proofs: { submitted_at: 'DESC' } } : undefined,
    });

    if (!payment) {
      throw new NotFoundException('Transaction manuelle introuvable.');
    }

    const ownerUserId = payment.subscription?.artisan_profile?.user_id;
    if (!ownerUserId || ownerUserId !== userId) {
      throw new BusinessException(
        'PAYMENT_MANUAL_FORBIDDEN',
        'Vous n\'etes pas autorise a acceder a cette transaction.',
      );
    }

    return payment;
  }

  private generateTransactionId(): string {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const bytes = randomBytes(8);
    let value = '';
    for (let i = 0; i < bytes.length; i += 1) {
      value += alphabet[bytes[i] % alphabet.length];
    }
    return `TX-${value}`;
  }

  private timelineEvent(type: string, details?: Record<string, unknown>) {
    return {
      type,
      at: new Date().toISOString(),
      ...(details ? { details } : {}),
    };
  }

  private parseImageRef(imageUrl: string): { bucket: string; objectKey: string } {
    const normalized = (imageUrl || '').trim().replace(/^\/+/, '');
    const [bucket, ...rest] = normalized.split('/');

    if (!bucket || rest.length === 0) {
      throw new Error(`Invalid image ref: ${imageUrl}`);
    }

    return {
      bucket,
      objectKey: rest.join('/'),
    };
  }

  private async streamToBuffer(stream: NodeJS.ReadableStream): Promise<Buffer> {
    return new Promise<Buffer>((resolve, reject) => {
      const chunks: Buffer[] = [];
      stream.on('data', (chunk) => {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      });
      stream.on('error', reject);
      stream.on('end', () => resolve(Buffer.concat(chunks)));
    });
  }
}
