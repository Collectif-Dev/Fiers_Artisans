import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/phone_number.dart';
import '../common/app_button.dart';
import '../common/app_snackbar.dart';
import '../common/app_text_field.dart';
import 'widgets/auth_preferences_bar.dart';

class ForgotPinPhoneScreen extends StatefulWidget {
  const ForgotPinPhoneScreen({super.key});

  @override
  State<ForgotPinPhoneScreen> createState() => _ForgotPinPhoneScreenState();
}

class _ForgotPinPhoneScreenState extends State<ForgotPinPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isHydratingPhone = false;
  bool _isLoading = false;
  bool _phoneAttested = false;

  @override
  void initState() {
    super.initState();
    _hydrateSavedPhone();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _hydrateSavedPhone() async {
    if (_isHydratingPhone) return;
    _isHydratingPhone = true;
    try {
      final savedPhone = await SecureStorage.getLastLoginPhone();
      if (!mounted) return;
      final normalized = normalizeLocalPhoneNumber(savedPhone ?? '');
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

  Future<bool> _confirmPhoneDialog(String phone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('auth.forgot_pin_flow.confirm_title'.tr()),
          content: Text(
            'auth.forgot_pin_flow.confirm_message'.tr(
              namedArgs: {'phone': phone},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('auth.forgot_pin_flow.confirm_edit'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('auth.forgot_pin_flow.confirm_continue'.tr()),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<void> _continueToPinReset() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_phoneAttested) {
      AppSnackBar.show(
        context,
        message: 'auth.forgot_pin_flow.attestation_required'.tr(),
        backgroundColor: AppTheme.error,
      );
      return;
    }

    final phone = normalizeLocalPhoneNumber(_phoneController.text.trim());

    setState(() => _isLoading = true);
    final confirmed = await _confirmPhoneDialog(phone);
    if (!mounted) return;

    if (!confirmed) {
      setState(() => _isLoading = false);
      return;
    }

    context.push('/setup-pin', extra: phone);
    setState(() => _isLoading = false);
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
                Align(
                  alignment: Alignment.centerRight,
                  child: AuthPreferencesBar(compact: true),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 40,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'auth.forgot_pin_flow.title'.tr(),
                    style: theme.textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'auth.forgot_pin_flow.subtitle'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _phoneController,
                  label: 'auth.phone'.tr(),
                  hint: '07 XX XX XX XX',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: const [LocalPhoneNumberInputFormatter()],
                  maxLength: localPhoneNumberLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _continueToPinReset(),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) {
                      return 'auth.phone_required'.tr();
                    }
                    if (!isLocalPhoneNumber(value)) {
                      return 'auth.phone_invalid'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _phoneAttested,
                  onChanged: (value) {
                    setState(() => _phoneAttested = value ?? false);
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('auth.forgot_pin_flow.attestation'.tr()),
                ),
                const SizedBox(height: 18),
                AppButton(
                  text: 'auth.forgot_pin_flow.cta'.tr(),
                  isLoading: _isLoading,
                  onPressed: _continueToPinReset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
