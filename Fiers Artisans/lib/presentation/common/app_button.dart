import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOutlined) {
      return SizedBox(
        width: widget.width ?? double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: OutlinedButton(
            onPressed: (widget.isLoading || widget.onPressed == null)
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    widget.onPressed?.call();
                  },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: _buildChild(context),
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: widget.onPressed != null && !widget.isLoading
              ? AppTheme.goldGradient
              : null,
          color: widget.onPressed == null || widget.isLoading
              ? Colors.grey.shade600
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: ElevatedButton(
            onPressed: (widget.isLoading || widget.onPressed == null)
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    widget.onPressed?.call();
                  },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: _buildChild(context),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context) {
    if (widget.isLoading) {
      return const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Text(
      widget.text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}
