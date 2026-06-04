import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class AnalyticsRepository {
  final ApiClient _api = ApiClient();

  Future<void> logEvent({
    required String action,
    String? targetId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final body = <String, dynamic>{'action': action};
      if (targetId != null) body['targetId'] = targetId;
      if (metadata != null) body['metadata'] = metadata;
      await _api.post(ApiEndpoints.analyticsLog, data: body);
    } catch (_) {
      // Fire-and-forget — never block UI for analytics
    }
  }
}
