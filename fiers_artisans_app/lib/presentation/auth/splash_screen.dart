import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _minSplashVisible = Duration(milliseconds: 3200);
  static const Duration _timelineDuration = Duration(milliseconds: 2550);
  static const Duration _ambientDuration = Duration(seconds: 14);
  static const Duration _exitDuration = Duration(milliseconds: 440);
  static const String _brandWord = 'Fiers Artisans';

  late final AnimationController _timelineController;
  late final AnimationController _ambientController;
  late final AnimationController _exitController;
  late final List<_LetterSeed> _letterSeeds;
  late final List<_ParticleSeed> _particleSeeds;
  late final ProviderSubscription<AuthState> _authSubscription;
  late DateTime _splashStartedAt;

  Timer? _pendingNavTimer;
  AuthState? _latestAuthState;
  bool _navigated = false;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _splashStartedAt = DateTime.now();

    _timelineController = AnimationController(
      vsync: this,
      duration: _timelineDuration,
    )..forward();

    _ambientController = AnimationController(
      vsync: this,
      duration: _ambientDuration,
    )..repeat();

    _exitController = AnimationController(vsync: this, duration: _exitDuration);

    _letterSeeds = _buildLetterSeeds(_brandWord.length);
    _particleSeeds = _buildParticleSeeds();

    final authState = ref.read(authProvider);
    _latestAuthState = authState;
    _scheduleNavigation(authState);

    _authSubscription = ref.listenManual<AuthState>(authProvider, (
      previous,
      next,
    ) {
      _latestAuthState = next;
      _scheduleNavigation(next);
    });
  }

  void _scheduleNavigation(AuthState authState) {
    if (_navigated || _isExiting) return;
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      return;
    }

    final elapsed = DateTime.now().difference(_splashStartedAt);
    final remaining = _minSplashVisible - elapsed;

    if (remaining <= Duration.zero) {
      _triggerExitAndNavigate();
      return;
    }

    _pendingNavTimer?.cancel();
    _pendingNavTimer = Timer(remaining, () {
      _triggerExitAndNavigate();
    });
  }

  Future<void> _triggerExitAndNavigate() async {
    if (_navigated || _isExiting || !mounted) return;

    final authState = _latestAuthState ?? ref.read(authProvider);
    if (authState == null) {
      return;
    }
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      return;
    }

    _isExiting = true;
    if (_timelineController.value < 1) {
      _timelineController.forward(from: _timelineController.value);
    }

    await _exitController.forward();
    _navigate(authState);
  }

  void _navigate(AuthState authState) {
    if (_navigated || !mounted) return;

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
    _pendingNavTimer?.cancel();
    _authSubscription.close();
    _timelineController.dispose();
    _ambientController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exitT = Curves.easeInOutCubic.transform(_exitController.value);

    final baseColor = isDark
        ? const Color(0xFF000000)
        : const Color(0xFFF6F8FC);
    final secondaryColor = isDark
        ? const Color(0xFF0D0D0F)
        : const Color(0xFFE7EDF8);

    final titleColor = isDark
        ? const Color(0xFFF3F7FF)
        : const Color(0xFF0F1A2B);

    return Scaffold(
      backgroundColor: baseColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _timelineController,
          _ambientController,
          _exitController,
        ]),
        builder: (context, child) {
          return Opacity(
            opacity: 1 - exitT,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 9 * exitT,
                sigmaY: 9 * exitT,
              ),
              child: Transform.scale(
                scale: 1 - (0.04 * exitT),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.2),
                          radius: 1.2,
                          colors: [secondaryColor, baseColor],
                          stops: const [0.08, 1],
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _ParticleFieldPainter(
                        progress: _ambientController.value,
                        particles: _particleSeeds,
                        isDark: isDark,
                      ),
                    ),
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final height = constraints.maxHeight;
                          final sizeFactor = width < 360 ? 0.1 : 0.112;
                          final fontSize = (width * sizeFactor).clamp(
                            30.0,
                            46.0,
                          );

                          final settleProgress = Curves.easeOutCubic.transform(
                            _intervalValue(_timelineController.value, 0.74, 1),
                          );

                          final shimmerPulse =
                              (0.5 +
                                  0.5 *
                                      sin(_ambientController.value * pi * 2)) *
                              settleProgress;

                          final toolAttachProgress = Curves.easeOutBack
                              .transform(
                                _intervalValue(
                                  _timelineController.value,
                                  0.44,
                                  0.94,
                                ),
                              );
                          final toolOpacity = Curves.easeIn.transform(
                            _intervalValue(
                              _timelineController.value,
                              0.52,
                              0.94,
                            ),
                          );
                          final toolPulse =
                              1 +
                              (0.028 *
                                  sin(
                                    (_ambientController.value * pi * 2) + 0.9,
                                  ) *
                                  settleProgress);

                          final shadowBlur =
                              (isDark ? 14.0 : 9.0) * shimmerPulse;
                          final letterSpacing = width < 360 ? 0.4 : 0.9;
                          final toolColor = isDark
                              ? const Color(0xFFFFB347)
                              : const Color(0xFFD17A00);

                          return SizedBox(
                            width: width,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...List.generate(_brandWord.length, (index) {
                                    final char = _brandWord[index];
                                    if (char == ' ') {
                                      return SizedBox(width: fontSize * 0.26);
                                    }

                                    final seed = _letterSeeds[index];
                                    final start = 0.06 + (index * 0.038);
                                    final end = (start + 0.42).clamp(0.0, 1.0);
                                    final t = Curves.easeOutCubic.transform(
                                      _intervalValue(
                                        _timelineController.value,
                                        start,
                                        end,
                                      ),
                                    );
                                    final opacity = Curves.easeIn.transform(
                                      _intervalValue(
                                        _timelineController.value,
                                        start * 0.8,
                                        end,
                                      ),
                                    );

                                    final drift = Offset(
                                      seed.dxFactor * width * (1 - t),
                                      seed.dyFactor * height * (1 - t),
                                    );
                                    final rotation = seed.rotation * (1 - t);
                                    final zScale =
                                        lerpDouble(seed.startScale, 1, t) ?? 1;
                                    final depthScale =
                                        1 + ((seed.depth / 360) * (1 - t));
                                    final composedScale = (zScale * depthScale)
                                        .clamp(0.68, 1.45);
                                    final blur = (seed.startBlur * (1 - t))
                                        .clamp(0.0, 6.0);

                                    final textStyle =
                                        GoogleFonts.plusJakartaSans(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: letterSpacing,
                                          color: titleColor,
                                          shadows: [
                                            Shadow(
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha:
                                                          0.20 * settleProgress,
                                                    )
                                                  : const Color(
                                                      0xFF8AA4D2,
                                                    ).withValues(
                                                      alpha:
                                                          0.18 * settleProgress,
                                                    ),
                                              blurRadius: shadowBlur,
                                            ),
                                          ],
                                        );

                                    Widget letter = Text(
                                      char,
                                      style: textStyle,
                                    );

                                    if (blur > 0.1) {
                                      letter = ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: blur,
                                          sigmaY: blur,
                                        ),
                                        child: letter,
                                      );
                                    }

                                    return Opacity(
                                      opacity: opacity,
                                      child: Transform.translate(
                                        offset: drift,
                                        child: Transform.rotate(
                                          angle: rotation,
                                          child: Transform.scale(
                                            scale: composedScale,
                                            child: letter,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  SizedBox(width: fontSize * 0.2),
                                  Opacity(
                                    opacity: toolOpacity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        fontSize *
                                            1.35 *
                                            (1 - toolAttachProgress),
                                        (-fontSize * 0.95) *
                                            (1 - toolAttachProgress),
                                      ),
                                      child: Transform.rotate(
                                        angle: 0.74 * (1 - toolAttachProgress),
                                        child: Transform.scale(
                                          scale:
                                              (0.76 +
                                                  (0.24 * toolAttachProgress)) *
                                              toolPulse,
                                          child: Container(
                                            padding: EdgeInsets.all(
                                              fontSize * 0.16,
                                            ),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.06,
                                                    )
                                                  : Colors.white.withValues(
                                                      alpha: 0.72,
                                                    ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: toolColor.withValues(
                                                    alpha: isDark ? 0.30 : 0.24,
                                                  ),
                                                  blurRadius: fontSize * 0.34,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.handyman_rounded,
                                              color: toolColor,
                                              size: fontSize * 0.68,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_LetterSeed> _buildLetterSeeds(int count) {
    final random = Random(2026);
    return List.generate(count, (index) {
      if (_brandWord[index] == ' ') {
        return const _LetterSeed(
          dxFactor: 0,
          dyFactor: 0,
          rotation: 0,
          startScale: 1,
          depth: 0,
          startBlur: 0,
        );
      }

      final direction = random.nextInt(4);
      final primary = 0.8 + random.nextDouble() * 0.65;
      final secondary = -0.45 + random.nextDouble() * 0.9;

      double dx = secondary;
      double dy = secondary;

      switch (direction) {
        case 0:
          dx = secondary;
          dy = -primary;
          break;
        case 1:
          dx = secondary;
          dy = primary;
          break;
        case 2:
          dx = -primary;
          dy = secondary;
          break;
        case 3:
          dx = primary;
          dy = secondary;
          break;
      }

      return _LetterSeed(
        dxFactor: dx,
        dyFactor: dy,
        rotation: -0.52 + random.nextDouble() * 1.04,
        startScale: 0.72 + random.nextDouble() * 0.72,
        depth: -110 + random.nextDouble() * 220,
        startBlur: 0.7 + random.nextDouble() * 5.9,
      );
    });
  }

  List<_ParticleSeed> _buildParticleSeeds() {
    final random = Random(8021);
    return List.generate(26, (_) {
      return _ParticleSeed(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 0.002 + random.nextDouble() * 0.005,
        opacity: 0.3 + random.nextDouble() * 0.7,
        drift: 0.008 + random.nextDouble() * 0.018,
        phase: random.nextDouble() * pi * 2,
      );
    });
  }

  double _intervalValue(double value, double begin, double end) {
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return (value - begin) / (end - begin);
  }
}

class _ParticleFieldPainter extends CustomPainter {
  final double progress;
  final List<_ParticleSeed> particles;
  final bool isDark;

  _ParticleFieldPainter({
    required this.progress,
    required this.particles,
    required this.isDark,
  }) : super(repaint: AlwaysStoppedAnimation(progress));

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = isDark ? Colors.white : const Color(0xFFE8A020);
    final glowStrength = isDark ? 0.15 : 0.34;
    final shortSide = size.shortestSide;

    for (final particle in particles) {
      final driftX = sin((progress * pi * 2) + particle.phase) * particle.drift;
      final driftY =
          cos((progress * pi * 1.65) + particle.phase * 0.7) * particle.drift;

      final dx = (particle.x + driftX).clamp(0.02, 0.98) * size.width;
      final dy = (particle.y + driftY).clamp(0.02, 0.98) * size.height;
      final radius = shortSide * particle.radius;
      final visibleRadius = isDark ? radius : radius * 1.22;

      final paint = Paint()
        ..color = baseColor.withValues(alpha: glowStrength * particle.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 1.5 : 2.2);

      canvas.drawCircle(Offset(dx, dy), visibleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleFieldPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class _LetterSeed {
  final double dxFactor;
  final double dyFactor;
  final double rotation;
  final double startScale;
  final double depth;
  final double startBlur;

  const _LetterSeed({
    required this.dxFactor,
    required this.dyFactor,
    required this.rotation,
    required this.startScale,
    required this.depth,
    required this.startBlur,
  });
}

class _ParticleSeed {
  final double x;
  final double y;
  final double radius;
  final double opacity;
  final double drift;
  final double phase;

  const _ParticleSeed({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
    required this.drift,
    required this.phase,
  });
}
