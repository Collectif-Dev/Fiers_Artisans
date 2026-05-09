import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../common/app_snackbar.dart';
import '../common/app_button.dart';
import '../common/pin_code_field.dart';
import '../common/app_text_field.dart';

class RegisterClientScreen extends ConsumerStatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  ConsumerState<RegisterClientScreen> createState() =>
      _RegisterClientScreenState();
}

class _RegisterClientScreenState extends ConsumerState<RegisterClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _communeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final LocationService _locationService = LocationService();
  bool _isLoading = false;
  bool _isPrefillingLocation = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _prefillLocation() async {
    if (!mounted) return;
    setState(() => _isPrefillingLocation = true);

    final result = await _locationService.getCurrentLocationResult(
      reverseGeocode: true,
      requestPermission: true,
    );

    if (!mounted) return;

    final snapshot = result.snapshot;
    if (snapshot != null) {
      _latitude = snapshot.latitude;
      _longitude = snapshot.longitude;

      if (_cityCtrl.text.trim().isEmpty &&
          (snapshot.city?.isNotEmpty ?? false)) {
        _cityCtrl.text = snapshot.city!.trim();
      }

      if (_communeCtrl.text.trim().isEmpty &&
          (snapshot.commune?.isNotEmpty ?? false)) {
        _communeCtrl.text = snapshot.commune!.trim();
      }
      if (result.issueType == LocationIssueType.reverseGeocodingFailed &&
          result.message != null) {
        AppSnackBar.show(
          context,
          message: 'location.error_reverse_geocoding_failed'.tr(),
        );
      }
    } else {
      final message = _locationIssueMessage(result.issueType);
      final actionLabel =
          result.issueType == LocationIssueType.permissionDeniedForever
          ? 'location.open_settings'.tr()
          : result.issueType == LocationIssueType.servicesDisabled
          ? 'location.enable_gps'.tr()
          : null;
      final actionCallback =
          result.issueType == LocationIssueType.permissionDeniedForever
          ? Geolocator.openAppSettings
          : result.issueType == LocationIssueType.servicesDisabled
          ? Geolocator.openLocationSettings
          : null;

      AppSnackBar.show(
        context,
        message: message,
        actionLabel: actionLabel,
        onAction: actionCallback,
      );
    }

    setState(() => _isPrefillingLocation = false);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _cityCtrl.dispose();
    _communeCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final success = await ref
        .read(authProvider.notifier)
        .registerClient(
          phone: _phoneCtrl.text.trim(),
          pinCode: _pinCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          commune: _communeCtrl.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          email: _emailCtrl.text.trim().isNotEmpty
              ? _emailCtrl.text.trim()
              : null,
        );
    setState(() => _isLoading = false);

    if (success && mounted) {
      final phone = _phoneCtrl.text.trim();
      context.push('/otp', extra: phone);
    } else if (mounted) {
      AppSnackBar.show(
        context,
        message: ref.read(authProvider).error ?? 'error.generic'.tr(),
        backgroundColor: AppTheme.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('auth.client'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _firstNameCtrl,
                        label: 'auth.first_name'.tr(),
                        prefixIcon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v!.isEmpty ? 'common.required'.tr() : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _lastNameCtrl,
                        label: 'auth.last_name'.tr(),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v!.isEmpty ? 'common.required'.tr() : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _phoneCtrl,
                  label: 'auth.phone'.tr(),
                  hint: '07 XX XX XX XX',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (v) => v!.isEmpty ? 'common.required'.tr() : null,
                ),
                const SizedBox(height: 16),

                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isPrefillingLocation ? null : _prefillLocation,
                    icon: _isPrefillingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      _isPrefillingLocation
                          ? 'location.prefill_in_progress'.tr()
                          : 'location.use_current_position'.tr(),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _cityCtrl,
                        label: 'auth.city'.tr(),
                        hint: 'Abidjan',
                        prefixIcon: Icons.location_city_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v!.isEmpty ? 'common.required'.tr() : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _communeCtrl,
                        label: 'auth.commune'.tr(),
                        hint: 'Cocody',
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v!.isEmpty ? 'common.required'.tr() : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _emailCtrl,
                  label: 'auth.email'.tr(),
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                PinCodeField(
                  controller: _pinCtrl,
                  label: 'auth.pin'.tr(),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'auth.pin'.tr();
                    if (v.length != 5) return 'auth.pin_5_digits'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                PinCodeField(
                  controller: _confirmPinCtrl,
                  label: 'auth.confirm_pin'.tr(),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _register(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'auth.confirm_pin'.tr();
                    if (v != _pinCtrl.text) return 'auth.pin_mismatch'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                AppButton(
                  text: 'auth.register'.tr(),
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _locationIssueMessage(LocationIssueType? issueType) {
    return switch (issueType) {
      LocationIssueType.servicesDisabled =>
        'location.error_services_disabled'.tr(),
      LocationIssueType.permissionDenied =>
        'location.error_permission_required'.tr(),
      LocationIssueType.permissionDeniedForever =>
        'location.error_permission_denied_forever'.tr(),
      LocationIssueType.positionReadFailed =>
        'location.error_position_failed'.tr(),
      LocationIssueType.reverseGeocodingFailed =>
        'location.error_reverse_geocoding_failed'.tr(),
      _ => 'location.error_position_failed'.tr(),
    };
  }
}
