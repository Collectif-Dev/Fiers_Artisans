import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/manual_payment_model.dart';

abstract class PaymentManualRepositoryContract {
  Future<ManualPaymentModel> initiatePayment({required String provider});
  Future<ManualPaymentModel> fetchStatus({required String transactionId});
  Future<void> submitProof({
    required String transactionId,
    required String filePath,
    required String senderNumber,
    DateTime? declaredPaymentTime,
  });
}

class PaymentManualRepository implements PaymentManualRepositoryContract {
  final ApiClient _api = ApiClient();

  @override
  Future<ManualPaymentModel> initiatePayment({required String provider}) async {
    final response = await _api.post(
      ApiEndpoints.manualPaymentInitiate,
      data: {'provider': provider},
    );
    return ManualPaymentModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<ManualPaymentModel> fetchStatus({required String transactionId}) async {
    final response = await _api.get(ApiEndpoints.manualPaymentStatus(transactionId));
    return ManualPaymentModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> submitProof({
    required String transactionId,
    required String filePath,
    required String senderNumber,
    DateTime? declaredPaymentTime,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'sender_number': senderNumber,
      if (declaredPaymentTime != null)
        'declared_payment_time': declaredPaymentTime.toIso8601String(),
    });

    await _api.post(
      ApiEndpoints.manualPaymentSubmitProof(transactionId),
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}
