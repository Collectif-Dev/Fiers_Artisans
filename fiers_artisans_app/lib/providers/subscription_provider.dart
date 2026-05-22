import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/subscription_model.dart';
import '../data/repositories/subscription_repository.dart';
import 'session_scope_provider.dart';
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
    bool clearSubscription = false,
    bool? isLoading,
    bool? hasLoaded,
    String? error,
  }) {
    return SubscriptionState(
      subscription: clearSubscription
          ? null
          : (subscription ?? this.subscription),
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      error: error,
    );
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
      ref.watch(sessionEpochProvider);
      return SubscriptionNotifier();
    });

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionRepositoryContract _repo;
  final ChatRealtimeService _realtime;
  final PushNotificationService? _push;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;
  late final void Function() _onSubscriptionUpdate;

  SubscriptionNotifier({
    SubscriptionRepositoryContract? repository,
    ChatRealtimeService? realtime,
    PushNotificationService? push,
    bool bindPushUpdates = true,
  }) : _repo = repository ?? SubscriptionRepository(),
       _realtime = realtime ?? ChatRealtimeService(),
       _push = push ?? (bindPushUpdates ? PushNotificationService() : null),
       super(const SubscriptionState()) {
    _onSubscriptionUpdate = () {
      if (!state.hasLoaded && state.subscription == null) {
        return;
      }
      loadStatus();
    };
    _push?.onSubscriptionUpdate = _onSubscriptionUpdate;
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
    final push = _push;
    if (push != null &&
        identical(push.onSubscriptionUpdate, _onSubscriptionUpdate)) {
      push.onSubscriptionUpdate = null;
    }
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> loadStatus() async {
    state = state.copyWith(
      isLoading: true,
      clearSubscription: true,
      error: null,
    );
    try {
      final sub = await _repo.getStatus();
      state = state.copyWith(
        subscription: sub,
        clearSubscription: sub == null,
        isLoading: false,
        hasLoaded: true,
      );
    } catch (e) {
      state = state.copyWith(
        clearSubscription: true,
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
