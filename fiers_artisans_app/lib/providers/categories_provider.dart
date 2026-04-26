import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/category_model.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>((ref) {
      return CategoriesNotifier();
    });

class CategoriesState {
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;

  const CategoriesState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  CategoriesState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    String? error,
  }) {
    return CategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  CategoriesNotifier() : super(const CategoriesState());

  Future<void> load({bool force = false}) async {
    if (!force && state.categories.isNotEmpty) return; // cached
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiClient().get(ApiEndpoints.categories);
      final list = response.data is List
          ? response.data
          : response.data['data'] ?? [];
      final categories = (list as List)
          .map((e) => CategoryModel.fromJson(e))
          .toList();

      state = CategoriesState(categories: categories, isLoading: false);
    } catch (e) {
      state = CategoriesState(
        categories: const [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() => load(force: true);
}
