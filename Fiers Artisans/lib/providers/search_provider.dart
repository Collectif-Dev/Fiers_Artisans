import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/artisan_model.dart';
import '../data/repositories/search_repository.dart';

class SearchState {
  final List<ArtisanModel> results;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? query;
  final String? categoryId;
  final String? subcategoryId;
  final double? radius;
  final String? sortBy;
  final double? minRating;
  final double? latitude;
  final double? longitude;
  final int page;
  final bool hasMore;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.query,
    this.categoryId,
    this.subcategoryId,
    this.radius,
    this.sortBy,
    this.minRating,
    this.latitude,
    this.longitude,
    this.page = 1,
    this.hasMore = true,
  });

  SearchState copyWith({
    List<ArtisanModel>? results,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? query,
    String? categoryId,
    String? subcategoryId,
    double? radius,
    String? sortBy,
    double? minRating,
    double? latitude,
    double? longitude,
    int? page,
    bool? hasMore,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      query: query ?? this.query,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      radius: radius ?? this.radius,
      sortBy: sortBy ?? this.sortBy,
      minRating: minRating ?? this.minRating,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  return SearchNotifier();
});

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchRepository _repo = SearchRepository();
  int _activeSearchRequestId = 0;
  static const int _searchPageSize = 50;

  SearchNotifier() : super(const SearchState());

  Future<void> search({
    double? latitude,
    double? longitude,
    double? radius,
    String? categoryId,
    String? subcategoryId,
    String? query,
    String? sortBy,
    double? minRating,
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final requestId = ++_activeSearchRequestId;
    if (silent) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: null,
        query: query,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        radius: radius,
        sortBy: sortBy,
        minRating: minRating,
        latitude: latitude,
        longitude: longitude,
        page: 1,
        hasMore: true,
      );
    } else {
      state = SearchState(
        isLoading: true,
        isLoadingMore: false,
        query: query,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        radius: radius,
        sortBy: sortBy,
        minRating: minRating,
        latitude: latitude,
        longitude: longitude,
      );
    }

    try {
      final results = await _repo.searchArtisans(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        query: query,
        sortBy: sortBy,
        minRating: minRating,
        page: 1,
        limit: _searchPageSize,
        forceRefresh: forceRefresh,
      );
      if (requestId != _activeSearchRequestId) {
        return;
      }
      final uniqueResults = _uniqueByUserId(results);
      state = state.copyWith(
        results: uniqueResults,
        isLoading: false,
        isLoadingMore: false,
        error: null,
        page: 1,
        hasMore: results.length >= _searchPageSize,
      );
    } catch (e) {
      if (requestId != _activeSearchRequestId) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore({double? latitude, double? longitude}) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final nextPage = state.page + 1;
      final results = await _repo.searchArtisans(
        latitude: latitude,
        longitude: longitude,
        radius: state.radius,
        categoryId: state.categoryId,
        subcategoryId: state.subcategoryId,
        query: state.query,
        sortBy: state.sortBy,
        minRating: state.minRating,
        page: nextPage,
        limit: _searchPageSize,
      );
      final merged = _mergeUniqueByUserId(state.results, results);
      state = state.copyWith(
        results: merged,
        isLoading: false,
        isLoadingMore: false,
        page: nextPage,
        hasMore: results.length >= _searchPageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  void clear() {
    state = const SearchState();
  }

  List<ArtisanModel> _uniqueByUserId(List<ArtisanModel> items) {
    final deduped = <ArtisanModel>[];
    final seen = <String>{};

    for (final item in items) {
      if (item.userId.isEmpty) {
        continue;
      }
      if (seen.add(item.userId)) {
        deduped.add(item);
      }
    }

    return deduped;
  }

  List<ArtisanModel> _mergeUniqueByUserId(
    List<ArtisanModel> current,
    List<ArtisanModel> incoming,
  ) {
    final merged = <ArtisanModel>[];
    final indexByUserId = <String, int>{};

    for (final artisan in current) {
      if (artisan.userId.isEmpty) {
        continue;
      }
      indexByUserId[artisan.userId] = merged.length;
      merged.add(artisan);
    }

    for (final artisan in incoming) {
      if (artisan.userId.isEmpty) {
        continue;
      }

      final existingIndex = indexByUserId[artisan.userId];
      if (existingIndex == null) {
        indexByUserId[artisan.userId] = merged.length;
        merged.add(artisan);
      } else {
        merged[existingIndex] = artisan;
      }
    }

    return merged;
  }

  void applyRealtimeVisibilityUpdate({
    required String artisanUserId,
    required bool isAvailable,
    double? latitude,
    double? longitude,
    DateTime? locationUpdatedAt,
  }) {
    final index = state.results.indexWhere((a) => a.userId == artisanUserId);
    if (index < 0) {
      return;
    }

    if (!isAvailable) {
      final filtered = state.results
          .where((artisan) => artisan.userId != artisanUserId)
          .toList(growable: false);
      state = state.copyWith(results: filtered);
      return;
    }

    final updated = [...state.results];
    final current = updated[index];
    final nextLatitude = latitude ?? current.latitude;
    final nextLongitude = longitude ?? current.longitude;
    final nextLocationUpdatedAt =
        locationUpdatedAt ?? current.locationUpdatedAt;
    final hasChanged =
        !current.isAvailable ||
        current.latitude != nextLatitude ||
        current.longitude != nextLongitude ||
        current.locationUpdatedAt != nextLocationUpdatedAt;
    if (!hasChanged) {
      return;
    }

    updated[index] = current.copyWith(
      isAvailable: true,
      latitude: nextLatitude,
      longitude: nextLongitude,
      locationUpdatedAt: nextLocationUpdatedAt,
    );

    state = state.copyWith(results: updated);
  }
}
