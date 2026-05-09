import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/subscription_model.dart';

class SubscriptionRepository {
  final ApiClient _api = ApiClient();

  Future<SubscriptionModel?> getStatus() async {
    try {
      final response = await _api.get(ApiEndpoints.subscriptionStatus);
      final data = response.data;
      // Backend returns { subscription: {...}, is_active: bool }
      if (data is Map<String, dynamic> && data.containsKey('subscription')) {
        final rawSub = data['subscription'];
        if (rawSub == null || rawSub is! Map<String, dynamic> || rawSub.isEmpty) {
          return null;
        }
        final sub = Map<String, dynamic>.from(rawSub);
        sub['is_active'] = data['is_active'];
        return SubscriptionModel.fromJson(sub);
      }
      if (data is Map<String, dynamic>) {
        return SubscriptionModel.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> initiatePayment() async {
    final response = await _api.post(ApiEndpoints.subscriptionInitiate);
    return response.data;
  }
}
