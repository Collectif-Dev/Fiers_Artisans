import 'package:flutter/material.dart';
import '../../config/theme.dart';

enum BadgeType { verified, certified }

class BadgeVerified extends StatefulWidget {
  final BadgeType type;
  final double size;

  const BadgeVerified({
    super.key,
    required this.type,
    this.size = 18,
  });

  @override
  State<BadgeVerified> createState() => _BadgeVerifiedState();
}

class _BadgeVerifiedState extends State<BadgeVerified>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.type == BadgeType.certified
        ? AppTheme.gold
        : AppTheme.success;
    final icon = widget.type == BadgeType.certified
        ? Icons.workspace_premium
        : Icons.verified;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Icon(icon, size: widget.size, color: color),
        );
      },
    );
  }
}
