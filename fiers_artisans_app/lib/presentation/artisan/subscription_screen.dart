import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme.dart';
import '../../providers/payment_manual_provider.dart';
import '../../providers/subscription_provider.dart';
import '../common/app_snackbar.dart';
import '../common/app_button.dart';
import 'manual_payment_page.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(subscriptionProvider.notifier).loadStatus();
      await ref
          .read(paymentManualProvider.notifier)
          .loadCurrentTransaction(refresh: true);
    });
  }

  void _openManualPayment({required bool isSubscriptionActive}) {
    if (isSubscriptionActive) {
      AppSnackBar.show(
        context,
        message: 'subscription.manual.already_active'.tr(),
      );
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ManualPaymentPage()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subState = ref.watch(subscriptionProvider);
    final manualState = ref.watch(paymentManualProvider);
    final subscription = subState.subscription;
    final manualTx = manualState.currentTransaction;

    final isActive = subscription?.isActive == true;
    final daysRemaining = subscription?.daysRemaining ?? 0;

    final manualInProgress =
        manualTx != null && (manualTx.isPending || manualTx.isPendingAdmin);
    final manualRejected = manualTx?.isRejected == true;
    final hasExpiredSubscription =
        subscription != null && !subscription.isPending;

    final statusText = isActive
        ? 'subscription.active'.tr()
        : !hasExpiredSubscription
        ? 'subscription.none'.tr()
        : 'subscription.expired'.tr();

    final manualStatusText = manualInProgress
        ? (manualTx.isPendingAdmin
              ? 'subscription.manual.pending_admin'.tr()
              : 'subscription.manual.pending'.tr())
        : manualRejected
        ? 'subscription.manual.rejected'.tr()
        : null;

    final manualActionText = manualInProgress
        ? 'subscription.manual.view_pending'.tr()
        : manualRejected
        ? 'subscription.manual.retry_payment'.tr()
        : 'subscription.manual.start_payment'.tr();
    final manualCardBackgroundColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : theme.colorScheme.surfaceContainerHighest;
    final manualCardBorderColor = isDark
        ? AppTheme.gold.withValues(alpha: 0.35)
        : theme.colorScheme.outlineVariant;
    final manualCardTitleColor = isDark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final manualCardBodyColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;
    final manualCardIconColor = isDark
        ? AppTheme.gold
        : Colors.deepOrange.shade800;
    final manualCardIconBackgroundColor = isDark
        ? AppTheme.gold.withValues(alpha: 0.15)
        : Colors.deepOrange.shade50;

    return Scaffold(
      appBar: AppBar(title: Text('subscription.title'.tr())),
      body: subState.isLoading && subState.subscription == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.workspace_premium,
                                size: 56,
                                color: Colors.black,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'subscription.amount'.tr(),
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                statusText,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'subscription.expires_in'.tr(
                                    namedArgs: {'days': '$daysRemaining'},
                                  ),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (subState.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              subState.error!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        if (manualStatusText != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.gold.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  manualInProgress
                                      ? Icons.hourglass_top_outlined
                                      : Icons.warning_amber_rounded,
                                  color: manualInProgress
                                      ? AppTheme.warning
                                      : AppTheme.error,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    manualStatusText,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.bolt_outlined,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'subscription.manual.wave_automatic'.tr(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'subscription.manual.temporarily_disabled'
                                          .tr(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: manualCardBackgroundColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: manualCardBorderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: manualCardIconBackgroundColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: manualCardIconColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'subscription.manual.mobile_money_title'
                                          .tr(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: manualCardTitleColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'subscription.manual.instructions'.tr(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: manualCardBodyColor,
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'subscription.manual.active_days_remaining'
                                      .tr(
                                        namedArgs: {'days': '$daysRemaining'},
                                      ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              AppButton(
                                text: manualActionText,
                                icon: Icons.upload_file_outlined,
                                isLoading: false,
                                onPressed: isActive
                                    ? null
                                    : () => _openManualPayment(
                                        isSubscriptionActive: isActive,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
