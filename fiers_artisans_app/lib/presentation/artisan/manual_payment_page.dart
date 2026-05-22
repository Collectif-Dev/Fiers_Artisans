import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../config/theme.dart';
import '../../providers/payment_manual_provider.dart';
import '../common/app_snackbar.dart';
import 'payment_status_widget.dart';

class ManualPaymentPage extends ConsumerStatefulWidget {
  const ManualPaymentPage({super.key});

  @override
  ConsumerState<ManualPaymentPage> createState() => _ManualPaymentPageState();
}

class _ManualPaymentPageState extends ConsumerState<ManualPaymentPage> {
  static final RegExp _digits10Pattern = RegExp(r'^\d{10}$');
  static const Map<String, List<String>> _allowedPrefixesByProvider = {
    'ORANGE_MONEY': ['07'],
    'MTN_MOMO': ['05'],
    'WAVE': ['07', '05', '01'],
    // Reserved for future activation.
    'MOOV_MONEY': ['01'],
  };
  static const Map<String, String?> _recipientByProvider = {
    'ORANGE_MONEY': '0703063570',
    'MTN_MOMO': '0503265984',
    'MOOV_MONEY': null,
    'WAVE': '0703063570',
  };

  final _senderController = TextEditingController();
  XFile? _proofImage;
  Uint8List? _proofBytes;
  String _provider = 'ORANGE_MONEY';

  @override
  void initState() {
    super.initState();
    ref.listenManual<PaymentManualState>(paymentManualProvider, (
      previous,
      next,
    ) {
      final tx = next.currentTransaction;
      if (tx == null) {
        return;
      }
      if (tx.provider != _provider && mounted) {
        setState(() {
          _provider = tx.provider;
        });
      }
    });

    Future.microtask(
      () => ref
          .read(paymentManualProvider.notifier)
          .loadCurrentTransaction(refresh: true),
    );
  }

  @override
  void dispose() {
    _senderController.dispose();
    super.dispose();
  }

  String _formatPhoneSpaced(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return raw;
    return '${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4, 6)} ${digits.substring(6, 8)} ${digits.substring(8, 10)}';
  }

