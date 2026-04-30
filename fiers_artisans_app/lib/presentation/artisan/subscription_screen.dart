import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme.dart';
import '../../providers/subscription_provider.dart';
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
    Future.microtask(
      () => ref.read(subscriptionProvider.notifier).loadStatus(),
    );
  }

  void _openManualPayment({required bool isSubscriptionActive}) {
    if (isSubscriptionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre abonnement est deja actif. Aucun paiement n\'est requis pour le moment.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManualPaymentPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subState = ref.watch(subscriptionProvider);
    final subscription = subState.subscription;
    final isActive = subscription?.isActive == true;
    final daysRemaining = subscription?.daysRemaining ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text('subscription.title'.tr())),
      body: subState.isLoading && subState.subscription == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
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
                                isActive
                                    ? 'subscription.active'.tr()
                                    : 'subscription.expired'.tr(),
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.bolt_outlined, color: Colors.black87),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wave (automatique)',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    SizedBox(height: 4),
                                    Text('Temporairement desactive'),
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
                            color: Colors.black.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.gold.withOpacity(0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined, color: AppTheme.gold),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Mobile Money (paiement manuel)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Effectuez le virement vers le numero affiche, puis envoyez la preuve dans l\'application.',
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                              ),
                              if (isActive) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Abonnement actif: $daysRemaining jour(s) restant(s).',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              AppButton(
                                text: 'Commencer un paiement manuel',
                                icon: Icons.upload_file_outlined,
                                isLoading: false,
                                onPressed: isActive
                                    ? null
                                    : () => _openManualPayment(isSubscriptionActive: isActive),
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
