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

  Future<void> markAsRead(String id) async {
    await _api.put(ApiEndpoints.notificationRead(id));
  }

  Future<void> markAllAsRead() async {
    await _api.put(ApiEndpoints.notificationsReadAll);
  }
}
