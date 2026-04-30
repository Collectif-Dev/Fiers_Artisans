import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/artisan_model.dart';
import '../../data/models/review_model.dart';
import '../../data/repositories/artisan_repository.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_realtime_service.dart';
import '../common/rating_stars.dart';

class ArtisanReviewsHistoryScreen extends ConsumerStatefulWidget {
  const ArtisanReviewsHistoryScreen({super.key});

  @override
  ConsumerState<ArtisanReviewsHistoryScreen> createState() =>
      _ArtisanReviewsHistoryScreenState();
}

class _ArtisanReviewsHistoryScreenState
    extends ConsumerState<ArtisanReviewsHistoryScreen> {
  final ArtisanRepository _repository = ArtisanRepository();
  final ChatRealtimeService _realtime = ChatRealtimeService();
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  bool _isLoading = true;
  String? _error;
  String? _replyingReviewId;
  ArtisanModel? _artisan;
  List<ReviewModel> _reviews = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
    _realtimeSub = _realtime.domainEvents.listen(_onRealtimeEvent);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'error.unauthorized'.tr();
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final artisan = await _repository.getMyArtisanProfile();
      final reviews = await _repository.getReviews(artisan.id);
      if (!mounted) return;
      setState(() {
        _artisan = artisan;
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'error.generic'.tr();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('dashboard.artisan.reviews_history_title'.tr()),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 48),
                    Icon(
                      Icons.error_outline,
                      size: 40,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton(
                        onPressed: _load,
                        child: Text('common.retry'.tr()),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSummary(theme),
                    const SizedBox(height: 20),
                    Text(
                      'dashboard.artisan.total_reviews'.tr(),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_reviews.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Text(
                          'review.empty'.tr(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      ..._reviews.map(
                        (review) => _buildReviewItem(theme, review),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final artisan = _artisan;
    final totalReviews = artisan?.totalReviews ?? _reviews.length;
    final averageRating = artisan?.averageRating ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dashboard.artisan.avg_rating'.tr(),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                Formatters.rating(averageRating),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              RatingStars(rating: averageRating),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$totalReviews ${'dashboard.artisan.total_reviews'.tr()}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(ThemeData theme, ReviewModel review) {
    final hasArtisanReply = (review.artisanReply ?? '').trim().isNotEmpty;
    final isReplying = _replyingReviewId == review.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.clientName ?? 'Client',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              RatingStars(rating: review.rating.toDouble(), size: 15),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (review.comment ?? '').trim().isEmpty
                ? 'review.no_comment'.tr()
                : review.comment!,
            style: theme.textTheme.bodyMedium,
          ),
          if (hasArtisanReply) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'review.artisan_reply_label'.tr(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(review.artisanReply!, style: theme.textTheme.bodyMedium),
                  if (review.artisanReplyAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      Formatters.relativeDate(review.artisanReplyAt!),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: isReplying ? null : () => _openReplyDialog(review),
                icon: isReplying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.reply_outlined, size: 16),
                label: Text('review.reply_action'.tr()),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            Formatters.relativeDate(review.createdAt),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _openReplyDialog(ReviewModel review) async {
    final replyController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('review.reply_dialog_title'.tr()),
        content: TextField(
          controller: replyController,
          autofocus: true,
          maxLines: 4,
          maxLength: 1000,
          decoration: InputDecoration(
            hintText: 'review.reply_dialog_hint'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(replyController.text.trim()),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    );

    if (!mounted) return;
    final reply = result?.trim() ?? '';
    if (reply.isEmpty) return;

    setState(() => _replyingReviewId = review.id);
    try {
      await _repository.replyToReview(reviewId: review.id, reply: reply);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('review.reply_success'.tr())));
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final message = status == 409
          ? 'review.reply_already_exists'.tr()
          : 'error.generic'.tr();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error.generic'.tr())));
    } finally {
      if (mounted) {
        setState(() => _replyingReviewId = null);
      }
    }
  }

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    final currentUserId = ref.read(authProvider).user?.id;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final artisanUserId = event.payload['artisanUserId']?.toString();
    final isCurrentArtisan =
        artisanUserId != null && artisanUserId == currentUserId;

    if (event.event == 'artisanReviewsUpdated' && isCurrentArtisan) {
      _load();
      return;
    }

    if (event.event == 'notificationCreated') {
      final notif = event.payload['notification'];
      if (notif is Map<String, dynamic>) {
        final type = notif['type']?.toString().toUpperCase();
        if (type == 'REVIEW_CREATED' || type == 'REVIEW_UPDATED') {
          _load();
        }
      }
    }
  }
}
