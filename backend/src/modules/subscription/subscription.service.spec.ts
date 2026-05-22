import { SubscriptionService } from './subscription.service';

describe('SubscriptionService.getStatus', () => {
  function createService() {
    const artisanProfileRepository = {
      find: jest.fn(),
    };

    const subscriptionRepository = {
      find: jest.fn(),
    };

    const service = new SubscriptionService(
      subscriptionRepository as any,
      {} as any,
      artisanProfileRepository as any,
      {} as any,
      {} as any,
      { logActivity: jest.fn() } as any,
      { emit: jest.fn() } as any,
      { create: jest.fn() } as any,
      { emitUserSyncEvent: jest.fn(), emitGlobalSyncEvent: jest.fn() } as any,
    );

    return { service, artisanProfileRepository, subscriptionRepository };
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
});
