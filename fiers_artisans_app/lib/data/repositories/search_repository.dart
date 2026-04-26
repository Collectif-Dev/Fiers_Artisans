import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/artisan_model.dart';

class SearchRepository {
  final ApiClient _api = ApiClient();

  Future<List<ArtisanModel>> searchArtisans({
    double? latitude,
    double? longitude,
    double? radius,
    String? categoryId,
    String? subcategoryId,
    String? query,
    String? sortBy,
    double? minRating,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (latitude != null) params['lat'] = latitude;
    if (longitude != null) params['lng'] = longitude;
    if (radius != null) params['radius_km'] = radius;
    if (categoryId != null) params['category'] = categoryId;
    if (subcategoryId != null) params['subcategory'] = subcategoryId;
    if (query != null && query.isNotEmpty) params['query'] = query;
    if (sortBy != null) params['sort_by'] = sortBy;
    if (minRating != null) params['min_rating'] = minRating;

    final response = await _api.get(
      ApiEndpoints.search,
      queryParameters: params,
    );
    final list = response.data is List
        ? response.data
        : response.data['data'] ?? [];
    return (list as List).map((e) => ArtisanModel.fromJson(e)).toList();
  }
}
