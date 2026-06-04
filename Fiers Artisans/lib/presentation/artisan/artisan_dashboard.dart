import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/manual_payment_model.dart';
import '../../data/repositories/artisan_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_manual_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/verification_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/chat_realtime_service.dart';
import '../../services/location_service.dart';
import '../common/recent_conversation_tile.dart';
import '../common/app_snackbar.dart';

class ArtisanDashboard extends ConsumerStatefulWidget {
  const ArtisanDashboard({super.key});

  @override
  ConsumerState<ArtisanDashboard> createState() => _ArtisanDashboardState();
}

class _ArtisanDashboardState extends ConsumerState<ArtisanDashboard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  bool _isAvailable = true;
  bool _isReviewMetricsLoading = true;
  bool _isStatsLoading = true;
  bool _hasStatsData = false;
  bool _hasReviewMetricsData = false;
  bool _isStatsBackgroundRefreshing = false;
  bool _isReviewMetricsBackgroundRefreshing = false;
  bool _isLocationMissing = false;
  bool _isStatusCardsHydrating = true;
  double _avgRating = 0;
  int _totalReviews = 0;
  int _experienceYears = 0;
  int _profileViews48h = 0;
  String? _categoryName;
  String? _subcategoryName;
  String? _businessName;
  final ApiClient _api = ApiClient();
  final ArtisanRepository _artisanRepository = ArtisanRepository();
  final LocationService _locationService = LocationService();
  final ChatRealtimeService _realtime = ChatRealtimeService();
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    Future.microtask(() {
      _bootstrapDashboard();
    });
    _realtimeSub = _realtime.domainEvents.listen(_handleRealtimeEvent);
  }

  Future<void> _bootstrapDashboard() async {
    await _loadAvailability();
    await Future.wait([
      ref.read(subscriptionProvider.notifier).loadStatus(),
      ref.read(paymentManualProvider.notifier).loadCurrentTransaction(refresh: true),
      ref.read(chatProvider.notifier).loadConversations(),
      ref.read(verificationProvider.notifier).refresh(),
      _syncAvailabilityFromBackend(),
      _syncLocationToBackend(),
      _loadArtisanStats(),
    ]);
    await _loadReviewMetrics();
    if (!mounted) return;
    setState(() => _isStatusCardsHydrating = false);
  }

  Future<void> _loadAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isAvailable = prefs.getBool('artisan_available') ?? true);
  }

  Future<void> _toggleAvailability(bool val) async {
    final previous = _isAvailable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('artisan_available', val);
    setState(() => _isAvailable = val);

    try {
      await _api.put(ApiEndpoints.artisanProfile, data: {'is_available': val});
      if (val) {
        _syncLocationToBackend();
      }
    } catch (error) {
      await prefs.setBool('artisan_available', previous);
      if (mounted) {
        setState(() => _isAvailable = previous);
        AppSnackBar.show(
          context,
          message: mapException(error).userMessage,
        );
      }
    }
  }

  Future<void> _syncAvailabilityFromBackend() async {
    try {
      final profile = await _artisanRepository.getMyArtisanProfile();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('artisan_available', profile.isAvailable);
      if (mounted) {
        setState(() => _isAvailable = profile.isAvailable);
      }
    } catch (_) {
      // Keep local fallback when offline or backend unavailable.
    }
  }

  Future<void> _syncLocationToBackend() async {
    await _locationService.captureAndSyncForAuthenticatedUser();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(subscriptionProvider.notifier).loadStatus(),
      ref
          .read(paymentManualProvider.notifier)
          .loadCurrentTransaction(refresh: true),
      ref.read(chatProvider.notifier).loadConversations(),
      ref.read(verificationProvider.notifier).refresh(),
      _loadArtisanStats(silentRefresh: true),
      _loadReviewMetrics(silentRefresh: true),
    ]);
  }

  Future<void> _loadArtisanStats({bool silentRefresh = false}) async {
    final shouldShowInitialLoader = !_hasStatsData && !silentRefresh;

    if (mounted) {
      setState(() {
        if (shouldShowInitialLoader) {
          _isStatsLoading = true;
        }

        if (silentRefresh && _hasStatsData) {
          _isStatsBackgroundRefreshing = true;
        }
      });
    }

    try {
      final response = await _api.get(ApiEndpoints.artisanStats);
      final data = response.data as Map<String, dynamic>;
      final profileViewsRaw =
          data['profile_views_48h'] ?? data['profileViews48h'] ?? 0;

      if (!mounted) return;
      setState(() {
        _profileViews48h = _toInt(profileViewsRaw) ?? 0;
        _isStatsLoading = false;
        _isStatsBackgroundRefreshing = false;
        _hasStatsData = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStatsLoading = false;
        _isStatsBackgroundRefreshing = false;
      });
    }
  }

  Future<void> _loadReviewMetrics({bool silentRefresh = false}) async {
    final shouldShowInitialLoader = !_hasReviewMetricsData && !silentRefresh;

    if (mounted) {
      setState(() {
        if (shouldShowInitialLoader) {
          _isReviewMetricsLoading = true;
        }

        if (silentRefresh && _hasReviewMetricsData) {
          _isReviewMetricsBackgroundRefreshing = true;
        }
      });
    }

    try {
      final profile = await _artisanRepository.getMyArtisanProfile();
      final categoryName = _cleanString(profile.categoryName);
      final subcategoryName =
          _cleanString(profile.subcategoryName) ??
          _cleanString(profile.profession);
      final businessName = _cleanString(profile.businessName);

      if (!mounted) return;
      setState(() {
        _avgRating = profile.averageRating;
        _totalReviews = profile.totalReviews;
        _experienceYears = profile.experienceYears;
        _isLocationMissing = profile.latitude == null || profile.longitude == null;
        _categoryName = categoryName;
        _subcategoryName = subcategoryName;
        _businessName = businessName;
        _isReviewMetricsLoading = false;
        _isReviewMetricsBackgroundRefreshing = false;
        _hasReviewMetricsData = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isReviewMetricsLoading = false;
        _isReviewMetricsBackgroundRefreshing = false;
      });
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _cleanString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
      return null;
    }
    return trimmed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(verificationProvider.notifier).refresh();
      ref
          .read(paymentManualProvider.notifier)
          .loadCurrentTransaction(refresh: true);
      _syncLocationToBackend();
      _loadArtisanStats(silentRefresh: true);
      _loadReviewMetrics(silentRefresh: true);
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  void _handleRealtimeEvent(ChatRealtimeEvent event) {
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final artisanUserId =
        event.payload['artisanUserId']?.toString() ??
        event.payload['artisan_user_id']?.toString();
    final forCurrentArtisan =
        artisanUserId != null && artisanUserId == currentUserId;

    final shouldRefresh = switch (event.event) {
      'userProfileUpdated' => true,
      'verificationStatusUpdated' => true,
      'subscriptionStatusUpdated' => true,
      'artisanSubscriptionUpdated' => forCurrentArtisan,
      'artisanReviewsUpdated' => forCurrentArtisan,
      'artisanPortfolioUpdated' => forCurrentArtisan,
      'artisanProfileUpdated' => forCurrentArtisan,
      'notificationCreated' => _isArtisanDashboardNotification(event.payload),
      _ => false,
    };

    if (!shouldRefresh) return;

    _loadArtisanStats(silentRefresh: true);
    _loadReviewMetrics(silentRefresh: true);
    ref.read(subscriptionProvider.notifier).loadStatus();
    ref.read(verificationProvider.notifier).refresh();
  }

  bool _isArtisanDashboardNotification(Map<String, dynamic> payload) {
    final notif = payload['notification'];
    if (notif is Map<String, dynamic>) {
      final type = notif['type']?.toString().toUpperCase() ?? '';
      return type == 'REVIEW_CREATED' ||
          type == 'REVIEW_UPDATED' ||
          type == 'SUBSCRIPTION_UPDATED' ||
          type == 'PAYMENT_UPDATED' ||
          type == 'DOCUMENT_APPROVED' ||
          type == 'DOCUMENT_REJECTED';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final subState = ref.watch(subscriptionProvider);
    final manualPaymentState = ref.watch(paymentManualProvider);
    final chatState = ref.watch(chatProvider);
    final vState = ref.watch(verificationProvider);
    final isDark = theme.brightness == Brightness.dark;
    final isSubActive = subState.subscription?.isActive == true;
    final subDaysRemaining = subState.subscription?.daysRemaining ?? 0;
    final manualTx = manualPaymentState.currentTransaction;
    final hasManualInProgress =
        manualTx != null && (manualTx.isPending || manualTx.isPendingAdmin);
    final hasManualRejected = manualTx?.isRejected == true;
    final showLocationAlert =
        !_isStatusCardsHydrating &&
        _isLocationMissing &&
        (_isAvailable || isSubActive);

    final showSubscriptionAlert =
        !_isStatusCardsHydrating &&
        (hasManualInProgress ||
            hasManualRejected ||
            (subState.hasLoaded &&
                subState.error == null &&
                (!isSubActive || subDaysRemaining <= 4)));

    final unreadMessages = chatState.conversations.fold<int>(
      0,
      (sum, c) => sum + c.unreadCount,
    );
    final isKpiRefreshingInBackground =
        _isStatsBackgroundRefreshing || _isReviewMetricsBackgroundRefreshing;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: _onRefresh,
          child: FadeTransition(
            opacity: _fadeIn,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── Header + availability toggle ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'home.greeting'.tr(
                                  namedArgs: {'name': user?.firstName ?? ''},
                                ),
                                style: theme.textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'dashboard.artisan.subtitle'.tr(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Switch.adaptive(
                              value: _isAvailable,
                              activeTrackColor: AppTheme.success,
                              onChanged: _toggleAvailability,
                            ),
                            Text(
                              _isAvailable
                                  ? 'artisan.available'.tr()
                                  : 'artisan.unavailable'.tr(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _isAvailable
                                    ? AppTheme.success
                                    : AppTheme.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _ArtisanIdentityCard(
                      categoryName: _categoryName,
                      subcategoryName: _subcategoryName,
                      businessName: _businessName,
                      experienceYears: _experienceYears,
                    ),
                  ),
                ),

                // ── Account status cards ──
                if (showSubscriptionAlert)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _SubscriptionCard(
                        subState: subState,
                        manualTransaction: manualTx,
                        onTap: () => context.push('/artisan/subscription'),
                      ),
                    ),
                  ),

                if (showLocationAlert)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _LocationSyncCard(
                        onTap: () => context.push('/settings'),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      showSubscriptionAlert ? 12 : 20,
                      20,
                      0,
                    ),
                    child: _VerificationCard(
                      vState: vState,
                      onTap: () => context
                          .push('/artisan/verification')
                          .then(
                            (_) => ref
                                .read(verificationProvider.notifier)
                                .refresh(),
                          ),
                    ),
                  ),
                ),

                // ── Performance KPIs ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Text(
                          'dashboard.artisan.performance'.tr(),
                          style: theme.textTheme.headlineMedium,
                        ),
                        if (isKpiRefreshingInBackground) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            icon: Icons.visibility_outlined,
                            value: _isStatsLoading ? '--' : '$_profileViews48h',
                            label: 'dashboard.artisan.profile_views'.tr(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            icon: Icons.mail_outline_rounded,
                            value: '$unreadMessages',
                            label: 'dashboard.artisan.unread_messages'.tr(),
                            highlight: unreadMessages > 0,
                            onTap: () => context.push('/chat'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _KpiCard(
                            icon: Icons.star_outline_rounded,
                            value: _isReviewMetricsLoading
                                ? '--'
                                : Formatters.rating(_avgRating),
                            label: 'dashboard.artisan.avg_rating'.tr(),
                            onTap: () => context.push('/artisan/reviews'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _KpiCard(
                            icon: Icons.rate_review_outlined,
                            value: _isReviewMetricsLoading
                                ? '--'
                                : '$_totalReviews',
                            label: 'dashboard.artisan.total_reviews'.tr(),
                            highlight:
                                !_isReviewMetricsLoading && _totalReviews > 0,
                            onTap: () => context.push('/artisan/reviews'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Quick actions ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      'dashboard.artisan.quick_actions'.tr(),
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const crossAxisSpacing = 12.0;
                        const crossAxisCount = 2;
                        final tileWidth =
                            (constraints.maxWidth - crossAxisSpacing) /
                            crossAxisCount;

                        final textScale = MediaQuery.textScalerOf(
                          context,
                        ).scale(1);
                        final minTileHeight = textScale > 1.1 ? 116.0 : 108.0;
                        final responsiveAspectRatio =
                            (tileWidth / minTileHeight).clamp(1.15, 1.5);

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: crossAxisSpacing,
                          mainAxisSpacing: 12,
                          childAspectRatio: responsiveAspectRatio,
                          children: [
                            _ActionTile(
                              icon: Icons.photo_library_outlined,
                              label: 'portfolio.title'.tr(),
                              color: AppTheme.gold,
                              onTap: () => context.push('/artisan/portfolio'),
                            ),
                            _ActionTile(
                              icon: Icons.verified_outlined,
                              label: 'artisan.verification.title'.tr(),
                              color: AppTheme.warning,
                              onTap: () => context
                                  .push('/artisan/verification')
                                  .then(
                                    (_) => ref
                                        .read(verificationProvider.notifier)
                                        .refresh(),
                                  ),
                            ),
                            _ActionTile(
                              icon: Icons.credit_card_outlined,
                              label: 'subscription.title'.tr(),
                              color: AppTheme.success,
                              onTap: () =>
                                  context.push('/artisan/subscription'),
                            ),
                            _ActionTile(
                              icon: Icons.settings_outlined,
                              label: 'settings.title'.tr(),
                              color: isDark
                                  ? const Color(0xFF9E9EA8)
                                  : const Color(0xFF6B6B75),
                              onTap: () => context.push('/settings'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // ── Recent conversations ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'dashboard.artisan.inbox'.tr(),
                          style: theme.textTheme.headlineMedium,
                        ),
                        if (chatState.conversations.isNotEmpty)
                          TextButton(
                            onPressed: () => context.push('/chat'),
                            child: Text('home.see_all'.tr()),
                          ),
                      ],
                    ),
                  ),
                ),

                if (chatState.conversations.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'chat.empty'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= 3) return null;
                      final convo = chatState.conversations[index];
                      return RecentConversationTile(
                        name: convo.participantName,
                        lastMessage: convo.lastMessage ?? '',
                        unread: convo.unreadCount,
                        lastMessageAt: convo.lastMessageAt,
                        avatarUrl: convo.participantAvatarUrl,
                        showUnavailableBadge:
                            convo.participantRole == 'ARTISAN' &&
                            convo.participantIsAvailable == false,
                        onTap: () {
                          final queryParams = <String, String>{
                            'name': convo.participantName,
                          };
                          final role = convo.participantRole?.trim();
                          if (role != null && role.isNotEmpty) {
                            queryParams['participantRole'] = role;
                          }
                          if (convo.participantIsAvailable != null) {
                            queryParams['participantIsAvailable'] =
                                '${convo.participantIsAvailable}';
                          }
                          final avatar = convo.participantAvatarUrl?.trim();
                          if (avatar != null && avatar.isNotEmpty) {
                            queryParams['avatar'] = avatar;
                          }
                          final query = Uri(queryParameters: queryParams).query;
                          context.push('/chat/${convo.id}?$query');
                        },
                      );
                    }, childCount: chatState.conversations.length.clamp(0, 3)),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// COMPONENTS
// ═══════════════════════════════════════════════════════════════════

class _ArtisanIdentityCard extends StatelessWidget {
  final String? categoryName;
  final String? subcategoryName;
  final String? businessName;
  final int experienceYears;

  const _ArtisanIdentityCard({
    required this.categoryName,
    required this.subcategoryName,
    required this.businessName,
    required this.experienceYears,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = categoryName?.trim();
    final subcategory = subcategoryName?.trim();
    final business = businessName?.trim();

    final categoryLabel = category == null || category.isEmpty
        ? '...'
        : category;

    final parts = <String>['${'auth.artisan'.tr()}: $categoryLabel'];
    if (subcategory != null && subcategory.isNotEmpty) {
      parts.add(subcategory);
    }
    if (business != null &&
        business.isNotEmpty &&
        business.toLowerCase() != (subcategory ?? '').toLowerCase()) {
      parts.add('${'artisan.business_name'.tr()}: $business');
    }
    if (experienceYears > 0) {
      parts.add(
        'artisan.experience'.tr(namedArgs: {'years': '$experienceYears'}),
      );
    }

    return Container(
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.work_outline_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _LoopingMarquee(
              text: parts.join('   •   '),
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              pixelsPerSecond: 34,
              gap: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoopingMarquee extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final double pixelsPerSecond;
  final double gap;

  const _LoopingMarquee({
    required this.text,
    this.textStyle,
    this.pixelsPerSecond = 34,
    this.gap = 36,
  });

  @override
  State<_LoopingMarquee> createState() => _LoopingMarqueeState();
}

class _LoopingMarqueeState extends State<_LoopingMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isAnimating = false;
  double _lastCycleWidth = -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _LoopingMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.pixelsPerSecond != widget.pixelsPerSecond ||
        oldWidget.gap != widget.gap) {
      _lastCycleWidth = -1;
    }
  }

  void _ensureAnimation(double cycleWidth) {
    if (cycleWidth <= 0 || widget.pixelsPerSecond <= 0) {
      if (_isAnimating) {
        _controller.stop();
      }
      _isAnimating = false;
      return;
    }

    if (_isAnimating && (_lastCycleWidth - cycleWidth).abs() < 1) {
      return;
    }

    final durationMs = ((cycleWidth / widget.pixelsPerSecond) * 1000)
        .round()
        .clamp(5000, 45000);

    _lastCycleWidth = cycleWidth;
    _controller
      ..duration = Duration(milliseconds: durationMs)
      ..repeat();
    _isAnimating = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(
      context,
    ).style.merge(widget.textStyle);
    final displayText = widget.text.trim().isEmpty ? '...' : widget.text.trim();
    final textScaler = MediaQuery.textScalerOf(context);
    final lineHeightPainter = TextPainter(
      text: TextSpan(text: 'Ag', style: effectiveStyle),
      textDirection: Directionality.of(context),
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final marqueeHeight =
        lineHeightPainter.preferredLineHeight.ceilToDouble() + 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
          return SizedBox(
            height: marqueeHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayText,
                style: effectiveStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          );
        }

        final textPainter = TextPainter(
          text: TextSpan(text: displayText, style: effectiveStyle),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          maxLines: 1,
        )..layout();

        final textWidth = textPainter.width.ceilToDouble() + 2;
        final safeTextWidth = textWidth + 4;

        if (safeTextWidth <= constraints.maxWidth - 2) {
          if (_isAnimating) {
            _controller.stop();
            _isAnimating = false;
          }

          return SizedBox(
            height: marqueeHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayText,
                style: effectiveStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          );
        }

        final cycleWidth = safeTextWidth + widget.gap;
        _ensureAnimation(cycleWidth);
        final trackWidth = cycleWidth + safeTextWidth;

        return SizedBox(
          height: marqueeHeight,
          child: ClipRect(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final offset = -_controller.value * cycleWidth;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: trackWidth,
                  maxWidth: trackWidth,
                  minHeight: marqueeHeight,
                  maxHeight: marqueeHeight,
                  child: SizedBox(
                    width: trackWidth,
                    height: marqueeHeight,
                    child: Row(
                      children: [
                        SizedBox(
                          width: safeTextWidth,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              displayText,
                              style: effectiveStyle,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ),
                        SizedBox(width: widget.gap),
                        SizedBox(
                          width: safeTextWidth,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              displayText,
                              style: effectiveStyle,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionState subState;
  final ManualPaymentModel? manualTransaction;
  final VoidCallback onTap;

  const _SubscriptionCard({
    required this.subState,
    required this.manualTransaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sub = subState.subscription;
    final isActive = sub?.isActive == true;
    final hasSubscriptionRecord = sub != null && !sub.isPending;
    final manual = manualTransaction;

    final bool isManualPending =
        manual != null && (manual.isPending || manual.isPendingAdmin);
    final bool isManualRejected = manual?.isRejected == true;

    final String statusText = isActive
        ? 'subscription.expires_in'.tr(
            namedArgs: {'days': '${sub!.daysRemaining}'},
          )
        : isManualPending
        ? (manual.isPendingAdmin
              ? 'subscription.manual.pending_admin'.tr()
              : 'subscription.manual.pending'.tr())
        : isManualRejected
        ? 'subscription.manual.rejected'.tr()
        : hasSubscriptionRecord
        ? 'subscription.expired'.tr()
        : 'subscription.none'.tr();

    final String actionText = isManualPending
        ? 'subscription.manual.view_pending'.tr()
        : 'subscription.pay'.tr();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isActive ? AppTheme.goldGradient : null,
          color: isActive ? null : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? null
              : Border.all(
                  color: isManualPending
                      ? AppTheme.warning.withValues(alpha: 0.55)
                      : AppTheme.error.withValues(alpha: 0.5),
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.black.withValues(alpha: 0.15)
                        : (isManualPending
                              ? AppTheme.warning.withValues(alpha: 0.15)
                              : AppTheme.error.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.workspace_premium_rounded
                        : (isManualPending
                              ? Icons.hourglass_top_rounded
                              : Icons.warning_amber_rounded),
                    color: isActive
                        ? Colors.black
                        : (isManualPending ? AppTheme.warning : AppTheme.error),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'subscription.title'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isActive ? Colors.black : null,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive
                              ? Colors.black87
                              : (isManualPending
                                    ? AppTheme.warning
                                    : AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Icon(Icons.chevron_right, color: Colors.black54),
                  ),
              ],
            ),
            if (!isActive) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationSyncCard extends StatelessWidget {
  final VoidCallback onTap;

  const _LocationSyncCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.warning.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_searching_rounded,
                    color: AppTheme.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'dashboard.artisan.location_required_title'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'dashboard.artisan.location_required_subtitle'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warning,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'dashboard.artisan.location_required_action'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  final VerificationState vState;
  final VoidCallback onTap;

  const _VerificationCard({required this.vState, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = vState.dashboardLabel;

    final (
      Color statusColor,
      String statusText,
      IconData statusIcon,
    ) = switch (label) {
      'VERIFIED' || 'CERTIFIED' => (
        AppTheme.success,
        'artisan.verification.approved'.tr(),
        Icons.check_circle_outline,
      ),
      'PENDING' => (
        AppTheme.warning,
        'artisan.verification.pending'.tr(),
        Icons.schedule_outlined,
      ),
      'REJECTED' => (
        AppTheme.error,
        'artisan.verification.rejected'.tr(),
        Icons.cancel_outlined,
      ),
      _ => (
        theme.textTheme.bodySmall?.color ?? Colors.grey,
        'artisan.verification.not_submitted'.tr(),
        Icons.upload_file_outlined,
      ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'artisan.verification.title'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 13, color: statusColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppTheme.gold.withValues(alpha: 0.5)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
