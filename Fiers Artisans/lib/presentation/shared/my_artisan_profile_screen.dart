import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/artisan_model.dart';
import '../../presentation/common/app_snackbar.dart';
import '../../providers/profile_provider.dart';
import '../../services/chat_realtime_service.dart';
import 'profile_ui.dart';

class MyArtisanProfileScreen extends ConsumerStatefulWidget {
  const MyArtisanProfileScreen({super.key});

  @override
  ConsumerState<MyArtisanProfileScreen> createState() =>
      _MyArtisanProfileScreenState();
}

class _MyArtisanProfileScreenState extends ConsumerState<MyArtisanProfileScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey _cardCaptureKey = GlobalKey();
  late final AnimationController _controller;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _realtimeSub = ChatRealtimeService().domainEvents.listen(_onRealtimeEvent);
    Future.microtask(_revalidateCachedProfile);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(artisanOwnProfileProvider);
    }
  }

  void _revalidateCachedProfile() {
    final current = ref.read(artisanOwnProfileProvider);
    if (current.hasValue || current.hasError) {
      ref.invalidate(artisanOwnProfileProvider);
    }
  }

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (event.event == 'userProfileUpdated' ||
        event.event == 'verificationStatusUpdated' ||
        event.event == 'subscriptionStatusUpdated' ||
        event.event == 'artisanSubscriptionUpdated' ||
        event.event == 'artisanProfileUpdated') {
      ref.invalidate(artisanOwnProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProfile = ref.watch(artisanOwnProfileProvider);

    return Scaffold(
      body: asyncProfile.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ProfileErrorState(
          onRetry: () => ref.refresh(artisanOwnProfileProvider),
        ),
        data: (artisan) {
          final initials = _initials(artisan.firstName, artisan.lastName);
          final locationDate = artisan.locationUpdatedAt;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                toolbarHeight: 0,
                expandedHeight: 232,
                pinned: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: ProfileHeader(
                    title: artisan.fullName,
                    subtitle: artisan.displayTrade,
                    initials: initials,
                    imageUrl: artisan.profilePhotoUrl,
                    badges: [
                      if (artisan.isVerified)
                        const _WhiteStatusPill(
                          icon: Icons.verified_rounded,
                          labelKey: 'artisan.verified',
                        ),
                      if (artisan.isCertified)
                        const _WhiteStatusPill(
                          icon: Icons.workspace_premium_rounded,
                          labelKey: 'artisan.certified',
                        ),
                      _WhiteStatusPill(
                        icon: artisan.isAvailable
                            ? Icons.flash_on_rounded
                            : Icons.pause_circle_outline_rounded,
                        labelKey: artisan.isAvailable
                            ? 'artisan.available'
                            : 'artisan.unavailable',
                      ),
                    ],
                  ),
                ),
              ),
              ProfileBodyPadding(
                children: [
                  ProfileSectionCard(
                    title: 'profile.artisan.metrics_title'.tr(),
                    subtitle: 'profile.artisan.metrics_subtitle'.tr(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 520;
                        final metrics = [
                          ProfileMetricTile(
                            label: 'profile.fields.experience'.tr(),
                            value: artisan.experienceYears > 0
                                ? 'artisan.experience'.tr(
                                    namedArgs: {
                                      'years': '${artisan.experienceYears}',
                                    },
                                  )
                                : 'profile.common.not_provided'.tr(),
                            icon: Icons.timeline_rounded,
                          ),
                          ProfileMetricTile(
                            label: 'profile.fields.rating'.tr(),
                            value:
                                '${Formatters.rating(artisan.averageRating)} / 5',
                            icon: Icons.star_rounded,
                          ),
                          ProfileMetricTile(
                            label: 'profile.fields.reviews_count'.tr(),
                            value: '${artisan.totalReviews}',
                            icon: Icons.rate_review_outlined,
                          ),
                          ProfileMetricTile(
                            label: 'profile.fields.subscription'.tr(),
                            value: artisan.hasActiveSubscription
                                ? 'profile.artisan.subscription_active'.tr()
                                : 'profile.artisan.subscription_inactive'.tr(),
                            icon: Icons.verified_user_outlined,
                          ),
                        ];

                        if (isNarrow) {
                          return Column(
                            children: [
                              for (var i = 0; i < metrics.length; i++) ...[
                                metrics[i],
                                if (i != metrics.length - 1)
                                  const SizedBox(height: 10),
                              ],
                            ],
                          );
                        }

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: metrics
                              .map(
                                (metric) => SizedBox(
                                  width: (constraints.maxWidth - 10) / 2,
                                  child: metric,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'profile.artisan.identity_title'.tr(),
                    subtitle: 'profile.artisan.identity_subtitle'.tr(),
                    child: Column(
                      children: [
                        ProfileInfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'profile.fields.full_name'.tr(),
                          value: artisan.fullName,
                        ),
                        ProfileInfoRow(
                          icon: Icons.call_outlined,
                          label: 'profile.fields.phone'.tr(),
                          value: Formatters.phone(artisan.phone),
                        ),
                        ProfileInfoRow(
                          icon: Icons.email_outlined,
                          label: 'profile.fields.email'.tr(),
                          value: (artisan.email ?? '').trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : artisan.email!,
                        ),
                        ProfileInfoRow(
                          icon: Icons.storefront_outlined,
                          label: 'profile.fields.business_name'.tr(),
                          value:
                              (artisan.displayBusinessName ?? '').trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : artisan.displayBusinessName!,
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'profile.artisan.trade_title'.tr(),
                    subtitle: 'profile.artisan.trade_subtitle'.tr(),
                    child: Column(
                      children: [
                        ProfileInfoRow(
                          icon: Icons.handyman_outlined,
                          label: 'profile.fields.trade'.tr(),
                          value: artisan.displayTrade,
                        ),
                        ProfileInfoRow(
                          icon: Icons.category_outlined,
                          label: 'profile.fields.category'.tr(),
                          value: (artisan.displayCategory ?? '').trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : artisan.displayCategory!,
                        ),
                        ProfileInfoRow(
                          icon: Icons.message_outlined,
                          label: 'profile.fields.whatsapp'.tr(),
                          value: (artisan.whatsappNumber ?? '').trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : Formatters.phone(artisan.whatsappNumber!),
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'profile.artisan.location_title'.tr(),
                    subtitle: 'profile.artisan.location_subtitle'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProfileInfoRow(
                          icon: Icons.location_city_outlined,
                          label: 'profile.fields.city'.tr(),
                          value: artisan.city.trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : artisan.city,
                        ),
                        ProfileInfoRow(
                          icon: Icons.place_outlined,
                          label: 'profile.fields.commune'.tr(),
                          value: artisan.commune.trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : artisan.commune,
                        ),
                        ProfileInfoRow(
                          icon: Icons.pin_drop_outlined,
                          label: 'profile.fields.address'.tr(),
                          value: (artisan.address ?? '').trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : artisan.address!,
                        ),
                        if (artisan.latitude != null &&
                            artisan.longitude != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 18,
                              runSpacing: 12,
                              children: [
                                ProfileLabelValue(
                                  label: 'profile.fields.latitude'.tr(),
                                  value: artisan.latitude!.toStringAsFixed(5),
                                ),
                                ProfileLabelValue(
                                  label: 'profile.fields.longitude'.tr(),
                                  value: artisan.longitude!.toStringAsFixed(5),
                                ),
                              ],
                            ),
                          )
                        else
                          ProfileEmptyValue(
                            label: 'profile.artisan.location_missing'.tr(),
                          ),
                        const SizedBox(height: 14),
                        ProfileSubtleHint(
                          icon: Icons.gps_fixed_rounded,
                          text:
                              artisan.latitude != null &&
                                  artisan.longitude != null
                              ? 'profile.artisan.location_ok'.tr(
                                  namedArgs: {
                                    'date': locationDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy HH:mm',
                                          ).format(locationDate)
                                        : 'profile.common.unknown'.tr(),
                                  },
                                )
                              : 'profile.artisan.location_warning'.tr(),
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'profile.artisan.professional_info_title'.tr(),
                    subtitle: 'profile.artisan.professional_info_subtitle'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((artisan.description ?? '').trim().isNotEmpty)
                          Text(
                            artisan.description!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          ProfileEmptyValue(
                            label: 'profile.common.not_provided'.tr(),
                          ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ProfileStatusPill(
                              icon: artisan.isAvailable
                                  ? Icons.flash_on_rounded
                                  : Icons.pause_circle_outline_rounded,
                              label: artisan.isAvailable
                                  ? 'profile.artisan.visible_now'.tr()
                                  : 'profile.artisan.not_visible_now'.tr(),
                              background: artisan.isAvailable
                                  ? AppTheme.success.withValues(alpha: 0.14)
                                  : AppTheme.error.withValues(alpha: 0.12),
                              foreground: artisan.isAvailable
                                  ? AppTheme.success
                                  : AppTheme.error,
                            ),
                            ProfileStatusPill(
                              icon: artisan.hasActiveSubscription
                                  ? Icons.workspace_premium_outlined
                                  : Icons.lock_outline_rounded,
                              label: artisan.hasActiveSubscription
                                  ? 'profile.artisan.subscription_active'.tr()
                                  : 'profile.artisan.subscription_inactive'
                                        .tr(),
                              background: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12),
                              foreground: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'profile.artisan.card_title'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _isSharing
                                ? null
                                : () => _shareCard(artisan),
                            icon: _isSharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.ios_share_rounded),
                            label: Text('profile.artisan.share_card'.tr()),
                          ),
                        ),
                        const SizedBox(height: 14),
                        RepaintBoundary(
                          key: _cardCaptureKey,
                          child: _ProfessionalCard(
                            artisan: artisan,
                            animation: _controller,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _shareCard(ArtisanModel artisan) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    File? sharedFile;

    try {
      HapticFeedback.mediumImpact();
      final boundary =
          _cardCaptureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Card boundary unavailable');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('Captured image is empty');
      }

      final directory = await getTemporaryDirectory();
      final safeName = artisan.fullName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      sharedFile = File('${directory.path}/fiers-artisans-$safeName-card.png');
      await sharedFile.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(sharedFile.path)],
          text: 'profile.artisan.share_caption'.tr(
            namedArgs: {
              'name': artisan.fullName,
              'trade': artisan.displayTrade,
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(context, message: 'profile.artisan.share_error'.tr());
    } finally {
      if (sharedFile != null) {
        try {
          if (await sharedFile.exists()) {
            await sharedFile.delete();
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  String _initials(String firstName, String lastName) {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final value = '$first$last'.toUpperCase();
    return value.isEmpty ? 'FA' : value;
  }
}

class _ProfessionalCard extends StatelessWidget {
  final ArtisanModel artisan;
  final Animation<double> animation;

  const _ProfessionalCard({required this.artisan, required this.animation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(artisan.firstName, artisan.lastName);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final wave = animation.value;
        return LayoutBuilder(
          builder: (context, viewport) {
            final aspectRatio = switch (viewport.maxWidth) {
              < 320 => 0.90,
              < 360 => 0.97,
              _ => 1.08,
            };

            return AspectRatio(
              aspectRatio: aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact =
                      constraints.maxHeight < 320 || constraints.maxWidth < 340;
                  final isVeryCompact =
                      constraints.maxHeight < 300 || constraints.maxWidth < 315;
                  final padding = isVeryCompact
                      ? 14.0
                      : isCompact
                      ? 16.0
                      : 20.0;
                  final avatarSize = isVeryCompact
                      ? 46.0
                      : isCompact
                      ? 50.0
                      : 60.0;
                  final headerGap = isVeryCompact
                      ? 10.0
                      : isCompact
                      ? 14.0
                      : 24.0;
                  final textGap = isVeryCompact
                      ? 3.0
                      : isCompact
                      ? 5.0
                      : 8.0;
                  final footerGap = isVeryCompact
                      ? 8.0
                      : isCompact
                      ? 10.0
                      : 14.0;
                  final showBusinessName =
                      !isVeryCompact &&
                      (artisan.displayBusinessName ?? '').trim().isNotEmpty;

                  return Container(
                    padding: EdgeInsets.all(padding),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1C1712),
                          Color.lerp(
                            AppTheme.goldDark,
                            const Color(0xFF4A3111),
                            wave,
                          )!,
                          const Color(0xFFF0B24A),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.goldDark.withValues(alpha: 0.28),
                          blurRadius: 28,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -28 + (wave * 14),
                          right: -18,
                          child: _GlowOrb(
                            size: isCompact ? 96 : 120,
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        Positioned(
                          bottom: -34 + (wave * 10),
                          left: -24,
                          child: _GlowOrb(
                            size: isCompact ? 120 : 150,
                            color: Colors.black.withValues(alpha: 0.14),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: avatarSize,
                                  height: avatarSize,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      isCompact ? 16 : 20,
                                    ),
                                    color: Colors.white.withValues(alpha: 0.14),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isCompact ? 20 : 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isVeryCompact
                                        ? 8
                                        : isCompact
                                        ? 10
                                        : 12,
                                    vertical: isVeryCompact
                                        ? 5
                                        : isCompact
                                        ? 6
                                        : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'FIERS ARTISANS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      fontSize: isVeryCompact
                                          ? 9
                                          : isCompact
                                          ? 10
                                          : 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: headerGap),
                            Flexible(
                              fit: FlexFit.loose,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    artisan.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        (isVeryCompact
                                                ? theme.textTheme.titleMedium
                                                : isCompact
                                                ? theme.textTheme.titleLarge
                                                : theme
                                                      .textTheme
                                                      .headlineMedium)
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                  ),
                                  SizedBox(height: textGap),
                                  Text(
                                    artisan.displayTrade,
                                    maxLines: isVeryCompact ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        (isVeryCompact
                                                ? theme.textTheme.bodyLarge
                                                : isCompact
                                                ? theme.textTheme.titleMedium
                                                : theme.textTheme.titleLarge)
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                            ),
                                  ),
                                  if (showBusinessName) ...[
                                    SizedBox(height: isCompact ? 4 : 6),
                                    Text(
                                      artisan.displayBusinessName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.76,
                                            ),
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _CardMetaPill(
                                  compact: isCompact,
                                  icon: Icons.place_outlined,
                                  label: '${artisan.commune}, ${artisan.city}',
                                ),
                                _CardMetaPill(
                                  compact: isCompact,
                                  icon: Icons.timeline_rounded,
                                  label: artisan.experienceYears > 0
                                      ? 'profile.artisan.card_experience'.tr(
                                          namedArgs: {
                                            'years':
                                                '${artisan.experienceYears}',
                                          },
                                        )
                                      : 'profile.common.not_provided'.tr(),
                                ),
                              ],
                            ),
                            SizedBox(height: footerGap),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  artisan.isVerified
                                      ? Icons.verified_rounded
                                      : Icons.shield_outlined,
                                  color: Colors.white,
                                  size: isCompact ? 16 : 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    artisan.isVerified
                                        ? 'profile.artisan.card_verified'.tr()
                                        : 'profile.artisan.card_pending'.tr(),
                                    maxLines: isVeryCompact ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _initials(String firstName, String lastName) {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final value = '$first$last'.toUpperCase();
    return value.isEmpty ? 'FA' : value;
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _CardMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _CardMetaPill({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 14, color: Colors.white),
          SizedBox(width: compact ? 5 : 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 10.5 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteStatusPill extends StatelessWidget {
  final IconData icon;
  final String labelKey;

  const _WhiteStatusPill({required this.icon, required this.labelKey});

  @override
  Widget build(BuildContext context) {
    return ProfileStatusPill(
      icon: icon,
      label: labelKey.tr(),
      background: Colors.white.withValues(alpha: 0.16),
      foreground: Colors.white,
    );
  }
}
