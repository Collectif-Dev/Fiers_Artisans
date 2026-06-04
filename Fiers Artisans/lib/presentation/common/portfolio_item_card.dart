import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/portfolio_model.dart';
import '../../config/theme.dart';

class PortfolioItemCard extends StatefulWidget {
  final PortfolioModel item;
  final bool showDeleteAction;
  final VoidCallback? onDelete;

  const PortfolioItemCard({
    super.key,
    required this.item,
    this.showDeleteAction = false,
    this.onDelete,
  });

  @override
  State<PortfolioItemCard> createState() => _PortfolioItemCardState();
}

class _PortfolioItemCardState extends State<PortfolioItemCard> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  Timer? _autoSlideResumeTimer;
  int _currentImageIndex = 0;
  bool _isVisibleToUser = true;
  bool _isUserInteracting = false;
  bool _isProgrammaticPageChange = false;

  static const Duration _autoSlideInterval = Duration(seconds: 4);

  bool get _reduceMotionRequested =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  bool get _canAutoSlide =>
      widget.item.imageUrls.length > 1 &&
      _isVisibleToUser &&
      !_isUserInteracting &&
      !_reduceMotionRequested;

  bool get _showCursorArrows {
    final platform = defaultTargetPlatform;
    final isPhonePlatform =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;

    if (kIsWeb) {
      // On mobile browsers (Android/iOS), hide arrows and keep tactile swipe.
      return !isPhonePlatform;
    }

    // On native apps, keep arrows only for desktop platforms.
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  Future<void> _goToImage(int index, {bool userInitiated = false}) async {
    if (!_pageController.hasClients) return;
    if (index == _currentImageIndex) return;

    if (userInitiated) {
      _pauseAndResetAutoSlide();
    }

    _isProgrammaticPageChange = true;
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    _isProgrammaticPageChange = false;
  }

  void _cancelAutoSlideTimer() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  void _updateAutoSlideTimer() {
    if (!_canAutoSlide) {
      _cancelAutoSlideTimer();
      return;
    }

    _autoSlideTimer ??= Timer.periodic(_autoSlideInterval, (_) {
      _advanceToNextImage();
    });
  }

  Future<void> _advanceToNextImage() async {
    if (!_canAutoSlide || !_pageController.hasClients) return;

    final total = widget.item.imageUrls.length;
    if (total < 2) return;

    final nextIndex = (_currentImageIndex + 1) % total;
    await _goToImage(nextIndex);
  }

  void _pauseAndResetAutoSlide({Duration resumeDelay = _autoSlideInterval}) {
    _isUserInteracting = true;
    _cancelAutoSlideTimer();
    _autoSlideResumeTimer?.cancel();

    if (!_isVisibleToUser || _reduceMotionRequested) return;

    _autoSlideResumeTimer = Timer(resumeDelay, () {
      if (!mounted) return;
      _isUserInteracting = false;
      _updateAutoSlideTimer();
    });
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final isVisibleNow = info.visibleFraction > 0.55;
    if (isVisibleNow == _isVisibleToUser) return;

    _isVisibleToUser = isVisibleNow;
    if (!_isVisibleToUser) {
      _cancelAutoSlideTimer();
      _autoSlideResumeTimer?.cancel();
      return;
    }

    _isUserInteracting = false;
    _updateAutoSlideTimer();
  }

  Future<void> _openPreview(int initialIndex) async {
    if (widget.item.imageUrls.isEmpty) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black.withValues(alpha: 0.86),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _PortfolioImagePreviewDialog(
            imageUrls: widget.item.imageUrls,
            initialIndex: initialIndex,
            showCursorArrows: _showCursorArrows,
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAutoSlideTimer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAutoSlideTimer();
  }

  @override
  void didUpdateWidget(covariant PortfolioItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _currentImageIndex = 0;
      _isUserInteracting = false;
      _isProgrammaticPageChange = false;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAutoSlideTimer();
    });
  }

  @override
  void dispose() {
    _cancelAutoSlideTimer();
    _autoSlideResumeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrice = widget.item.price != null;
    final hasDescription =
        widget.item.description != null &&
        widget.item.description!.trim().isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAutoSlideTimer();
    });

    return VisibilityDetector(
      key: ValueKey('portfolio-item-${widget.item.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _buildImageArea(theme)),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final compact = constraints.maxHeight < 74;
                    final tightLayout =
                        widget.showDeleteAction &&
                        (constraints.maxHeight < 84 || textScale > 1.0);
                    final showDescription =
                        hasDescription && !compact && !tightLayout;
                    final deleteButtonSize = textScale > 1.15 ? 26.0 : 24.0;
                    final minBottomRowHeight = widget.showDeleteAction
                        ? deleteButtonSize
                        : (compact ? 18.0 : 20.0);
                    final titleMaxLines = (tightLayout || compact)
                        ? 1
                        : (showDescription ? 1 : 2);
                    final verticalGap = compact ? 2.0 : 4.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: titleMaxLines,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (showDescription) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.item.description!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withValues(alpha: 0.9),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: verticalGap),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: minBottomRowHeight,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: hasPrice
                                    ? Text(
                                        Formatters.fcfa(widget.item.price!),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (widget.showDeleteAction)
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppTheme.error,
                                  ),
                                  onPressed: widget.onDelete,
                                  tooltip: 'Supprimer',
                                  padding: EdgeInsets.zero,
                                  splashRadius: 16,
                                  visualDensity: VisualDensity.compact,
                                  constraints: BoxConstraints.tightFor(
                                    width: deleteButtonSize,
                                    height: deleteButtonSize,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea(ThemeData theme) {
    if (widget.item.imageUrls.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.photo_outlined, size: 40)),
      );
    }

    final hasMultiple = widget.item.imageUrls.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        hasMultiple
            ? NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) {
                    _pauseAndResetAutoSlide();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.item.imageUrls.length,
                  onPageChanged: (index) {
                    if (!mounted) return;
                    setState(() => _currentImageIndex = index);

                    if (_isProgrammaticPageChange) {
                      return;
                    }

                    _pauseAndResetAutoSlide();
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _openPreview(index),
                      child: _NetworkImage(url: widget.item.imageUrls[index]),
                    );
                  },
                ),
              )
            : GestureDetector(
                onTap: () => _openPreview(0),
                child: _NetworkImage(url: widget.item.imageUrls.first),
              ),
        if (hasMultiple)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${widget.item.imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (hasMultiple && _showCursorArrows)
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: _CarouselArrowButton(
                icon: Icons.chevron_left,
                tooltip: 'Image precedente',
                onPressed: _currentImageIndex > 0
                    ? () => _goToImage(
                        _currentImageIndex - 1,
                        userInitiated: true,
                      )
                    : null,
              ),
            ),
          ),
        if (hasMultiple && _showCursorArrows)
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: _CarouselArrowButton(
                icon: Icons.chevron_right,
                tooltip: 'Image suivante',
                onPressed: _currentImageIndex < widget.item.imageUrls.length - 1
                    ? () => _goToImage(
                        _currentImageIndex + 1,
                        userInitiated: true,
                      )
                    : null,
              ),
            ),
          ),
        if (hasMultiple)
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.item.imageUrls.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: _currentImageIndex == index ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CarouselArrowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CarouselArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 18),
        tooltip: tooltip,
        onPressed: onPressed,
        splashRadius: 16,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;

  const _NetworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
      ),
    );
  }
}

