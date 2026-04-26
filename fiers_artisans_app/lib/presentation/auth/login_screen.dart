import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme.dart';
import '../../core/storage/secure_storage.dart';
import '../../providers/auth_provider.dart';
import '../common/app_button.dart';
import '../common/pin_code_field.dart';
import '../common/app_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  Timer? _autoLoginDebounce;
  String _lastAutoAttemptSignature = '';
  bool _isHydratingPhone = false;

  @override
  void initState() {
    super.initState();
    _pinController.clear();
    _hydrateSavedPhone();
  }

  @override
  void dispose() {
    _autoLoginDebounce?.cancel();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _hydrateSavedPhone() async {
    if (_isHydratingPhone) return;
    _isHydratingPhone = true;
    try {
      final savedPhone = await SecureStorage.getLastLoginPhone();
      if (!mounted) return;
      final normalized = savedPhone?.trim() ?? '';
      if (normalized.isNotEmpty && _phoneController.text.trim().isEmpty) {
        _phoneController.text = normalized;
        _phoneController.selection = TextSelection.fromPosition(
          TextPosition(offset: _phoneController.text.length),
        );
      }
    } finally {
      _isHydratingPhone = false;
    }
  }

  bool _isCredentialsValidForAutoLogin() {
    final phone = _phoneController.text.trim();
    final pinCode = _pinController.text;
    return _isPhoneComplete(phone) && pinCode.length == 5;
  }

  bool _isPhoneComplete(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length >= 10;
  }

  void _dismissKeyboard() {
    final focusScope = FocusScope.of(context);
    if (!focusScope.hasPrimaryFocus) {
      focusScope.unfocus();
    }
  }

  void _scheduleAutoLoginIfReady({bool fromPinInput = false}) {
    if (_isLoading) return;
    _autoLoginDebounce?.cancel();

    if (!_isCredentialsValidForAutoLogin()) {
      return;
    }

    if (fromPinInput && _pinController.text.length == 5) {
      _dismissKeyboard();
    }

    final signature = '${_phoneController.text.trim()}|${_pinController.text}';
    if (signature == _lastAutoAttemptSignature) {
      return;
    }

    _autoLoginDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || _isLoading) return;
      final latestSignature =
          '${_phoneController.text.trim()}|${_pinController.text}';
      if (latestSignature != signature) return;
      _dismissKeyboard();
      _login(triggeredByAuto: true);
    });
  }

  Future<void> _login({bool triggeredByAuto = false}) async {
    if (_isLoading) return;

    if (triggeredByAuto) {
      _dismissKeyboard();
    }

    if (!_formKey.currentState!.validate()) return;

    final signature = '${_phoneController.text.trim()}|${_pinController.text}';
    if (triggeredByAuto && signature == _lastAutoAttemptSignature) {
      return;
    }

    _lastAutoAttemptSignature = signature;

    setState(() => _isLoading = true);
    final success = await ref
        .read(authProvider.notifier)
        .login(
          phone: _phoneController.text.trim(),
          pinCode: _pinController.text,
        );
    setState(() => _isLoading = false);

    if (success && mounted) {
      final role = ref.read(authProvider).user?.role.toLowerCase();
      if (role == 'artisan') {
        context.go('/artisan');
      } else {
        context.go('/client');
      }
    } else if (mounted) {
      final authState = ref.read(authProvider);
      if (authState.otpRequired && authState.otpPhone != null) {
        context.push('/otp', extra: authState.otpPhone);
        return;
      }
      if (authState.pinSetupRequired && authState.pinSetupPhone != null) {
        context.push('/setup-pin', extra: authState.pinSetupPhone);
        return;
      }
      final error = authState.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'error.generic'.tr()),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_phoneController.text.trim().isEmpty && !_isHydratingPhone) {
      Future.microtask(_hydrateSavedPhone);
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                // Header
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      size: 40,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'auth.welcome'.tr(),
                    style: theme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'auth.login'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Phone
                AppTextField(
                  controller: _phoneController,
                  label: 'auth.phone'.tr(),
                  hint: '07 XX XX XX XX',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  onChanged: (_) => _scheduleAutoLoginIfReady(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'auth.phone_required'.tr();
                    }
                    if (!_isPhoneComplete(v)) {
                      return 'auth.phone_invalid'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // PIN
                PinCodeField(
                  controller: _pinController,
                  label: 'auth.pin'.tr(),
                  hint: '•••••',
                  textInputAction: TextInputAction.done,
                  onChanged: (_) =>
                      _scheduleAutoLoginIfReady(fromPinInput: true),
                  onSubmitted: (_) => _login(),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'auth.pin_required'.tr();
                    }
                    if (v.length != 5) {
                      return 'auth.pin_5_digits'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Login button
                AppButton(
                  text: 'auth.login'.tr(),
                  isLoading: _isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: 24),

                // Register link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'auth.no_account'.tr(),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => context.push('/register'),
                        child: Text(
                          'auth.register'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
