import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/artisan_model.dart';
import '../data/repositories/favorites_repository.dart';
import 'session_scope_provider.dart';
import '../services/chat_realtime_service.dart';

class FavoritesState {
  final List<ArtisanModel> favorites;
  final Set<String> favoriteUserIds;
  final Set<String> loadingUserIds;
  final bool isLoading;
  final String? error;

  const FavoritesState({
    this.favorites = const [],
    this.favoriteUserIds = const {},
    this.loadingUserIds = const {},
    this.isLoading = false,
    this.error,
  });

  FavoritesState copyWith({
    List<ArtisanModel>? favorites,
    Set<String>? favoriteUserIds,
    Set<String>? loadingUserIds,
    bool? isLoading,
    String? error,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      favoriteUserIds: favoriteUserIds ?? this.favoriteUserIds,
      loadingUserIds: loadingUserIds ?? this.loadingUserIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
      ref.watch(sessionEpochProvider);
      return FavoritesNotifier();
    });

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final FavoritesRepository _repo = FavoritesRepository();
  final ChatRealtimeService _realtime = ChatRealtimeService();
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  FavoritesNotifier() : super(const FavoritesState()) {
    _realtimeSub = _realtime.domainEvents.listen(_onRealtimeEvent);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> loadFavorites() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final favorites = await _repo.getFavorites();
      state = state.copyWith(
        favorites: favorites,
        favoriteUserIds: favorites.map((artisan) => artisan.userId).toSet(),
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void patchFavoriteFromArtisan(ArtisanModel artisan) {
    if (!state.favoriteUserIds.contains(artisan.userId)) return;

    final index = state.favorites.indexWhere(
      (item) => item.userId == artisan.userId,
    );
    if (index < 0) return;

    final updatedFavorites = [...state.favorites];
    updatedFavorites[index] = updatedFavorites[index].copyWith(
      averageRating: artisan.averageRating,
      totalReviews: artisan.totalReviews,
    );

    state = state.copyWith(favorites: updatedFavorites);
  }

  Future<bool> refreshFavoriteStatus(String artisanUserId) async {
    final loadingSet = {...state.loadingUserIds, artisanUserId};
    state = state.copyWith(loadingUserIds: loadingSet);
    try {
      final isFavorite = await _repo.getFavoriteStatus(artisanUserId);
      final ids = {...state.favoriteUserIds};
      if (isFavorite) {
        ids.add(artisanUserId);
      } else {
        ids.remove(artisanUserId);
      }
      final afterLoading = {...state.loadingUserIds}..remove(artisanUserId);
      state = state.copyWith(
        favoriteUserIds: ids,
        loadingUserIds: afterLoading,
      );
      return isFavorite;
    } catch (_) {
      final afterLoading = {...state.loadingUserIds}..remove(artisanUserId);
      state = state.copyWith(loadingUserIds: afterLoading);
      return state.favoriteUserIds.contains(artisanUserId);
    }
  }

  Future<bool> toggleFavorite(ArtisanModel artisan) async {
    final artisanUserId = artisan.userId;
    final current = state.favoriteUserIds.contains(artisanUserId);
    final target = !current;

    final loadingSet = {...state.loadingUserIds, artisanUserId};
    state = state.copyWith(loadingUserIds: loadingSet, error: null);

    try {
      final updated = await _repo.setFavoriteStatus(
        artisanUserId: artisanUserId,
        isFavorite: target,
      );

      final ids = {...state.favoriteUserIds};
      final favorites = [...state.favorites];

      if (updated) {
        ids.add(artisanUserId);
        if (!favorites.any((item) => item.userId == artisanUserId)) {
          favorites.insert(0, artisan);
        }
      } else {
        ids.remove(artisanUserId);
        favorites.removeWhere((item) => item.userId == artisanUserId);
      }

      final afterLoading = {...state.loadingUserIds}..remove(artisanUserId);
      state = state.copyWith(
        favorites: favorites,
        favoriteUserIds: ids,
        loadingUserIds: afterLoading,
      );
      return updated;
    } catch (e) {
      final afterLoading = {...state.loadingUserIds}..remove(artisanUserId);
      state = state.copyWith(loadingUserIds: afterLoading, error: e.toString());
      return current;
    }
  }

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (event.event != 'favoriteStatusUpdated') {
      return;
    }
    final artisanUserId = event.payload['artisanUserId']?.toString();
    if (artisanUserId == null || artisanUserId.isEmpty) {
      return;
    }
    final isFavorite = event.payload['isFavorite'] == true;

    final ids = {...state.favoriteUserIds};
    final favorites = [...state.favorites];

    if (isFavorite) {
      ids.add(artisanUserId);
      state = state.copyWith(favoriteUserIds: ids);
      loadFavorites();
      return;
    } else {
      ids.remove(artisanUserId);
      favorites.removeWhere((item) => item.userId == artisanUserId);
    }

    state = state.copyWith(favoriteUserIds: ids, favorites: favorites);
  }
}
