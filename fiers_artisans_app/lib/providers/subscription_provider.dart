import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/subscription_model.dart';
import '../data/repositories/subscription_repository.dart';
import '../services/push_notification_service.dart';
import '../services/chat_realtime_service.dart';

class SubscriptionState {
  final SubscriptionModel? subscription;
  final bool isLoading;
  final bool hasLoaded;
  final String? error;

  const SubscriptionState({
    this.subscription,
    this.isLoading = false,
    this.hasLoaded = false,
    this.error,
  });

  SubscriptionState copyWith({
    SubscriptionModel? subscription,
    bool? isLoading,
    bool? hasLoaded,
    String? error,
  }) {
    return SubscriptionState(
      subscription: subscription ?? this.subscription,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      error: error,
    );
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionRepository _repo = SubscriptionRepository();
  final ChatRealtimeService _realtime = ChatRealtimeService();
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  SubscriptionNotifier() : super(const SubscriptionState()) {
    PushNotificationService().onSubscriptionUpdate = () {
      if (!state.hasLoaded && state.subscription == null) {
        return;
      }
      loadStatus();
    };
    _realtimeSub = _realtime.domainEvents.listen((event) {
      if (event.event == 'subscriptionStatusUpdated' ||
          event.event == 'artisanSubscriptionUpdated' ||
          (event.event == 'notificationCreated' &&
              _isSubscriptionNotification(event.payload))) {
        if (state.hasLoaded || state.subscription != null) {
          loadStatus();
        }
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sub = await _repo.getStatus();
      state = state.copyWith(
        subscription: sub,
        isLoading: false,
        hasLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>?> initiatePayment() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.initiatePayment();
      state = state.copyWith(isLoading: false);
      return data;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  bool _isSubscriptionNotification(Map<String, dynamic> payload) {
    final notif = payload['notification'];
    if (notif is Map<String, dynamic>) {
      final type = notif['type']?.toString().toUpperCase();
      return type == 'SUBSCRIPTION_UPDATED' || type == 'PAYMENT_UPDATED';
    }
    return false;
  }
}