  Future<void> _pickImage({required bool disabled}) async {
    if (disabled) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (!mounted) return;
    setState(() {
      _proofImage = image;
      _proofBytes = null;
    });

    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _proofBytes = bytes;
      });
    }
  }

  Future<void> _copyRecipient(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    AppSnackBar.show(context, message: 'manual_payment.copy_success'.tr());
  }

  Future<void> _initiate() async {
    final state = ref.read(paymentManualProvider);
    final tx = state.currentTransaction;

    if (_recipientByProvider[_provider] == null) {
      AppSnackBar.show(
        context,
        message: 'manual_payment.provider_unavailable_moov'.tr(),
      );
      return;
    }

    if (tx != null && (tx.isPending || tx.isPendingAdmin)) {
      AppSnackBar.show(context, message: 'manual_payment.request_pending'.tr());
      return;
    }

    if (tx != null && !tx.canInitiateNewTransaction) {
      AppSnackBar.show(
        context,
        message: 'manual_payment.new_transaction_not_allowed'.tr(),
      );
      return;
    }

    await ref
        .read(paymentManualProvider.notifier)
        .initiatePayment(provider: _provider);

    if (!mounted) return;
    final latest = ref.read(paymentManualProvider).currentTransaction;
    if (latest != null &&
        latest.provider == _provider &&
        latest.recipientNumber != null &&
        latest.recipientNumber!.isNotEmpty) {
      AppSnackBar.show(
        context,
        message: 'manual_payment.recipient_number_label'.tr(
          namedArgs: {'number': _formatPhoneSpaced(latest.recipientNumber!)},
        ),
      );
    }
  }

  Future<void> _submit() async {
    final state = ref.read(paymentManualProvider);
    final tx = state.currentTransaction;
    final image = _proofImage;
    final sender = _senderController.text.trim();

    if (tx == null) {
      AppSnackBar.show(context, message: 'manual_payment.generate_first'.tr());
      return;
    }

    if (!(tx.isPending || tx.isRejected)) {
      AppSnackBar.show(
        context,
        message: 'manual_payment.proof_not_allowed'.tr(),
      );
      return;
    }

    if (state.hasSubmittedProof && tx.isPendingAdmin) {
      AppSnackBar.show(
        context,
        message: 'manual_payment.proof_already_pending'.tr(),
      );
      return;
    }

    if (image == null) {
      AppSnackBar.show(context, message: 'manual_payment.proof_required'.tr());
      return;
    }

    final providerForValidation = tx.provider.trim().isNotEmpty
        ? tx.provider
        : _provider;
    final allowedPrefixes = _allowedPrefixesByProvider[providerForValidation];
    if (allowedPrefixes == null || allowedPrefixes.isEmpty) {
      AppSnackBar.show(
        context,
        message: 'manual_payment.sender_provider_unknown'.tr(),
      );
      return;
    }

    if (!_isValidSenderNumberForProvider(
      sender,
      provider: providerForValidation,
    )) {
      AppSnackBar.show(
        context,
        message: 'manual_payment.sender_invalid_for_provider'.tr(
          namedArgs: {
            'provider': _providerLabel(providerForValidation),
            'prefixes': _prefixesLabel(allowedPrefixes),
          },
        ),
      );
      return;
    }

    await ref
        .read(paymentManualProvider.notifier)
        .submitProof(filePath: image.path, senderNumber: sender);

    if (!mounted) return;
    final error = ref.read(paymentManualProvider).error;
    if (error == null) {
      AppSnackBar.show(context, message: 'manual_payment.proof_sent'.tr());
    }
  }

  Widget _stepItem(
    IconData icon,
    String title,
    String text, {
    required Color iconBackgroundColor,
    required Color iconColor,
    required Color titleColor,
    required Color bodyColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(text, style: TextStyle(color: bodyColor)),
            ],
          ),
        ),
      ],
    );
  }

  bool _isValidSenderNumberForProvider(
    String sender, {
    required String provider,
  }) {
    if (!_digits10Pattern.hasMatch(sender)) {
      return false;
    }
    final allowedPrefixes = _allowedPrefixesByProvider[provider];
    if (allowedPrefixes == null || allowedPrefixes.isEmpty) {
      return false;
    }
    for (final prefix in allowedPrefixes) {
      if (sender.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  String _providerLabel(String provider) {
    return switch (provider) {
      'ORANGE_MONEY' => 'manual_payment.provider.orange'.tr(),
      'MTN_MOMO' => 'manual_payment.provider.mtn'.tr(),
      'MOOV_MONEY' => 'manual_payment.provider.moov_unavailable'.tr(),
      'WAVE' => 'manual_payment.provider.wave_manual'.tr(),
      _ => provider,
    };
  }

  String _prefixesLabel(List<String> prefixes) {
    if (prefixes.length == 1) {
      return prefixes.first;
    }
    if (prefixes.length == 2) {
      return '${prefixes[0]} ou ${prefixes[1]}';
    }
    final head = prefixes.sublist(0, prefixes.length - 1).join(', ');
    return '$head ou ${prefixes.last}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(paymentManualProvider);
    final tx = state.currentTransaction;

    final providerUnavailable = _recipientByProvider[_provider] == null;
    final isPendingAdminLocked = tx != null && tx.isPendingAdmin;

    final canInitiate =
        !state.isLoading &&
        !providerUnavailable &&
        (tx == null || tx.canInitiateNewTransaction);
    final canSubmit =
        !state.isLoading &&
        tx != null &&
        (tx.isPending || tx.isRejected) &&
        !(state.hasSubmittedProof && tx.isPendingAdmin);

    final recipientFromBackend =
        tx != null && tx.provider == _provider && tx.recipientNumber != null;
    final selectedRecipient = recipientFromBackend
        ? tx.recipientNumber
        : _recipientByProvider[_provider];
    final formattedRecipient = selectedRecipient == null
        ? null
        : _formatPhoneSpaced(selectedRecipient);
    final guideBackgroundColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : theme.colorScheme.surfaceContainerHighest;
    final guideBorderColor = isDark
        ? AppTheme.gold.withValues(alpha: 0.32)
        : theme.colorScheme.outlineVariant;
    final guideTitleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final guideBodyColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final noticeColor = isDark ? Colors.orangeAccent : Colors.orange.shade800;
    final recipientCardColor = isDark
        ? Colors.black.withValues(alpha: 0.36)
        : theme.colorScheme.surfaceContainer;
    final recipientHintColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final recipientNumberColor = isDark
        ? AppTheme.gold
        : Colors.deepOrange.shade800;
    final serverConfirmedColor = isDark
        ? Colors.white54
        : theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text('manual_payment.title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'manual_payment.guide_title'.tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: guideBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: guideBorderColor),
              ),
              child: Column(
                children: [
                  _stepItem(
                    Icons.looks_one_outlined,
                    'manual_payment.step1_title'.tr(),
                    'manual_payment.step1_body'.tr(),
                    iconBackgroundColor: AppTheme.gold.withValues(alpha: 0.18),
                    iconColor: AppTheme.gold,
                    titleColor: guideTitleColor,
                    bodyColor: guideBodyColor,
                  ),
                  const SizedBox(height: 10),
                  _stepItem(
                    Icons.looks_two_outlined,
                    'manual_payment.step2_title'.tr(),
                    'manual_payment.step2_body'.tr(),
                    iconBackgroundColor: AppTheme.gold.withValues(alpha: 0.18),
                    iconColor: AppTheme.gold,
                    titleColor: guideTitleColor,
                    bodyColor: guideBodyColor,
                  ),
                  const SizedBox(height: 10),
                  _stepItem(
                    Icons.looks_3_outlined,
                    'manual_payment.step3_title'.tr(),
                    'manual_payment.step3_body'.tr(),
                    iconBackgroundColor: AppTheme.gold.withValues(alpha: 0.18),
                    iconColor: AppTheme.gold,
                    titleColor: guideTitleColor,
                    bodyColor: guideBodyColor,
                  ),
                  const SizedBox(height: 10),
                  _stepItem(
                    Icons.looks_4_outlined,
                    'manual_payment.step4_title'.tr(),
                    'manual_payment.step4_body'.tr(),
                    iconBackgroundColor: AppTheme.gold.withValues(alpha: 0.18),
                    iconColor: AppTheme.gold,
                    titleColor: guideTitleColor,
                    bodyColor: guideBodyColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD166)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'manual_payment.refund_policy_title'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'manual_payment.refund_policy_line1'.tr(),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'manual_payment.refund_policy_line2'.tr(),
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'manual_payment.refund_policy_line3'.tr(),
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'manual_payment.mobile_money_title'.tr(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              items: [
                DropdownMenuItem(
                  value: 'ORANGE_MONEY',
                  child: Text('manual_payment.provider.orange'.tr()),
                ),
                DropdownMenuItem(
                  value: 'MTN_MOMO',
                  child: Text('manual_payment.provider.mtn'.tr()),
                ),
                DropdownMenuItem(
                  value: 'MOOV_MONEY',
                  child: Text('manual_payment.provider.moov_unavailable'.tr()),
                ),
                DropdownMenuItem(
                  value: 'WAVE',
                  child: Text('manual_payment.provider.wave_manual'.tr()),
                ),
              ],
              onChanged: isPendingAdminLocked
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _provider = value;
                      });
                    },
              decoration: InputDecoration(
                labelText: 'manual_payment.method'.tr(),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: recipientCardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppTheme.gold.withValues(alpha: 0.42)
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: selectedRecipient == null
                  ? Text(
                      'manual_payment.recipient_unavailable'.tr(),
                      style: TextStyle(
                        color: noticeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'manual_payment.send_exact_amount'.tr(),
                          style: TextStyle(color: recipientHintColor),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formattedRecipient ?? selectedRecipient,
                                style: TextStyle(
                                  color: recipientNumberColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'manual_payment.copy'.tr(),
                              onPressed: () =>
                                  _copyRecipient(selectedRecipient),
                              icon: Icon(
                                Icons.copy_rounded,
                                color: recipientNumberColor,
                              ),
                            ),
                          ],
                        ),
                        if (recipientFromBackend)
                          Text(
                            'manual_payment.server_confirmed_number'.tr(),
                            style: TextStyle(
                              color: serverConfirmedColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
            ),
            if (providerUnavailable) ...[
              const SizedBox(height: 8),
              Text(
                'manual_payment.moov_temporarily_unavailable'.tr(),
                style: TextStyle(color: noticeColor),
              ),
            ],
            if (tx != null && tx.isPendingAdmin) ...[
              const SizedBox(height: 8),
              Text(
                'manual_payment.pending_admin_notice'.tr(),
                style: TextStyle(color: noticeColor),
              ),
            ] else if (tx != null && tx.isPending) ...[
              const SizedBox(height: 8),
              Text(
                'manual_payment.transaction_initiated_notice'.tr(),
                style: TextStyle(color: noticeColor),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: canInitiate ? _initiate : null,
              child: Text('manual_payment.generate_transaction'.tr()),
            ),
            const SizedBox(height: 16),
            PaymentStatusWidget(transaction: tx),
            const SizedBox(height: 12),
            if (tx != null) ...[
              Text(
                'manual_payment.amount_label'.tr(
                  namedArgs: {'amount': '${tx.amountFcfa}'},
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _senderController,
                enabled: !isPendingAdminLocked,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  prefixText: '+225 ',
                  labelText: 'manual_payment.sender_number_label'.tr(),
                  hintText: 'manual_payment.sender_number_hint'.tr(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isPendingAdminLocked
                    ? null
                    : () => _pickImage(disabled: isPendingAdminLocked),
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  isPendingAdminLocked
                      ? 'manual_payment.proof_already_submitted'.tr()
                      : 'manual_payment.select_proof'.tr(),
                ),
              ),
              const SizedBox(height: 8),
              if (_proofBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _proofBytes!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: canSubmit ? _submit : null,
                icon: const Icon(Icons.upload_file),
                label: Text('manual_payment.submit_proof'.tr()),
              ),
            ],
            if (state.error != null && state.error!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
