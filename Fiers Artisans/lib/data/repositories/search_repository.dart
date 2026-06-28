import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/artisan_model.dart';

class _SearchCacheEntry {
  final List<ArtisanModel> results;
  final DateTime expiresAt;

  const _SearchCacheEntry({required this.results, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class SearchRepository {
  final ApiClient _api = ApiClient();
  final Map<String, _SearchCacheEntry> _cache = {};
  final Map<String, Future<List<ArtisanModel>>> _inflight = {};

  static const Duration _cacheTtl = Duration(seconds: 25);

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
    bool forceRefresh = false,
  }) async {
    final safeLatitude = _sanitizeLatitude(latitude);
    final safeLongitude = _sanitizeLongitude(longitude);
    final safeRadius = _sanitizeRadius(radius);
    final safeQuery = _sanitizeQuery(query);

    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (safeLatitude != null) params['lat'] = safeLatitude;
    if (safeLongitude != null) params['lng'] = safeLongitude;
    if (safeRadius != null) params['radius_km'] = safeRadius;
    if (categoryId != null) params['category'] = categoryId;
    if (subcategoryId != null) params['subcategory'] = subcategoryId;
    if (safeQuery != null && safeQuery.isNotEmpty) params['query'] = safeQuery;
    if (sortBy != null) params['sort_by'] = sortBy;
    if (minRating != null) params['min_rating'] = minRating;

    final cacheKey = _buildCacheKey(
      latitude: safeLatitude,
      longitude: safeLongitude,
      radius: safeRadius,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      query: safeQuery,
      sortBy: sortBy,
      minRating: minRating,
      page: page,
      limit: limit,
    );

    if (!forceRefresh) {
      final cached = _cache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.results;
      }

      final pending = _inflight[cacheKey];
      if (pending != null) {
        return pending;
      }
    }

    final request = _fetchSearch(params, cacheKey);
    _inflight[cacheKey] = request;

    try {
      return await request;
    } finally {
      _inflight.remove(cacheKey);
    }
  }

  Future<List<ArtisanModel>> _fetchSearch(
    Map<String, dynamic> params,
    String cacheKey,
  ) async {
    final response = await _api.get(
      ApiEndpoints.search,
      queryParameters: params,
    );
    final list = response.data is List
        ? response.data
        : response.data['data'] ?? [];
    final mapped = (list as List)
        .map((e) => ArtisanModel.fromJson(e))
        .toList(growable: false);

    _cache[cacheKey] = _SearchCacheEntry(
      results: mapped,
      expiresAt: DateTime.now().add(_cacheTtl),
    );

    return mapped;
  }

  String _buildCacheKey({
    double? latitude,
    double? longitude,
    double? radius,
    String? categoryId,
    String? subcategoryId,
    String? query,
    String? sortBy,
    double? minRating,
    required int page,
    required int limit,
  }) {
    return [
      latitude?.toStringAsFixed(4) ?? '-',
      longitude?.toStringAsFixed(4) ?? '-',
      radius?.toStringAsFixed(2) ?? '-',
      categoryId ?? '-',
      subcategoryId ?? '-',
      query?.trim().toLowerCase() ?? '-',
      sortBy ?? '-',
      minRating?.toStringAsFixed(2) ?? '-',
      page.toString(),
      limit.toString(),
    ].join('|');
  }

  double? _sanitizeLatitude(double? value) {
    if (value == null || !value.isFinite) return null;
    return value.clamp(-90, 90).toDouble();
  }

  double? _sanitizeLongitude(double? value) {
    if (value == null || !value.isFinite) return null;
    return value.clamp(-180, 180).toDouble();
  }

  double? _sanitizeRadius(double? value) {
    if (value == null || !value.isFinite) return null;
    return value.clamp(1, 120).toDouble();
  }

  String? _sanitizeQuery(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= 120) return trimmed;
    return trimmed.substring(0, 120);
  }
}
