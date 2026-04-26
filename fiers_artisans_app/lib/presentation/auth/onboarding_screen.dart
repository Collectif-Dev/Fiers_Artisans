import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/app_providers.dart';
import '../common/app_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_OnboardingPage> get _pages => [
        _OnboardingPage(
          icon: Icons.search_rounded,
          title: 'onboarding.step1_title'.tr(),
          subtitle: 'onboarding.step1_subtitle'.tr(),
        ),
        _OnboardingPage(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'onboarding.step2_title'.tr(),
          subtitle: 'onboarding.step2_subtitle'.tr(),
        ),
        _OnboardingPage(
          icon: Icons.star_outline_rounded,
          title: 'onboarding.step3_title'.tr(),
          subtitle: 'onboarding.step3_subtitle'.tr(),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Theme & Language selectors
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Theme toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ThemeOption(
                        icon: Icons.dark_mode_rounded,
                        label: 'theme.dark'.tr(),
                        isSelected: isDark,
                        onTap: () => ref.read(themeProvider.notifier).setDark(),
                      ),
                      const SizedBox(width: 12),
                      _ThemeOption(
                        icon: Icons.light_mode_rounded,
                        label: 'theme.light'.tr(),
                        isSelected: !isDark,
                        onTap: () =>
                            ref.read(themeProvider.notifier).setLight(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Language toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LanguageOption(
                        flag: '🇫🇷',
                        label: 'FR',
                        isSelected:
                            context.locale.languageCode == 'fr',
                        onTap: () => ref
                            .read(localeProvider.notifier)
                            .setFrench(context),
                      ),
                      const SizedBox(width: 12),
                      _LanguageOption(
                        flag: '🇬🇧',
                        label: 'EN',
                        isSelected:
                            context.locale.languageCode == 'en',
                        onTap: () => ref
                            .read(localeProvider.notifier)
                            .setEnglish(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 56,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          style: theme.textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.subtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots + buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: AppConstants.animNormal,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? theme.colorScheme.primary
                              : theme.dividerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_currentPage == _pages.length - 1)
                    AppButton(
                      text: 'onboarding.get_started'.tr(),
                      onPressed: _completeOnboarding,
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: Text('onboarding.skip'.tr()),
                        ),
                        const Spacer(),
                        AppButton(
                          text: 'onboarding.next'.tr(),
                          width: 140,
                          onPressed: () {
                            _pageController.nextPage(
                              duration: AppConstants.animNormal,
                              curve: Curves.easeOutCubic,
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _completeOnboarding() {
    ref.read(onboardingCompletedProvider.notifier).complete();
    context.go('/login');
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;

  _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animNormal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? theme.colorScheme.primary : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.flag,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animNormal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : null,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
