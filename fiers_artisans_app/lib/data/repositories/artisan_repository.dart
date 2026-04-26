import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/artisan_model.dart';
import '../models/review_model.dart';
import '../models/portfolio_model.dart';

enum ReviewSubmitErrorType { duplicate, network, backend, unknown }

class ReviewSubmitException implements Exception {
  final ReviewSubmitErrorType type;
  final String? message;
  final int? statusCode;

  const ReviewSubmitException({
    required this.type,
    this.message,
    this.statusCode,
  });
}

class ArtisanRepository {
  final ApiClient _api = ApiClient();

  Future<ArtisanModel> getMyArtisanProfile() async {
    final response = await _api.get(ApiEndpoints.artisanProfile);
    final payload = response.data is Map<String, dynamic>
        ? ((response.data['data'] as Map<String, dynamic>?) ?? response.data)
        : response.data;
    return ArtisanModel.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<ArtisanModel> getArtisan(String userId) async {
    final response = await _api.get(ApiEndpoints.artisanById(userId));
    final payload = response.data is Map<String, dynamic>
        ? ((response.data['data'] as Map<String, dynamic>?) ?? response.data)
        : response.data;
    return ArtisanModel.fromJson(Map<String, dynamic>.from(payload));
  }

  Future<List<ReviewModel>> getReviews(String artisanId, {int page = 1}) async {
    try {
      final response = await _api.get(
        ApiEndpoints.reviewsByArtisan(artisanId),
        queryParameters: {'page': page},
      );
      final list = response.data is List
          ? response.data
          : response.data['data'] ?? [];
      return (list as List).map((e) => ReviewModel.fromJson(e)).toList();
    } on DioException catch (e) {
      // Some environments may return 404 when no reviews exist yet.
      if (e.response?.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> submitReview({
    required String artisanId,
    required int rating,
    String? comment,
  }) async {
    final body = <String, dynamic>{'artisan_id': artisanId, 'rating': rating};
    if (comment != null) body['comment'] = comment;

    try {
      await _api.post(ApiEndpoints.reviews, data: body);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final message = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['message']?.toString())
          : null;

      if (statusCode == 409) {
        throw ReviewSubmitException(
          type: ReviewSubmitErrorType.duplicate,
          message: message,
          statusCode: statusCode,
        );
      }

      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ReviewSubmitException(
          type: ReviewSubmitErrorType.network,
          message: message,
          statusCode: statusCode,
        );
      }

      if (statusCode != null) {
        throw ReviewSubmitException(
          type: ReviewSubmitErrorType.backend,
          message: message,
          statusCode: statusCode,
        );
      }

      throw ReviewSubmitException(
        type: ReviewSubmitErrorType.unknown,
        message: message,
        statusCode: statusCode,
      );
    }
  }

  Future<void> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    await _api.put(
      ApiEndpoints.reviewReply(reviewId),
      data: {'reply': reply.trim()},
    );
  }

  Future<List<PortfolioModel>> getPortfolio(String artisanId) async {
    final response = await _api.get(ApiEndpoints.portfolioByArtisan(artisanId));
    final list = response.data is List
        ? response.data
        : response.data['data'] ?? [];
    return (list as List).map((e) => PortfolioModel.fromJson(e)).toList();
  }

  Future<void> addPortfolioItem({
    required String title,
    String? description,
    double? price,
    required List<Map<String, String>> imageObjects,
    required List<String> imageUrls,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'imageObjects': imageObjects,
      'imageUrls': imageUrls,
    };
    if (description != null) body['description'] = description;
    if (price != null) body['priceFcfa'] = price.toInt();

    await _api.post(ApiEndpoints.portfolio, data: body);
  }
}
