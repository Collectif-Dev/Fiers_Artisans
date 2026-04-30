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

    final theme = Theme.of(context);
    final status = transaction!.status;
    final color = _colorForStatus(status, theme);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statut: $status',
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          if (transaction!.isRejected &&
              transaction!.rejectionReason != null &&
              transaction!.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Motif du rejet: ${transaction!.rejectionReason}',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
