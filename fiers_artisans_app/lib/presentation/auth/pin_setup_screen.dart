import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../common/app_button.dart';
import '../common/app_text_field.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  final String phone;

  const PinSetupScreen({super.key, required this.phone});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _isLoading = false;
  int _resendTimer = AppConfig.otpResendDelay;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    Future.microtask(_sendOtpSilently);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtpSilently() async {
    try {
      await ref.read(authProvider.notifier).sendOtp(widget.phone);
    } catch (_) {}
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

  Future<void> _resend() async {
    if (_resendTimer > 0) return;

    try {
      await ref.read(authProvider.notifier).sendOtp(widget.phone);
      _startResendTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.otp.sent'.tr(namedArgs: {'phone': widget.phone}))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth.otp.unavailable'.tr()),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final success = await ref.read(authProvider.notifier).setupPin(
          phone: widget.phone,
          code: _otpCtrl.text.trim(),
          pinCode: _pinCtrl.text,
        );
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      final role = ref.read(authProvider).user?.role.toLowerCase();
      if (role == 'artisan') {
        context.go('/artisan');
      } else {
        context.go('/client');
      }
      return;
    }

    final error = ref.read(authProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'error.generic'.tr()),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('auth.pin_setup.title'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'auth.pin_setup.subtitle'.tr(namedArgs: {'phone': widget.phone}),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _otpCtrl,
                  label: 'auth.pin_setup.otp_label'.tr(),
                  hint: '000000',
                  prefixIcon: Icons.sms_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.length != 6) return 'auth.pin_setup.otp_6_digits'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _pinCtrl,
                  label: 'auth.pin'.tr(),
                  hint: '•••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 5,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if ((v ?? '').length != 5) return 'auth.pin_5_digits'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmPinCtrl,
                  label: 'auth.confirm_pin'.tr(),
                  hint: '•••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 5,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v != _pinCtrl.text) return 'auth.pin_mismatch'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                AppButton(
                  text: 'auth.pin_setup.cta'.tr(),
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    onTap: _resendTimer == 0 ? _resend : null,
                    child: Text(
                      _resendTimer > 0
                          ? 'auth.otp.resend_in'.tr(namedArgs: {'seconds': '$_resendTimer'})
                          : 'auth.otp.resend'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _resendTimer == 0
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodySmall?.color,
                        fontWeight: _resendTimer == 0 ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
