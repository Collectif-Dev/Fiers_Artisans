import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../data/repositories/artisan_repository.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/location_service.dart';
import '../../services/push_notification_service.dart';
import '../common/app_button.dart';
import '../common/app_snackbar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final themeMode = ref.watch(themeProvider);
    final themeIcon = switch (themeMode) {
      ThemeMode.system => Icons.brightness_auto_rounded,
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
    };
    final themeSubtitle = switch (themeMode) {
      ThemeMode.system => 'theme.system'.tr(),
      ThemeMode.dark => 'theme.dark'.tr(),
      ThemeMode.light => 'theme.light'.tr(),
    };

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text('settings.title'.tr())),
          body: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _SettingsTile(
                icon: themeIcon,
                title: 'settings.theme'.tr(),
                subtitle: themeSubtitle,
                onTap: () => _openThemeSelector(context, ref, themeMode),
              ),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'settings.language'.tr(),
                subtitle: 'language.${context.locale.languageCode}'.tr(),
                onTap: () => _openLanguageSelector(
                  context,
                  ref,
                  context.locale.languageCode,
                ),
              ),
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'settings.notifications_system'.tr(),
                subtitle: 'settings.notifications_hint'.tr(),
                onTap: () => _openNotificationsSystemSettings(context),
              ),
              const Divider(height: 32),
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'settings.profile'.tr(),
                onTap: () {
                  final role = ref.read(authProvider).user?.role.toLowerCase();
                  context.push(
                    role == 'artisan' ? '/profile/artisan' : '/profile/client',
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.my_location_rounded,
                title: 'settings.location_update'.tr(),
                subtitle: 'settings.location_update_hint'.tr(),
                onTap: () => _openLocationUpdateSheet(context, ref),
              ),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'settings.about'.tr(),
                subtitle: 'settings.version'.tr(
                  namedArgs: {'version': AppConfig.appVersion},
                ),
                onTap: () => context.push('/about'),
              ),
              const Divider(height: 32),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'settings.logout'.tr(),
                iconColor: AppTheme.error,
                titleColor: AppTheme.error,
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),
        ),
        IgnorePointer(
          ignoring: !_isLoggingOut,
          child: AnimatedOpacity(
            opacity: _isLoggingOut ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: Container(
              color: Colors.black.withValues(alpha: 0.16),
              alignment: Alignment.center,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _isLoggingOut ? Offset.zero : const Offset(0, 0.03),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openLocationUpdateSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final role = ref.read(authProvider).user?.role ?? 'client';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LocationUpdateSheet(role: role),
    );
  }

  Future<void> _openNotificationsSystemSettings(BuildContext context) async {
    final messaging = FirebaseMessaging.instance;
    final current = await messaging.getNotificationSettings();

    if (current.authorizationStatus == AuthorizationStatus.notDetermined) {
      await PushNotificationService().initialize();
      final refreshed = await messaging.getNotificationSettings();
      if (refreshed.authorizationStatus == AuthorizationStatus.authorized ||
          refreshed.authorizationStatus == AuthorizationStatus.provisional) {
        if (!context.mounted) return;
        AppSnackBar.show(
          context,
          message: 'settings.notifications_enabled'.tr(),
        );
        return;
      }
    }

    final opened = await openAppSettings();
    if (!opened && context.mounted) {
      AppSnackBar.show(
        context,
        message: 'settings.notifications_open_settings_fail'.tr(),
      );
    }
  }

  Future<void> _openThemeSelector(
    BuildContext context,
    WidgetRef ref,
    ThemeMode selectedMode,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_auto_rounded),
                title: Text('theme.system'.tr()),
                trailing: selectedMode == ThemeMode.system
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setSystem();
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode_rounded),
                title: Text('theme.dark'.tr()),
                trailing: selectedMode == ThemeMode.dark
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setDark();
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_rounded),
                title: Text('theme.light'.tr()),
                trailing: selectedMode == ThemeMode.light
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setLight();
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLanguageSelector(
    BuildContext context,
    WidgetRef ref,
    String selectedLanguageCode,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text('language.select'.tr()),
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: Text('language.fr'.tr()),
                trailing: selectedLanguageCode == 'fr'
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).setFrench(context);
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_circle_rounded),
                title: Text('language.en'.tr()),
                trailing: selectedLanguageCode == 'en'
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).setEnglish(context);
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.logout'.tr()),
        content: Text('settings.logout_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _runLogoutTransition(ref);
            },
            child: Text(
              'settings.logout'.tr(),
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runLogoutTransition(WidgetRef ref) async {
    if (_isLoggingOut) return;

    final router = GoRouter.of(context);
    setState(() => _isLoggingOut = true);
    unawaited(ref.read(authProvider.notifier).logout());

    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    router.go('/login');
  }
}

class _LocationProfileSnapshot {
  final String city;
  final String commune;
  final double? latitude;
  final double? longitude;
  final DateTime? locationUpdatedAt;

