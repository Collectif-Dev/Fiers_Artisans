import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
  ConflictException,
  HttpStatus,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, LessThan, Repository } from 'typeorm';
import { randomBytes, createHash, randomUUID } from 'node:crypto';
import Redis from 'ioredis';
import {
  PaymentManual,
  PaymentManualStatus,
  PaymentProviderManual,
} from '../entities/payment-manual.entity';
import { PaymentProof } from '../entities/payment-proof.entity';
import {
  Subscription,
  SubscriptionStatus,
} from '../../subscription/entities/subscription.entity';
import { ArtisanProfile } from '../../users/entities/artisan-profile.entity';
import { User, UserRole } from '../../users/entities/user.entity';
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
  scope?: 'ACTIVE' | 'HISTORY' | 'ALL';
  status?: PaymentManualStatus | 'REFUND_REQUIRED';
  page?: number;
  limit?: number;
  sort?: 'asc' | 'desc' | string;
}

type AutoReplacementReason =
  | 'REJECTED_AFTER_VALIDATION'
  | 'EXPIRED_REFUND_CLEARED';

const MANUAL_PAYMENT_PROOF_ATTEMPTS_PER_CYCLE = 3;
const MANUAL_PAYMENT_COOLDOWN_BASE_HOURS = 5;

const MANUAL_PAYMENT_RECIPIENT_BY_PROVIDER: Record<
  PaymentProviderManual,
  string | null
> = {
  [PaymentProviderManual.ORANGE_MONEY]: '0703063570',
  [PaymentProviderManual.MTN_MOMO]: '0503265984',
  [PaymentProviderManual.WAVE]: '0703063570',
  [PaymentProviderManual.MOOV_MONEY]: null,
};

@Injectable()
export class PaymentManualService implements OnModuleDestroy {
  private readonly logger = new Logger(PaymentManualService.name);
  private readonly amountFcfa: number;
  private readonly expiryHours: number;
  private readonly bucket: string;
  private readonly dailyUploadLimit: number;
  private readonly submitBurstLimit: number;
  private readonly submitBurstTtlSeconds: number;
  private readonly maxExpireBatchLoops: number;
  private readonly disableRedisRateLimit: boolean;
  private rateLimitRedis: Redis | null = null;

  constructor(
    @InjectRepository(PaymentManual)
    private readonly paymentManualRepository: Repository<PaymentManual>,
    @InjectRepository(PaymentProof)
    private readonly paymentProofRepository: Repository<PaymentProof>,
    @InjectRepository(Subscription)
    private readonly subscriptionRepository: Repository<Subscription>,
    @InjectRepository(ArtisanProfile)
    private readonly artisanProfileRepository: Repository<ArtisanProfile>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
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
    this.amountFcfa = Number(
      this.configService.get('PAYMENT_MANUAL_AMOUNT_FCFA') || 5000,
    );
    this.expiryHours = Number(
      this.configService.get('PAYMENT_MANUAL_EXPIRY_HOURS') || 72,
    );
    this.bucket =
      this.configService.get<string>('minio.buckets.paymentProofs') ||
      this.configService.get<string>('MINIO_PAYMENT_PROOF_BUCKET') ||
      'payment-proofs';
    this.dailyUploadLimit = Math.max(
      1,
      Number(
        this.configService.get('PAYMENT_MANUAL_UPLOADS_PER_DAY_LIMIT') || 12,
      ),
    );
    this.submitBurstLimit = Math.max(
      1,
      Number(this.configService.get('PAYMENT_MANUAL_SUBMIT_BURST_LIMIT') || 2),
    );
    this.submitBurstTtlSeconds = Math.max(
      30,
      Number(
        this.configService.get('PAYMENT_MANUAL_SUBMIT_BURST_TTL_SECONDS') || 60,
      ),
    );
    this.maxExpireBatchLoops = Math.max(
      1,
      Number(this.configService.get('PAYMENT_MANUAL_EXPIRE_BATCH_LOOPS') || 30),
    );
    this.disableRedisRateLimit =
      String(
        this.configService.get('PAYMENT_MANUAL_DISABLE_REDIS_RATE_LIMIT') ||
          'false',
      ) === 'true';
  }

  async onModuleDestroy(): Promise<void> {
    if (this.rateLimitRedis) {
      await this.rateLimitRedis.quit().catch(() => null);
      this.rateLimitRedis = null;
    }
  }

