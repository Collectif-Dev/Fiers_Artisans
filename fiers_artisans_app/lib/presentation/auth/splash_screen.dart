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
  static const Duration _minSplashVisible = Duration(milliseconds: 900);

  late AnimationController _controller;
  late Animation<double> _darkScaleAnimation;
  late DateTime _splashStartedAt;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _splashStartedAt = DateTime.now();
    _controller = AnimationController(
      vsync: this,
      duration: _minSplashVisible,
    );

    _darkScaleAnimation = Tween<double>(begin: 0.24, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
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
      const AssetImage('assets/branding/splash_dark_layer_1.png'),
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

  Widget _buildDarkAnimatedLogo() {
    return ScaleTransition(
      scale: _darkScaleAnimation,
      child: SizedBox(
        width: 320,
        height: 320,
        child: Image.asset(
          'assets/branding/splash_dark_layer_1.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/branding/logo_app_dark.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/branding/logo_app.png',
                  fit: BoxFit.contain,
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockupAsset = isDark
        ? 'assets/branding/logo_lockup_dark.png'
        : 'assets/branding/logo_lockup_light.png';

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF000000), const Color(0xFF000000)]
                : [const Color(0xFFF7F7F9), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isDark)
              _buildDarkAnimatedLogo()
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Image.asset(
                    lockupAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/branding/logo_app.png',
                        fit: BoxFit.contain,
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