class _PortfolioImagePreviewDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool showCursorArrows;

  const _PortfolioImagePreviewDialog({
    required this.imageUrls,
    required this.initialIndex,
    required this.showCursorArrows,
  });

  @override
  State<_PortfolioImagePreviewDialog> createState() =>
      _PortfolioImagePreviewDialogState();
}

class _PortfolioImagePreviewDialogState
    extends State<_PortfolioImagePreviewDialog>
    with WidgetsBindingObserver {
  late final PageController _controller;
  late int _currentIndex;
  Timer? _autoSlideTimer;
  Timer? _autoSlideResumeTimer;
  bool _isUserInteracting = false;
  bool _isProgrammaticPageChange = false;
  bool _isAppInForeground = true;

  static const Duration _autoSlideInterval = Duration(seconds: 4);

  bool get _hasMultiple => widget.imageUrls.length > 1;

  bool get _reduceMotionRequested =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  bool get _canAutoSlide =>
      _hasMultiple &&
      _isAppInForeground &&
      !_isUserInteracting &&
      !_reduceMotionRequested;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _controller = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateAutoSlideTimer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAutoSlideTimer();
  }

  Future<void> _goTo(int index, {bool userInitiated = false}) async {
    if (!_controller.hasClients) return;
    if (index == _currentIndex) return;

    if (userInitiated) {
      _pauseAndResetAutoSlide();
    }

    _isProgrammaticPageChange = true;
    await _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    _isProgrammaticPageChange = false;
  }

  void _cancelAutoSlideTimer() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
  }

  void _updateAutoSlideTimer() {
    if (!_canAutoSlide) {
      _cancelAutoSlideTimer();
      return;
    }

    _autoSlideTimer ??= Timer.periodic(_autoSlideInterval, (_) {
      _advanceToNextImage();
    });
  }

  Future<void> _advanceToNextImage() async {
    if (!_canAutoSlide || !_controller.hasClients) return;

    final nextIndex = (_currentIndex + 1) % widget.imageUrls.length;
    await _goTo(nextIndex);
  }

  void _pauseAndResetAutoSlide({Duration resumeDelay = _autoSlideInterval}) {
    _isUserInteracting = true;
    _cancelAutoSlideTimer();
    _autoSlideResumeTimer?.cancel();

    if (_reduceMotionRequested || !_isAppInForeground) return;

    _autoSlideResumeTimer = Timer(resumeDelay, () {
      if (!mounted) return;
      _isUserInteracting = false;
      _updateAutoSlideTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;

    if (!_isAppInForeground) {
      _cancelAutoSlideTimer();
      _autoSlideResumeTimer?.cancel();
      return;
    }

    _isUserInteracting = false;
    _updateAutoSlideTimer();
  }

  @override
  void dispose() {
    _cancelAutoSlideTimer();
    _autoSlideResumeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Stack(
            children: [
              NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) {
                    _pauseAndResetAutoSlide();
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (index) {
                    if (!mounted) return;
                    setState(() => _currentIndex = index);

                    if (_isProgrammaticPageChange) {
                      return;
                    }

                    _pauseAndResetAutoSlide();
                  },
                  itemBuilder: (context, index) {
                    return _PreviewImage(url: widget.imageUrls[index]);
                  },
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Fermer',
                ),
              ),
              if (_hasMultiple)
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_hasMultiple && widget.showCursorArrows)
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CarouselArrowButton(
                      icon: Icons.chevron_left,
                      tooltip: 'Image precedente',
                      onPressed: _currentIndex > 0
                          ? () => _goTo(_currentIndex - 1, userInitiated: true)
                          : null,
                    ),
                  ),
                ),
              if (_hasMultiple && widget.showCursorArrows)
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _CarouselArrowButton(
                      icon: Icons.chevron_right,
                      tooltip: 'Image suivante',
                      onPressed: _currentIndex < widget.imageUrls.length - 1
                          ? () => _goTo(_currentIndex + 1, userInitiated: true)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  final String url;

  const _PreviewImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 3,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 52,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
