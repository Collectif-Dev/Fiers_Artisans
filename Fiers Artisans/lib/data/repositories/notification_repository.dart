import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class NotificationRepository {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    final response = await _api.get(
      ApiEndpoints.notifications,
      queryParameters: {'page': page, 'limit': 20},
    );
    final raw = response.data;
    if (raw is Map<String, dynamic>) {
      final list = raw['data'] is List ? raw['data'] as List : <dynamic>[];
      return {
        'data': list.cast<Map<String, dynamic>>(),
        'total': raw['total'] ?? list.length,
      };
    }
    if (raw is List) {
      return {
        'data': raw.cast<Map<String, dynamic>>(),
        'total': raw.length,
      };
    }
    return {'data': <Map<String, dynamic>>[], 'total': 0};
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get(ApiEndpoints.notificationsUnreadCount);
    final raw = response.data;
    if (raw is int) return raw;
    if (raw is Map) return raw['count'] ?? raw['unreadCount'] ?? 0;
    return 0;
  }

  Future<({int messagesUnread, int notificationsUnread, int totalUnread})>
  getBadgeCounts() async {
    final response = await _api.get(ApiEndpoints.notificationsBadgeCounts);
    final raw = response.data;
    if (raw is Map) {
      final messagesUnread = _readInt(
        raw['messagesUnread'] ?? raw['badgeMessages'],
      );
      final notificationsUnread = _readInt(
        raw['notificationsUnread'] ?? raw['badgeNotifications'],
      );
      final totalUnread = _readOptionalInt(
        raw['totalUnread'] ?? raw['badgeTotal'],
      );
      return (
        messagesUnread: messagesUnread,
        notificationsUnread: notificationsUnread,
        totalUnread: totalUnread ?? messagesUnread + notificationsUnread,
      );
    }
    return (
      messagesUnread: 0,
      notificationsUnread: 0,
      totalUnread: 0,
    );
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int? _readOptionalInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> markAsRead(String id) async {
    await _api.put(ApiEndpoints.notificationRead(id));
  }

  Future<void> markAllAsRead() async {
    await _api.put(ApiEndpoints.notificationsReadAll);
  }
}
