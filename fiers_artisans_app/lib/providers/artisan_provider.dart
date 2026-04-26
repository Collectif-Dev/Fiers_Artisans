import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/artisan_model.dart';
import '../data/models/review_model.dart';
import '../data/models/portfolio_model.dart';
import '../data/repositories/artisan_repository.dart';
import '../services/push_notification_service.dart';

enum ReviewSubmitFailure { duplicate, network, backend, unknown }

class ReviewSubmitResult {
  final bool success;
  final ReviewSubmitFailure? errorType;

  const ReviewSubmitResult._({required this.success, this.errorType});

  const ReviewSubmitResult.success() : this._(success: true);

  const ReviewSubmitResult.failure(ReviewSubmitFailure type)
    : this._(success: false, errorType: type);
}

class ArtisanDetailState {
  final ArtisanModel? artisan;
  final List<ReviewModel> reviews;
  final List<PortfolioModel> portfolio;
  final bool isLoading;
  final String? error;

  const ArtisanDetailState({
    this.artisan,
    this.reviews = const [],
    this.portfolio = const [],
    this.isLoading = false,
    this.error,
  });

  ArtisanDetailState copyWith({
    ArtisanModel? artisan,
    List<ReviewModel>? reviews,
    List<PortfolioModel>? portfolio,
    bool? isLoading,
    String? error,
  }) {
    return ArtisanDetailState(
      artisan: artisan ?? this.artisan,
      reviews: reviews ?? this.reviews,
      portfolio: portfolio ?? this.portfolio,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final artisanDetailProvider =
    StateNotifierProvider<ArtisanDetailNotifier, ArtisanDetailState>((ref) {
      return ArtisanDetailNotifier();
    });

class ArtisanDetailNotifier extends StateNotifier<ArtisanDetailState> {
  final ArtisanRepository _repo = ArtisanRepository();

  ArtisanDetailNotifier() : super(const ArtisanDetailState()) {
    PushNotificationService().onReviewUpdate = () {
      final artisanId = state.artisan?.id;
      if (artisanId == null || artisanId.isEmpty) {
        return;
      }
      refreshReviewsAndSummary(artisanId);
    };
  }

  Future<void> loadArtisan(String userId) async {
    state = const ArtisanDetailState(isLoading: true);
    try {
      final artisan = await _repo.getArtisan(userId);
      state = state.copyWith(artisan: artisan, isLoading: false);
      // Load reviews and portfolio in parallel
      await Future.wait([_loadReviews(artisan.id), _loadPortfolio(artisan.id)]);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadReviews(String artisanId) async {
    try {
      final reviews = await _repo.getReviews(artisanId);
      state = state.copyWith(reviews: reviews);
    } catch (_) {}
  }

  Future<void> _loadPortfolio(String artisanId) async {
    try {
      final portfolio = await _repo.getPortfolio(artisanId);
      state = state.copyWith(portfolio: portfolio);
    } catch (_) {}
  }

  Future<void> refreshReviewsAndSummary(String artisanId) async {
    try {
      final results = await Future.wait<dynamic>([
        _repo.getArtisan(artisanId),
        _repo.getReviews(artisanId),
      ]);
      state = state.copyWith(
        artisan: results[0] as ArtisanModel,
        reviews: results[1] as List<ReviewModel>,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<ReviewSubmitResult> submitReview({
    required String artisanId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _repo.submitReview(
        artisanId: artisanId,
        rating: rating,
        comment: comment,
      );
      await refreshReviewsAndSummary(artisanId);
      return const ReviewSubmitResult.success();
    } on ReviewSubmitException catch (e) {
      final failure = switch (e.type) {
        ReviewSubmitErrorType.duplicate => ReviewSubmitFailure.duplicate,
        ReviewSubmitErrorType.network => ReviewSubmitFailure.network,
        ReviewSubmitErrorType.backend => ReviewSubmitFailure.backend,
        ReviewSubmitErrorType.unknown => ReviewSubmitFailure.unknown,
      };
      return ReviewSubmitResult.failure(failure);
    } catch (_) {
      return const ReviewSubmitResult.failure(ReviewSubmitFailure.unknown);
    }
  }

  Future<void> replyToReview({
    required String reviewId,
    required String reply,
    required String artisanId,
  }) async {
    await _repo.replyToReview(reviewId: reviewId, reply: reply);
    await refreshReviewsAndSummary(artisanId);
  }
}
