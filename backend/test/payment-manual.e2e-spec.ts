import { ConflictException, HttpException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
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

  const paymentManualRepository = {
    findOne: jest.fn(async ({ where, relations }: AnyRecord) => {
      if (where?.transaction_id) {
        const payment = state.payments.find(
          (p) => p.transaction_id === where.transaction_id && !p.deleted_at,
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
        const payment = state.payments.find((p) => p.id === where.id && !p.deleted_at);
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
                new Date(b.submitted_at).getTime() - new Date(a.submitted_at).getTime(),
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
              !p.deleted_at &&
              (allowed.length === 0 || allowed.includes(p.status)),
          )
          .sort(
            (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime(),
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
          if (idx >= 0) state.payments[idx] = { ...state.payments[idx], ...row };
        }
        return payload;
      }

      if (!payload.id) {
        const created = {
          id: randomUUID(),
          created_at: new Date(),
          updated_at: new Date(),
          timeline: [],
          refund_required: false,
          attempted_refund_count: 0,
          ...payload,
        };
        state.payments.push(created);
        return created;
      }

      const idx = state.payments.findIndex((p) => p.id === payload.id);
      if (idx >= 0) {
        state.payments[idx] = { ...state.payments[idx], ...payload, updated_at: new Date() };
        return state.payments[idx];
      }
      state.payments.push(payload);
      return payload;
    }),
    create: jest.fn((payload: AnyRecord) => payload),
    count: jest.fn(),
    find: jest.fn(async ({ where, take }: AnyRecord) => {
      const now = new Date();
      const list = state.payments.filter((p) => {
        const expired =
          p.expires_at_admin && new Date(p.expires_at_admin).getTime() < now.getTime();
        return (
          p.status === where.status &&
          expired &&
          !p.deleted_at
        );
      });
      return list.slice(0, take || list.length);
    }),
    createQueryBuilder: jest.fn(),
  } as any;

  const paymentProofRepository = {
    findOne: jest.fn(async ({ where }: AnyRecord) => {
      if (where?.image_hash_sha256) {
        return (
          state.proofs.find((p) => p.image_hash_sha256 === where.image_hash_sha256) || null
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
        const created = { id: randomUUID(), ...payload };
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
  } as any;

  const artisanProfileRepository = {
    findOne: jest.fn(async ({ where }: AnyRecord) => {
      return state.artisanProfiles.find((a) => a.user_id === where.user_id) || null;
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
    {
      activateSubscriptionFromManualPayment: jest.fn(async (subscriptionId: string) => {
        const sub = state.subscriptions.find((s) => s.id === subscriptionId);
        if (sub) {
          sub.status = SubscriptionStatus.ACTIVE;
        }
      }),
    } as any,
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
    mockFile,
  };
}

describe('Payment Manual (e2e scenarios)', () => {
  it('Scenario 1: initiate -> submit proof -> admin validates -> subscription active', async () => {
    const { service, state, mockFile } = createHarness();

    const initiated = await service.initiatePayment('user-1', PaymentProviderManual.ORANGE_MONEY);
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
    const subscription = state.subscriptions.find((s) => s.id === initiated.subscription_id);

    expect(updated?.status).toBe(PaymentManualStatus.COMPLETED);
    expect(subscription?.status).toBe(SubscriptionStatus.ACTIVE);
  });

  it('Scenario 2: reject proof -> resubmit -> validate', async () => {
    const { service, state, mockFile } = createHarness();
    const initiated = await service.initiatePayment('user-1', PaymentProviderManual.MTN_MOMO);

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
    await service.reopenProof(initiated.id, 'admin-1', 'moderation mistake');

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

    await service.reopenProof('pm-exp-1', 'admin-1', 'manual review override');
    const reopened = state.payments.find((p) => p.id === 'pm-exp-1');
    expect(reopened?.status).toBe(PaymentManualStatus.PENDING);
    expect(reopened?.refund_required).toBe(false);
  });

  it('Scenario 4: duplicate proof hash returns 409 conflict', async () => {
    const { service, state, mockFile } = createHarness();
    const initiated = await service.initiatePayment('user-1', PaymentProviderManual.ORANGE_MONEY);

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
    await service.reopenProof(initiated.id, 'admin-1', 'allow correction');

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

  it('Scenario 5: upload attempts over limit return 429', async () => {
    const { service, state } = createHarness();
    const initiated = await service.initiatePayment('user-1', PaymentProviderManual.ORANGE_MONEY);
    const payment = state.payments.find((p) => p.id === initiated.id)!;
    payment.status = PaymentManualStatus.REJECTED;

    state.proofs.push(
      { id: 'proof-1', payment_manual_id: initiated.id, deleted_at: null },
      { id: 'proof-2', payment_manual_id: initiated.id, deleted_at: null },
      { id: 'proof-3', payment_manual_id: initiated.id, deleted_at: null },
    );

    try {
      await service.submitProof({
        transactionId: initiated.transaction_id,
        userId: 'user-1',
        file: {
          buffer: Buffer.from('ffd8ffe1', 'hex'),
          mimetype: 'image/jpeg',
          size: 4,
          originalname: 'proof-over-limit.jpg',
        } as Express.Multer.File,
        senderNumber: '0700000000',
      });
      throw new Error('Expected submitProof to throw 429');
    } catch (error) {
      expect(error).toBeInstanceOf(HttpException);
      expect((error as HttpException).getStatus()).toBe(429);
    }
  });
});
