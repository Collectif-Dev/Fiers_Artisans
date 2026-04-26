import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../common/app_button.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendTimer = AppConfig.otpResendDelay;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-send OTP
    Future.microtask(() {
      ref.read(authProvider.notifier).sendOtp(widget.phone);
    });
  }

  void _startResendTimer() {
    _resendTimer = AppConfig.otpResendDelay;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final code = _code;
    if (code.length != 6) return;

    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).verifyOtp(
          phone: widget.phone,
          code: code,
        );
    setState(() => _isLoading = false);

    if (success && mounted) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        // Flux inscription: l'utilisateur a déjà des tokens
        final role = user.role.toLowerCase();
        if (role == 'artisan') {
          context.go('/artisan');
        } else {
          context.go('/client');
        }
      } else {
        // Flux login 403: pas de tokens, l'utilisateur doit se reconnecter
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('auth.otp.verified_login'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/login');
        }
      }
    } else if (mounted) {
      // Effacer les champs pour une nouvelle saisie
      for (var c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth.otp.invalid'.tr()),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _resend() async {
    if (_resendTimer > 0) return;
    try {
      await ref.read(authProvider.notifier).sendOtp(widget.phone);
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.otp.sent'.tr(namedArgs: {'phone': widget.phone}))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('auth.otp.unavailable'.tr()),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('auth.otp.title'.tr())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(Icons.verified_user_outlined,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'auth.otp.title'.tr(),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'auth.otp.subtitle'.tr(namedArgs: {'phone': widget.phone}),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // OTP fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: theme.textTheme.headlineMedium,
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _focusNodes[index + 1].requestFocus();
                        }
                        if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        if (_code.length == 6) {
                          _verify();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              AppButton(
                text: 'auth.otp.verify'.tr(),
                isLoading: _isLoading,
                onPressed: _code.length == 6 ? _verify : null,
              ),
              const SizedBox(height: 20),

              // Resend
              GestureDetector(
                onTap: _resendTimer == 0 ? _resend : null,
                child: Text(
                  _resendTimer > 0
                      ? 'auth.otp.resend_in'
                          .tr(namedArgs: {'seconds': '$_resendTimer'})
                      : 'auth.otp.resend'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _resendTimer == 0
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodySmall?.color,
                    fontWeight:
                        _resendTimer == 0 ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
