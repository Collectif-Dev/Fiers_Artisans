import 'package:flutter/material.dart';

import '../../data/models/manual_payment_model.dart';

class PaymentStatusWidget extends StatelessWidget {
  final ManualPaymentModel? transaction;

  const PaymentStatusWidget({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    if (transaction == null) {
      return const SizedBox.shrink();
    }

    final status = transaction!.status;
    final color = _colorForStatus(status, Theme.of(context));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statut: $status',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text('Transaction: ${transaction!.transactionId}'),
          if (transaction!.expiresAtAdmin != null)
            Text('Expiration admin: ${transaction!.expiresAtAdmin}'),
        ],
      ),
    );
  }

  Color _colorForStatus(String status, ThemeData theme) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green;
      case 'REJECTED':
        return theme.colorScheme.error;
      case 'PENDING_ADMIN':
        return Colors.orange;
      case 'EXPIRED':
        return Colors.redAccent;
      default:
        return theme.colorScheme.primary;
    }
  }
}
