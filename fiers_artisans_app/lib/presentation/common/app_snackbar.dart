import 'dart:async';

import 'package:flutter/material.dart';

class AppSnackBar {
  AppSnackBar._();

  static OverlayEntry? _entry;
  static AnimationController? _controller;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Color? textColor,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);

    if (overlay == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    _removeCurrent(immediate: true);

    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 18;

    final controller = AnimationController(
      vsync: overlay,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final entry = OverlayEntry(
      builder: (_) {
        final foreground = textColor ?? theme.colorScheme.onInverseSurface;
        final bg = backgroundColor ?? theme.colorScheme.inverseSurface;

        return Positioned(
          left: 16,
          right: 16,
          top: topPadding,
          child: Material(
            color: Colors.transparent,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.05, 0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(
                opacity: animation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: foreground),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            onAction();
                            hide();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: foreground,
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: Text(actionLabel),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    _controller = controller;

    overlay.insert(entry);
    controller.forward();

    _dismissTimer = Timer(duration, hide);
  }

  static Future<void> hide() async {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    final controller = _controller;
    if (controller != null && controller.status == AnimationStatus.completed) {
      await controller.reverse();
    }

    _removeCurrent(immediate: true);
  }

  static void _removeCurrent({required bool immediate}) {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    _entry?.remove();
    _entry = null;

    _controller?.dispose();
    _controller = null;
  }
}
