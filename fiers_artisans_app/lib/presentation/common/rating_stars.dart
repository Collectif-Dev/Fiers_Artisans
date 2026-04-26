import 'package:flutter/material.dart';
import '../../config/theme.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final bool allowClear;
  final ValueChanged<int>? onRatingChanged;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.interactive = false,
    this.allowClear = true,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;
        Color color;

        if (rating >= starValue) {
          icon = Icons.star_rounded;
          color = AppTheme.gold;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half_rounded;
          color = AppTheme.gold;
        } else {
          icon = Icons.star_outline_rounded;
          color = Colors.grey.shade400;
        }

        final isSameSelected = (rating - starValue).abs() < 0.001;
        final nextValue = (interactive && allowClear && isSameSelected)
            ? 0
            : starValue;
        final semanticsLabel = interactive ? '$starValue/5' : '$rating/5';

        final starIcon = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(icon, size: size, color: color),
        );

        return Semantics(
          button: interactive,
          label: semanticsLabel,
          value: rating.toStringAsFixed(1),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: interactive ? () => onRatingChanged?.call(nextValue) : null,
            child: Padding(
              padding: interactive
                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
                  : EdgeInsets.zero,
              child: starIcon,
            ),
          ),
        );
      }),
    );
  }
}
