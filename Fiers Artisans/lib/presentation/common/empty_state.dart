import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final isCompact = hasBoundedHeight && constraints.maxHeight < 260;
        final verticalPadding = isCompact ? 20.0 : 32.0;
        final iconSize = isCompact ? 56.0 : 64.0;
        final titleSpacing = isCompact ? 12.0 : 16.0;
        final subtitleSpacing = isCompact ? 6.0 : 8.0;
        final actionSpacing = isCompact ? 16.0 : 24.0;
        final minContentHeight = hasBoundedHeight
            ? (constraints.maxHeight - (verticalPadding * 2))
                .clamp(0.0, double.infinity)
                .toDouble()
            : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: verticalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minContentHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: titleSpacing),
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: subtitleSpacing),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (actionLabel != null && onAction != null) ...[
                    SizedBox(height: actionSpacing),
                    ElevatedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
