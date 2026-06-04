import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../data/models/artisan_model.dart';
import '../data/repositories/search_repository.dart';

class SearchState {
  final List<ArtisanModel> results;
  final bool isLoading;
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
  }) async {
    state = SearchState(
      isLoading: true,
      query: query,
      categoryId: categoryId,
      subcategoryId: subcategoryId,
      radius: radius,
      sortBy: sortBy,
      minRating: minRating,
      latitude: latitude,
      longitude: longitude,
    );

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
      );
      state = state.copyWith(
        results: results,
        isLoading: false,
        page: 1,
        hasMore: results.length >= AppConfig.defaultPageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore({double? latitude, double? longitude}) async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

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
      );
      state = state.copyWith(
        results: [...state.results, ...results],
        isLoading: false,
        page: nextPage,
        hasMore: results.length >= AppConfig.defaultPageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = const SearchState();
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
    updated[index] = current.copyWith(
      isAvailable: true,
      latitude: latitude ?? current.latitude,
      longitude: longitude ?? current.longitude,
      locationUpdatedAt: locationUpdatedAt ?? current.locationUpdatedAt,
    );

    state = state.copyWith(results: updated);
  }
}
