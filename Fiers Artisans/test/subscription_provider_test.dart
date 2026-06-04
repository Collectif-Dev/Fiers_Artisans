import 'package:fiers_artisans_app/data/models/subscription_model.dart';
import 'package:fiers_artisans_app/data/repositories/subscription_repository.dart';
import 'package:fiers_artisans_app/providers/subscription_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSubscriptionRepository implements SubscriptionRepositoryContract {
  FakeSubscriptionRepository({required this.results});

  final List<Object?> results;
  int _index = 0;

  @override
  Future<SubscriptionModel?> getStatus() async {
    if (_index >= results.length) {
      return null;
    }
    final value = results[_index++];
    if (value is Exception) {
      throw value;
    }
    return value as SubscriptionModel?;
  }

  @override
  Future<Map<String, dynamic>> initiatePayment() async {
    return <String, dynamic>{};
  }
}

void main() {
  test(
    'loadStatus clears stale subscription when backend returns null',
    () async {
      final repo = FakeSubscriptionRepository(
        results: [
          SubscriptionModel(
            id: 'sub-A',
            artisanId: 'artisan-A',
            status: 'active',
            endDate: DateTime.now().add(const Duration(days: 19)),
          ),
          null,
        ],
      );

      final notifier = SubscriptionNotifier(
        repository: repo,
        bindPushUpdates: false,
      );
      await notifier.loadStatus();
      expect(notifier.state.subscription?.id, 'sub-A');

      await notifier.loadStatus();
      expect(notifier.state.subscription, isNull);
      expect(notifier.state.hasLoaded, isTrue);
      expect(notifier.state.error, isNull);
      notifier.dispose();
    },
  );

  test('loadStatus clears stale subscription on request failure', () async {
    final repo = FakeSubscriptionRepository(
      results: [
        SubscriptionModel(
          id: 'sub-A',
          artisanId: 'artisan-A',
          status: 'active',
          endDate: DateTime.now().add(const Duration(days: 19)),
        ),
        Exception('network failure'),
      ],
    );

    final notifier = SubscriptionNotifier(
      repository: repo,
      bindPushUpdates: false,
    );
    await notifier.loadStatus();
    expect(notifier.state.subscription?.id, 'sub-A');

    await notifier.loadStatus();
    expect(notifier.state.subscription, isNull);
    expect(notifier.state.hasLoaded, isTrue);
    expect(notifier.state.error, contains('network failure'));
    notifier.dispose();
  });
}