  private async resolvePreferredArtisanProfileForUser(
    userId: string,
  ): Promise<ArtisanProfile> {
    const profiles = await this.artisanProfileRepository.find({
      where: { user_id: userId },
      select: [
        'id',
        'user_id',
        'is_subscription_active',
        'created_at',
        'updated_at',
      ],
      order: {
        updated_at: 'DESC',
        created_at: 'DESC',
      },
    });

    if (!profiles.length) {
      throw new BusinessException(
        'PAYMENT_MANUAL_ARTISAN_REQUIRED',
        'Seuls les artisans peuvent initier un paiement manuel.',
      );
    }

    if (profiles.length > 1) {
      this.logger.error(
        `Data integrity violation: multiple artisan profiles for user=${userId} ids=${profiles
          .map((profile) => profile.id)
          .join(',')}`,
      );
    }

    const activeProfile = profiles.find(
      (profile) => profile.is_subscription_active,
    );
    if (activeProfile) {
      return activeProfile;
    }

    const profileIds = profiles.map((profile) => profile.id);
    const [latestSubscription] = await this.subscriptionRepository.find({
      where: { artisan_profile_id: In(profileIds) },
      select: [
        'id',
        'status',
        'artisan_profile_id',
        'amount_fcfa',
        'created_at',
      ],
      order: { created_at: 'DESC' },
      take: 1,
    });

    if (latestSubscription) {
      const subscriptionProfile = profiles.find(
        (profile) => profile.id === latestSubscription.artisan_profile_id,
      );
      if (subscriptionProfile) {
        this.logger.warn(
          `Legacy duplicate artisan profiles resolved for manual payment user=${userId} preferredProfile=${subscriptionProfile.id}`,
        );
        return subscriptionProfile;
      }
    }

    if (profiles.length > 1) {
      this.logger.warn(
        `Legacy duplicate artisan profiles resolved for manual payment user=${userId} preferredProfile=${profiles[0].id}`,
      );
    }

    return profiles[0];
  }

