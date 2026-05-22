import { Repository } from 'typeorm';
import { PaymentManualService } from './payment-manual.service';
import {
  PaymentManualStatus,
  PaymentProviderManual,
} from '../entities/payment-manual.entity';
import { BusinessException } from '../../../common/exceptions/business.exception';

describe('PaymentManualService', () => {
  let service: PaymentManualService;

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
      {
        activateSubscriptionFromManualPayment: jest.fn(),
      } as any,
      {
        create: jest.fn(),
      } as any,
      {
        logActivity: jest.fn(),
      } as any,
      {
        validateImage: jest.fn(),
      } as any,
      {
        extract: jest.fn(),
        detectSuspiciousSoftware: jest.fn(),
      } as any,
      {
        scoreImage: jest.fn(),
      } as any,
      {
        emitNewProof: jest.fn(),
        emitPaymentUpdated: jest.fn(),
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
});
