import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/client_profile_model.dart';

class ProfileRepository {
  final ApiClient _api = ApiClient();

  Future<ClientProfileModel> getMyClientProfile() async {
    final response = await _api.get(ApiEndpoints.clientProfile);
    final payload = response.data is Map<String, dynamic>
        ? ((response.data['data'] as Map<String, dynamic>?) ?? response.data)
        : response.data;

    return ClientProfileModel.fromJson(Map<String, dynamic>.from(payload));
  }
}
