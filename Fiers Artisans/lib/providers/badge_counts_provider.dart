import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/secure_storage.dart';
import '../data/repositories/notification_repository.dart';
import 'auth_provider.dart';
import 'session_scope_provider.dart';
import '../services/app_icon_service.dart';
import '../services/chat_realtime_service.dart';

class BadgeCountsState {
  final int messagesUnread;
  final int notificationsUnread;
  final bool isLoading;

  const BadgeCountsState({
    this.messagesUnread = 0,
    this.notificationsUnread = 0,
    this.isLoading = false,
  });

  int get totalUnread => messagesUnread + notificationsUnread;

  BadgeCountsState copyWith({
    int? messagesUnread,
    int? notificationsUnread,
    bool? isLoading,
  }) {
    return BadgeCountsState(
      messagesUnread: messagesUnread ?? this.messagesUnread,
      notificationsUnread: notificationsUnread ?? this.notificationsUnread,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final badgeCountsProvider =
    StateNotifierProvider<BadgeCountsNotifier, BadgeCountsState>((ref) {
      ref.watch(sessionEpochProvider);
      final authSnapshot = ref.watch(
        authProvider.select((state) => (state.status, state.user?.id)),
      );
      final status = authSnapshot.$1;
      final userId = authSnapshot.$2;

      return BadgeCountsNotifier(
        bootstrapUserId: status == AuthStatus.authenticated ? userId : null,
      );
    });

class BadgeCountsNotifier extends StateNotifier<BadgeCountsState> {
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final ChatRealtimeService _realtime = ChatRealtimeService();

  StreamSubscription<ChatRealtimeEvent>? _domainEventSub;
  String? _currentUserId;

  BadgeCountsNotifier({String? bootstrapUserId})
    : super(const BadgeCountsState()) {
    if (bootstrapUserId == null || bootstrapUserId.isEmpty) {
      unawaited(_resetSessionState());
      return;
    }

    unawaited(_initialize(bootstrapUserId));
  }

  @override
  void dispose() {
    _domainEventSub?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      await _resetSessionState();
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final counts = await _notificationRepository.getBadgeCounts();
      _applyCounts(
        messagesUnread: counts.messagesUnread,
        notificationsUnread: counts.notificationsUnread,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _initialize(String preferredUserId) async {
    _currentUserId = preferredUserId;
    await _ensureRealtimeConnected();

    await _domainEventSub?.cancel();
    _domainEventSub = _realtime.domainEvents.listen(_onDomainEvent);

    await refresh();
  }

  Future<void> _ensureRealtimeConnected() async {
    _currentUserId ??= await SecureStorage.getUserId();
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return;
    }

    if (!_realtime.isConnected) {
      await _realtime.connect(userId: _currentUserId!);
    }
  }

  void _onDomainEvent(ChatRealtimeEvent event) {
    if (event.event == 'badgeCountsUpdated') {
      final counts = _parseCounts(event.payload);
      if (counts != null) {
        _applyCounts(
          messagesUnread: counts.messagesUnread,
          notificationsUnread: counts.notificationsUnread,
        );
      }
      return;
    }

    if (event.event == 'notificationCreated' ||
        event.event == 'notificationRead' ||
        event.event == 'notificationsReadAll') {
      final nested = event.payload['badgeCounts'];
      if (nested is Map) {
        final counts = _parseCounts(
          nested.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (counts != null) {
          _applyCounts(
            messagesUnread: counts.messagesUnread,
            notificationsUnread: counts.notificationsUnread,
          );
          return;
        }
      }

      unawaited(refresh());
    }
  }

  BadgeCountsState? _parseCounts(Map<String, dynamic> payload) {
    final messagesUnread = _readInt(
      payload['messagesUnread'] ?? payload['badgeMessages'],
    );
    final notificationsUnread = _readInt(
      payload['notificationsUnread'] ?? payload['badgeNotifications'],
    );

    if (messagesUnread == null || notificationsUnread == null) {
      return null;
    }

    return BadgeCountsState(
      messagesUnread: messagesUnread,
      notificationsUnread: notificationsUnread,
      isLoading: false,
    );
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _applyCounts({
    required int messagesUnread,
    required int notificationsUnread,
  }) {
    state = BadgeCountsState(
      messagesUnread: messagesUnread,
      notificationsUnread: notificationsUnread,
      isLoading: false,
    );
    unawaited(AppIconService.syncBadgeCount(state.totalUnread));
  }

  Future<void> _resetSessionState() async {
    _currentUserId = null;
    await _domainEventSub?.cancel();
    _domainEventSub = null;
    state = const BadgeCountsState();
    await AppIconService.clearBadgeCount();
  }
}
