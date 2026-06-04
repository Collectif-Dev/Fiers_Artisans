import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class RegisterChoiceScreen extends StatelessWidget {
  const RegisterChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('auth.register'.tr()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                'auth.register_as'.tr(),
                style: theme.textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Artisan card
              _RoleCard(
                icon: Icons.construction_rounded,
                title: 'auth.artisan'.tr(),
                description: 'Proposez vos services',
                onTap: () => context.push('/register/artisan'),
              ),
              const SizedBox(height: 20),

              // Client card
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'auth.client'.tr(),
                description: 'Trouvez un artisan',
                onTap: () => context.push('/register/client'),
              ),

              const Spacer(),

              // Back to login
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('auth.has_account'.tr(),
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'auth.login'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppConstants.animFast,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: _pressed
                    ? AppTheme.gold.withValues(alpha: 0.1)
                    : Colors.transparent,
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, size: 28, color: Colors.black),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(widget.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
