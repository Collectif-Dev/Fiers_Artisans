import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/categories_provider.dart';
import '../../data/models/category_model.dart';
import '../../services/location_service.dart';
import '../common/app_button.dart';
import '../common/pin_code_field.dart';
import '../common/app_text_field.dart';

class RegisterArtisanScreen extends ConsumerStatefulWidget {
  const RegisterArtisanScreen({super.key});

  @override
  ConsumerState<RegisterArtisanScreen> createState() =>
      _RegisterArtisanScreenState();
}

class _RegisterArtisanScreenState extends ConsumerState<RegisterArtisanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _communeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final LocationService _locationService = LocationService();
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  bool _isLoading = false;
  bool _submitAttempted = false;
  bool _isPrefillingLocation = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(categoriesProvider.notifier).load());
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('location.error_reverse_geocoding_failed'.tr()),
          ),
        );
      }
    } else {
      final message = _locationIssueMessage(result.issueType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: result.issueType == LocationIssueType.permissionDeniedForever
              ? SnackBarAction(
                  label: 'location.open_settings'.tr(),
                  onPressed: Geolocator.openAppSettings,
                )
              : result.issueType == LocationIssueType.servicesDisabled
              ? SnackBarAction(
                  label: 'location.enable_gps'.tr(),
                  onPressed: Geolocator.openLocationSettings,
                )
              : null,
        ),
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
    _businessNameCtrl.dispose();
    _cityCtrl.dispose();
    _communeCtrl.dispose();
    _emailCtrl.dispose();
    _descriptionCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _submitAttempted = true);

    final formIsValid = _formKey.currentState!.validate();
    final categoryIsValid = _selectedCategoryId != null;
    final subcategoryIsValid = _selectedSubcategoryId != null;
    if (!formIsValid || !categoryIsValid || !subcategoryIsValid) {
      return;
    }

    setState(() => _isLoading = true);
    final success = await ref
        .read(authProvider.notifier)
        .registerArtisan(
          phone: _phoneCtrl.text.trim(),
          pinCode: _pinCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          categoryId: _selectedCategoryId!,
          subcategoryId: _selectedSubcategoryId!,
          businessName: _businessNameCtrl.text.trim().isNotEmpty
              ? _businessNameCtrl.text.trim()
              : null,
          city: _cityCtrl.text.trim(),
          commune: _communeCtrl.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          email: _emailCtrl.text.trim().isNotEmpty
              ? _emailCtrl.text.trim()
              : null,
          description: _descriptionCtrl.text.trim().isNotEmpty
              ? _descriptionCtrl.text.trim()
              : null,
          experienceYears: int.tryParse(_experienceCtrl.text),
        );
    setState(() => _isLoading = false);

    if (success && mounted) {
      final phone = _phoneCtrl.text.trim();
      context.push('/otp', extra: phone);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authProvider).error ?? 'error.generic'.tr()),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesProvider);
    final categories = categoriesState.categories;
    CategoryModel? selectedCategory;
    if (_selectedCategoryId != null) {
      for (final category in categories) {
        if (category.id == _selectedCategoryId) {
          selectedCategory = category;
          break;
        }
      }
    }
    final List<SubcategoryModel> subcategories =
        selectedCategory?.subcategories ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text('auth.artisan'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row
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

                AppTextField(
                  controller: _businessNameCtrl,
                  label: 'auth.business_name'.tr(),
                  hint: 'auth.business_name_hint'.tr(),
                  prefixIcon: Icons.storefront_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                Text(
                  'auth.activity_section'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _SelectField(
                  label: 'home.categories'.tr(),
                  icon: Icons.category_outlined,
                  text: selectedCategory?.name ?? 'search.all_categories'.tr(),
                  enabled: !categoriesState.isLoading && categories.isNotEmpty,
                  helperText: categoriesState.isLoading
                      ? 'common.loading'.tr()
                      : (!categoriesState.isLoading && categories.isEmpty)
                      ? 'auth.no_categories_available'.tr()
                      : null,
                  errorText: _submitAttempted && _selectedCategoryId == null
                      ? 'auth.category_required'.tr()
                      : null,
                  onTap: () async {
                    final selected = await _showOptionPicker(
                      title: 'home.categories'.tr(),
                      options: categories
                          .map((c) => _PickerOption(value: c.id, label: c.name))
                          .toList(),
                      selectedValue: _selectedCategoryId,
                    );
                    if (selected == null || !mounted) return;

                    setState(() {
                      _selectedCategoryId = selected.value;
                      _selectedSubcategoryId = null;
                    });
                  },
                ),
                if (categoriesState.error != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'auth.categories_load_error'.tr(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(categoriesProvider.notifier).refresh(),
                        child: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _SelectField(
                  label: 'auth.profession'.tr(),
                  icon: Icons.handyman_outlined,
                  text:
                      subcategories
                          .where((s) => s.id == _selectedSubcategoryId)
                          .map((s) => s.name)
                          .firstOrNull ??
                      'search.all_trades'.tr(),
                  enabled:
                      _selectedCategoryId != null &&
                      !categoriesState.isLoading &&
                      subcategories.isNotEmpty,
                  helperText: _selectedCategoryId == null
                      ? 'auth.select_category_first'.tr()
                      : subcategories.isEmpty
                      ? 'auth.no_professions_available'.tr()
                      : null,
                  errorText: _submitAttempted && _selectedSubcategoryId == null
                      ? 'auth.profession_required'.tr()
                      : null,
                  onTap: () async {
                    final selected = await _showOptionPicker(
                      title: 'auth.profession'.tr(),
                      options: subcategories
                          .map((s) => _PickerOption(value: s.id, label: s.name))
                          .toList(),
                      selectedValue: _selectedSubcategoryId,
                    );
                    if (selected == null || !mounted) return;

                    setState(() {
                      _selectedSubcategoryId = selected.value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Location
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
                  controller: _experienceCtrl,
                  label: 'auth.experience_years'.tr(),
                  hint: '5',
                  prefixIcon: Icons.timeline_outlined,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _descriptionCtrl,
                  label: 'auth.description'.tr(),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
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

  Future<_PickerOption?> _showOptionPicker({
    required String title,
    required List<_PickerOption> options,
    required String? selectedValue,
  }) {
    return showModalBottomSheet<_PickerOption>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (options.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'auth.no_categories_available'.tr(),
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option.value == selectedValue;

                        return ListTile(
                          title: Text(option.label),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () => Navigator.pop(ctx, option),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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

class _PickerOption {
  final String value;
  final String label;

  const _PickerOption({required this.value, required this.label});
}

class _SelectField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String text;
  final bool enabled;
  final String? helperText;
  final String? errorText;
  final VoidCallback onTap;

  const _SelectField({
    required this.label,
    required this.icon,
    required this.text,
    required this.enabled,
    required this.onTap,
    this.helperText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20),
              suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
              errorText: hasError ? errorText : null,
              enabled: enabled,
            ),
            isEmpty: text.isEmpty,
            child: Text(
              text,
              style: theme.textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (helperText != null && helperText!.isNotEmpty && !hasError) ...[
          const SizedBox(height: 6),
          Text(helperText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
