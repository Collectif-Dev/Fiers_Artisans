import { ConflictException, HttpException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { BusinessException } from '../src/common/exceptions/business.exception';
import { PaymentManualService } from '../src/modules/payment-manual/services/payment-manual.service';
import {
  PaymentManualStatus,
  PaymentProviderManual,
} from '../src/modules/payment-manual/entities/payment-manual.entity';
import { SubscriptionStatus } from '../src/modules/subscription/entities/subscription.entity';

type AnyRecord = Record<string, any>;

function createHarness() {
  const state = {
    artisanProfiles: [
      {
        id: 'artisan-1',
        user_id: 'user-1',
        is_subscription_active: false,
      },
    ] as AnyRecord[],
    subscriptions: [] as AnyRecord[],
    payments: [] as AnyRecord[],
    proofs: [] as AnyRecord[],
  };

  const resolveStatusFilter = (statusFilter: unknown): string[] => {
    if (!statusFilter) return [];
    if (Array.isArray(statusFilter)) return statusFilter as string[];
    const maybeOp = statusFilter as { value?: unknown; _value?: unknown };
    if (Array.isArray(maybeOp?.value)) return maybeOp.value as string[];
    if (Array.isArray(maybeOp?._value)) return maybeOp._value as string[];
    return [String(statusFilter)];
  };

  const resolveListFilter = (value: unknown): string[] => {
    if (!value) return [];
    if (Array.isArray(value)) return value.map(String);
    const maybeOp = value as { value?: unknown; _value?: unknown };
    if (Array.isArray(maybeOp?.value)) return maybeOp.value.map(String);
    if (Array.isArray(maybeOp?._value)) return maybeOp._value.map(String);
    return [String(value)];
  };

  const paymentManualRepository = {
    findOne: jest.fn(async ({ where, relations }: AnyRecord) => {
      if (where?.transaction_id) {
        const payment = state.payments.find(
          (p) =>
            p.transaction_id === where.transaction_id &&
            (!where.deleted_at || !p.deleted_at),
        );
        if (!payment) return null;
        if (relations?.includes('subscription')) {
          payment.subscription = state.subscriptions.find(
            (s) => s.id === payment.subscription_id,
          );
          if (payment.subscription) {
            payment.subscription.artisan_profile = state.artisanProfiles.find(
              (a) => a.id === payment.subscription.artisan_profile_id,
            );
          }
        }
        return payment;
      }

      if (where?.id) {
        const payment = state.payments.find(
          (p) => p.id === where.id && !p.deleted_at,
        );
        if (!payment) return null;
        payment.subscription = state.subscriptions.find(
          (s) => s.id === payment.subscription_id,
        );
        if (payment.subscription) {
          payment.subscription.artisan_profile = state.artisanProfiles.find(
            (a) => a.id === payment.subscription.artisan_profile_id,
          );
        }
        if (relations?.includes('proofs')) {
          payment.proofs = state.proofs
            .filter((p) => p.payment_manual_id === payment.id && !p.deleted_at)
            .sort(
              (a, b) =>
                new Date(b.submitted_at).getTime() -
                new Date(a.submitted_at).getTime(),
            );
        }
        return payment;
      }

      if (where?.subscription_id) {
        const allowed = resolveStatusFilter(where.status);
        const payment = state.payments
          .filter(
            (p) =>
              p.subscription_id === where.subscription_id &&
              (!where.deleted_at || !p.deleted_at) &&
              (allowed.length === 0 || allowed.includes(p.status)),
          )
          .filter(
            (p) =>
              where.refund_required === undefined ||
              p.refund_required === where.refund_required,
          )
          .filter(
            (p) =>
              where.refund_done_at === undefined || p.refund_done_at == null,
          )
          .sort(
            (a, b) =>
              new Date(b.created_at).getTime() -
              new Date(a.created_at).getTime(),
          )[0];
        if (!payment) return null;
        if (relations?.includes('proofs')) {
          payment.proofs = state.proofs.filter(
            (p) => p.payment_manual_id === payment.id && !p.deleted_at,
          );
        }
        return payment;
      }

      return null;
    }),
    save: jest.fn(async (payload: AnyRecord) => {
      if (Array.isArray(payload)) {
        for (const row of payload) {
          const idx = state.payments.findIndex((p) => p.id === row.id);
          if (idx >= 0)
            state.payments[idx] = { ...state.payments[idx], ...row };
        }
        return payload;
      }

      if (!payload.id) {
        const created = {
          id: randomUUID(),
          created_at: new Date(),
          updated_at: new Date(),
          timeline: [],
          request_number: 1,
          refund_required: false,
          refund_done_at: null,
          cooldown_until: null,
          cooldown_cycle: 0,
          attempted_refund_count: 0,
          ...payload,
        };
        state.payments.push(created);
        return created;
      }

      const idx = state.payments.findIndex((p) => p.id === payload.id);
      if (idx >= 0) {
        state.payments[idx] = {
          ...state.payments[idx],
          ...payload,
          updated_at: new Date(),
        };
        return state.payments[idx];
      }
      state.payments.push(payload);
      return payload;
    }),
    create: jest.fn((payload: AnyRecord) => payload),
    count: jest.fn(async ({ where, withDeleted }: AnyRecord) => {
      if (where?.subscription_id) {
        return state.payments.filter(
          (p) =>
            p.subscription_id === where.subscription_id &&
            (withDeleted || !p.deleted_at),
        ).length;
      }
      return 0;
    }),
    find: jest.fn(async ({ where, take, relations }: AnyRecord) => {
      if (where?.subscription_id) {
        const subscriptionIds = resolveListFilter(where.subscription_id);
        const list = state.payments
          .filter(
            (p) =>
              subscriptionIds.includes(p.subscription_id) &&
              (!where.deleted_at || !p.deleted_at),
          )
          .sort(
            (a, b) =>
              new Date(b.created_at).getTime() -
              new Date(a.created_at).getTime(),
          );
        return list.slice(0, take || list.length).map((payment) => {
          const enriched = { ...payment };
          if (relations?.includes('proofs')) {
            enriched.proofs = state.proofs
              .filter(
                (proof) =>
                  proof.payment_manual_id === payment.id && !proof.deleted_at,
              )
              .sort(
                (a, b) =>
                  new Date(b.submitted_at).getTime() -
                  new Date(a.submitted_at).getTime(),
              );
          }
          if (relations?.includes('subscription')) {
            enriched.subscription = state.subscriptions.find(
              (subscription) => subscription.id === payment.subscription_id,
            );
            if (
              enriched.subscription &&
              relations?.includes('subscription.artisan_profile')
            ) {
              enriched.subscription.artisan_profile = state.artisanProfiles.find(
                (artisan) =>
                  artisan.id === enriched.subscription.artisan_profile_id,
              );
            }
          }
          return enriched;
        });
      }

      const now = new Date();
      const list = state.payments.filter((p) => {
        const expired =
          p.expires_at_admin &&
          new Date(p.expires_at_admin).getTime() < now.getTime();
        return p.status === where.status && expired && !p.deleted_at;
      });
      return list.slice(0, take || list.length);
    }),
    createQueryBuilder: jest.fn(),
  } as any;

  const paymentProofRepository = {
    findOne: jest.fn(async ({ where }: AnyRecord) => {
      if (where?.image_hash_sha256) {
        return (
          state.proofs.find(
            (p) => p.image_hash_sha256 === where.image_hash_sha256,
          ) || null
        );
      }
      if (where?.id) {
        return (
          state.proofs.find(
            (p) =>
              p.id === where.id &&
              p.payment_manual_id === where.payment_manual_id &&
              !p.deleted_at,
          ) || null
        );
      }
      return null;
    }),
    save: jest.fn(async (payload: AnyRecord | AnyRecord[]) => {
      if (Array.isArray(payload)) {
        for (const proof of payload) {
          const idx = state.proofs.findIndex((p) => p.id === proof.id);
          if (idx >= 0) state.proofs[idx] = { ...state.proofs[idx], ...proof };
        }
        return payload;
      }

      if (!payload.id) {
        const created = {
          id: randomUUID(),
          submitted_at: new Date(),
          deletion_requested: false,
          deleted_at: null,
          ...payload,
        };
        state.proofs.push(created);
        return created;
      }
      const idx = state.proofs.findIndex((p) => p.id === payload.id);
      if (idx >= 0) {
        state.proofs[idx] = { ...state.proofs[idx], ...payload };
        return state.proofs[idx];
      }
      state.proofs.push(payload);
      return payload;
    }),
    create: jest.fn((payload: AnyRecord) => payload),
    count: jest.fn(async ({ where }: AnyRecord) => {
      return state.proofs.filter(
        (p) => p.payment_manual_id === where.payment_manual_id && !p.deleted_at,
      ).length;
    }),
    find: jest.fn(async ({ where }: AnyRecord) => {
      return state.proofs.filter(
        (p) => p.payment_manual_id === where.payment_manual_id && !p.deleted_at,
      );
    }),
  } as any;

  const subscriptionRepository = {
    findOne: jest.fn(async ({ where }: AnyRecord) => {
      if (where?.id) {
        return state.subscriptions.find((s) => s.id === where.id) || null;
      }
      if (where?.artisan_profile_id) {
        return (
          state.subscriptions.find(
            (s) => s.artisan_profile_id === where.artisan_profile_id,
          ) || null
        );
      }
      return null;
    }),
    save: jest.fn(async (payload: AnyRecord) => {
      if (!payload.id) {
        const created = { id: randomUUID(), created_at: new Date(), ...payload };
        state.subscriptions.push(created);
        return created;
      }
      const idx = state.subscriptions.findIndex((s) => s.id === payload.id);
      if (idx >= 0) {
        state.subscriptions[idx] = { ...state.subscriptions[idx], ...payload };
        return state.subscriptions[idx];
      }
      state.subscriptions.push(payload);
      return payload;
    }),
    create: jest.fn((payload: AnyRecord) => payload),
    find: jest.fn(async ({ where }: AnyRecord) => {
      if (where?.artisan_profile_id) {
        const artisanIds = resolveListFilter(where.artisan_profile_id);
        return state.subscriptions
          .filter((subscription) =>
            artisanIds.includes(subscription.artisan_profile_id),
          )
          .sort(
            (a, b) =>
              new Date(b.created_at || 0).getTime() -
              new Date(a.created_at || 0).getTime(),
          );
      }
      return [];
    }),
  } as any;

  const artisanProfileRepository = {
    findOne: jest.fn(async ({ where }: AnyRecord) => {
      return (
        state.artisanProfiles.find((a) => a.user_id === where.user_id) || null
      );
    }),
    find: jest.fn(async ({ where }: AnyRecord) => {
      return state.artisanProfiles
        .filter((artisan) => artisan.user_id === where.user_id)
        .sort(
          (a, b) =>
            new Date(b.updated_at || 0).getTime() -
            new Date(a.updated_at || 0).getTime(),
        );
    }),
  } as any;

  const userRepository = {
    find: jest.fn(async () => []),
  } as any;

  const notificationsService = { create: jest.fn(async () => ({})) } as any;
  const analyticsService = { logActivity: jest.fn(async () => ({})) } as any;
  const paymentRealtimeService = {
    emitNewProof: jest.fn(async () => ({})),
    emitPaymentUpdated: jest.fn(async () => ({})),
    emitTimelineUpdated: jest.fn(async () => ({})),
  } as any;
  const subscriptionService = {
    activateSubscriptionFromManualPayment: jest.fn(
      async (subscriptionId: string) => {
        const sub = state.subscriptions.find((s) => s.id === subscriptionId);
        if (sub) {
          sub.status = SubscriptionStatus.ACTIVE;
          const artisan = state.artisanProfiles.find(
            (profile) => profile.id === sub.artisan_profile_id,
          );
          if (artisan) {
            artisan.is_subscription_active = true;
          }
        }
      },
    ),
    deactivateSubscriptionFromManualPayment: jest.fn(
      async ({
        subscriptionId,
        reason,
      }: {
        subscriptionId: string;
        reason: 'TRANSACTION_REJECTED' | 'TRANSACTION_EXPIRED';
      }) => {
        const sub = state.subscriptions.find((s) => s.id === subscriptionId);
        if (sub) {
          sub.status =
            reason === 'TRANSACTION_EXPIRED'
              ? SubscriptionStatus.EXPIRED
              : SubscriptionStatus.CANCELLED;
          const artisan = state.artisanProfiles.find(
            (profile) => profile.id === sub.artisan_profile_id,
          );
          if (artisan) {
            artisan.is_subscription_active = false;
          }
        }
      },
    ),
  } as any;

  const service = new PaymentManualService(
    paymentManualRepository,
    paymentProofRepository,
    subscriptionRepository,
    artisanProfileRepository,
    userRepository,
    {
      uploadRaw: jest.fn(async () => ({
        bucket: 'payment-proofs',
        objectKey: 'proofs/object-1',
      })),
      getSignedUrl: jest.fn(async () => 'https://signed-url'),
      streamFile: jest.fn(),
    } as any,
    subscriptionService,
    notificationsService,
    analyticsService,
    {
      validateImage: jest.fn(async () => ({
        mimeType: 'image/jpeg',
        sizeBytes: 120_000,
        width: 1080,
        height: 1920,
        format: 'jpeg',
        bytesPerPixel: 0.08,
        suspiciousCompression: false,
      })),
    } as any,
    {
      extract: jest.fn(async () => ({
        captureDate: null,
        modifiedDate: null,
        device: null,
        software: null,
        hasExif: false,
      })),
      detectSuspiciousSoftware: jest.fn(() => false),
    } as any,
    {
      scoreImage: jest.fn(() => 0.12),
    } as any,
    paymentRealtimeService,
    {
      get: jest.fn((key: string) => {
        if (key === 'PAYMENT_MANUAL_AMOUNT_FCFA') return 5000;
        if (key === 'PAYMENT_MANUAL_EXPIRY_HOURS') return 72;
        if (key === 'minio.buckets.paymentProofs') return 'payment-proofs';
        if (key === 'PAYMENT_MANUAL_UPLOADS_PER_DAY_LIMIT') return 50;
        if (key === 'PAYMENT_MANUAL_SUBMIT_BURST_LIMIT') return 20;
        if (key === 'PAYMENT_MANUAL_SUBMIT_BURST_TTL_SECONDS') return 300;
        if (key === 'PAYMENT_MANUAL_EXPIRE_BATCH_LOOPS') return 5;
        if (key === 'PAYMENT_MANUAL_DISABLE_REDIS_RATE_LIMIT') return 'true';
        if (key === 'redis.host') return '127.0.0.1';
        if (key === 'redis.port') return 6379;
        if (key === 'redis.password') return '';
        return undefined;
      }),
    } as any,
  );

  const mockFile = Buffer.from('ffd8ffe000104a464946000101', 'hex');
  return {
    service,
    state,
    paymentProofRepository,
    notificationsService,
    subscriptionService,
    mockFile,
  };
}

describe('Payment Manual (e2e scenarios)', () => {
  it('Scenario 1: initiate -> submit proof -> admin validates -> subscription active', async () => {
    const { service, state, mockFile } = createHarness();

    const initiated = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.ORANGE_MONEY,
    );
    expect(initiated.transaction_id).toMatch(/^TX-/);

    await service.submitProof({
      transactionId: initiated.transaction_id,
      userId: 'user-1',
      file: {
        buffer: mockFile,
        mimetype: 'image/jpeg',
        size: mockFile.length,
        originalname: 'proof.jpg',
      } as Express.Multer.File,
      senderNumber: '0700000000',
    });

    await service.validateProof(initiated.id, 'admin-1', 'ok');
    const updated = state.payments.find((p) => p.id === initiated.id);
    const subscription = state.subscriptions.find(
      (s) => s.id === initiated.subscription_id,
    );

    expect(updated?.status).toBe(PaymentManualStatus.COMPLETED);
    expect(subscription?.status).toBe(SubscriptionStatus.ACTIVE);
  });

  it('Scenario 2: reject proof -> resubmit -> validate', async () => {
    const { service, state, mockFile } = createHarness();
    const initiated = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.MTN_MOMO,
    );

    await service.submitProof({
      transactionId: initiated.transaction_id,
      userId: 'user-1',
      file: {
        buffer: mockFile,
        mimetype: 'image/jpeg',
        size: mockFile.length,
        originalname: 'proof-1.jpg',
      } as Express.Multer.File,
      senderNumber: '0500000000',
    });

    await service.rejectProof(initiated.id, 'admin-1', 'proof unclear');

    await service.submitProof({
      transactionId: initiated.transaction_id,
      userId: 'user-1',
      file: {
        buffer: Buffer.concat([mockFile, Buffer.from('aa', 'hex')]),
        mimetype: 'image/jpeg',
        size: mockFile.length + 1,
        originalname: 'proof-2.jpg',
      } as Express.Multer.File,
      senderNumber: '0100000000',
    });
    await service.validateProof(initiated.id, 'admin-2');

    const updated = state.payments.find((p) => p.id === initiated.id);
    expect(updated?.status).toBe(PaymentManualStatus.COMPLETED);
  });

  it('Scenario 3: pending admin payment expires and refund_required is set', async () => {
    const { service, state } = createHarness();
    const subscription = {
      id: 'sub-exp-1',
      artisan_profile_id: 'artisan-1',
      amount_fcfa: 5000,
      status: SubscriptionStatus.PENDING,
    };
    state.subscriptions.push(subscription);
    state.payments.push({
      id: 'pm-exp-1',
      subscription_id: subscription.id,
      transaction_id: 'TX-EXPIRE-1',
      amount_fcfa: 5000,
      provider: PaymentProviderManual.WAVE,
      status: PaymentManualStatus.PENDING_ADMIN,
      refund_required: false,
      attempted_refund_count: 0,
      created_at: new Date(),
      expires_at_admin: new Date(Date.now() - 60_000),
      timeline: [],
    });

    const expiredCount = await service.expirePayments();
    const expired = state.payments.find((p) => p.id === 'pm-exp-1');

    expect(expiredCount).toBe(1);
    expect(expired?.status).toBe(PaymentManualStatus.EXPIRED);
    expect(expired?.refund_required).toBe(true);

    await expect(
      service.initiatePayment('user-1', PaymentProviderManual.WAVE),
    ).rejects.toMatchObject({
      code: 'PAYMENT_MANUAL_REFUND_PENDING',
    });

    await service.markRefundDone('pm-exp-1', 'admin-1');
    const refunded = state.payments.find((p) => p.id === 'pm-exp-1');
    expect(refunded?.refund_required).toBe(false);
    expect(refunded?.refund_done_at).toBeInstanceOf(Date);

    const newRequest = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.WAVE,
    );
    expect(newRequest.request_number).toBe(2);
  });

  it('Scenario 4: duplicate proof hash returns 409 conflict', async () => {
    const { service, state, mockFile } = createHarness();
    const initiated = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.ORANGE_MONEY,
    );

    await service.submitProof({
      transactionId: initiated.transaction_id,
      userId: 'user-1',
      file: {
        buffer: mockFile,
        mimetype: 'image/jpeg',
        size: mockFile.length,
        originalname: 'proof-1.jpg',
      } as Express.Multer.File,
      senderNumber: '0700000000',
    });
    await service.rejectProof(initiated.id, 'admin-1', 'retry requested');

    await expect(
      service.submitProof({
        transactionId: initiated.transaction_id,
        userId: 'user-1',
        file: {
          buffer: mockFile,
          mimetype: 'image/jpeg',
          size: mockFile.length,
          originalname: 'proof-duplicate.jpg',
        } as Express.Multer.File,
        senderNumber: '0700000000',
      }),
    ).rejects.toBeInstanceOf(ConflictException);

    expect(state.proofs.length).toBe(1);
  });

  it('Scenario 5: reopening a rejected payment keeps the proof under review and blocks resubmission', async () => {
    const { service, state, notificationsService, mockFile } = createHarness();
    const initiated = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.ORANGE_MONEY,
    );

    await service.submitProof({
      transactionId: initiated.transaction_id,
      userId: 'user-1',
      file: {
        buffer: mockFile,
        mimetype: 'image/jpeg',
        size: mockFile.length,
        originalname: 'proof-1.jpg',
      } as Express.Multer.File,
      senderNumber: '0700000000',
    });
    await service.rejectProof(initiated.id, 'admin-1', 'proof unclear');
    await service.reopenProof(initiated.id, 'admin-1', 'moderation review');

    const reopened = state.payments.find((p) => p.id === initiated.id);
    expect(reopened?.status).toBe(PaymentManualStatus.PENDING_ADMIN);

    expect(notificationsService.create).toHaveBeenLastCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        type: 'PAYMENT_MANUAL_REOPENED',
        title: 'Paiement manuel rouvert',
        body: 'Votre paiement manuel a ete rouvert. La preuve deja soumise est de nouveau en cours de verification.',
      }),
    );

    await expect(
      service.submitProof({
        transactionId: initiated.transaction_id,
        userId: 'user-1',
        file: {
          buffer: Buffer.concat([mockFile, Buffer.from('aa', 'hex')]),
          mimetype: 'image/jpeg',
          size: mockFile.length + 1,
          originalname: 'proof-2.jpg',
        } as Express.Multer.File,
        senderNumber: '0700000000',
      }),
    ).rejects.toBeInstanceOf(BusinessException);
  });

  it('Scenario 6: rejected proof enters cooldown after third failed cycle and reopens on the same transaction', async () => {
    const { service, state, notificationsService, mockFile } = createHarness();
    const initiated = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.ORANGE_MONEY,
    );

    const proofBuffers = [
      mockFile,
      Buffer.concat([mockFile, Buffer.from('aa', 'hex')]),
      Buffer.concat([mockFile, Buffer.from('bb', 'hex')]),
      Buffer.concat([mockFile, Buffer.from('cc', 'hex')]),
    ];

    for (let index = 0; index < 3; index += 1) {
      await service.submitProof({
        transactionId: initiated.transaction_id,
        userId: 'user-1',
        file: {
          buffer: proofBuffers[index],
          mimetype: 'image/jpeg',
          size: proofBuffers[index].length,
          originalname: `proof-${index + 1}.jpg`,
        } as Express.Multer.File,
        senderNumber: '0700000000',
      });
      await service.rejectProof(initiated.id, 'admin-1', `reject-${index + 1}`);
    }

    const payment = state.payments.find((p) => p.id === initiated.id)!;
    expect(payment.cooldown_cycle).toBe(1);
    expect(payment.cooldown_until).toBeInstanceOf(Date);
    expect(notificationsService.create).toHaveBeenLastCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        type: 'PAYMENT_MANUAL_COOLDOWN',
        data: expect.objectContaining({
          cooldownCycle: 1,
        }),
      }),
    );

    try {
      await service.submitProof({
        transactionId: initiated.transaction_id,
        userId: 'user-1',
        file: {
          buffer: proofBuffers[3],
          mimetype: 'image/jpeg',
          size: proofBuffers[3].length,
          originalname: 'proof-over-limit.jpg',
        } as Express.Multer.File,
        senderNumber: '0700000000',
      });
      throw new Error('Expected submitProof to throw cooldown 429');
    } catch (error) {
      expect(error).toBeInstanceOf(HttpException);
      expect((error as HttpException).getStatus()).toBe(429);
    }

    payment.cooldown_until = new Date(Date.now() - 1000);

    await service.submitProof({
      transactionId: initiated.transaction_id,
      userId: 'user-1',
      file: {
        buffer: proofBuffers[3],
        mimetype: 'image/jpeg',
        size: proofBuffers[3].length,
        originalname: 'proof-after-cooldown.jpg',
      } as Express.Multer.File,
      senderNumber: '0700000000',
    });

    const refreshed = state.payments.find((p) => p.id === initiated.id)!;
    const latestProof = state.proofs[state.proofs.length - 1];
    expect(refreshed.status).toBe(PaymentManualStatus.PENDING_ADMIN);
    expect(refreshed.cooldown_until).toBeNull();
    expect(latestProof.upload_attempt_number).toBe(1);
  });

  it('Scenario 7: getCurrentTransaction always returns the latest payment, not an older rejected one', async () => {
    const { service, state } = createHarness();
    const subscription = {
      id: 'sub-latest-1',
      artisan_profile_id: 'artisan-1',
      amount_fcfa: 5000,
      status: SubscriptionStatus.PENDING,
      created_at: new Date('2026-05-01T08:00:00.000Z'),
    };
    state.subscriptions.push(subscription);
    state.payments.push(
      {
        id: 'pm-old-rejected',
        subscription_id: subscription.id,
        transaction_id: 'TX-OLD-REJ',
        amount_fcfa: 5000,
        provider: PaymentProviderManual.ORANGE_MONEY,
        status: PaymentManualStatus.REJECTED,
        request_number: 1,
        refund_required: false,
        refund_done_at: null,
        created_at: new Date('2026-05-01T09:00:00.000Z'),
        expires_at_admin: null,
        timeline: [],
      },
      {
        id: 'pm-latest-expired',
        subscription_id: subscription.id,
        transaction_id: 'TX-LATEST-EXP',
        amount_fcfa: 5000,
        provider: PaymentProviderManual.WAVE,
        status: PaymentManualStatus.EXPIRED,
        request_number: 2,
        refund_required: true,
        refund_done_at: null,
        created_at: new Date('2026-05-10T09:00:00.000Z'),
        expires_at_admin: new Date('2026-05-13T09:00:00.000Z'),
        timeline: [],
      },
    );

    const current = await service.getCurrentTransaction('user-1');

    expect(current?.transaction_id).toBe('TX-LATEST-EXP');
    expect(current?.status).toBe(PaymentManualStatus.EXPIRED);
    expect(current?.refund_required).toBe(true);
  });

  it('Scenario 8: a refunded expired payment does not get overridden by an older rejected request during re-initiation', async () => {
    const { service, state } = createHarness();
    const subscription = {
      id: 'sub-reinit-1',
      artisan_profile_id: 'artisan-1',
      amount_fcfa: 5000,
      status: SubscriptionStatus.PENDING,
      created_at: new Date('2026-05-01T08:00:00.000Z'),
    };
    state.subscriptions.push(subscription);
    state.payments.push(
      {
        id: 'pm-rejected-1',
        subscription_id: subscription.id,
        transaction_id: 'TX-OLD-001',
        amount_fcfa: 5000,
        provider: PaymentProviderManual.ORANGE_MONEY,
        status: PaymentManualStatus.REJECTED,
        request_number: 1,
        refund_required: false,
        refund_done_at: null,
        created_at: new Date('2026-05-01T09:00:00.000Z'),
        expires_at_admin: null,
        timeline: [],
      },
      {
        id: 'pm-expired-refunded',
        subscription_id: subscription.id,
        transaction_id: 'TX-EXP-002',
        amount_fcfa: 5000,
        provider: PaymentProviderManual.WAVE,
        status: PaymentManualStatus.EXPIRED,
        request_number: 2,
        refund_required: false,
        refund_done_at: new Date('2026-05-12T10:00:00.000Z'),
        created_at: new Date('2026-05-10T09:00:00.000Z'),
        expires_at_admin: new Date('2026-05-13T09:00:00.000Z'),
        timeline: [],
      },
    );

    const newRequest = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.WAVE,
    );

    expect(newRequest.transaction_id).not.toBe('TX-OLD-001');
    expect(newRequest.request_number).toBe(3);
    expect(newRequest.status).toBe(PaymentManualStatus.PENDING);
  });

  it('Scenario 9: a rejected payment after prior validation deactivates the subscription and auto-replaces with a new transaction', async () => {
    const { service, state, notificationsService, mockFile, subscriptionService } =
      createHarness();
    const initiated = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.ORANGE_MONEY,
    );

    await service.submitProof({
      transactionId: initiated.transaction_id,
      userId: 'user-1',
      file: {
        buffer: mockFile,
        mimetype: 'image/jpeg',
        size: mockFile.length,
        originalname: 'proof-initial.jpg',
      } as Express.Multer.File,
      senderNumber: '0700000000',
    });
    await service.validateProof(initiated.id, 'admin-1');
    await service.reopenProof(initiated.id, 'admin-1', 're-review');
    await service.rejectProof(initiated.id, 'admin-2', 'proof invalidated');

    const rejected = state.payments.find((payment) => payment.id === initiated.id)!;
    const subscription = state.subscriptions.find(
      (row) => row.id === initiated.subscription_id,
    );

    expect(rejected.status).toBe(PaymentManualStatus.REJECTED);
    expect(subscription?.status).toBe(SubscriptionStatus.CANCELLED);
    expect(state.artisanProfiles[0].is_subscription_active).toBe(false);
    expect(
      subscriptionService.deactivateSubscriptionFromManualPayment,
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        subscriptionId: initiated.subscription_id,
        reason: 'TRANSACTION_REJECTED',
      }),
    );

    const replacement = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.WAVE,
    );

    expect(replacement.status).toBe(PaymentManualStatus.PENDING);
    expect(replacement.provider).toBe(PaymentProviderManual.ORANGE_MONEY);
    expect(replacement.request_number).toBe(2);
    expect(rejected.replaced_by_transaction_id).toBe(
      replacement.transaction_id,
    );
    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        type: 'PAYMENT_MANUAL_AUTO_REPLACED',
        data: expect.objectContaining({
          previousTransactionId: initiated.transaction_id,
          transactionId: replacement.transaction_id,
        }),
      }),
    );
  });

  it('Scenario 10: expiration deactivates an active subscription before archiving the transaction', async () => {
    const { service, state, subscriptionService } = createHarness();
    state.artisanProfiles[0].is_subscription_active = true;
    const subscription = {
      id: 'sub-exp-active-1',
      artisan_profile_id: 'artisan-1',
      amount_fcfa: 5000,
      status: SubscriptionStatus.ACTIVE,
      created_at: new Date('2026-05-01T08:00:00.000Z'),
    };
    state.subscriptions.push(subscription);
    state.payments.push({
      id: 'pm-exp-active-1',
      subscription_id: subscription.id,
      transaction_id: 'TX-EXP-ACTIVE',
      amount_fcfa: 5000,
      provider: PaymentProviderManual.WAVE,
      status: PaymentManualStatus.PENDING_ADMIN,
      refund_required: false,
      attempted_refund_count: 0,
      created_at: new Date(),
      expires_at_admin: new Date(Date.now() - 60_000),
      timeline: [],
      subscription,
    });

    await service.expirePayments();

    expect(subscription.status).toBe(SubscriptionStatus.EXPIRED);
    expect(state.artisanProfiles[0].is_subscription_active).toBe(false);
    expect(
      subscriptionService.deactivateSubscriptionFromManualPayment,
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        subscriptionId: subscription.id,
        reason: 'TRANSACTION_EXPIRED',
      }),
    );
  });
});
