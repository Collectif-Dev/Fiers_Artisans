import { Repository } from 'typeorm';
import { PaymentManualService } from './payment-manual.service';
import {
  PaymentManualStatus,
  PaymentProviderManual,
} from '../entities/payment-manual.entity';
import { BusinessException } from '../../../common/exceptions/business.exception';

describe('PaymentManualService', () => {
  let service: PaymentManualService;
  let subscriptionService: {
    activateSubscriptionFromManualPayment: jest.Mock;
    deactivateSubscriptionFromManualPayment: jest.Mock;
  };

  const paymentManualRepository = {
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn((payload) => payload),
    count: jest.fn(),
    find: jest.fn(),
    createQueryBuilder: jest.fn(),
  } as unknown as Repository<any>;

  const paymentProofRepository = {
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn((payload) => payload),
    count: jest.fn(),
    find: jest.fn(),
  } as unknown as Repository<any>;

  const subscriptionRepository = {
    findOne: jest.fn(),
    find: jest.fn(),
    save: jest.fn(),
    create: jest.fn((payload) => payload),
  } as unknown as Repository<any>;

  const artisanProfileRepository = {
    findOne: jest.fn(),
    find: jest.fn(),
  } as unknown as Repository<any>;

  const userRepository = {
    find: jest.fn(),
  } as unknown as Repository<any>;

  beforeEach(() => {
    jest.clearAllMocks();

    subscriptionService = {
      activateSubscriptionFromManualPayment: jest.fn(),
      deactivateSubscriptionFromManualPayment: jest.fn(),
    };

    service = new PaymentManualService(
      paymentManualRepository,
      paymentProofRepository,
      subscriptionRepository,
      artisanProfileRepository,
      userRepository,
      {
        uploadRaw: jest.fn(),
        getSignedUrl: jest.fn(),
        streamFile: jest.fn(),
      } as any,
      subscriptionService as any,
      {
        create: jest.fn(),
      } as any,
      {
        logActivity: jest.fn().mockResolvedValue(undefined),
      } as any,
      {
        validateImage: jest.fn(),
      },
      {
        extract: jest.fn(),
        detectSuspiciousSoftware: jest.fn(),
      } as any,
      {
        scoreImage: jest.fn(),
      },
      {
        emitNewProof: jest.fn(),
        emitPaymentUpdated: jest.fn(),
        emitTimelineUpdated: jest.fn(),
      } as any,
      {
        get: jest.fn((key: string) => {
          if (key === 'PAYMENT_MANUAL_AMOUNT_FCFA') return 5000;
          if (key === 'PAYMENT_MANUAL_EXPIRY_HOURS') return 72;
          if (key === 'minio.buckets.paymentProofs') return 'payment-proofs';
          if (key === 'PAYMENT_MANUAL_UPLOADS_PER_DAY_LIMIT') return 12;
          if (key === 'PAYMENT_MANUAL_SUBMIT_BURST_LIMIT') return 5;
          if (key === 'PAYMENT_MANUAL_SUBMIT_BURST_TTL_SECONDS') return 300;
          if (key === 'PAYMENT_MANUAL_DISABLE_REDIS_RATE_LIMIT') return 'true';
          if (key === 'PAYMENT_ORANGE_RECIPIENT') return '0703063570';
          if (key === 'PAYMENT_MTN_RECIPIENT') return '0503265984';
          if (key === 'PAYMENT_WAVE_RECIPIENT') return '0703063570';
          return undefined;
        }),
      } as any,
    );
  });

  it('throws when artisan profile is missing', async () => {
    artisanProfileRepository.find = jest.fn().mockResolvedValue([]);

    await expect(
      service.initiatePayment('user-1', PaymentProviderManual.ORANGE_MONEY),
    ).rejects.toBeInstanceOf(BusinessException);
  });

  it('returns existing pending payment instead of creating duplicate', async () => {
    artisanProfileRepository.find = jest.fn().mockResolvedValue([
      {
        id: 'artisan-1',
        user_id: 'user-1',
        is_subscription_active: false,
      },
    ]);
    subscriptionRepository.findOne = jest.fn().mockResolvedValue({
      id: 'sub-1',
      status: 'PENDING',
      artisan_profile_id: 'artisan-1',
      amount_fcfa: 5000,
    });
    subscriptionRepository.find = jest.fn().mockResolvedValue([]);
    paymentManualRepository.findOne = jest.fn().mockResolvedValue({
      id: 'pm-1',
      transaction_id: 'TX-1',
      status: PaymentManualStatus.PENDING,
      proofs: [],
    });

    const result = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.ORANGE_MONEY,
    );

    expect(result.id).toBe('pm-1');
    expect(paymentManualRepository.save).not.toHaveBeenCalled();
  });

  it('blocks initiation when an expired payment is waiting for refund', async () => {
    artisanProfileRepository.find = jest.fn().mockResolvedValue([
      {
        id: 'artisan-1',
        user_id: 'user-1',
        is_subscription_active: false,
      },
    ]);
    subscriptionRepository.findOne = jest.fn().mockResolvedValue({
      id: 'sub-1',
      status: 'PENDING',
      artisan_profile_id: 'artisan-1',
      amount_fcfa: 5000,
    });
    subscriptionRepository.find = jest.fn().mockResolvedValue([]);
    paymentManualRepository.findOne = jest.fn().mockResolvedValueOnce({
      id: 'pm-exp-1',
      transaction_id: 'TX-EXP-1',
      status: PaymentManualStatus.EXPIRED,
      refund_required: true,
      refund_done_at: null,
      proofs: [],
    });

    await expect(
      service.initiatePayment('user-1', PaymentProviderManual.ORANGE_MONEY),
    ).rejects.toMatchObject({
      code: 'PAYMENT_MANUAL_REFUND_PENDING',
    });
  });

  it('assigns a request number when creating a new manual payment', async () => {
    artisanProfileRepository.find = jest.fn().mockResolvedValue([
      {
        id: 'artisan-1',
        user_id: 'user-1',
        is_subscription_active: false,
      },
    ]);
    subscriptionRepository.findOne = jest.fn().mockResolvedValue({
      id: 'sub-1',
      status: 'PENDING',
      artisan_profile_id: 'artisan-1',
      amount_fcfa: 5000,
    });
    subscriptionRepository.find = jest.fn().mockResolvedValue([]);
    paymentManualRepository.findOne = jest.fn().mockResolvedValue(null);
    paymentManualRepository.count = jest.fn().mockResolvedValue(1);
    paymentManualRepository.save = jest
      .fn()
      .mockImplementation(async (payload) => ({
        id: 'pm-new-1',
        ...payload,
      }));

    const payment = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.ORANGE_MONEY,
    );

    expect(payment.request_number).toBe(2);
    expect(paymentManualRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        request_number: 2,
      }),
    );
  });

  it('returns operator-specific recipient numbers', () => {
    expect(
      service.getRecipientNumberForProvider(PaymentProviderManual.ORANGE_MONEY),
    ).toBe('0703063570');
    expect(
      service.getRecipientNumberForProvider(PaymentProviderManual.MTN_MOMO),
    ).toBe('0503265984');
    expect(
      service.getRecipientNumberForProvider(PaymentProviderManual.WAVE),
    ).toBe('0703063570');
    expect(
      service.getRecipientNumberForProvider(PaymentProviderManual.MOOV_MONEY),
    ).toBeNull();
  });

  it('rejects initiation when provider is unavailable', async () => {
    await expect(
      service.initiatePayment('user-1', PaymentProviderManual.MOOV_MONEY),
    ).rejects.toBeInstanceOf(BusinessException);
  });

  it('auto-replaces a rejected payment that had already been validated using the previous provider', async () => {
    artisanProfileRepository.find = jest.fn().mockResolvedValue([
      {
        id: 'artisan-1',
        user_id: 'user-1',
        is_subscription_active: false,
      },
    ]);
    subscriptionRepository.findOne = jest.fn().mockResolvedValue({
      id: 'sub-1',
      status: 'CANCELLED',
      artisan_profile_id: 'artisan-1',
      amount_fcfa: 5000,
    });
    subscriptionRepository.find = jest.fn().mockResolvedValue([]);
    paymentManualRepository.findOne = jest.fn().mockResolvedValueOnce({
      id: 'pm-old-1',
      subscription_id: 'sub-1',
      transaction_id: 'TX-OLD-1',
      provider: PaymentProviderManual.MTN_MOMO,
      amount_fcfa: 5000,
      status: PaymentManualStatus.REJECTED,
      validated_at: new Date('2026-05-01T08:00:00.000Z'),
      refund_required: false,
      refund_done_at: null,
      proofs: [],
      timeline: [],
    });
    paymentManualRepository.count = jest.fn().mockResolvedValue(1);
    paymentManualRepository.save = jest
      .fn()
      .mockImplementationOnce(async (payload) => ({
        id: 'pm-new-1',
        ...payload,
      }))
      .mockImplementationOnce(async (payload) => payload);

    const payment = await service.initiatePayment(
      'user-1',
      PaymentProviderManual.WAVE,
    );

    expect(payment.provider).toBe(PaymentProviderManual.MTN_MOMO);
    expect(payment.request_number).toBe(2);
    expect(paymentManualRepository.save).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        provider: PaymentProviderManual.MTN_MOMO,
        request_number: 2,
      }),
    );
    expect(paymentManualRepository.save).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        id: 'pm-old-1',
        replaced_by_transaction_id: payment.transaction_id,
      }),
    );
  });
});
