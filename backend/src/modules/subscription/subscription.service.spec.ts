import { ArtisanProfile } from '../users/entities/artisan-profile.entity';
import { Subscription } from './entities/subscription.entity';
import { SubscriptionStatus } from './entities/subscription.entity';
import { SubscriptionService } from './subscription.service';

describe('SubscriptionService', () => {
  function createService() {
    const artisanProfileRepository = {
      find: jest.fn(),
      update: jest.fn(),
      findOne: jest.fn(),
    };

    const subscriptionRepository = {
      find: jest.fn(),
      findOne: jest.fn(),
      update: jest.fn(),
    };

    const notificationsService = {
      create: jest.fn().mockResolvedValue(undefined),
    };

    const adminRealtimeService = {
      emit: jest.fn(),
    };

    const chatGateway = {
      emitUserSyncEvent: jest.fn(),
      emitGlobalSyncEvent: jest.fn(),
    };

    const transactionSubscriptionRepository = {
      findOne: jest.fn(),
      update: jest.fn(),
    };
    const transactionArtisanProfileRepository = {
      findOne: jest.fn(),
      update: jest.fn(),
    };
    const dataSource = {
      transaction: jest.fn(
        async (
          callback: (manager: {
            getRepository: (entity: unknown) => unknown;
          }) => Promise<unknown>,
        ) =>
          callback({
            getRepository: (entity: unknown) => {
              if (entity === Subscription) {
                return transactionSubscriptionRepository;
              }
              if (entity === ArtisanProfile) {
                return transactionArtisanProfileRepository;
              }
              throw new Error(
                `Unexpected repository lookup: ${String(entity)}`,
              );
            },
          }),
      ),
    };

    const service = new SubscriptionService(
      subscriptionRepository as any,
      {} as any,
      artisanProfileRepository as any,
      dataSource as any,
      {} as any,
      { logActivity: jest.fn().mockResolvedValue(undefined) } as any,
      adminRealtimeService as any,
      notificationsService as any,
      chatGateway as any,
    );

    return {
      service,
      artisanProfileRepository,
      subscriptionRepository,
      transactionSubscriptionRepository,
      transactionArtisanProfileRepository,
      notificationsService,
      adminRealtimeService,
      chatGateway,
    };
  }

  it('keeps duplicate artisan profiles readable by resolving the latest scoped subscription', async () => {
    const { service, artisanProfileRepository, subscriptionRepository } =
      createService();
    artisanProfileRepository.find.mockResolvedValue([
      { id: 'profile-a', user_id: 'user-1', is_subscription_active: false },
      { id: 'profile-b', user_id: 'user-1', is_subscription_active: true },
    ]);
    subscriptionRepository.find
      .mockResolvedValueOnce([
        {
          id: 'sub-2',
          artisan_profile_id: 'profile-b',
          created_at: new Date(),
        },
      ])
      .mockResolvedValueOnce([
        {
          id: 'sub-2',
          artisan_profile_id: 'profile-b',
          payments: [],
          created_at: new Date(),
        },
      ]);

    const result = await service.getStatus('user-1');

    expect(result.subscription?.id).toBe('sub-2');
    expect(result.is_active).toBe(true);
  });

  it('returns only the authenticated user scoped subscription status', async () => {
    const { service, artisanProfileRepository, subscriptionRepository } =
      createService();
    artisanProfileRepository.find.mockResolvedValue([
      { id: 'profile-a', user_id: 'user-1', is_subscription_active: true },
    ]);
    subscriptionRepository.find
      .mockResolvedValueOnce([
        {
          id: 'sub-1',
          artisan_profile_id: 'profile-a',
          created_at: new Date(),
        },
      ])
      .mockResolvedValueOnce([
        {
          id: 'sub-1',
          artisan_profile_id: 'profile-a',
          payments: [],
          created_at: new Date(),
        },
      ]);

    const result = await service.getStatus('user-1');

    expect(result.is_active).toBe(true);
    expect(result.subscription?.id).toBe('sub-1');
    expect(subscriptionRepository.find).toHaveBeenLastCalledWith(
      expect.objectContaining({
        relations: ['payments'],
        take: 1,
      }),
    );
  });

  it('falls back to the active legacy profile when no subscription exists', async () => {
    const { service, artisanProfileRepository, subscriptionRepository } =
      createService();
    artisanProfileRepository.find.mockResolvedValue([
      { id: 'profile-a', user_id: 'user-1', is_subscription_active: false },
      { id: 'profile-b', user_id: 'user-1', is_subscription_active: true },
    ]);
    subscriptionRepository.find.mockResolvedValue([]);

    const result = await service.getStatus('user-1');

    expect(result.subscription).toBeNull();
    expect(result.is_active).toBe(true);
  });

  it('deactivates an active subscription after manual payment rejection', async () => {
    const {
      service,
      transactionSubscriptionRepository,
      transactionArtisanProfileRepository,
      notificationsService,
      adminRealtimeService,
      chatGateway,
    } = createService();

    transactionSubscriptionRepository.findOne.mockResolvedValue({
      id: 'sub-1',
      artisan_profile_id: 'profile-1',
      status: SubscriptionStatus.ACTIVE,
    });
    transactionArtisanProfileRepository.findOne.mockResolvedValue({
      id: 'profile-1',
      user_id: 'user-1',
      is_subscription_active: true,
    });

    await service.deactivateSubscriptionFromManualPayment({
      subscriptionId: 'sub-1',
      paymentManualId: 'pm-1',
      reason: 'TRANSACTION_REJECTED',
      correlationId: 'corr-1',
      actorId: 'admin-1',
    });

    expect(transactionSubscriptionRepository.update).toHaveBeenCalledWith(
      'sub-1',
      expect.objectContaining({
        status: SubscriptionStatus.CANCELLED,
      }),
    );
    expect(transactionArtisanProfileRepository.update).toHaveBeenCalledWith(
      'profile-1',
      expect.objectContaining({
        is_subscription_active: false,
      }),
    );
    expect(adminRealtimeService.emit).toHaveBeenCalledWith(
      'SUBSCRIPTION_UPDATED',
      expect.objectContaining({
        subscriptionId: 'sub-1',
        status: SubscriptionStatus.CANCELLED,
        source: 'TRANSACTION_REJECTED',
      }),
    );
    expect(notificationsService.create).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user-1',
        type: 'SUBSCRIPTION_UPDATED',
      }),
    );
    expect(chatGateway.emitUserSyncEvent).toHaveBeenCalled();
  });
});
