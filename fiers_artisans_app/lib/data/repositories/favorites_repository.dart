import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/artisan_model.dart';

class FavoritesRepository {
  final ApiClient _api = ApiClient();

  Future<List<ArtisanModel>> getFavorites() async {
    final response = await _api.get(ApiEndpoints.clientFavorites);
    final list = response.data is List
        ? response.data as List
        : (response.data['data'] as List? ?? const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(ArtisanModel.fromJson)
        .toList();
  }

  Future<bool> getFavoriteStatus(String artisanUserId) async {
    final response = await _api.get(
      ApiEndpoints.clientFavoriteStatus(artisanUserId),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final raw = data['is_favorite'] ?? data['isFavorite'];
      return raw == true;
    }
    return false;
  }

  Future<bool> setFavoriteStatus({
    required String artisanUserId,
    required bool isFavorite,
  }) async {
    final response = isFavorite
        ? await _api.put(
            ApiEndpoints.clientFavoriteByArtisanUser(artisanUserId),
          )
        : await _api.delete(
            ApiEndpoints.clientFavoriteByArtisanUser(artisanUserId),
          );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final raw = data['is_favorite'] ?? data['isFavorite'];
      return raw == true;
    }
    return isFavorite;
  }
}
