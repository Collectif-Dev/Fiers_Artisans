import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/payment_manual_provider.dart';
import 'payment_status_widget.dart';

class ManualPaymentPage extends ConsumerStatefulWidget {
  const ManualPaymentPage({super.key});

  @override
  ConsumerState<ManualPaymentPage> createState() => _ManualPaymentPageState();
}

class _ManualPaymentPageState extends ConsumerState<ManualPaymentPage> {
  final _senderController = TextEditingController();
  XFile? _proofImage;
  Uint8List? _proofBytes;
  String _provider = 'ORANGE_MONEY';

  @override
  void dispose() {
    _senderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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

  Future<void> _initiate() async {
    await ref
        .read(paymentManualProvider.notifier)
        .initiatePayment(provider: _provider);
  }

  Future<void> _submit() async {
    final image = _proofImage;
    final sender = _senderController.text.trim();
    if (image == null || sender.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectionnez une image et entrez 10 chiffres.')),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentManualProvider);
    final tx = state.currentTransaction;

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement manuel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mobile Money',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _provider,
              items: const [
                DropdownMenuItem(value: 'ORANGE_MONEY', child: Text('Orange Money')),
                DropdownMenuItem(value: 'MTN_MOMO', child: Text('MTN MoMo')),
                DropdownMenuItem(value: 'MOOV_MONEY', child: Text('Moov Money')),
                DropdownMenuItem(value: 'WAVE', child: Text('Wave (manuel)')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _provider = value;
                });
              },
              decoration: const InputDecoration(labelText: 'Methode'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: state.isLoading ? null : _initiate,
              child: const Text('Generer une transaction'),
            ),
            const SizedBox(height: 16),
            PaymentStatusWidget(transaction: tx),
            const SizedBox(height: 12),
            if (tx != null) ...[
              Text('Montant: ${tx.amountFcfa} FCFA'),
              if (tx.recipientNumber != null)
                Text('Numero destinataire: ${tx.recipientNumber}'),
              const SizedBox(height: 12),
              TextField(
                controller: _senderController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numero expediteur (10 chiffres)',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Selectionner la preuve'),
              ),
              const SizedBox(height: 8),
              if (_proofBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _proofBytes!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: state.isLoading ? null : _submit,
                icon: const Icon(Icons.upload_file),
                label: const Text('Envoyer la preuve'),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 10),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
