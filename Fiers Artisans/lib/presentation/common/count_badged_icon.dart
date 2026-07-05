import 'package:flutter/material.dart';

class CountBadgedIcon extends StatelessWidget {
  final Widget child;
  final int count;

  const CountBadgedIcon({
    super.key,
    required this.child,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return child;
    }

    final label = count > 99 ? '99+' : '$count';
    final theme = Theme.of(context);
    final badgeColor = theme.colorScheme.error;
    final badgeTextColor = theme.colorScheme.onError;
    final badgeOutlineColor = theme.colorScheme.surface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -10,
          top: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeOutlineColor, width: 1.5),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
