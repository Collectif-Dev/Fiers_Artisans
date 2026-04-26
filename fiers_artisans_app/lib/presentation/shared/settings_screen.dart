import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Theme
          _SettingsTile(
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            title: 'settings.theme'.tr(),
            subtitle: isDark ? 'theme.dark'.tr() : 'theme.light'.tr(),
            onTap: () => ref.read(themeProvider.notifier).toggle(),
          ),

          // Language
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'settings.language'.tr(),
            subtitle: context.locale.languageCode == 'fr'
                ? 'Français'
                : 'English',
            onTap: () => ref
                .read(localeProvider.notifier)
                .toggleLocale(context),
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
            subtitle: 'settings.version'
                .tr(namedArgs: {'version': AppConfig.appVersion}),
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
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
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
      title: Text(title,
          style: theme.textTheme.titleMedium?.copyWith(color: titleColor)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: theme.textTheme.bodySmall)
          : null,
      trailing: Icon(Icons.chevron_right_rounded,
          color: theme.textTheme.bodySmall?.color),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
