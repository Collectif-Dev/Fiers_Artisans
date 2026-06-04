import 'package:dio/dio.dart';
import 'dart:typed_data';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class VerificationRepository {
  final ApiClient _api = ApiClient();

  /// Uploads a file to the verifications bucket.
  /// Returns {url, objectKey} of the uploaded file.
  Future<Map<String, String>> uploadDocument(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _api.dio.post(
      ApiEndpoints.upload,
      data: formData,
      queryParameters: {'bucket': 'documents'},
    );
    final data = response.data;
    return {
      'url': data['url'] as String,
      'objectKey': (data['objectKey'] as String?) ?? '',
    };
  }

  /// Uploads binary file bytes (web-safe) to the verifications bucket.
  /// Returns {url, objectKey} of the uploaded file.
  Future<Map<String, String>> uploadDocumentBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _api.dio.post(
      ApiEndpoints.upload,
      data: formData,
      queryParameters: {'bucket': 'documents'},
    );
    final data = response.data;
    return {
      'url': data['url'] as String,
      'objectKey': (data['objectKey'] as String?) ?? '',
    };
  }

  /// Submits a verification document with structured files to the backend.
  /// [files] is a list of {file_url, page_role} maps.
  Future<Map<String, dynamic>> submitDocumentWithFiles({
    required String documentType,
    required List<Map<String, dynamic>> files,
  }) async {
    final response = await _api.post(
      ApiEndpoints.verificationSubmit,
      data: {
        'document_type': documentType,
        'files': files,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Legacy single-file submit (backwards compatible).
  Future<Map<String, dynamic>> submitDocument({
    required String documentType,
    required String fileUrl,
  }) async {
    final response = await _api.post(
      ApiEndpoints.verificationSubmit,
      data: {
        'document_type': documentType,
        'file_url': fileUrl,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetches the current verification status and documents.
  Future<Map<String, dynamic>> getVerificationStatus() async {
    final response = await _api.get(ApiEndpoints.verificationStatus);
    return response.data as Map<String, dynamic>;
  }
}
