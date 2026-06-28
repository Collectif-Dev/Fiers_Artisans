import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/app_config.dart';
import '../../data/models/artisan_model.dart';
import '../../providers/search_provider.dart';
import '../../providers/categories_provider.dart';
import '../../data/models/category_model.dart';
import '../../services/location_service.dart';
import '../../services/chat_realtime_service.dart';
import '../../services/map_visibility_realtime_service.dart';
import '../common/app_text_field.dart';
import '../common/artisan_card.dart';
import '../common/category_chip.dart';
import '../common/skeleton_loader.dart';
import '../common/empty_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialParams;
  const SearchScreen({super.key, this.initialParams});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const double _nearbyRadiusKm = 10;
  static const double _urgentRadiusKm = 20;
  static const double _topRatedRadiusKm = 20;
  static const double _topRatedMinRating = 3;
  static const double _initialMapZoom = 12;
  static const double _minMapZoom = 10;
  static const double _maxMapZoom = 19;
  static const double _clusterTapZoomStep = 1.2;

  final _searchCtrl = TextEditingController();
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final MapVisibilityRealtimeService _mapRealtimeService =
      MapVisibilityRealtimeService();
  final ChatRealtimeService _chatRealtimeService = ChatRealtimeService();

  StreamSubscription<Map<String, dynamic>>? _visibilitySubscription;
  StreamSubscription<ChatRealtimeEvent>? _domainEventSubscription;
  Timer? _availabilityRefreshDebounce;
  Timer? _queryDebounce;

  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  String? _sortBy;
  double? _minRating;
  bool _isNearbyPreset = false;
  bool _showMap = false;
  double _radius = AppConfig.defaultSearchRadius;
  double? _latitude;
  double? _longitude;
  bool _locationLoading = false;
  double _currentMapZoom = _initialMapZoom;
  DateTime? _lastRealtimeRefreshAt;
  String? _selectedMapArtisanId;
  String _cachedMarkersKey = '';
  List<Marker> _cachedMarkers = const [];

  static const Map<String, String> _accentReplacements = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };

  String _normalizeSearchTerm(String value) {
    var normalized = value.trim().toLowerCase();
    _accentReplacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });

    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  bool _matchesTerm(String haystack, String query) {
    final normalizedHaystack = _normalizeSearchTerm(haystack);
    final normalizedQuery = _normalizeSearchTerm(query);
    if (normalizedHaystack.isEmpty || normalizedQuery.isEmpty) {
      return false;
    }
    return normalizedHaystack.contains(normalizedQuery) ||
        normalizedQuery.contains(normalizedHaystack);
  }

  ({String? categoryId, String? subcategoryId}) _resolveQueryFilters(
    List<CategoryModel> categories,
    String rawQuery,
    String? currentCategoryId,
    String? currentSubcategoryId,
  ) {
    if (rawQuery.trim().isEmpty) {
      return (
        categoryId: currentCategoryId,
        subcategoryId: currentSubcategoryId,
      );
    }

    var resolvedCategoryId = currentCategoryId;
    var resolvedSubcategoryId = currentSubcategoryId;

    if (resolvedSubcategoryId == null) {
      final candidateCategories = resolvedCategoryId == null
          ? categories
          : categories.where((c) => c.id == resolvedCategoryId).toList();

      for (final category in candidateCategories) {
        for (final sub in category.subcategories) {
          final slug = sub.slug ?? '';
          if (_matchesTerm(sub.name, rawQuery) ||
              _matchesTerm(slug, rawQuery)) {
            resolvedCategoryId = category.id;
            resolvedSubcategoryId = sub.id;
            break;
          }
        }
        if (resolvedSubcategoryId != null) break;
      }
    }

    if (resolvedCategoryId == null) {
      for (final category in categories) {
        final slug = category.slug ?? '';
        if (_matchesTerm(category.name, rawQuery) ||
            _matchesTerm(slug, rawQuery)) {
          resolvedCategoryId = category.id;
          break;
        }
      }
    }

    return (
      categoryId: resolvedCategoryId,
      subcategoryId: resolvedSubcategoryId,
    );
  }

  String _categoryLabel(List<CategoryModel> categories, String? categoryId) {
    if (categoryId == null) return 'search.all_categories'.tr();

    for (final category in categories) {
      if (category.id == categoryId) return category.name;
    }
    return 'search.all_categories'.tr();
  }

  String _tradeLabel(List<SubcategoryModel> trades, String? subcategoryId) {
    if (subcategoryId == null) return 'search.all_trades'.tr();

    for (final trade in trades) {
      if (trade.id == subcategoryId) return trade.name;
    }
    return 'search.all_trades'.tr();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(categoriesProvider.notifier).load();

      // Handle initial params from dashboard CTAs
      if (widget.initialParams != null) {
        final params = widget.initialParams!;
        final cat = params['categoryId'] as String?;
        if (cat != null) _selectedCategoryId = cat;
        final subcat = params['subcategoryId'] as String?;
        if (subcat != null) _selectedSubcategoryId = subcat;
        final initialQuery = params['query']?.toString().trim();
        if (initialQuery != null && initialQuery.isNotEmpty) {
          _searchCtrl.text = initialQuery;
        }

        final preset = params['preset']?.toString();

        if (preset == 'urgent') {
          _radius = _urgentRadiusKm;
        } else if (preset == 'nearby') {
          _isNearbyPreset = true;
          _radius = _nearbyRadiusKm;
        } else if (preset == 'topRated') {
          _sortBy = 'rating';
          _minRating = _topRatedMinRating;
          _radius = _topRatedRadiusKm;
        }

        if (preset == null && params['topRated'] == true) {
          _sortBy = 'rating';
          _minRating = _topRatedMinRating;
          _radius = _topRatedRadiusKm;
        }
        if (preset == null && params['nearby'] == true) {
          _isNearbyPreset = true;
          _radius = _nearbyRadiusKm;
        }
      }

      _initLocation();
      _initMapVisibilityRealtime();
    });
  }

  Future<void> _initMapVisibilityRealtime() async {
    await _mapRealtimeService.connect();
    _mapRealtimeService.updateFilterRooms(
      categoryId: _selectedCategoryId,
      subcategoryId: _selectedSubcategoryId,
    );

    _visibilitySubscription = _mapRealtimeService.visibilityUpdates.listen(
      _handleRealtimeVisibilityUpdate,
    );
    _domainEventSubscription = _chatRealtimeService.domainEvents.listen(
      _handleDomainRealtimeEvent,
    );
  }

  void _handleRealtimeVisibilityUpdate(Map<String, dynamic> payload) {
    final artisanUserId =
        payload['artisan_user_id']?.toString() ??
        payload['artisanUserId']?.toString() ??
        '';

    if (artisanUserId.isEmpty) {
      return;
    }

    final isAvailable = _toBool(
      payload['is_available'] ?? payload['isAvailable'],
    );
    final latitude = _toDouble(payload['latitude']);
    final longitude = _toDouble(payload['longitude']);

    DateTime? locationUpdatedAt;
    final rawUpdatedAt =
        payload['location_updated_at'] ?? payload['locationUpdatedAt'];
    if (rawUpdatedAt != null) {
      locationUpdatedAt = DateTime.tryParse(rawUpdatedAt.toString());
    }

    ref
        .read(searchProvider.notifier)
        .applyRealtimeVisibilityUpdate(
          artisanUserId: artisanUserId,
          isAvailable: isAvailable,
          latitude: latitude,
          longitude: longitude,
          locationUpdatedAt: locationUpdatedAt,
        );

    if (isAvailable) {
      _availabilityRefreshDebounce?.cancel();
      _availabilityRefreshDebounce = Timer(const Duration(seconds: 2), () {
        final now = DateTime.now();
        final elapsed = _lastRealtimeRefreshAt == null
            ? null
            : now.difference(_lastRealtimeRefreshAt!);
        if (elapsed != null && elapsed < const Duration(milliseconds: 900)) {
          return;
        }
        _lastRealtimeRefreshAt = now;
        _search(silent: true);
      });
    }
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _initLocation() async {
    setState(() => _locationLoading = true);
    final snapshot = await _locationService.getCurrentLocation(
      fallbackToAbidjan: true,
    );

    if (snapshot != null) {
      _latitude = snapshot.latitude;
      _longitude = snapshot.longitude;
    }

    setState(() => _locationLoading = false);
    _search();
  }

  void _handleDomainRealtimeEvent(ChatRealtimeEvent event) {
    final shouldRefreshSearch = switch (event.event) {
      'artisanProfileUpdated' => true,
      'artisanReviewsUpdated' => true,
      'artisanPortfolioUpdated' => true,
      'artisanSubscriptionUpdated' => true,
      _ => false,
    };

    if (!shouldRefreshSearch) return;
    _availabilityRefreshDebounce?.cancel();
    _availabilityRefreshDebounce = Timer(
      const Duration(milliseconds: 700),
      () => _search(silent: true),
    );
  }

  @override
  void dispose() {
    _visibilitySubscription?.cancel();
    _domainEventSubscription?.cancel();
    _availabilityRefreshDebounce?.cancel();
    _queryDebounce?.cancel();
    _mapRealtimeService.disconnect();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_SheetPickerOption?> _showOptionPicker({
    required BuildContext context,
    required String title,
    required List<_SheetPickerOption> options,
    required String? selectedValue,
  }) {
    return showModalBottomSheet<_SheetPickerOption>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (options.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'auth.no_categories_available'.tr(),
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option.value == selectedValue;

                        return ListTile(
                          title: Text(option.label),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () => Navigator.pop(ctx, option),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(searchProvider);
    final catState = ref.watch(categoriesProvider);

    CategoryModel? selectedCategory;
    if (_selectedCategoryId != null) {
      for (final category in catState.categories) {
        if (category.id == _selectedCategoryId) {
          selectedCategory = category;
          break;
        }
      }
    }
    final List<SubcategoryModel> availableSubcategories =
        selectedCategory?.subcategories ?? const [];

    String? selectedCategoryName;
    if (_selectedCategoryId != null) {
      for (final category in catState.categories) {
        if (category.id == _selectedCategoryId) {
          selectedCategoryName = category.name;
          break;
        }
      }
    }

    String? selectedSubcategoryName;
    if (_selectedSubcategoryId != null) {
      for (final subcategory in availableSubcategories) {
        if (subcategory.id == _selectedSubcategoryId) {
          selectedSubcategoryName = subcategory.name;
          break;
        }
      }
    }

    final hasPartialResults = searchState.hasMore || searchState.isLoadingMore;
    final resultsCountText =
        '${searchState.results.length}${hasPartialResults ? '+' : ''}';

    return Scaffold(
      appBar: AppBar(title: Text('search.title'.tr())),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppTextField(
              controller: _searchCtrl,
              hint: 'search.placeholder'.tr(),
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: (_) {
                _queryDebounce?.cancel();
                _queryDebounce = Timer(
                  const Duration(milliseconds: 350),
                  _search,
                );
              },
              onSubmitted: (_) => _search(),
              suffix: IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20),
                onPressed: _showFilters,
              ),
            ),
          ),

          // Category chips
          if (catState.isLoading && catState.categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            )
          else if (catState.categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: catState.categories.length,
                itemBuilder: (context, index) {
                  final cat = catState.categories[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      label: cat.name,
                      isSelected: _selectedCategoryId == cat.id,
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = _selectedCategoryId == cat.id
                              ? null
                              : cat.id;
                          _selectedSubcategoryId = null;
                        });
                        _search();
                      },
                    ),
                  );
                },
              ),
            ),
          if (catState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'auth.categories_load_error'.tr(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(categoriesProvider.notifier).refresh(),
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),

          // Active filter chips
          if (_sortBy != null ||
              _selectedCategoryId != null ||
              _selectedSubcategoryId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_selectedCategoryId != null)
                    InputChip(
                      label: Text(selectedCategoryName ?? 'search.filter'.tr()),
                      avatar: const Icon(Icons.category_outlined, size: 16),
                      selected: true,
                      onDeleted: () {
                        setState(() {
                          _selectedCategoryId = null;
                          _selectedSubcategoryId = null;
                        });
                        _search();
                      },
                    ),
                  if (_selectedSubcategoryId != null)
                    InputChip(
                      label: Text(
                        selectedSubcategoryName ?? 'auth.profession'.tr(),
                      ),
                      avatar: const Icon(Icons.handyman_outlined, size: 16),
                      selected: true,
                      onDeleted: () {
                        setState(() => _selectedSubcategoryId = null);
                        _search();
                      },
                    ),
                  if (_sortBy == 'rating')
                    InputChip(
                      label: Text('search.top_rated'.tr()),
                      avatar: const Icon(Icons.star_rounded, size: 16),
                      selected: true,
                      onDeleted: () {
                        setState(() {
                          _sortBy = null;
                          _minRating = null;
                        });
                        _search();
                      },
                    ),
                ],
              ),
            ),

          // Radius indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'search.radius'.tr(
                    namedArgs: {'km': _radius.toStringAsFixed(0)},
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                if (searchState.results.isNotEmpty)
                  Text(
                    '  •  ${'search.results'.tr(namedArgs: {'count': resultsCountText})}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                ChoiceChip(
                  selected: !_showMap,
                  label: Text('search.view_list'.tr()),
                  avatar: const Icon(Icons.view_agenda_rounded, size: 18),
                  onSelected: (_) => setState(() => _showMap = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: _showMap,
                  label: Text('search.view_map'.tr()),
                  avatar: const Icon(Icons.map_outlined, size: 18),
                  onSelected: (_) => setState(() => _showMap = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Results
          Expanded(
            child: _locationLoading || searchState.isLoading
                ? ListView.builder(
                    itemCount: 5,
                    itemBuilder: (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SkeletonLoader.artisanCard(),
                    ),
                  )
                : searchState.error != null && searchState.results.isEmpty
                ? EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'error.generic'.tr(),
                    subtitle: searchState.error,
                    actionLabel: 'common.retry'.tr(),
                    onAction: _search,
                  )
                : searchState.results.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'search.no_results'.tr(),
                    actionLabel: 'common.retry'.tr(),
                    onAction: _search,
                  )
                : _showMap
                ? _buildMapResults(searchState)
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: searchState.results.length,
                    itemBuilder: (context, index) {
                      final artisan = searchState.results[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ArtisanCard(
                          artisan: artisan,
                          onTap: () =>
                              context.push('/client/artisan/${artisan.userId}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapResults(SearchState searchState) {
    final mapArtisans = _deduplicateArtisansByUserId(
      searchState.results
          .where(
            (a) =>
                a.latitude != null &&
                a.longitude != null &&
                a.latitude!.isFinite &&
                a.longitude!.isFinite &&
                a.latitude! >= -90 &&
                a.latitude! <= 90 &&
                a.longitude! >= -180 &&
                a.longitude! <= 180,
          )
          .toList(growable: false),
    );

    if (_latitude == null || _longitude == null) {
      return EmptyState(
        icon: Icons.location_off_rounded,
        title: 'search.position_unavailable'.tr(),
        subtitle: 'search.enable_location_map'.tr(),
        actionLabel: 'common.retry'.tr(),
        onAction: _initLocation,
      );
    }

    if (mapArtisans.isEmpty) {
      return EmptyState(
        icon: Icons.map_outlined,
        title: 'search.none_geolocated'.tr(),
        subtitle: 'search.adjust_filters'.tr(),
        actionLabel: 'common.retry'.tr(),
        onAction: _search,
      );
    }

    final center = LatLng(_latitude!, _longitude!);
    final selectedArtisanId =
        mapArtisans.any((artisan) => artisan.userId == _selectedMapArtisanId)
        ? _selectedMapArtisanId
        : null;
    final clusters = _clusterArtisans(mapArtisans, _currentMapZoom);
    final markerColor = Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;
    final isPartialCount = searchState.hasMore || searchState.isLoadingMore;
    final zoomPercent = _zoomUsagePercent(_currentMapZoom);
    _scheduleMapPrefetch(searchState);
    final mapMarkers = _buildMarkers(
      center: center,
      clusters: clusters,
      markerColor: markerColor,
      isPartialCount: isPartialCount,
      selectedArtisanId: selectedArtisanId,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _initialMapZoom,
                minZoom: _minMapZoom,
                maxZoom: _maxMapZoom,
                onTap: (_, _) {
                  if (_selectedMapArtisanId == null) return;
                  setState(() {
                    _selectedMapArtisanId = null;
                    _cachedMarkersKey = '';
                  });
                },
                onPositionChanged: (position, _) {
                  final zoom = position.zoom
                      .clamp(_minMapZoom, _maxMapZoom)
                      .toDouble();
                  if ((zoom - _currentMapZoom).abs() < 0.15) return;
                  setState(() {
                    _currentMapZoom = zoom;
                    _cachedMarkersKey = '';
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fiers.artisans.app',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: _radius * 1000,
                      useRadiusInMeter: true,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.12),
                      borderStrokeWidth: 1.5,
                      borderColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                MarkerLayer(markers: mapMarkers),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.84),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${zoomPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 78,
                        child: LinearProgressIndicator(
                          value: (zoomPercent / 100).clamp(0, 1),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: colorScheme.onSurface.withValues(
                            alpha: 0.14,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 12,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _recenterToUserPosition,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.my_location_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers({
    required LatLng center,
    required List<_MapCluster> clusters,
    required Color markerColor,
    required bool isPartialCount,
    required String? selectedArtisanId,
  }) {
    final key = _buildMarkersCacheKey(
      center,
      clusters,
      markerColor,
      isPartialCount,
      selectedArtisanId,
    );
    if (key == _cachedMarkersKey && _cachedMarkers.isNotEmpty) {
      return _cachedMarkers;
    }

    final markers = <Marker>[
      ...clusters.map(
        (cluster) => _buildClusterMarker(
          cluster,
          markerColor,
          isPartialCount,
          selectedArtisanId,
        ),
      ),
      _buildUserLocationMarker(center, markerColor),
    ];

    _cachedMarkersKey = key;
    _cachedMarkers = List<Marker>.unmodifiable(markers);
    return _cachedMarkers;
  }

  String _buildMarkersCacheKey(
    LatLng center,
    List<_MapCluster> clusters,
    Color markerColor,
    bool isPartialCount,
    String? selectedArtisanId,
  ) {
    final buff = StringBuffer()
      ..write(center.latitude.toStringAsFixed(5))
      ..write(':')
      ..write(center.longitude.toStringAsFixed(5))
      ..write(':')
      ..write(_currentMapZoom.toStringAsFixed(2))
      ..write(':')
      ..write(markerColor.toARGB32())
      ..write(':')
      ..write(isPartialCount ? 'p' : 'f')
      ..write(':')
      ..write(selectedArtisanId ?? '-');

    for (final cluster in clusters) {
      buff
        ..write('|')
        ..write(cluster.count)
        ..write('@')
        ..write(cluster.center.latitude.toStringAsFixed(4))
        ..write(',')
        ..write(cluster.center.longitude.toStringAsFixed(4));
      if (!cluster.isCluster) {
        buff
          ..write('#')
          ..write(cluster.artisans.first.userId);
      }
    }

    return buff.toString();
  }

  List<_MapCluster> _clusterArtisans(List<ArtisanModel> artisans, double zoom) {
    if (artisans.isEmpty) {
      return const [];
    }

    final cellSize = _clusterCellSizeForZoom(zoom);
    if (cellSize <= 0) {
      return _expandExactOverlaps(artisans, zoom);
    }

    final buckets = <String, List<ArtisanModel>>{};
    for (final artisan in artisans) {
      final lat = artisan.latitude!;
      final lng = artisan.longitude!;
      final key = '${(lat / cellSize).floor()}:${(lng / cellSize).floor()}';
      buckets.putIfAbsent(key, () => <ArtisanModel>[]).add(artisan);
    }

    return buckets.values
        .map((group) {
          if (group.length == 1) {
            final artisan = group.first;
            return _MapCluster(
              center: LatLng(artisan.latitude!, artisan.longitude!),
              artisans: group,
            );
          }

          var latSum = 0.0;
          var lngSum = 0.0;
          for (final artisan in group) {
            latSum += artisan.latitude!;
            lngSum += artisan.longitude!;
          }

          return _MapCluster(
            center: LatLng(latSum / group.length, lngSum / group.length),
            artisans: group,
          );
        })
        .toList(growable: false);
  }

  List<_MapCluster> _expandExactOverlaps(
    List<ArtisanModel> artisans,
    double zoom,
  ) {
    final groupedByCoordinate = <String, List<ArtisanModel>>{};

    for (final artisan in artisans) {
      final key =
          '${artisan.latitude!.toStringAsFixed(6)}:${artisan.longitude!.toStringAsFixed(6)}';
      groupedByCoordinate.putIfAbsent(key, () => <ArtisanModel>[]).add(artisan);
    }

    final expanded = <_MapCluster>[];
    for (final group in groupedByCoordinate.values) {
      if (group.length == 1) {
        final artisan = group.first;
        expanded.add(
          _MapCluster(
            center: LatLng(artisan.latitude!, artisan.longitude!),
            artisans: [artisan],
          ),
        );
        continue;
      }

      final centerLat = group.first.latitude!;
      final centerLng = group.first.longitude!;
      final radius = _overlapSpreadRadiusDegrees(zoom, group.length);
      final latCos = math.cos(centerLat * math.pi / 180).abs();
      final safeLngDivisor = latCos < 0.2 ? 0.2 : latCos;

      for (var i = 0; i < group.length; i++) {
        final angle = (2 * math.pi * i) / group.length;
        final latOffset = math.sin(angle) * radius;
        final lngOffset = (math.cos(angle) * radius) / safeLngDivisor;

        expanded.add(
          _MapCluster(
            center: LatLng(centerLat + latOffset, centerLng + lngOffset),
            artisans: [group[i]],
          ),
        );
      }
    }

    return expanded;
  }

  double _overlapSpreadRadiusDegrees(double zoom, int groupSize) {
    final zoomFactor = (_maxMapZoom / zoom).clamp(1.0, 1.35);
    final countFactor = 1 + ((groupSize - 2).clamp(0, 8) * 0.16);
    return 0.00010 * zoomFactor * countFactor;
  }

  List<ArtisanModel> _deduplicateArtisansByUserId(List<ArtisanModel> artisans) {
    final seen = <String>{};
    final unique = <ArtisanModel>[];

    for (final artisan in artisans) {
      if (artisan.userId.isEmpty) {
        continue;
      }
      if (seen.add(artisan.userId)) {
        unique.add(artisan);
      }
    }

    return unique;
  }

  double _clusterCellSizeForZoom(double zoom) {
    if (zoom >= 14.5) return 0;
    if (zoom >= 13) return 0.008;
    if (zoom >= 11.5) return 0.015;
    if (zoom >= 10) return 0.025;
    return 0.05;
  }

  Marker _buildClusterMarker(
    _MapCluster cluster,
    Color markerColor,
    bool isPartialCount,
    String? selectedArtisanId,
  ) {
    if (!cluster.isCluster) {
      return _buildArtisanMarker(
        cluster.artisans.first,
        markerColor,
        isSelected: selectedArtisanId == cluster.artisans.first.userId,
      );
    }

    return Marker(
      width: 52,
      height: 52,
      point: cluster.center,
      child: InkWell(
        onTap: () {
          if (_selectedMapArtisanId != null) {
            setState(() {
              _selectedMapArtisanId = null;
              _cachedMarkersKey = '';
            });
          }

          if (_currentMapZoom >= (_maxMapZoom - 0.05)) {
            return;
          }

          final targetZoom = (_currentMapZoom + _clusterTapZoomStep)
              .clamp(_minMapZoom, _maxMapZoom)
              .toDouble();
          _mapController.move(cluster.center, targetZoom);
        },
        child: Container(
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 7,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${cluster.count}${isPartialCount ? '+' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  double _zoomUsagePercent(double zoom) {
    final span = _maxMapZoom - _minMapZoom;
    if (span <= 0) return 100;
    final normalized = ((zoom - _minMapZoom) / span).clamp(0, 1);
    return normalized * 100;
  }

  void _scheduleMapPrefetch(SearchState searchState) {
    if (!searchState.hasMore ||
        searchState.isLoading ||
        searchState.isLoadingMore) {
      return;
    }

    Future.microtask(() {
      if (!mounted || !_showMap) return;
      ref
          .read(searchProvider.notifier)
          .loadMore(latitude: _latitude, longitude: _longitude);
    });
  }

  Marker _buildArtisanMarker(
    ArtisanModel artisan,
    Color markerColor, {
    required bool isSelected,
  }) {
    final point = LatLng(artisan.latitude!, artisan.longitude!);
    final colorScheme = Theme.of(context).colorScheme;

    return Marker(
      width: isSelected ? 196 : 42,
      height: isSelected ? 148 : 42,
      point: point,
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            if (isSelected)
              Positioned(
                bottom: 50,
                child: _buildMapArtisanPreviewCard(
                  artisan,
                  colorScheme,
                  markerColor,
                ),
              ),
            InkWell(
              onTap: () => _handleArtisanMarkerTap(artisan),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: markerColor, width: 1.8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.handyman_rounded,
                  size: 20,
                  color: markerColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleArtisanMarkerTap(ArtisanModel artisan) {
    if (_selectedMapArtisanId == artisan.userId) {
      context.push('/client/artisan/${artisan.userId}');
      return;
    }

    setState(() {
      _selectedMapArtisanId = artisan.userId;
      _cachedMarkersKey = '';
    });
  }

  Widget _buildMapArtisanPreviewCard(
    ArtisanModel artisan,
    ColorScheme colorScheme,
    Color accentColor,
  ) {
    final fullName = '${artisan.firstName} ${artisan.lastName}'.trim();
    final categoryText =
        artisan.displayCategory ?? artisan.categoryName ?? 'Categorie';
    final subcategoryText = artisan.displayTrade;
    final distanceText = artisan.distance == null
        ? '-- km'
        : '${artisan.distance!.toStringAsFixed(1)} km';
    final profilePhotoUrl = _safeHttpImageUrl(artisan.profilePhotoUrl);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _handleArtisanMarkerTap(artisan),
      child: Container(
        width: 176,
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: profilePhotoUrl != null
                      ? NetworkImage(profilePhotoUrl)
                      : null,
                  child: profilePhotoUrl == null
                      ? Icon(
                          Icons.person,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        )
                      : null,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    fullName.isEmpty ? 'Artisan' : fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$categoryText • $subcategoryText',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 13,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 2),
                Text(
                  artisan.averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                _statusPill(
                  label: 'C',
                  active: artisan.isCertified,
                  accentColor: accentColor,
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 4),
                _statusPill(
                  label: 'V',
                  active: artisan.isVerified,
                  accentColor: accentColor,
                  colorScheme: colorScheme,
                ),
                const Spacer(),
                Text(
                  distanceText,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required bool active,
    required Color accentColor,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.8),
      decoration: BoxDecoration(
        color: active
            ? accentColor.withValues(alpha: 0.2)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? label : '$label-',
        style: TextStyle(
          color: active ? accentColor : colorScheme.onSurfaceVariant,
          fontSize: 9.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Marker _buildUserLocationMarker(LatLng center, Color markerColor) {
    return Marker(
      width: 56,
      height: 56,
      point: center,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: markerColor.withValues(alpha: 0.2),
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.95),
                border: Border.all(color: markerColor, width: 2.4),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: markerColor,
                border: Border.all(color: Colors.white, width: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recenterToUserPosition() async {
    if (_locationLoading) {
      return;
    }

    final previousLatitude = _latitude;
    final previousLongitude = _longitude;

    final freshSnapshot = await _locationService.getCurrentLocation(
      fallbackToAbidjan: false,
      timeout: const Duration(seconds: 8),
    );
    if (freshSnapshot != null) {
      _latitude = freshSnapshot.latitude;
      _longitude = freshSnapshot.longitude;
    }

    if (_latitude == null || _longitude == null) {
      await _initLocation();
      if (!mounted || _latitude == null || _longitude == null) {
        return;
      }
    }

    final target = LatLng(_latitude!, _longitude!);
    final targetZoom = _currentMapZoom.clamp(_initialMapZoom, _maxMapZoom);
    _mapController.move(target, targetZoom);

    final shouldRefreshSearch = _hasLocationChangedSignificantly(
      previousLatitude: previousLatitude,
      previousLongitude: previousLongitude,
      currentLatitude: _latitude,
      currentLongitude: _longitude,
    );

    if (shouldRefreshSearch) {
      _search(silent: true, forceRefresh: true);
    }

    setState(() => _cachedMarkersKey = '');
  }

  bool _hasLocationChangedSignificantly({
    required double? previousLatitude,
    required double? previousLongitude,
    required double? currentLatitude,
    required double? currentLongitude,
  }) {
    if (previousLatitude == null ||
        previousLongitude == null ||
        currentLatitude == null ||
        currentLongitude == null) {
      return true;
    }

    final latDelta = (previousLatitude - currentLatitude).abs();
    final lngDelta = (previousLongitude - currentLongitude).abs();

    // ~55m threshold at equator to avoid noisy re-searches.
    return latDelta > 0.0005 || lngDelta > 0.0005;
  }

  String? _safeHttpImageUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(value);
    if (parsed == null) {
      return null;
    }

    final scheme = parsed.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    return value;
  }

  void _search({bool silent = false, bool forceRefresh = false}) {
    final queryText = _searchCtrl.text.trim();
    final categories = ref.read(categoriesProvider).categories;
    final resolved = _resolveQueryFilters(
      categories,
      queryText,
      _selectedCategoryId,
      _selectedSubcategoryId,
    );

    final effectiveCategoryId = resolved.categoryId;
    final effectiveSubcategoryId = resolved.subcategoryId;

    _mapRealtimeService.updateFilterRooms(
      categoryId: effectiveCategoryId,
      subcategoryId: effectiveSubcategoryId,
    );

    ref
        .read(searchProvider.notifier)
        .search(
          latitude: _latitude,
          longitude: _longitude,
          radius: _radius,
          categoryId: effectiveCategoryId,
          subcategoryId: effectiveSubcategoryId,
          query: queryText.isNotEmpty ? queryText : null,
          sortBy: _sortBy,
          minRating: _minRating,
          silent: silent,
          forceRefresh: forceRefresh,
        );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, modalRef, _) {
          final categoriesState = modalRef.watch(categoriesProvider);
          final categories = categoriesState.categories;

          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              CategoryModel? selectedCategoryForSheet;
              if (_selectedCategoryId != null) {
                for (final category in categories) {
                  if (category.id == _selectedCategoryId) {
                    selectedCategoryForSheet = category;
                    break;
                  }
                }
              }
              final availableSubcategoriesForSheet =
                  selectedCategoryForSheet?.subcategories ??
                  const <SubcategoryModel>[];
              final media = MediaQuery.of(ctx);

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                  child: SizedBox(
                    height: media.size.height * 0.82,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'search.filter'.tr(),
                            style: Theme.of(ctx).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 16),
                          if (categoriesState.error != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'auth.categories_load_error'.tr(),
                                    style: Theme.of(ctx).textTheme.bodySmall,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => modalRef
                                      .read(categoriesProvider.notifier)
                                      .refresh(),
                                  child: Text('common.retry'.tr()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'search.radius'.tr(
                                      namedArgs: {
                                        'km': _radius.toStringAsFixed(0),
                                      },
                                    ),
                                    style: Theme.of(ctx).textTheme.bodyMedium,
                                  ),
                                  Slider(
                                    value: _radius,
                                    min: 1,
                                    max: _isNearbyPreset
                                        ? _nearbyRadiusKm
                                        : AppConfig.maxSearchRadius,
                                    divisions:
                                        (_isNearbyPreset
                                                ? _nearbyRadiusKm
                                                : AppConfig.maxSearchRadius)
                                            .toInt() -
                                        1,
                                    label: '${_radius.toStringAsFixed(0)} km',
                                    onChanged: (v) {
                                      setState(() => _radius = v);
                                      setSheetState(() {});
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _SheetSelectField(
                                    label: 'home.categories'.tr(),
                                    icon: Icons.category_outlined,
                                    text: _categoryLabel(
                                      categories,
                                      _selectedCategoryId,
                                    ),
                                    enabled:
                                        !categoriesState.isLoading &&
                                        categories.isNotEmpty,
                                    helperText: categoriesState.isLoading
                                        ? 'common.loading'.tr()
                                        : (!categoriesState.isLoading &&
                                              categories.isEmpty)
                                        ? 'auth.no_categories_available'.tr()
                                        : null,
                                    onTap: () async {
                                      final selected = await _showOptionPicker(
                                        context: ctx,
                                        title: 'home.categories'.tr(),
                                        options: [
                                          _SheetPickerOption(
                                            value: null,
                                            label: 'search.all_categories'.tr(),
                                          ),
                                          ...categories.map(
                                            (c) => _SheetPickerOption(
                                              value: c.id,
                                              label: c.name,
                                            ),
                                          ),
                                        ],
                                        selectedValue: _selectedCategoryId,
                                      );

                                      if (selected == null || !mounted) return;
                                      setState(() {
                                        _selectedCategoryId = selected.value;
                                        _selectedSubcategoryId = null;
                                      });
                                      setSheetState(() {});
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _SheetSelectField(
                                    label: 'auth.profession'.tr(),
                                    icon: Icons.handyman_outlined,
                                    text: _tradeLabel(
                                      availableSubcategoriesForSheet,
                                      _selectedSubcategoryId,
                                    ),
                                    enabled:
                                        _selectedCategoryId != null &&
                                        availableSubcategoriesForSheet
                                            .isNotEmpty,
                                    helperText: _selectedCategoryId == null
                                        ? 'search.select_category_for_trade'
                                              .tr()
                                        : availableSubcategoriesForSheet.isEmpty
                                        ? 'auth.no_professions_available'.tr()
                                        : null,
                                    onTap: () async {
                                      final selected = await _showOptionPicker(
                                        context: ctx,
                                        title: 'auth.profession'.tr(),
                                        options: [
                                          _SheetPickerOption(
                                            value: null,
                                            label: 'search.all_trades'.tr(),
                                          ),
                                          ...availableSubcategoriesForSheet.map(
                                            (s) => _SheetPickerOption(
                                              value: s.id,
                                              label: s.name,
                                            ),
                                          ),
                                        ],
                                        selectedValue: _selectedSubcategoryId,
                                      );

                                      if (selected == null || !mounted) return;
                                      setState(() {
                                        _selectedSubcategoryId = selected.value;
                                      });
                                      setSheetState(() {});
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SwitchListTile(
                                    title: Text('search.top_rated'.tr()),
                                    subtitle: Text(
                                      'search.top_rated_desc'.tr(),
                                    ),
                                    value: _sortBy == 'rating',
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (v) {
                                      setState(() {
                                        _sortBy = v ? 'rating' : null;
                                        _minRating = v
                                            ? _topRatedMinRating
                                            : null;
                                      });
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _search();
                              },
                              child: Text('search.apply_filters'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MapCluster {
  final LatLng center;
  final List<ArtisanModel> artisans;

  const _MapCluster({required this.center, required this.artisans});

  bool get isCluster => artisans.length > 1;
  int get count => artisans.length;
}

class _SheetPickerOption {
  final String? value;
  final String label;

  const _SheetPickerOption({required this.value, required this.label});
}

class _SheetSelectField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String text;
  final bool enabled;
  final VoidCallback onTap;
  final String? helperText;

  const _SheetSelectField({
    required this.label,
    required this.icon,
    required this.text,
    required this.enabled,
    required this.onTap,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = enabled
        ? theme.inputDecorationTheme.enabledBorder?.borderSide.color ??
              theme.colorScheme.outlineVariant
        : theme.disabledColor.withValues(alpha: 0.4);
    final iconColor = enabled ? theme.iconTheme.color : theme.disabledColor;
    final textColor = enabled
        ? theme.textTheme.bodyLarge?.color
        : theme.disabledColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
              ],
            ),
          ),
        ),
        if (helperText != null && helperText!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
