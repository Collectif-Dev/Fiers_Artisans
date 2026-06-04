import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/subscription_model.dart';

abstract class SubscriptionRepositoryContract {
  Future<SubscriptionModel?> getStatus();
  Future<Map<String, dynamic>> initiatePayment();
}

class SubscriptionRepository implements SubscriptionRepositoryContract {
  final ApiClient _api = ApiClient();

  @override
  Future<SubscriptionModel?> getStatus() async {
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
      if (data.isEmpty) {
        return null;
      }
      final rawSub = data['subscription'];
      if (rawSub == null && !data.containsKey('id')) {
        return null;
      }
      if (rawSub is Map<String, dynamic>) {
        return SubscriptionModel.fromJson(rawSub);
      }
      if (data.containsKey('id')) {
        return SubscriptionModel.fromJson(data);
      }
      return null;
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> initiatePayment() async {
    final response = await _api.post(ApiEndpoints.subscriptionInitiate);
    return response.data;
  }
}