  async initiatePayment(
    userId: string,
    provider: PaymentProviderManual,
  ): Promise<PaymentManual> {
    if (!this.isProviderAvailable(provider)) {
      throw new BusinessException(
        'PAYMENT_MANUAL_PROVIDER_UNAVAILABLE',
        "Le paiement manuel via Moov Money n'est pas encore disponible.",
      );
    }

    const artisanProfile =
      await this.resolvePreferredArtisanProfileForUser(userId);

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

    if (
      artisanProfile.is_subscription_active &&
      subscription?.status === SubscriptionStatus.ACTIVE
    ) {
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

    const latestPayment = await this.paymentManualRepository.findOne({
      where: {
        subscription_id: subscription.id,
        deleted_at: IsNull(),
      },
      order: {
        created_at: 'DESC',
        request_number: 'DESC',
      },
      relations: ['proofs'],
    });

    if (latestPayment && this.hasPendingRefund(latestPayment)) {
      throw new BusinessException(
        'PAYMENT_MANUAL_REFUND_PENDING',
        'Un remboursement est en cours. Vous ne pouvez pas creer une nouvelle demande.',
        HttpStatus.CONFLICT,
      );
    }

    if (
      latestPayment &&
      [PaymentManualStatus.PENDING, PaymentManualStatus.PENDING_ADMIN].includes(
        latestPayment.status,
      )
    ) {
      return latestPayment;
    }

    if (
      latestPayment?.status === PaymentManualStatus.REJECTED &&
      !this.isRejectedAfterValidation(latestPayment)
    ) {
      return latestPayment;
    }

    if (latestPayment && this.isAutoReplacementCandidate(latestPayment)) {
      return this.createReplacementPayment({
        previousPayment: latestPayment,
        subscription,
        userId,
      });
    }

    const payment = await this.createPendingPayment({
      subscription,
      provider,
      userId,
    });

    this.analyticsService
      .logActivity({
        actorId: userId,
        action: 'PAYMENT_MANUAL_INITIATED',
        targetId: payment.id,
        metadata: {
          transactionId: payment.transaction_id,
          provider,
        },
      })
      .catch(() => {});

    return payment;
  }

  async submitProof(params: {
    transactionId: string;
    userId: string;
    file: Express.Multer.File;
    senderNumber: string;
    declaredTime?: Date;
  }): Promise<PaymentProof> {
    const payment = await this.findOwnedPaymentByTransactionId(
      params.userId,
      params.transactionId,
    );

    if (
      ![PaymentManualStatus.PENDING, PaymentManualStatus.REJECTED].includes(
        payment.status,
      )
    ) {
      throw new BusinessException(
        'PAYMENT_MANUAL_INVALID_STATUS',
        'La transaction ne peut pas recevoir de nouvelle preuve.',
      );
    }

    const attempts = await this.paymentProofRepository.count({
      where: { payment_manual_id: payment.id, deleted_at: IsNull() },
    });

    if (
      payment.status === PaymentManualStatus.REJECTED &&
      this.hasActiveCooldown(payment)
    ) {
      const cooldownUntil = payment.cooldown_until!;
      throw new BusinessException(
        'PAYMENT_MANUAL_COOLDOWN_ACTIVE',
        `Nouvelle soumission possible dans ${this.formatRemainingDuration(cooldownUntil)}.`,
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    await this.enforceProofSubmissionRateLimit(params.userId);

    this.logger.log(
      `[SUBMIT] Proof submission allowed for user=${params.userId} transactionId=${params.transactionId}`,
    );

    const uploadAttemptNumber =
      (attempts % MANUAL_PAYMENT_PROOF_ATTEMPTS_PER_CYCLE) + 1;

    const validation = await this.proofValidationService.validateImage(
      params.file,
    );
    const imageHash = createHash('sha256')
      .update(params.file.buffer)
      .digest('hex');

    const existingHash = await this.paymentProofRepository.findOne({
      where: { image_hash_sha256: imageHash },
      select: ['id'],
    });
    if (existingHash) {
      throw new ConflictException('Cette preuve a deja ete soumise.');
    }

    const exif = await this.exifExtractorService.extract(params.file.buffer);
    const suspiciousSoftware =
      this.exifExtractorService.detectSuspiciousSoftware(exif);
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
      upload_attempt_number: uploadAttemptNumber,
      file_type: validation.mimeType,
      file_size_kb: Math.max(1, Math.round(validation.sizeBytes / 1024)),
      file_resolution: `${validation.width}x${validation.height}`,
      has_exif: exif.hasExif,
      exif_capture_date: exif.captureDate,
      exif_modified_date: exif.modifiedDate,
      exif_device: exif.device,
      exif_software: exif.software,
      ai_suspicion_score: aiScore,
      is_suspected_fraud:
        suspiciousSoftware ||
        validation.suspiciousCompression ||
        aiScore >= 0.7,
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
    payment.cooldown_until = null;
    payment.timeline = [
      ...(payment.timeline || []),
      this.timelineEvent('PROOF_SUBMITTED', {
        byUserId: params.userId,
        proofId: savedProof.id,
        attempt: uploadAttemptNumber,
      }),
    ];
    await this.paymentManualRepository.save(payment);

    this.analyticsService
      .logActivity({
        actorId: params.userId,
        action: 'PROOF_SUBMITTED',
        targetId: payment.id,
        metadata: {
          transactionId: payment.transaction_id,
          proofId: savedProof.id,
        },
      })
      .catch(() => {});

    await this.paymentRealtimeService.emitNewProof({
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      submittedAt:
        savedProof.submitted_at?.toISOString?.() || new Date().toISOString(),
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

  async validateProof(
    paymentId: string,
    adminId: string,
    notes?: string,
  ): Promise<void> {
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
      try {
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
      } catch (error) {
        this.logger.warn(
          `Notification non bloquante ignoree pour paymentId=${payment.id} type=PAYMENT_MANUAL_VALIDATED: ${error}`,
        );
      }
    }

    this.analyticsService
      .logActivity({
        actorId: adminId,
        action: 'PROOF_VALIDATED',
        targetId: payment.id,
        metadata: {
          transactionId: payment.transaction_id,
          notes: notes || null,
        },
      })
      .catch(() => {});

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: artisanUserId,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      updatedAt: new Date().toISOString(),
    });
  }

  async rejectProof(
    paymentId: string,
    adminId: string,
    reason: string,
  ): Promise<void> {
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

    const proofCount = await this.paymentProofRepository.count({
      where: { payment_manual_id: payment.id, deleted_at: IsNull() },
    });
    const rejectedAfterValidation = payment.validated_at != null;
    const shouldStartCooldown =
      !rejectedAfterValidation &&
      proofCount > 0 &&
      proofCount % MANUAL_PAYMENT_PROOF_ATTEMPTS_PER_CYCLE === 0;
    const correlationId = randomUUID();

    payment.status = PaymentManualStatus.REJECTED;
    payment.rejected_at = new Date();
    payment.rejection_reason = reason;
    if (shouldStartCooldown) {
      const nextCooldownCycle = Math.max(1, (payment.cooldown_cycle || 0) + 1);
      const cooldownUntil = new Date(
        Date.now() + this.cooldownDurationMs(nextCooldownCycle),
      );
      payment.cooldown_cycle = nextCooldownCycle;
      payment.cooldown_until = cooldownUntil;
    } else {
      if (rejectedAfterValidation) {
        payment.cooldown_cycle = 0;
      }
      payment.cooldown_until = null;
    }
    payment.timeline = [
      ...(payment.timeline || []),
      this.timelineEvent('PAYMENT_MANUAL_REJECTED', {
        byAdminId: adminId,
        reason,
        rejectedAfterValidation,
        cooldownCycle: payment.cooldown_cycle || 0,
        cooldownUntil: payment.cooldown_until?.toISOString?.() || null,
      }),
    ];

    if (
      rejectedAfterValidation &&
      !this.hasPendingRefund(payment) &&
      payment.subscription?.status === SubscriptionStatus.ACTIVE
    ) {
      payment.timeline.push(
        this.timelineEvent('SUBSCRIPTION_DEACTIVATION_REQUESTED', {
          byAdminId: adminId,
          correlationId,
          reason: 'TRANSACTION_REJECTED',
        }),
      );
    }
    await this.paymentManualRepository.save(payment);

    if (
      rejectedAfterValidation &&
      !this.hasPendingRefund(payment) &&
      payment.subscription?.status === SubscriptionStatus.ACTIVE
    ) {
      await this.subscriptionService.deactivateSubscriptionFromManualPayment({
        subscriptionId: payment.subscription_id,
        paymentManualId: payment.id,
        reason: 'TRANSACTION_REJECTED',
        actorId: adminId,
        correlationId,
      });
      await this.paymentRealtimeService.emitTimelineUpdated({
        paymentId: payment.id,
        transactionId: payment.transaction_id,
        correlationId,
        reason: 'TRANSACTION_REJECTED',
      });
    }

    const artisanUserId = payment.subscription?.artisan_profile?.user_id;
    if (artisanUserId) {
      const rejectionType = payment.cooldown_until
        ? 'PAYMENT_MANUAL_COOLDOWN'
        : 'PAYMENT_MANUAL_REJECTED';
      const rejectionTitle = payment.cooldown_until
        ? 'Blocage temporaire actif'
        : 'Preuve rejetee';
      const rejectionBody = payment.cooldown_until
        ? `Blocage temporaire actif. Nouvelle soumission possible dans ${this.formatRemainingDuration(payment.cooldown_until)}.`
        : `Preuve rejetee : ${reason}`;
      await this.notificationsService.create({
        userId: artisanUserId,
        type: rejectionType,
        title: rejectionTitle,
        body: rejectionBody,
        data: {
          paymentId: payment.id,
          transactionId: payment.transaction_id,
          reason,
          cooldownUntil: payment.cooldown_until?.toISOString?.() || null,
          cooldownCycle: payment.cooldown_cycle || 0,
        },
      });
    }

    this.analyticsService
      .logActivity({
        actorId: adminId,
        action: 'PAYMENT_MANUAL_REJECTED',
        targetId: payment.id,
        metadata: {
          transactionId: payment.transaction_id,
        },
      })
      .catch(() => {});

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: artisanUserId,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      rejectionReason: reason,
      updatedAt: new Date().toISOString(),
    });
  }

  async reopenProof(
    paymentId: string,
    adminId: string,
    reason?: string,
  ): Promise<void> {
    const payment = await this.paymentManualRepository.findOne({
      where: { id: paymentId, deleted_at: IsNull() },
      relations: ['subscription', 'subscription.artisan_profile'],
    });

    if (!payment) {
      throw new NotFoundException('Paiement manuel introuvable.');
    }

    if (this.isHistoricalPayment(payment)) {
      throw new BadRequestException(
        'Les paiements historiques remplaces ou expires ne peuvent plus etre rouverts.',
      );
    }

    const canReopenByStatus = [
      PaymentManualStatus.REJECTED,
      PaymentManualStatus.EXPIRED,
      PaymentManualStatus.COMPLETED,
    ].includes(payment.status);

    if (!canReopenByStatus && !payment.refund_done_at) {
      throw new BadRequestException(
        'Seuls les paiements rejetes, expires, valides ou rembourses peuvent etre rouverts.',
      );
    }

    const activeProofs = await this.paymentProofRepository.find({
      where: {
        payment_manual_id: payment.id,
        deleted_at: IsNull(),
      },
    });
    const now = new Date();
    const expiresAtAdmin = new Date(
      now.getTime() + this.expiryHours * 60 * 60 * 1000,
    );
    const hasRetainedProofs = activeProofs.length > 0;

    payment.status = hasRetainedProofs
      ? PaymentManualStatus.PENDING_ADMIN
      : PaymentManualStatus.PENDING;
    payment.rejected_at = null;
    payment.rejection_reason = null;
    payment.refund_required = false;
    payment.refund_done_at = null;
    payment.cooldown_until = null;
    payment.expires_at_admin = expiresAtAdmin;
    payment.timeline = [
      ...(payment.timeline || []),
      this.timelineEvent('PAYMENT_MANUAL_REOPENED', {
        byAdminId: adminId,
        reason: reason || null,
        keptProofsCount: activeProofs.length,
      }),
    ];
    await this.paymentManualRepository.save(payment);

    const artisanUserId = payment.subscription?.artisan_profile?.user_id;
    if (artisanUserId) {
      await this.notificationsService.create({
        userId: artisanUserId,
        type: 'PAYMENT_MANUAL_REOPENED',
        title: hasRetainedProofs
          ? 'Paiement manuel rouvert'
          : 'Preuve a soumettre de nouveau',
        body: hasRetainedProofs
          ? 'Votre paiement manuel a ete rouvert. La preuve deja soumise est de nouveau en cours de verification.'
          : 'Votre paiement manuel a ete rouvert. Vous pouvez soumettre une nouvelle preuve.',
        data: {
          paymentId: payment.id,
          transactionId: payment.transaction_id,
        },
      });
    }

    this.analyticsService
      .logActivity({
        actorId: adminId,
        action: 'PAYMENT_MANUAL_REOPENED',
        targetId: payment.id,
        metadata: {
          transactionId: payment.transaction_id,
          keptProofsCount: activeProofs.length,
        },
      })
      .catch(() => {});

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: artisanUserId,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      rejectionReason: null,
      refundRequired: false,
      updatedAt: new Date().toISOString(),
    });
  }

  async softDeletePayment(paymentId: string, adminId: string): Promise<void> {
    const payment = await this.paymentManualRepository.findOne({
      where: { id: paymentId, deleted_at: IsNull() },
      relations: ['subscription', 'subscription.artisan_profile'],
    });

    if (!payment) {
      throw new NotFoundException('Paiement manuel introuvable.');
    }

    const isFinalStatus = [
      PaymentManualStatus.COMPLETED,
      PaymentManualStatus.REJECTED,
      PaymentManualStatus.EXPIRED,
    ].includes(payment.status);

    if (!isFinalStatus && !payment.refund_done_at) {
      throw new BadRequestException(
        'Seuls les paiements finalises (valide, rejete, expire ou rembourse) peuvent etre supprimes.',
      );
    }

    const now = new Date();
    payment.deleted_at = now;
    payment.timeline = [
      ...(payment.timeline || []),
      this.timelineEvent('PAYMENT_MANUAL_SOFT_DELETED', {
        byAdminId: adminId,
      }),
    ];
    await this.paymentManualRepository.save(payment);

    this.analyticsService
      .logActivity({
        actorId: adminId,
        action: 'PAYMENT_MANUAL_SOFT_DELETED',
        targetId: payment.id,
        metadata: {
          transactionId: payment.transaction_id,
        },
      })
      .catch(() => {});

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: payment.subscription?.artisan_profile?.user_id,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      updatedAt: now.toISOString(),
    });
  }

  async expirePayments(): Promise<number> {
    let totalExpired = 0;

    for (let i = 0; i < this.maxExpireBatchLoops; i += 1) {
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

      if (stale.length === 0) {
        break;
      }

      for (const payment of stale) {
        const correlationId = randomUUID();
        const shouldDeactivateSubscription =
          !this.hasPendingRefund(payment) &&
          payment.subscription?.status === SubscriptionStatus.ACTIVE;
        if (shouldDeactivateSubscription) {
          await this.subscriptionService.deactivateSubscriptionFromManualPayment(
            {
              subscriptionId: payment.subscription_id,
              paymentManualId: payment.id,
              reason: 'TRANSACTION_EXPIRED',
              correlationId,
            },
          );
        }

        payment.status = PaymentManualStatus.EXPIRED;
        payment.refund_required = true;
        payment.attempted_refund_count =
          (payment.attempted_refund_count || 0) + 1;
        payment.timeline = [
          ...(payment.timeline || []),
          ...(shouldDeactivateSubscription
            ? [
                this.timelineEvent('SUBSCRIPTION_DEACTIVATION_REQUESTED', {
                  correlationId,
                  reason: 'TRANSACTION_EXPIRED',
                }),
              ]
            : []),
          this.timelineEvent('PAYMENT_MANUAL_EXPIRED', {
            reason: 'PENDING_ADMIN_TIMEOUT',
            correlationId,
          }),
        ];
        await this.paymentManualRepository.save(payment);
        await this.paymentRealtimeService.emitTimelineUpdated({
          paymentId: payment.id,
          transactionId: payment.transaction_id,
          correlationId,
          reason: 'TRANSACTION_EXPIRED',
        });

        const artisanUserId = payment.subscription?.artisan_profile?.user_id;
        if (artisanUserId) {
          await this.notificationsService.create({
            userId: artisanUserId,
            type: 'PAYMENT_MANUAL_EXPIRED',
            title: 'Paiement expire',
            body: "Votre preuve n'a pas ete traitee a temps. Un remboursement est requis.",
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

        this.analyticsService
          .logActivity({
            actorId: 'system',
            action: 'PAYMENT_MANUAL_EXPIRED',
            targetId: payment.id,
            metadata: { transactionId: payment.transaction_id },
          })
          .catch(() => {});
      }

      totalExpired += stale.length;
      if (stale.length < 200) {
        break;
      }
    }

    return totalExpired;
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
        body: `Votre remboursement de ${payment.amount_fcfa} FCFA a ete confirme. Vous pouvez maintenant creer une nouvelle demande.`,
        data: {
          paymentId: payment.id,
          transactionId: payment.transaction_id,
        },
      });
    }

    this.analyticsService
      .logActivity({
        actorId: adminId,
        action: 'REFUND_PROCESSED',
        targetId: payment.id,
        metadata: {
          transactionId: payment.transaction_id,
        },
      })
      .catch(() => {});

    await this.paymentRealtimeService.emitPaymentUpdated({
      userId: artisanUserId,
      paymentId: payment.id,
      transactionId: payment.transaction_id,
      status: payment.status,
      refundRequired: false,
      refundDone: true,
      updatedAt: new Date().toISOString(),
    });
  }

  async getAdminList(filters: AdminListFilters) {
    const page = Math.max(1, Number(filters.page || 1));
    const limit = Math.min(100, Math.max(1, Number(filters.limit || 20)));
    const sortDirection =
      (filters.sort || 'desc').toLowerCase() === 'asc' ? 'ASC' : 'DESC';

    const qb = this.paymentManualRepository
      .createQueryBuilder('pm')
      .leftJoinAndSelect('pm.subscription', 's')
      .leftJoinAndSelect('s.artisan_profile', 'artisan')
      .leftJoinAndSelect('artisan.user', 'user')
      .where('pm.deleted_at IS NULL');

    const archivedPredicate = `(pm.status = :expiredStatus OR (pm.status = :rejectedStatus AND pm.validated_at IS NOT NULL) OR pm.replaced_by_transaction_id IS NOT NULL)`;

    if (filters.scope === 'ACTIVE') {
      qb.andWhere(`NOT ${archivedPredicate}`, {
        expiredStatus: PaymentManualStatus.EXPIRED,
        rejectedStatus: PaymentManualStatus.REJECTED,
      });
    } else if (filters.scope === 'HISTORY') {
      qb.andWhere(archivedPredicate, {
        expiredStatus: PaymentManualStatus.EXPIRED,
        rejectedStatus: PaymentManualStatus.REJECTED,
      });
    }

    if (filters.status) {
      if (filters.status === 'REFUND_REQUIRED') {
        qb.andWhere('pm.refund_required = true');
      } else {
        qb.andWhere('pm.status = :status', { status: filters.status });
      }
    }

    const [data, total] = await qb
      .orderBy('pm.created_at', sortDirection)
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
      relations: [
        'proofs',
        'subscription',
        'subscription.artisan_profile',
        'subscription.artisan_profile.user',
      ],
      order: { proofs: { submitted_at: 'DESC' } },
    });

    if (!payment) {
      throw new NotFoundException('Paiement manuel introuvable.');
    }

    return payment;
  }

  async getCurrentTransaction(userId: string): Promise<PaymentManual | null> {
    const artisanProfile =
      await this.resolvePreferredArtisanProfileForUser(userId);
    const subscriptions = await this.subscriptionRepository.find({
      where: { artisan_profile_id: artisanProfile.id },
      select: ['id', 'artisan_profile_id', 'created_at'],
      order: { created_at: 'DESC' },
    });

    if (!subscriptions.length) {
      return null;
    }

    const [latestPayment] = await this.paymentManualRepository.find({
      where: {
        subscription_id: In(
          subscriptions.map((subscription) => subscription.id),
        ),
        deleted_at: IsNull(),
      },
      relations: ['proofs', 'subscription', 'subscription.artisan_profile'],
      order: {
        created_at: 'DESC',
        request_number: 'DESC',
        proofs: { submitted_at: 'DESC' },
      },
      take: 1,
    });

    if (!latestPayment) {
      return null;
    }

    if (
      latestPayment.status === PaymentManualStatus.COMPLETED &&
      !latestPayment.subscription?.artisan_profile?.is_subscription_active
    ) {
      return null;
    }

    return latestPayment;
  }

  async getStatus(
    transactionId: string,
    userId: string,
  ): Promise<PaymentManual> {
    return this.findOwnedPaymentByTransactionId(userId, transactionId, true);
  }

  async getProofSignedUrl(
    transactionId: string,
    proofId: string,
    userId: string,
  ): Promise<{ url: string; expiresInSeconds: number }> {
    const payment = await this.findOwnedPaymentByTransactionId(
      userId,
      transactionId,
    );

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
    const url = await this.mediaService.getSignedUrl(
      parsed.bucket,
      parsed.objectKey,
    );

    return { url, expiresInSeconds: 3600 };
  }

  async verifyProofHashesIntegrity(): Promise<{
    checked: number;
    mismatches: number;
  }> {
    const proofs = await this.paymentProofRepository.find({
      where: { deleted_at: IsNull() },
      select: ['id', 'image_url', 'image_hash_sha256'],
      take: 1000,
    });

    let mismatches = 0;
    const incidentProofIds: string[] = [];

    for (const proof of proofs) {
      try {
        const parsed = this.parseImageRef(proof.image_url);
        const { stream } = await this.mediaService.streamFile(
          parsed.bucket,
          parsed.objectKey,
        );
        const buffer = await this.streamToBuffer(stream);
        const currentHash = createHash('sha256').update(buffer).digest('hex');

        if (currentHash !== proof.image_hash_sha256) {
          mismatches += 1;
          incidentProofIds.push(proof.id);
          this.logger.error(
            `Hash mismatch for payment proof ${proof.id}: expected=${proof.image_hash_sha256} actual=${currentHash}`,
          );
        }
      } catch (error) {
        mismatches += 1;
        incidentProofIds.push(proof.id);
        this.logger.error(
          `Hash verification failed for proof ${proof.id}: ${error}`,
        );
      }
    }

    if (mismatches > 0) {
      await this.notifyIntegrityAlert(
        proofs.length,
        mismatches,
        incidentProofIds,
      );
    }

    return {
      checked: proofs.length,
      mismatches,
    };
  }

  private async enforceProofSubmissionRateLimit(userId: string): Promise<void> {
    if (this.disableRedisRateLimit) {
      return;
    }

    try {
      const redis = this.getRateLimitRedis();
      const dayKey = this.dailyUploadKey(userId);
      const burstKey = `PAYMENT_SUBMIT_THROTTLE:${userId}`;

      const dayCount = await redis.incr(dayKey);
      if (dayCount === 1) {
        await redis.expire(dayKey, this.secondsUntilUtcDayEnd());
      }
      if (dayCount > this.dailyUploadLimit) {
        this.logger.warn(
          `[RATE-LIMIT] Daily upload limit reached for user=${userId} dayCount=${dayCount} dayLimit=${this.dailyUploadLimit}`,
        );
        throw new BusinessException(
          'PAYMENT_MANUAL_DAILY_UPLOAD_LIMIT',
          `Limite quotidienne de ${this.dailyUploadLimit} envois atteinte. Reessayez demain.`,
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }

      const burstCount = await redis.incr(burstKey);
      if (burstCount === 1) {
        await redis.expire(burstKey, this.submitBurstTtlSeconds);
      }
      if (burstCount > this.submitBurstLimit) {
        const remainingTtl = await redis.ttl(burstKey);
        this.logger.warn(
          `[RATE-LIMIT] Burst limit reached for user=${userId} burstCount=${burstCount} burstLimit=${this.submitBurstLimit} remainingTtl=${remainingTtl}s`,
        );
        throw new BusinessException(
          'PAYMENT_MANUAL_SUBMIT_RATE_LIMIT',
          `Trop de soumissions. Reessayez dans ${Math.ceil(remainingTtl / 60)} minute(s).`,
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    } catch (error) {
      if (error instanceof BusinessException) {
        throw error;
      }
      this.logger.warn(
        `Redis rate-limit unavailable for payment manual submit (user ${userId}): ${error}`,
      );
    }
  }

  private getRateLimitRedis(): Redis {
    if (this.rateLimitRedis) {
      return this.rateLimitRedis;
    }

    this.rateLimitRedis = new Redis({
      host: this.configService.get<string>('redis.host') || 'localhost',
      port: this.configService.get<number>('redis.port') || 6379,
      password: this.configService.get<string>('redis.password') || undefined,
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      enableReadyCheck: false,
      retryStrategy: () => null,
    });

    this.rateLimitRedis.on('error', (err) => {
      this.logger.warn(`Payment manual Redis rate-limit error: ${err}`);
    });

    return this.rateLimitRedis;
  }

  private dailyUploadKey(userId: string): string {
    const now = new Date();
    const yyyy = now.getUTCFullYear();
    const mm = String(now.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(now.getUTCDate()).padStart(2, '0');
    return `PAYMENT_UPLOAD:${userId}:${yyyy}${mm}${dd}`;
  }

  private secondsUntilUtcDayEnd(): number {
    const now = new Date();
    const next = new Date(now);
    next.setUTCHours(24, 0, 0, 0);
    return Math.max(60, Math.ceil((next.getTime() - now.getTime()) / 1000));
  }

  private async notifyIntegrityAlert(
    checked: number,
    mismatches: number,
    proofIds: string[],
  ): Promise<void> {
    const admins = await this.userRepository.find({
      where: { role: UserRole.ADMIN, is_active: true },
      select: ['id'],
      take: 50,
    });

    if (admins.length === 0) {
      return;
    }

    const sample = proofIds.slice(0, 10);
    await Promise.all(
      admins.map((admin) =>
        this.notificationsService
          .create({
            userId: admin.id,
            type: 'PAYMENT_MANUAL_INTEGRITY_ALERT',
            title: 'Alerte integrite paiement manuel',
            body: `${mismatches} preuve(s) presentent une incoherence de hash sur ${checked} verifiees.`,
            data: {
              checked,
              mismatches,
              sampleProofIds: sample,
            },
          })
          .catch(() => null),
      ),
    );
  }

  getRecipientNumberForProvider(
    provider: PaymentProviderManual,
  ): string | null {
    return MANUAL_PAYMENT_RECIPIENT_BY_PROVIDER[provider] ?? null;
  }

  isProviderAvailable(provider: PaymentProviderManual): boolean {
    return this.getRecipientNumberForProvider(provider) !== null;
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
        "Vous n'etes pas autorise a acceder a cette transaction.",
      );
    }

    return payment;
  }

  private cooldownDurationMs(cycle: number): number {
    return (
      MANUAL_PAYMENT_COOLDOWN_BASE_HOURS *
      60 *
      60 *
      1000 *
      Math.pow(2, Math.max(0, cycle - 1))
    );
  }

  private hasActiveCooldown(
    payment: Pick<PaymentManual, 'cooldown_until'>,
  ): boolean {
    if (!payment.cooldown_until) {
      return false;
    }

    return payment.cooldown_until.getTime() > Date.now();
  }

  private hasPendingRefund(
    payment: Pick<PaymentManual, 'refund_required' | 'refund_done_at'>,
  ): boolean {
    return payment.refund_required && !payment.refund_done_at;
  }

  private isRejectedAfterValidation(
    payment: Pick<PaymentManual, 'status' | 'validated_at'>,
  ): boolean {
    return (
      payment.status === PaymentManualStatus.REJECTED &&
      payment.validated_at != null
    );
  }

  private isHistoricalPayment(
    payment: Pick<
      PaymentManual,
      'status' | 'validated_at' | 'replaced_by_transaction_id'
    >,
  ): boolean {
    return (
      payment.status === PaymentManualStatus.EXPIRED ||
      this.isRejectedAfterValidation(payment) ||
      Boolean(payment.replaced_by_transaction_id)
    );
  }

  private isAutoReplacementCandidate(
    payment: Pick<
      PaymentManual,
      'status' | 'validated_at' | 'refund_required' | 'refund_done_at'
    >,
  ): boolean {
    if (this.hasPendingRefund(payment)) {
      return false;
    }

    if (payment.status === PaymentManualStatus.EXPIRED) {
      return true;
    }

    return this.isRejectedAfterValidation(payment);
  }

  private autoReplacementReason(
    payment: Pick<PaymentManual, 'status' | 'validated_at'>,
  ): AutoReplacementReason {
    return this.isRejectedAfterValidation(payment)
      ? 'REJECTED_AFTER_VALIDATION'
      : 'EXPIRED_REFUND_CLEARED';
  }

  private async createPendingPayment(params: {
    subscription: Pick<Subscription, 'id' | 'amount_fcfa'>;
    provider: PaymentProviderManual;
    userId: string;
    reason?: AutoReplacementReason;
    previousTransactionId?: string;
    correlationId?: string;
  }): Promise<PaymentManual> {
    const requestNumber =
      (await this.paymentManualRepository.count({
        where: { subscription_id: params.subscription.id },
        withDeleted: true,
      })) + 1;

    const now = new Date();
    const expiresAtAdmin = new Date(
      now.getTime() + this.expiryHours * 60 * 60 * 1000,
    );
    const timelineType = params.reason
      ? 'PAYMENT_MANUAL_AUTO_REPLACEMENT_CREATED'
      : 'PAYMENT_MANUAL_INITIATED';

    const payload = this.paymentManualRepository.create({
      subscription_id: params.subscription.id,
      transaction_id: this.generateTransactionId(),
      amount_fcfa: params.subscription.amount_fcfa || this.amountFcfa,
      provider: params.provider,
      status: PaymentManualStatus.PENDING,
      request_number: requestNumber,
      expires_at_admin: expiresAtAdmin,
      timeline: [
        this.timelineEvent(timelineType, {
          byUserId: params.userId,
          provider: params.provider,
          amountFcfa: params.subscription.amount_fcfa || this.amountFcfa,
          previousTransactionId: params.previousTransactionId || null,
          reason: params.reason || null,
          correlationId: params.correlationId || null,
        }),
      ],
    });

    try {
      return await this.paymentManualRepository.save(payload);
    } catch (error) {
      const isUniqueViolation =
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as { code?: string }).code === '23505';
      if (!isUniqueViolation) {
        throw error;
      }

      const existingPending = await this.paymentManualRepository.findOne({
        where: {
          subscription_id: params.subscription.id,
          status: PaymentManualStatus.PENDING,
          deleted_at: IsNull(),
        },
        relations: ['proofs'],
        order: {
          created_at: 'DESC',
        },
      });
      if (existingPending) {
        return existingPending;
      }

      throw error;
    }
  }

  private async createReplacementPayment(params: {
    previousPayment: PaymentManual;
    subscription: Pick<Subscription, 'id' | 'amount_fcfa'>;
    userId: string;
  }): Promise<PaymentManual> {
    const reason = this.autoReplacementReason(params.previousPayment);
    const correlationId = randomUUID();
    const payment = await this.createPendingPayment({
      subscription: params.subscription,
      provider: params.previousPayment.provider,
      userId: params.userId,
      reason,
      previousTransactionId: params.previousPayment.transaction_id,
      correlationId,
    });

    params.previousPayment.replaced_by_transaction_id = payment.transaction_id;
    params.previousPayment.timeline = [
      ...(params.previousPayment.timeline || []),
      this.timelineEvent('PAYMENT_MANUAL_AUTO_REPLACED', {
        byUserId: params.userId,
        previousTransactionId: params.previousPayment.transaction_id,
        replacedByTransactionId: payment.transaction_id,
        reason,
        correlationId,
      }),
    ];
    await this.paymentManualRepository.save(params.previousPayment);

    const artisanProfile = await this.resolvePreferredArtisanProfileForUser(
      params.userId,
    );
    const artisanUserId = artisanProfile.user_id;

    if (artisanUserId) {
      try {
        await this.notificationsService.create({
          userId: artisanUserId,
          type: 'PAYMENT_MANUAL_AUTO_REPLACED',
          title: 'Nouvelle demande creee automatiquement',
          body: `Votre transaction ${params.previousPayment.transaction_id} a ete remplacee par ${payment.transaction_id}.`,
          data: {
            previousTransactionId: params.previousPayment.transaction_id,
            transactionId: payment.transaction_id,
            paymentId: payment.id,
            reason,
            correlationId,
          },
        });
      } catch (error) {
        this.logger.warn(
          `Notification non bloquante ignoree pour transaction=${payment.transaction_id} type=PAYMENT_MANUAL_AUTO_REPLACED: ${error}`,
        );
      }
    }

    this.logger.log(
      JSON.stringify({
        event: 'manual_payment_auto_replaced',
        correlation_id: correlationId,
        previousTransactionId: params.previousPayment.transaction_id,
        replacementTransactionId: payment.transaction_id,
        reason,
      }),
    );

    await this.paymentRealtimeService.emitTimelineUpdated({
      paymentId: params.previousPayment.id,
      transactionId: params.previousPayment.transaction_id,
      replacedByTransactionId: payment.transaction_id,
      reason,
      correlationId,
    });

    this.analyticsService
      .logActivity({
        actorId: params.userId,
        action: 'PAYMENT_MANUAL_INITIATED',
        targetId: payment.id,
        metadata: {
          transactionId: payment.transaction_id,
          provider: payment.provider,
          source: 'AUTO_REPLACEMENT',
          previousTransactionId: params.previousPayment.transaction_id,
          correlationId,
        },
      })
      .catch(() => {});

    return payment;
  }

  private formatRemainingDuration(target: Date): string {
    const remainingMs = Math.max(0, target.getTime() - Date.now());
    const totalMinutes = Math.ceil(remainingMs / (60 * 1000));
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;

    if (hours <= 0) {
      return `${minutes} min`;
    }

    if (minutes === 0) {
      return `${hours} h`;
    }

    return `${hours} h ${minutes} min`;
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

  private parseImageRef(imageUrl: string): {
    bucket: string;
    objectKey: string;
  } {
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
