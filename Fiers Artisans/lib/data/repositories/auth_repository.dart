import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/phone_number.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> login({
    required String phone,
    required String pinCode,
  }) async {
    final response = await _api.post(
      ApiEndpoints.login,
      data: {
        'phone_number': normalizeLocalPhoneNumber(phone),
        'pin_code': pinCode,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> registerArtisan({
    required String phone,
    required String pinCode,
    required String firstName,
    required String lastName,
    required String categoryId,
    required String subcategoryId,
    required String city,
    required String commune,
    double? latitude,
    double? longitude,
    String? businessName,
    String? email,
    String? description,
    int? experienceYears,
  }) async {
    final body = <String, dynamic>{
      'phone_number': normalizeLocalPhoneNumber(phone),
      'pin_code': pinCode,
      'first_name': firstName,
      'last_name': lastName,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'city': city,
      'commune': commune,
    };
    if (businessName != null) body['business_name'] = businessName;
    if (email != null) body['email'] = email;
    if (description != null) body['bio'] = description;
    if (experienceYears != null) body['years_experience'] = experienceYears;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    final response = await _api.post(ApiEndpoints.registerArtisan, data: body);
    return response.data;
  }

  Future<Map<String, dynamic>> registerClient({
    required String phone,
    required String pinCode,
    required String firstName,
    required String lastName,
    required String city,
    required String commune,
    double? latitude,
    double? longitude,
    String? email,
  }) async {
    final body = <String, dynamic>{
      'phone_number': normalizeLocalPhoneNumber(phone),
      'pin_code': pinCode,
      'first_name': firstName,
      'last_name': lastName,
      'city': city,
      'commune': commune,
    };
    if (email != null) body['email'] = email;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    final response = await _api.post(ApiEndpoints.registerClient, data: body);
    return response.data;
  }

  Future<void> sendOtp(String phone) async {
    await _api.post(
      ApiEndpoints.sendOtp,
      data: {'phone_number': normalizeLocalPhoneNumber(phone)},
    );
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final response = await _api.post(
      ApiEndpoints.verifyOtp,
      data: {'phone_number': normalizeLocalPhoneNumber(phone), 'code': code},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> setupPin({
    required String phone,
    required String code,
    required String pinCode,
  }) async {
    final response = await _api.post(
      ApiEndpoints.setupPin,
      data: {
        'phone_number': normalizeLocalPhoneNumber(phone),
        'code': code,
        'pin_code': pinCode,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _api.post(
      ApiEndpoints.refreshToken,
      data: {'refresh_token': refreshToken},
    );
    return response.data;
  }

  Future<UserModel> getProfile() async {
    final role = await SecureStorage.getUserRole();
    final endpoint = (role ?? '').toUpperCase() == 'ARTISAN'
        ? ApiEndpoints.artisanProfile
        : ApiEndpoints.clientProfile;
    final response = await _api.get(endpoint);
    return UserModel.fromJson(response.data);
  }
}
