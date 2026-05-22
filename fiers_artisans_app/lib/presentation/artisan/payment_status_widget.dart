import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
            'manual_payment.status_label'.tr(
              namedArgs: {'status': _statusLabel(status).tr()},
            ),
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
          if (transaction!.isRejected &&
              transaction!.rejectionReason != null &&
              transaction!.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'manual_payment.rejection_reason_label'.tr(
                namedArgs: {'reason': transaction!.rejectionReason!},
              ),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'manual_payment.transaction_id'.tr(
              namedArgs: {'id': transaction!.transactionId},
            ),
          ),
          if (transaction!.requestNumber > 0)
            Text(
              'manual_payment.request_number'.tr(
                namedArgs: {'number': '${transaction!.requestNumber}'},
              ),
            ),
          if ((transaction!.isPending ||
                  transaction!.isPendingAdmin ||
                  transaction!.isRejected) &&
              transaction!.currentAttemptNumber > 0)
            Text(
              'manual_payment.attempt_count'.tr(
                namedArgs: {
                  'attempt': '${transaction!.currentAttemptNumber}',
                },
              ),
            ),
          if (transaction!.isRejected && transaction!.isCooldownActive)
            Text(
              'manual_payment.cooldown_countdown'.tr(
                namedArgs: {
                  'remaining': _formatCooldown(transaction!.cooldownRemainingSeconds),
                },
              ),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (transaction!.expiresAtAdmin != null)
            Text(
              'manual_payment.expiration'.tr(
                namedArgs: {
                  'date': DateFormat(
                    'dd/MM/yyyy HH:mm',
                  ).format(transaction!.expiresAtAdmin!.toLocal()),
                },
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'COMPLETED' => 'manual_payment.status.completed',
      'REJECTED' => 'manual_payment.status.rejected',
      'PENDING_ADMIN' => 'manual_payment.status.pending_admin',
      'EXPIRED' => 'manual_payment.status.expired',
      _ => 'manual_payment.status.pending',
    };
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

  String _formatCooldown(int totalSeconds) {
    final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}min ${seconds.toString().padLeft(2, '0')}s';
  }
}
