import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../services/push_notification_service.dart';
import '../common/app_snackbar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Theme
          _SettingsTile(
            icon: themeIcon,
            title: 'settings.theme'.tr(),
            subtitle: themeSubtitle,
            onTap: () => _openThemeSelector(context, ref, themeMode),
          ),

          // Language
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

          // Profile
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'settings.profile'.tr(),
            onTap: () {
              // TODO: Navigate to profile edit
            },
          ),

          // About
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'settings.about'.tr(),
            subtitle: 'settings.version'.tr(
              namedArgs: {'version': AppConfig.appVersion},
            ),
            onTap: () {},
          ),

          const Divider(height: 32),

          // Logout
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'settings.logout'.tr(),
            iconColor: AppTheme.error,
            titleColor: AppTheme.error,
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
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
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/login');
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