  const _LocationProfileSnapshot({
    required this.city,
    required this.commune,
    required this.latitude,
    required this.longitude,
    required this.locationUpdatedAt,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasResolvedAddress =>
      city.trim().isNotEmpty && commune.trim().isNotEmpty;

  String get summary {
    if (!hasLocation && !hasResolvedAddress) {
      return '';
    }
    if (city.trim().isEmpty && commune.trim().isEmpty) {
      return '${latitude?.toStringAsFixed(6) ?? '--'}, ${longitude?.toStringAsFixed(6) ?? '--'}';
    }
    return '$city, $commune';
  }
}

class _LocationUpdateSheet extends ConsumerStatefulWidget {
  final String role;

  const _LocationUpdateSheet({required this.role});

  @override
  ConsumerState<_LocationUpdateSheet> createState() =>
      _LocationUpdateSheetState();
}

class _LocationUpdateSheetState extends ConsumerState<_LocationUpdateSheet> {
  final ApiClient _api = ApiClient();
  final ArtisanRepository _artisanRepository = ArtisanRepository();
  final LocationService _locationService = LocationService();

  bool _isLoading = true;
  bool _isUpdating = false;
  _LocationProfileSnapshot? _snapshot;
  String? _loadError;

  bool get _isArtisan => widget.role.toLowerCase() == 'artisan';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCurrentLocationState);
  }

  Future<void> _loadCurrentLocationState() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final next = _isArtisan
          ? await _loadArtisanSnapshot()
          : await _loadClientSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = next;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = mapException(error).userMessage;
        _isLoading = false;
      });
    }
  }

  Future<_LocationProfileSnapshot> _loadArtisanSnapshot() async {
    final profile = await _artisanRepository.getMyArtisanProfile();
    return _LocationProfileSnapshot(
      city: profile.city,
      commune: profile.commune,
      latitude: profile.latitude,
      longitude: profile.longitude,
      locationUpdatedAt: profile.locationUpdatedAt,
    );
  }

  Future<_LocationProfileSnapshot> _loadClientSnapshot() async {
    final response = await _api.get(ApiEndpoints.clientProfile);
    final payload = response.data is Map<String, dynamic>
        ? ((response.data['data'] as Map<String, dynamic>?) ?? response.data)
        : <String, dynamic>{};

    return _LocationProfileSnapshot(
      city: (payload['city'] ?? '').toString(),
      commune: (payload['commune'] ?? '').toString(),
      latitude: _toDouble(payload['latitude']),
      longitude: _toDouble(payload['longitude']),
      locationUpdatedAt: _toDateTime(
        payload['location_updated_at'] ?? payload['locationUpdatedAt'],
      ),
    );
  }

  Future<void> _refreshLocation() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      final result = await _locationService.getCurrentLocationResult(
        reverseGeocode: true,
        requestPermission: true,
      );

      if (!mounted) return;

      final snapshot = result.snapshot;
      if (snapshot == null) {
        AppSnackBar.show(
          context,
          message: result.message ?? 'location.error_position_failed'.tr(),
        );
        setState(() => _isUpdating = false);
        return;
      }

      final city = snapshot.city?.trim() ?? '';
      final commune = snapshot.commune?.trim() ?? '';
      if (city.isEmpty || commune.isEmpty) {
        AppSnackBar.show(
          context,
          message: 'location.error_incomplete_resolved_position'.tr(),
        );
        setState(() => _isUpdating = false);
        return;
      }

      final before = _snapshot;
      await _locationService.syncUserLocation(
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        city: city,
        commune: commune,
        throwOnError: true,
      );
      if (_isArtisan) {
        ref.invalidate(artisanOwnProfileProvider);
      } else {
        ref.invalidate(clientProfileProvider);
      }

      final next = _LocationProfileSnapshot(
        city: city,
        commune: commune,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
        locationUpdatedAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _snapshot = next;
        _isUpdating = false;
      });

      final alreadyCurrent =
          before != null &&
          _sameLocation(before.latitude, next.latitude) &&
          _sameLocation(before.longitude, next.longitude) &&
          before.city.trim() == next.city.trim() &&
          before.commune.trim() == next.commune.trim();

      AppSnackBar.show(
        context,
        message: alreadyCurrent
            ? 'location.update_already_current'.tr()
            : 'location.update_success'.tr(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      AppSnackBar.show(context, message: mapException(error).userMessage);
    }
  }

  bool _sameLocation(double? a, double? b) {
    if (a == null || b == null) return a == b;
    return (a - b).abs() < 0.00001;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = _snapshot;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'settings.location_update'.tr(),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'settings.location_update_modal_hint'.tr(),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _loadError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.error,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings.current_location'.tr(),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot == null || snapshot.summary.isEmpty
                          ? 'location.current_unknown'.tr()
                          : snapshot.summary,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot == null || !snapshot.hasLocation
                          ? 'location.current_missing_coordinates'.tr()
                          : '${snapshot.latitude!.toStringAsFixed(6)}, ${snapshot.longitude!.toStringAsFixed(6)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot?.locationUpdatedAt == null
                          ? 'location.last_update_unknown'.tr()
                          : 'location.last_update'.tr(
                              namedArgs: {
                                'date': DateFormat(
                                  'dd/MM/yyyy HH:mm',
                                ).format(snapshot!.locationUpdatedAt!),
                              },
                            ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            AppButton(
              text: _isUpdating
                  ? 'location.prefill_in_progress'.tr()
                  : 'settings.location_update'.tr(),
              icon: Icons.my_location_rounded,
              isLoading: _isUpdating,
              onPressed: _isLoading ? null : _refreshLocation,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: iconColor ?? theme.colorScheme.primary),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(color: titleColor),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: theme.textTheme.bodySmall)
          : null,
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.textTheme.bodySmall?.color,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
