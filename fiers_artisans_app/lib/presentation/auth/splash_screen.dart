import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minSplashVisible = Duration(milliseconds: 1800);

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late DateTime _splashStartedAt;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _splashStartedAt = DateTime.now();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    final authState = ref.read(authProvider);
    _scheduleNavigation(authState);

    ref.listenManual<AuthState>(authProvider, (previous, next) {
      _scheduleNavigation(next);
    });

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(
      const AssetImage('assets/branding/logo_lockup_dark.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/branding/logo_lockup_light.png'),
      context,
    );
  }

  void _scheduleNavigation(AuthState authState) {
    if (_navigated) return;
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      return;
    }

    final elapsed = DateTime.now().difference(_splashStartedAt);
    final remaining = _minSplashVisible - elapsed;

    if (remaining <= Duration.zero) {
      _navigate(authState);
      return;
    }

    Future.delayed(remaining, () {
      _navigate(authState);
    });
  }

  void _navigate(AuthState authState) {
    if (_navigated || !mounted) return;
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      return;
    }

    _navigated = true;

    if (authState.status == AuthStatus.authenticated) {
      final role = authState.user?.role.toLowerCase() ?? '';
      if (role == 'artisan') {
        context.go('/artisan');
      } else {
        context.go('/client');
      }
    } else {
      final onboardingDone = ref.read(onboardingCompletedProvider);
      if (onboardingDone) {
        context.go('/login');
      } else {
        context.go('/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Image.asset(
            isDark
                ? 'assets/branding/logo_lockup_dark.png'
                : 'assets/branding/logo_lockup_light.png',
            width: MediaQuery.of(context).size.width * 0.72,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
