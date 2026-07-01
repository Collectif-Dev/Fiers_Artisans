import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../providers/artisan_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/artisan_model.dart';
import '../../data/repositories/analytics_repository.dart';
import '../common/app_snackbar.dart';
import '../common/rating_stars.dart';
import '../common/badge_verified.dart';
import '../common/skeleton_loader.dart';
import '../common/app_button.dart';
import '../common/portfolio_item_card.dart';
import '../common/availability_badge.dart';

class ArtisanProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const ArtisanProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ArtisanProfileScreen> createState() =>
      _ArtisanProfileScreenState();
}

class _ArtisanProfileScreenState extends ConsumerState<ArtisanProfileScreen>
  with WidgetsBindingObserver {
  final ScrollController _portfolioScrollController = ScrollController();
  Timer? _portfolioAutoScrollTimer;
  Timer? _portfolioAutoScrollResumeTimer;
  bool _portfolioUserInteracting = false;
  double _portfolioScrollStep = 300;
  int _portfolioItemCount = 0;

  static const Duration _portfolioAutoScrollInterval = Duration(seconds: 4);
  static const Duration _portfolioResumeDelay = Duration(seconds: 5);

  bool get _reduceMotionRequested =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await Future.wait([
        ref.read(artisanDetailProvider.notifier).loadArtisan(widget.userId),
        ref
            .read(favoritesProvider.notifier)
            .refreshFavoriteStatus(widget.userId),
      ]);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(artisanDetailProvider.notifier).loadArtisan(widget.userId);
      ref.read(favoritesProvider.notifier).refreshFavoriteStatus(widget.userId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _portfolioAutoScrollTimer?.cancel();
    _portfolioAutoScrollResumeTimer?.cancel();
    _portfolioScrollController.dispose();
    super.dispose();
  }

  void _syncPortfolioAutoScrollConfig({
    required int itemCount,
    required double cardWidth,
  }) {
    _portfolioItemCount = itemCount;
    _portfolioScrollStep = cardWidth + 12;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updatePortfolioAutoScrollTimer();
    });
  }

  void _updatePortfolioAutoScrollTimer() {
    final canRun =
        _portfolioItemCount > 1 &&
        !_portfolioUserInteracting &&
        !_reduceMotionRequested &&
        _portfolioScrollController.hasClients &&
        _portfolioScrollController.position.maxScrollExtent > 0;

    if (!canRun) {
      _portfolioAutoScrollTimer?.cancel();
      _portfolioAutoScrollTimer = null;
      return;
    }

    _portfolioAutoScrollTimer ??= Timer.periodic(
      _portfolioAutoScrollInterval,
      (_) => _autoScrollPortfolioOnce(),
    );
  }

  Future<void> _autoScrollPortfolioOnce() async {
    if (!mounted || _portfolioUserInteracting) return;
    if (!_portfolioScrollController.hasClients) return;

    final position = _portfolioScrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final target = (position.pixels + _portfolioScrollStep).clamp(
      0.0,
      position.maxScrollExtent,
    );
    final shouldLoop = target >= position.maxScrollExtent - 2;
    final nextOffset = shouldLoop ? 0.0 : target;

    await _portfolioScrollController.animateTo(
      nextOffset,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _registerPortfolioInteraction() {
    _portfolioUserInteracting = true;
    _portfolioAutoScrollTimer?.cancel();
    _portfolioAutoScrollTimer = null;
    _portfolioAutoScrollResumeTimer?.cancel();

    _portfolioAutoScrollResumeTimer = Timer(_portfolioResumeDelay, () {
      if (!mounted) return;
      _portfolioUserInteracting = false;
      _updatePortfolioAutoScrollTimer();
    });
  }

  bool _handlePortfolioScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _registerPortfolioInteraction();
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _registerPortfolioInteraction();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(artisanDetailProvider);
    final favoritesState = ref.watch(favoritesProvider);
    final artisan = state.artisan;
    final isFavorite = favoritesState.favoriteUserIds.contains(widget.userId);
    final isFavoriteLoading = favoritesState.loadingUserIds.contains(
      widget.userId,
    );

    if (state.isLoading || artisan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SkeletonLoader(width: 80, height: 80, borderRadius: 40),
            const SizedBox(height: 16),
            const SkeletonLoader(width: 160, height: 20),
            const SizedBox(height: 8),
            const SkeletonLoader(width: 120, height: 14),
          ],
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // SliverAppBar with profile
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: isFavoriteLoading
                      ? null
                      : () => _toggleFavorite(artisan),
                  icon: isFavoriteLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isFavorite
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isFavorite ? AppTheme.gold : Colors.white,
                        ),
                  tooltip: 'dashboard.client.favorites'.tr(),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppTheme.goldGradient),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.black26,
                        child: artisan.profilePhotoUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: artisan.profilePhotoUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, err) => Text(
                                    '${artisan.firstName[0]}${artisan.lastName[0]}'
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                '${artisan.firstName[0]}${artisan.lastName[0]}'
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        artisan.fullName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profession + badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              artisan.displayTrade,
                              style: theme.textTheme.titleLarge,
                            ),
                            if (artisan.displayCategory != null)
                              Text(
                                artisan.displayCategory!,
                                style: theme.textTheme.bodySmall,
                              ),
                            if (artisan.displayBusinessName != null &&
                                artisan.displayBusinessName !=
                                    artisan.displayTrade)
                              Text(
                                '${'artisan.business_name'.tr()}: ${artisan.displayBusinessName!}',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (artisan.isVerified)
                                const _ProfileBadgeWithLabel(
                                  type: BadgeType.verified,
                                  labelKey: 'verified',
                                ),
                              if (artisan.isCertified)
                                const _ProfileBadgeWithLabel(
                                  type: BadgeType.certified,
                                  labelKey: 'certified',
                                ),
                              if (!artisan.isAvailable)
                                const UnavailableBadge(compact: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rating + experience
                  Row(
                    children: [
                      RatingStars(rating: artisan.averageRating),
                      const SizedBox(width: 8),
                      Text(
                        '${Formatters.rating(artisan.averageRating)} (${artisan.totalReviews})',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (artisan.experienceYears > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'artisan.experience'.tr(
                        namedArgs: {'years': '${artisan.experienceYears}'},
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${artisan.commune}, ${artisan.city}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (artisan.description != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'artisan.about'.tr(),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artisan.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Contact buttons
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale = MediaQuery.textScalerOf(
                        context,
                      ).scale(1);
                      final isCompactLayout =
                          constraints.maxWidth < 340 || textScale > 1.15;

                      final chatButton = AppButton(
                        text: 'artisan.contact.chat'.tr(),
                        icon: Icons.chat_bubble_outline,
                        onPressed: () => _openChatWithArtisan(
                          participantUserId: artisan.userId,
                          participantName: artisan.fullName,
                          participantAvatarUrl: artisan.profilePhotoUrl,
                          participantRole: 'ARTISAN',
                          participantIsAvailable: artisan.isAvailable,
                        ),
                      );

                      final quickActions = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ContactIcon(
                            icon: Icons.phone_outlined,
                            tooltip: 'contact.phone'.tr(),
                            onTap: () => _launchPhone(artisan.phone),
                          ),
                          const SizedBox(width: 8),
                          _ContactIcon(
                            icon: Icons.message_outlined, // WhatsApp
                            tooltip: 'contact.whatsapp'.tr(),
                            onTap: () => _launchWhatsApp(artisan.phone),
                          ),
                          const SizedBox(width: 8),
                          _ContactIcon(
                            icon: Icons.sms_outlined,
                            tooltip: 'contact.sms'.tr(),
                            onTap: () => _launchSms(artisan.phone),
                          ),
                        ],
                      );

                      if (isCompactLayout) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            chatButton,
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [quickActions],
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: chatButton),
                          const SizedBox(width: 12),
                          quickActions,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Portfolio section
                  if (state.portfolio.isNotEmpty) ...[
                    Text(
                      'artisan.portfolio'.tr(),
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale = MediaQuery.textScalerOf(
                          context,
                        ).scale(1);
                        final maxWidth = constraints.maxWidth;
                        final cardWidth = maxWidth >= 1100
                            ? 320.0
                            : maxWidth >= 700
                            ? 280.0
                            : (maxWidth * 0.76).clamp(220.0, 300.0);
                        final cardHeight = textScale > 1.15 ? 280.0 : 260.0;
                        const scrollAreaExtraHeight = 24.0;
                        _syncPortfolioAutoScrollConfig(
                          itemCount: state.portfolio.length,
                          cardWidth: cardWidth,
                        );
                        final styledScrollbarTheme = theme.scrollbarTheme
                            .copyWith(
                              thumbVisibility: const WidgetStatePropertyAll(
                                true,
                              ),
                              trackVisibility: const WidgetStatePropertyAll(
                                true,
                              ),
                              thickness: const WidgetStatePropertyAll(10),
                              radius: const Radius.circular(999),
                              minThumbLength: 42,
                              mainAxisMargin: 4,
                              crossAxisMargin: 2,
                              thumbColor: WidgetStatePropertyAll(
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.82,
                                ),
                              ),
                              trackColor: WidgetStatePropertyAll(
                                theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.68),
                              ),
                              trackBorderColor: WidgetStatePropertyAll(
                                theme.colorScheme.primary.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            );

                        return SizedBox(
                          height: cardHeight + scrollAreaExtraHeight,
                          child: Theme(
                            data: theme.copyWith(
                              scrollbarTheme: styledScrollbarTheme,
                            ),
                            child: ScrollConfiguration(
                              behavior: const MaterialScrollBehavior().copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                  PointerDeviceKind.stylus,
                                },
                              ),
                              child: Scrollbar(
                                controller: _portfolioScrollController,
                                scrollbarOrientation:
                                    ScrollbarOrientation.bottom,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child:
                                      NotificationListener<ScrollNotification>(
                                        onNotification:
                                            _handlePortfolioScrollNotification,
                                        child: ListView.separated(
                                          controller:
                                              _portfolioScrollController,
                                          scrollDirection: Axis.horizontal,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          itemCount: state.portfolio.length,
                                          separatorBuilder: (context, index) =>
                                              const SizedBox(width: 12),
                                          itemBuilder: (ctx, i) {
                                            final item = state.portfolio[i];
                                            return SizedBox(
                                              width: cardWidth,
                                              child: PortfolioItemCard(
                                                key: ValueKey(item.id),
                                                item: item,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Reviews section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'artisan.reviews'.tr(),
                        style: theme.textTheme.headlineMedium,
                      ),
                      TextButton(
                        onPressed: () => context
                            .push('/client/review/${artisan.id}')
                            .then(
                              (_) => ref
                                  .read(artisanDetailProvider.notifier)
                                  .refreshReviewsAndSummary(artisan.id),
                            ),
                        child: Text('review.leave'.tr()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.reviews.isEmpty)
                    Text('review.empty'.tr(), style: theme.textTheme.bodySmall)
                  else
                    ...state.reviews
                        .take(5)
                        .map(
                          (review) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        review.clientName ?? 'auth.client'.tr(),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    RatingStars(
                                      rating: review.rating.toDouble(),
                                      size: 14,
                                    ),
                                  ],
                                ),
                                if (review.comment != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    review.comment!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                                if ((review.artisanReply ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'review.artisan_reply_label'.tr(),
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          review.artisanReply!,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        if (review.artisanReplyAt != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            Formatters.relativeDate(
                                              review.artisanReplyAt!,
                                            ),
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.relativeDate(review.createdAt),
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  final AnalyticsRepository _analytics = AnalyticsRepository();

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String _normalizePhoneWithPrefix(String phone) {
    final prefixDigits = _digitsOnly(AppConfig.phonePrefix);
    final rawDigits = _digitsOnly(phone);

    if (rawDigits.isEmpty) return '';
    if (rawDigits.startsWith(prefixDigits)) return rawDigits;

    return '$prefixDigits$rawDigits';
  }

  Future<void> _launchPhone(String phone) async {
    _analytics.logEvent(
      action: 'CONTACT_CLICK',
      targetId: widget.userId,
      metadata: {'method': 'phone'},
    );

    final normalized = _normalizePhoneWithPrefix(phone);
    if (normalized.isEmpty) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'artisan.contact.invalid_phone'.tr(),
        );
      }
      return;
    }

    final uri = Uri.parse('tel:+$normalized');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      AppSnackBar.show(
        context,
        message: kIsWeb
            ? 'artisan.contact.phone_unavailable_web'.tr()
            : 'artisan.contact.phone_unavailable'.tr(),
      );
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    _analytics.logEvent(
      action: 'CONTACT_CLICK',
      targetId: widget.userId,
      metadata: {'method': 'whatsapp'},
    );

    final normalized = _normalizePhoneWithPrefix(phone);
    if (normalized.isEmpty) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'artisan.contact.invalid_phone'.tr(),
        );
      }
      return;
    }

    final message = 'artisan.contact.whatsapp_prefill'.tr();
    final encodedMessage = Uri.encodeComponent(message);
    final appUri = Uri.parse(
      'whatsapp://send?phone=$normalized&text=$encodedMessage',
    );
    final webUri = Uri.parse('https://wa.me/$normalized?text=$encodedMessage');

    var launched = false;
    if (!kIsWeb) {
      launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
    }

    if (!launched) {
      final openedInBrowser = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );

      if (!openedInBrowser) {
        if (mounted) {
          AppSnackBar.show(
            context,
            message: 'artisan.contact.whatsapp_unavailable'.tr(),
          );
        }
        return;
      }

      if (mounted && !kIsWeb) {
        AppSnackBar.show(
          context,
          message: 'artisan.contact.whatsapp_browser_fallback'.tr(),
        );
      }
    }
  }

  Future<void> _launchSms(String phone) async {
    _analytics.logEvent(
      action: 'CONTACT_CLICK',
      targetId: widget.userId,
      metadata: {'method': 'sms'},
    );

    final normalized = _normalizePhoneWithPrefix(phone);
    if (normalized.isEmpty) {
      if (mounted) {
        AppSnackBar.show(
          context,
          message: 'artisan.contact.invalid_phone'.tr(),
        );
      }
      return;
    }

    final uri = Uri(
      scheme: 'sms',
      path: '+$normalized',
      queryParameters: {'body': 'artisan.contact.sms_prefill'.tr()},
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppSnackBar.show(
        context,
        message: kIsWeb
            ? 'artisan.contact.sms_unavailable_web'.tr()
            : 'artisan.contact.sms_unavailable'.tr(),
      );
    }
  }

  Future<void> _openChatWithArtisan({
    required String participantUserId,
    required String participantName,
    String? participantAvatarUrl,
    String? participantRole,
    bool? participantIsAvailable,
  }) async {
    final queryParams = <String, String>{
      'name': participantName,
      'participantId': participantUserId,
    };
    final role = participantRole?.trim();
    if (role != null && role.isNotEmpty) {
      queryParams['participantRole'] = role;
    }
    if (participantIsAvailable != null) {
      queryParams['participantIsAvailable'] = '$participantIsAvailable';
    }
    final avatar = participantAvatarUrl?.trim();
    if (avatar != null && avatar.isNotEmpty) {
      queryParams['avatar'] = avatar;
    }
    final query = Uri(queryParameters: queryParams).query;
    context.push('/chat/new?$query');
  }

  Future<void> _toggleFavorite(ArtisanModel artisan) async {
    final updated = await ref
        .read(favoritesProvider.notifier)
        .toggleFavorite(artisan);
    if (!mounted) return;

    AppSnackBar.show(
      context,
      message: updated
          ? 'dashboard.client.favorite_added'.tr()
          : 'dashboard.client.favorite_removed'.tr(),
    );
  }
}

class _ContactIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ContactIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _ProfileBadgeWithLabel extends StatelessWidget {
  final BadgeType type;
  final String labelKey;

  const _ProfileBadgeWithLabel({required this.type, required this.labelKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BadgeVerified(type: type),
        const SizedBox(height: 2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 88),
          child: Text(
            labelKey.tr(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
