import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/verification_repository.dart';
import '../services/push_notification_service.dart';

/// Document-level status for a single document family (identity or diploma).
enum DocFamilyStatus { none, pending, approved, rejected }

class VerificationState {
  final bool isLoading;
  final String? error;

  /// Identity document (CNI / PASSPORT) — most recent per family
  final DocFamilyStatus identityStatus;
  final String? identityRejectionReason;

  /// Diploma / Certificat / Attestation — most recent per family
  final DocFamilyStatus diplomaStatus;
  final String? diplomaRejectionReason;

  /// Raw documents list from backend (for advanced display if needed)
  final List<Map<String, dynamic>> documents;

  const VerificationState({
    this.isLoading = false,
    this.error,
    this.identityStatus = DocFamilyStatus.none,
    this.identityRejectionReason,
    this.diplomaStatus = DocFamilyStatus.none,
    this.diplomaRejectionReason,
    this.documents = const [],
  });

  VerificationState copyWith({
    bool? isLoading,
    String? error,
    DocFamilyStatus? identityStatus,
    String? identityRejectionReason,
    DocFamilyStatus? diplomaStatus,
    String? diplomaRejectionReason,
    List<Map<String, dynamic>>? documents,
  }) {
    return VerificationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      identityStatus: identityStatus ?? this.identityStatus,
      identityRejectionReason:
          identityRejectionReason ?? this.identityRejectionReason,
      diplomaStatus: diplomaStatus ?? this.diplomaStatus,
      diplomaRejectionReason:
          diplomaRejectionReason ?? this.diplomaRejectionReason,
      documents: documents ?? this.documents,
    );
  }

  /// Aggregated dashboard label: worst-status-wins across both families.
  /// Priority: REJECTED > PENDING > NONE > per-family approved.
  String get dashboardLabel {
    final statuses = [identityStatus, diplomaStatus];

    // Any rejection → global REJECTED
    if (statuses.contains(DocFamilyStatus.rejected)) return 'REJECTED';

    // Any pending → global PENDING
    if (statuses.contains(DocFamilyStatus.pending)) return 'PENDING';

    // Both approved → CERTIFIED
    if (identityStatus == DocFamilyStatus.approved &&
        diplomaStatus == DocFamilyStatus.approved) {
      return 'CERTIFIED';
    }

    // Only identity approved (diploma not yet submitted) → VERIFIED
    if (identityStatus == DocFamilyStatus.approved) return 'VERIFIED';

    // Both NONE → NONE
    return 'NONE';
  }
}

class VerificationNotifier extends StateNotifier<VerificationState> {
  final VerificationRepository _repo;

  VerificationNotifier(this._repo) : super(const VerificationState()) {
    // Global FCM bridge: any DOCUMENT_APPROVED/REJECTED push triggers refresh
    // regardless of which screen is currently active.
    PushNotificationService().onVerificationUpdate = () => refresh();
  }

  static const _identityTypes = {'CNI', 'PASSPORT'};
  static const _diplomaTypes = {'DIPLOME', 'CERTIFICAT', 'ATTESTATION'};

  /// Fetch latest verification status from backend and normalize.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _repo.getVerificationStatus();
      final docs =
          (data['documents'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];

      // Backend returns DESC by submitted_at — first match per family is most recent.
      DocFamilyStatus idStatus = DocFamilyStatus.none;
      String? idReason;
      DocFamilyStatus dipStatus = DocFamilyStatus.none;
      String? dipReason;

      for (final doc in docs) {
        final type = (doc['document_type'] as String?) ?? '';
        final rawStatus = (doc['status'] as String?) ?? '';
        final reason = doc['rejection_reason'] as String?;

        if (_identityTypes.contains(type) &&
            idStatus == DocFamilyStatus.none) {
          idStatus = _parseStatus(rawStatus);
          idReason = reason;
        } else if (_diplomaTypes.contains(type) &&
            dipStatus == DocFamilyStatus.none) {
          dipStatus = _parseStatus(rawStatus);
          dipReason = reason;
        }
      }

      state = VerificationState(
        identityStatus: idStatus,
        identityRejectionReason: idReason,
        diplomaStatus: dipStatus,
        diplomaRejectionReason: dipReason,
        documents: docs,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Optimistic update after a successful local submission.
  void markFamilyPending({required bool isIdentity}) {
    if (isIdentity) {
      state = state.copyWith(
        identityStatus: DocFamilyStatus.pending,
        identityRejectionReason: null,
      );
    } else {
      state = state.copyWith(
        diplomaStatus: DocFamilyStatus.pending,
        diplomaRejectionReason: null,
      );
    }
  }

  static DocFamilyStatus _parseStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'PENDING':
        return DocFamilyStatus.pending;
      case 'APPROVED':
        return DocFamilyStatus.approved;
      case 'REJECTED':
        return DocFamilyStatus.rejected;
      default:
        return DocFamilyStatus.none;
    }
  }
}

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  return VerificationNotifier(VerificationRepository());
});
