import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../presentation/common/count_badged_icon.dart';
import '../providers/badge_counts_provider.dart';
import '../presentation/auth/onboarding_screen.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/auth/register_choice_screen.dart';
import '../presentation/auth/register_artisan_screen.dart';
import '../presentation/auth/register_client_screen.dart';
import '../presentation/auth/forgot_pin_phone_screen.dart';
import '../presentation/auth/otp_verification_screen.dart';
import '../presentation/auth/pin_setup_screen.dart';
import '../presentation/client/client_dashboard.dart';
import '../presentation/client/search_screen.dart';
import '../presentation/client/artisan_profile_screen.dart';
import '../presentation/client/review_screen.dart';
import '../presentation/artisan/artisan_dashboard.dart';
import '../presentation/artisan/portfolio_screen.dart';
import '../presentation/artisan/artisan_reviews_history_screen.dart';
import '../presentation/artisan/verification_screen.dart';
import '../presentation/artisan/subscription_screen.dart';
import '../presentation/chat/conversations_list.dart';
import '../presentation/chat/chat_screen.dart';
import '../presentation/shared/notifications_screen.dart';
import '../presentation/shared/settings_screen.dart';
import '../presentation/shared/client_profile_screen.dart';
import '../presentation/shared/my_artisan_profile_screen.dart';
import '../presentation/shared/about_screen.dart';

// Shell keys for bottom nav
final _clientShellKey = GlobalKey<NavigatorState>(debugLabel: 'clientShell');
final _artisanShellKey = GlobalKey<NavigatorState>(debugLabel: 'artisanShell');

// Custom slide+fade transition
CustomTransitionPage<void> _buildTransition(
  GoRouterState state,
  Widget child, {
  Duration duration = const Duration(milliseconds: 350),
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      );
    },
  );
}

Future<bool> _isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(AppConstants.keyOnboardingCompleted) ?? false;
}

Future<String> _resolveLaunchPath() async {
  final completed = await _isOnboardingCompleted();
  return completed ? '/login' : '/onboarding';
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) async => _resolveLaunchPath(),
    ),

    // Onboarding
    GoRoute(
      path: '/onboarding',
      redirect: (context, state) async {
        final completed = await _isOnboardingCompleted();
        return completed ? '/login' : null;
      },
      pageBuilder: (context, state) => _buildTransition(
        state,
        const OnboardingScreen(),
        duration: const Duration(milliseconds: 240),
      ),
    ),

    // Auth
    GoRoute(
      path: '/login',
      redirect: (context, state) async {
        final completed = await _isOnboardingCompleted();
        return completed ? null : '/onboarding';
      },
      pageBuilder: (context, state) =>
          _buildTransition(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/register',
      redirect: (context, state) async {
        final completed = await _isOnboardingCompleted();
        return completed ? null : '/onboarding';
      },
      pageBuilder: (context, state) =>
          _buildTransition(state, const RegisterChoiceScreen()),
    ),
    GoRoute(
      path: '/register/artisan',
      redirect: (context, state) async {
        final completed = await _isOnboardingCompleted();
        return completed ? null : '/onboarding';
      },
      pageBuilder: (context, state) =>
          _buildTransition(state, const RegisterArtisanScreen()),
    ),
    GoRoute(
      path: '/register/client',
      redirect: (context, state) async {
        final completed = await _isOnboardingCompleted();
        return completed ? null : '/onboarding';
      },
      pageBuilder: (context, state) =>
          _buildTransition(state, const RegisterClientScreen()),
    ),
    GoRoute(
      path: '/otp',
      pageBuilder: (context, state) => _buildTransition(
        state,
        OtpVerificationScreen(phone: state.extra as String? ?? ''),
      ),
    ),
    GoRoute(
      path: '/forgot-pin',
      pageBuilder: (context, state) =>
          _buildTransition(state, const ForgotPinPhoneScreen()),
    ),
    GoRoute(
      path: '/setup-pin',
      pageBuilder: (context, state) => _buildTransition(
        state,
        PinSetupScreen(phone: state.extra as String? ?? ''),
      ),
    ),

    // ──────────── CLIENT SHELL ────────────
    ShellRoute(
      navigatorKey: _clientShellKey,
      builder: (context, state, child) => _ClientShell(child: child),
      routes: [
        GoRoute(
          path: '/client',
          pageBuilder: (context, state) =>
              _buildTransition(state, const ClientDashboard()),
          routes: [
            GoRoute(
              path: 'search',
              pageBuilder: (context, state) => _buildTransition(
                state,
                SearchScreen(
                  initialParams: state.extra as Map<String, dynamic>?,
                ),
              ),
            ),
            GoRoute(
              path: 'artisan/:userId',
              pageBuilder: (context, state) => _buildTransition(
                state,
                ArtisanProfileScreen(userId: state.pathParameters['userId']!),
              ),
            ),
            GoRoute(
              path: 'review/:artisanId',
              pageBuilder: (context, state) => _buildTransition(
                state,
                ReviewScreen(artisanId: state.pathParameters['artisanId']!),
              ),
            ),
          ],
        ),
      ],
    ),

    // ──────────── ARTISAN SHELL ────────────
    ShellRoute(
      navigatorKey: _artisanShellKey,
      builder: (context, state, child) => _ArtisanShell(child: child),
      routes: [
        GoRoute(
          path: '/artisan',
          pageBuilder: (context, state) =>
              _buildTransition(state, const ArtisanDashboard()),
          routes: [
            GoRoute(
              path: 'portfolio',
              pageBuilder: (context, state) =>
                  _buildTransition(state, const PortfolioScreen()),
            ),
            GoRoute(
              path: 'reviews',
              pageBuilder: (context, state) =>
                  _buildTransition(state, const ArtisanReviewsHistoryScreen()),
            ),
            GoRoute(
              path: 'verification',
              pageBuilder: (context, state) =>
                  _buildTransition(state, const VerificationScreen()),
            ),
            GoRoute(
              path: 'subscription',
              pageBuilder: (context, state) =>
                  _buildTransition(state, const SubscriptionScreen()),
            ),
          ],
        ),
      ],
    ),

    // ──────────── SHARED ────────────
    GoRoute(
      path: '/chat',
      pageBuilder: (context, state) =>
          _buildTransition(state, const ConversationsListScreen()),
    ),
    GoRoute(
      path: '/chat/:conversationId',
      pageBuilder: (context, state) => _buildTransition(
        state,
        ChatScreen(
          conversationId: state.pathParameters['conversationId']!,
          participantName: state.uri.queryParameters['name'],
          participantId: state.uri.queryParameters['participantId'],
          participantAvatarUrl: state.uri.queryParameters['avatar'],
          participantRole: state.uri.queryParameters['participantRole'],
          participantIsAvailable:
              state.uri.queryParameters['participantIsAvailable'] == null
              ? null
              : state.uri.queryParameters['participantIsAvailable'] == 'true',
        ),
      ),
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) =>
          _buildTransition(state, const NotificationsScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          _buildTransition(state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/profile/client',
      pageBuilder: (context, state) =>
          _buildTransition(state, const ClientProfileScreen()),
    ),
    GoRoute(
      path: '/profile/artisan',
      pageBuilder: (context, state) =>
          _buildTransition(state, const MyArtisanProfileScreen()),
    ),
    GoRoute(
      path: '/about',
      pageBuilder: (context, state) =>
          _buildTransition(state, const AboutScreen()),
    ),
  ],
);

