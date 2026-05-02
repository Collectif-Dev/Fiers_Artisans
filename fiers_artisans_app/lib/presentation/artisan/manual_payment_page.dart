import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../providers/payment_manual_provider.dart';
import 'payment_status_widget.dart';

class ManualPaymentPage extends ConsumerStatefulWidget {
  const ManualPaymentPage({super.key});

  @override
  ConsumerState<ManualPaymentPage> createState() => _ManualPaymentPageState();
}

class _ManualPaymentPageState extends ConsumerState<ManualPaymentPage> {
  static final RegExp _ivorianMobilePattern = RegExp(r'^(07|05|01)\d{8}$');
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Numero copie.')),
    );
  }

  Future<void> _initiate() async {
    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(paymentManualProvider);
    final tx = state.currentTransaction;

    if (_recipientByProvider[_provider] == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Moov Money n\'est pas encore disponible pour le paiement manuel.'),
        ),
      );
      return;
    }

    if (tx != null && (tx.isPending || tx.isPendingAdmin)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Une demande est deja en cours. Veuillez finaliser ou attendre la validation.'),
        ),
      );
      return;
    }

    if (tx != null && !tx.canInitiateNewTransaction) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez pas initier une nouvelle transaction pour le moment.'),
        ),
      );
      return;
    }

    await ref.read(paymentManualProvider.notifier).initiatePayment(provider: _provider);

    if (!mounted) return;
    final latest = ref.read(paymentManualProvider).currentTransaction;
    if (latest != null &&
        latest.provider == _provider &&
        latest.recipientNumber != null &&
        latest.recipientNumber!.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('Numero destinataire: ${_formatPhoneSpaced(latest.recipientNumber!)}')),
      );
    }
  }

  Future<void> _submit() async {
    final state = ref.read(paymentManualProvider);
    final tx = state.currentTransaction;
    final image = _proofImage;
    final sender = _senderController.text.trim();

    if (tx == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generez d\'abord une transaction.')),
      );
      return;
    }

    if (!(tx.isPending || tx.isRejected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La transaction ne permet pas une nouvelle preuve.')),
      );
      return;
    }

    if (state.hasSubmittedProof && tx.isPendingAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre preuve est deja en attente de validation.')),
      );
      return;
    }

    if (image == null || !_ivorianMobilePattern.hasMatch(sender)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numero expediteur invalide: +225 suivi de 10 chiffres (07, 05 ou 01).'),
        ),
      );
      return;
    }

    await ref.read(paymentManualProvider.notifier).submitProof(
          filePath: image.path,
          senderNumber: sender,
        );

    if (!mounted) return;
    final error = ref.read(paymentManualProvider).error;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preuve envoyee.')),
      );
    }
  }

  Widget _stepItem(IconData icon, String title, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppTheme.gold),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentManualProvider);
    final tx = state.currentTransaction;

    final providerUnavailable = _recipientByProvider[_provider] == null;
    final isPendingAdminLocked =
        tx != null && tx.isPendingAdmin && state.hasSubmittedProof;

    final canInitiate = !state.isLoading &&
        !providerUnavailable &&
        (tx == null || tx.canInitiateNewTransaction);
    final canSubmit = !state.isLoading &&
        tx != null &&
        (tx.isPending || tx.isRejected) &&
        !(state.hasSubmittedProof && tx.isPendingAdmin);

    final recipientFromBackend =
        tx != null && tx.provider == _provider && tx.recipientNumber != null;
    final selectedRecipient = recipientFromBackend
        ? tx.recipientNumber
        : _recipientByProvider[_provider];
    final formattedRecipient =
        selectedRecipient == null ? null : _formatPhoneSpaced(selectedRecipient);

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement manuel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guide de paiement manuel',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.32)),
              ),
              child: Column(
                children: [
                  _stepItem(
                    Icons.looks_one_outlined,
                    '1. Choisissez un operateur',
                    'Selectionnez le canal Mobile Money et verifiez le numero destinataire.',
                  ),
                  const SizedBox(height: 10),
                  _stepItem(
                    Icons.looks_two_outlined,
                    '2. Faites le virement',
                    'Effectuez le transfert depuis votre compte et conservez une capture claire.',
                  ),
                  const SizedBox(height: 10),
                  _stepItem(
                    Icons.looks_3_outlined,
                    '3. Soumettez la preuve',
                    'Saisissez le numero de telephone que vous avez utilise pour effectuer le depot, puis envoyez la capture d\'ecran du paiement.',
                  ),
                  const SizedBox(height: 10),
                  _stepItem(
                    Icons.looks_4_outlined,
                    '4. Attendez la validation',
                    'Le statut passe en attente admin puis valide/rejete selon controle.',
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Politique de remboursement',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '- Si vous envoyez un montant inferieur a 5 000 FCFA (frais non inclus), la transaction est rejetee et un remboursement est du.',
                    style: TextStyle(color: Colors.black87),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '- Si vous envoyez un montant superieur a 5 000 FCFA et que le compte n\'est pas active (rejet/expiration), vous etes rembourse des frais deduits par l\'operateur.',
                    style: TextStyle(color: Colors.black87),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '- En cas de non-validation sous 72 heures, la demande expire et un remboursement est necessaire.',
                    style: TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mobile Money (paiement manuel)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              items: const [
                DropdownMenuItem(value: 'ORANGE_MONEY', child: Text('Orange Money')),
                DropdownMenuItem(value: 'MTN_MOMO', child: Text('MTN MoMo')),
                DropdownMenuItem(value: 'MOOV_MONEY', child: Text('Moov Money (indisponible)')),
                DropdownMenuItem(value: 'WAVE', child: Text('Wave (manuel)')),
              ],
              onChanged: isPendingAdminLocked
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _provider = value;
                      });
                    },
              decoration: const InputDecoration(labelText: 'Methode'),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.36),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.42)),
              ),
              child: selectedRecipient == null
                  ? const Text(
                      'Numero destinataire: Pas encore disponible pour cet operateur.',
                      style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w700),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Veuillez envoyer exactement 5 000 FCFA a ce numero :',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formattedRecipient ?? selectedRecipient,
                                style: TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copier',
                              onPressed: () => _copyRecipient(selectedRecipient),
                              icon: Icon(Icons.copy_rounded, color: AppTheme.gold),
                            ),
                          ],
                        ),
                        if (recipientFromBackend)
                          const Text(
                            'Numero confirme par le serveur',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                      ],
                    ),
            ),
            if (providerUnavailable) ...[
              const SizedBox(height: 8),
              const Text(
                'Moov Money est temporairement indisponible. Choisissez Orange, MTN ou Wave manuel.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ],
            if (tx != null && tx.isPendingAdmin) ...[
              const SizedBox(height: 8),
              const Text(
                'Votre demande de paiement est en attente de validation par nos equipes.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ] else if (tx != null && tx.isPending) ...[
              const SizedBox(height: 8),
              const Text(
                'Transaction initiee - veuillez soumettre votre preuve.',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: canInitiate ? _initiate : null,
              child: const Text('Generer une transaction manuelle'),
            ),
            const SizedBox(height: 16),
            PaymentStatusWidget(transaction: tx),
            const SizedBox(height: 12),
            if (tx != null) ...[
              Text('Montant: ${tx.amountFcfa} FCFA'),
              const SizedBox(height: 12),
              TextField(
                controller: _senderController,
                enabled: !isPendingAdminLocked,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  prefixText: '+225 ',
                  labelText: 'Numero qui a effectue le depot (ex: 07XXXXXXXX)',
                  hintText: '07XXXXXXXX',
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
                      ? 'Preuve deja soumise'
                      : 'Selectionner la preuve',
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
                label: const Text('Envoyer la preuve'),
              ),
            ],
            if (state.error != null && state.error!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
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
