import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE0E0E6),
      highlightColor:
          isDark ? const Color(0xFF3A3A3E) : const Color(0xFFF0F0F4),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Skeleton card matching ArtisanCard shape
  static Widget artisanCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const SkeletonLoader(width: 56, height: 56, borderRadius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonLoader(width: 140, height: 16),
                SizedBox(height: 8),
                SkeletonLoader(width: 100, height: 12),
                SizedBox(height: 8),
                SkeletonLoader(width: 80, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
