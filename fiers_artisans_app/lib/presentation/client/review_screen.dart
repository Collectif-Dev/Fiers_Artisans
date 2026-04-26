import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/theme.dart';
import '../../providers/artisan_provider.dart';
import '../../providers/favorites_provider.dart';
import '../common/rating_stars.dart';
import '../common/app_button.dart';
import '../common/app_text_field.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String artisanId;
  const ReviewScreen({super.key, required this.artisanId});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _isLoading = true);

    final result = await ref
        .read(artisanDetailProvider.notifier)
        .submitReview(
          artisanId: widget.artisanId,
          rating: _rating,
          comment: _commentCtrl.text.trim().isNotEmpty
              ? _commentCtrl.text.trim()
              : null,
        );

    setState(() => _isLoading = false);

    if (mounted) {
      if (result.success) {
        final refreshedArtisan = ref.read(artisanDetailProvider).artisan;
        if (refreshedArtisan != null) {
          ref
              .read(favoritesProvider.notifier)
              .patchFavoriteFromArtisan(refreshedArtisan);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('review.submitted_success'.tr()),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      } else {
        final errorMessage = switch (result.errorType) {
          ReviewSubmitFailure.duplicate => 'review.already_done'.tr(),
          ReviewSubmitFailure.network => 'error.no_internet'.tr(),
          ReviewSubmitFailure.backend => 'error.server'.tr(),
          _ => 'error.generic'.tr(),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('review.leave'.tr())),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'review.your_rating'.tr(),
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: RatingStars(
                          rating: _rating.toDouble(),
                          size: 40,
                          interactive: true,
                          allowClear: true,
                          onRatingChanged: (r) => setState(() => _rating = r),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'review.tap_again_to_clear'.tr(),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      AppTextField(
                        controller: _commentCtrl,
                        label: 'review.your_comment'.tr(),
                        maxLines: 5,
                      ),
                      const Spacer(),
                      AppButton(
                        text: 'review.submit'.tr(),
                        isLoading: _isLoading,
                        onPressed: _rating > 0 ? _submit : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