// ──────────── Client Shell with Bottom Nav ────────────
class _ClientShell extends ConsumerWidget {
  final Widget child;
  const _ClientShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final badgeCounts = ref.watch(badgeCountsProvider);

    int currentIndex = 0;
    if (location.contains('/chat')) currentIndex = 1;
    if (location.contains('/notifications')) currentIndex = 2;
    if (location.contains('/settings')) currentIndex = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/client');
            case 1:
              context.push('/chat');
            case 2:
              context.push('/notifications');
            case 3:
              context.push('/settings');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: 'nav.home'.tr(),
          ),
          NavigationDestination(
            icon: CountBadgedIcon(
              count: badgeCounts.messagesUnread,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: CountBadgedIcon(
              count: badgeCounts.messagesUnread,
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'nav.messages'.tr(),
          ),
          NavigationDestination(
            icon: CountBadgedIcon(
              count: badgeCounts.notificationsUnread,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            selectedIcon: CountBadgedIcon(
              count: badgeCounts.notificationsUnread,
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'nav.notifications'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: 'nav.settings'.tr(),
          ),
        ],
      ),
    );
  }
}

// ──────────── Artisan Shell with Bottom Nav ────────────
class _ArtisanShell extends ConsumerWidget {
  final Widget child;
  const _ArtisanShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final badgeCounts = ref.watch(badgeCountsProvider);

    int currentIndex = 0;
    if (location.contains('/chat')) currentIndex = 1;
    if (location.contains('/notifications')) currentIndex = 2;
    if (location.contains('/settings')) currentIndex = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/artisan');
            case 1:
              context.push('/chat');
            case 2:
              context.push('/notifications');
            case 3:
              context.push('/settings');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: 'nav.dashboard'.tr(),
          ),
          NavigationDestination(
            icon: CountBadgedIcon(
              count: badgeCounts.messagesUnread,
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: CountBadgedIcon(
              count: badgeCounts.messagesUnread,
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'nav.messages'.tr(),
          ),
          NavigationDestination(
            icon: CountBadgedIcon(
              count: badgeCounts.notificationsUnread,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            selectedIcon: CountBadgedIcon(
              count: badgeCounts.notificationsUnread,
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'nav.notifications'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: 'nav.settings'.tr(),
          ),
        ],
      ),
    );
  }
}
