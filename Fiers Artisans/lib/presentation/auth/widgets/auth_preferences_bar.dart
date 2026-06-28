import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../providers/app_providers.dart';

enum _AuthThemeChoice { system, dark, light }
enum _AuthLocaleChoice { fr, en }

class AuthPreferencesBar extends ConsumerWidget {
  final bool compact;

  const AuthPreferencesBar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final localeCode = context.locale.languageCode;

    final themeIcon = switch (themeMode) {
      ThemeMode.dark => Icons.dark_mode_rounded,
      ThemeMode.light => Icons.light_mode_rounded,
      ThemeMode.system => Icons.brightness_auto_rounded,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<_AuthLocaleChoice>(
          tooltip: 'Language',
          onSelected: (value) async {
            if (value == _AuthLocaleChoice.fr) {
              await ref.read(localeProvider.notifier).setFrench(context);
            } else {
              await ref.read(localeProvider.notifier).setEnglish(context);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _AuthLocaleChoice.fr,
              child: _MenuLabel(
                label: 'FR',
                selected: localeCode == 'fr',
              ),
            ),
            PopupMenuItem(
              value: _AuthLocaleChoice.en,
              child: _MenuLabel(
                label: 'EN',
                selected: localeCode == 'en',
              ),
            ),
          ],
          child: compact
              ? Icon(Icons.translate_rounded, color: theme.iconTheme.color)
              : _PillButton(
                  icon: Icons.translate_rounded,
                  label: localeCode.toUpperCase(),
                ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<_AuthThemeChoice>(
          tooltip: 'Theme',
          onSelected: (value) async {
            final notifier = ref.read(themeProvider.notifier);
            switch (value) {
              case _AuthThemeChoice.system:
                await notifier.setSystem();
              case _AuthThemeChoice.dark:
                await notifier.setDark();
              case _AuthThemeChoice.light:
                await notifier.setLight();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _AuthThemeChoice.system,
              child: _MenuLabel(
                label: 'theme.system'.tr(),
                selected: themeMode == ThemeMode.system,
              ),
            ),
            PopupMenuItem(
              value: _AuthThemeChoice.dark,
              child: _MenuLabel(
                label: 'theme.dark'.tr(),
                selected: themeMode == ThemeMode.dark,
              ),
            ),
            PopupMenuItem(
              value: _AuthThemeChoice.light,
              child: _MenuLabel(
                label: 'theme.light'.tr(),
                selected: themeMode == ThemeMode.light,
              ),
            ),
          ],
          child: compact
              ? Icon(themeIcon, color: theme.iconTheme.color)
              : _PillButton(
                  icon: themeIcon,
                  label: 'Theme',
                ),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PillButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  final String label;
  final bool selected;

  const _MenuLabel({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        if (selected) Icon(Icons.check_rounded, color: theme.colorScheme.primary),
      ],
    );
  }
}
