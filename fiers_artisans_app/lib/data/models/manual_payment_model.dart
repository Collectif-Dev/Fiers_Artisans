class ManualPaymentModel {
  final String transactionId;
  final String provider;
  final int amountFcfa;
  final String status;
  final String? recipientNumber;
  final String? rejectionReason;
  final bool refundRequired;
  final DateTime? refundDoneAt;
  final bool providerAvailable;
  final DateTime? expiresAtAdmin;
  final int submittedProofCount;
  final int requestNumber;
  final DateTime? cooldownUntil;
  final int cooldownCycle;

  const ManualPaymentModel({
    required this.transactionId,
    required this.provider,
    required this.amountFcfa,
    required this.status,
    this.recipientNumber,
    this.rejectionReason,
    this.refundRequired = false,
    this.refundDoneAt,
    this.providerAvailable = true,
    this.expiresAtAdmin,
    this.submittedProofCount = 0,
    this.requestNumber = 0,
    this.cooldownUntil,
    this.cooldownCycle = 0,
  });

  bool get isRejected => status == 'REJECTED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isPendingAdmin => status == 'PENDING_ADMIN';
  bool get isPending => status == 'PENDING';
  bool get isExpired => status == 'EXPIRED';
  bool get isRefundPending => isExpired && refundRequired && refundDoneAt == null;
  bool get isRefundDone => refundDoneAt != null;
  bool get canInitiateNewRequest => isExpired && isRefundDone;
  bool get canInitiateNewTransaction => canInitiateNewRequest;
  bool get isCooldownActive =>
      cooldownUntil != null && cooldownUntil!.isAfter(DateTime.now());
  int get cooldownRemainingSeconds {
    if (cooldownUntil == null) {
      return 0;
    }
    final remaining = cooldownUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
  int get currentAttemptNumber {
    if (submittedProofCount <= 0) {
      return 0;
    }
    return ((submittedProofCount - 1) % 3) + 1;
  }

  bool hasActiveCooldownAt(DateTime now) =>
      cooldownUntil != null && cooldownUntil!.isAfter(now);

  factory ManualPaymentModel.fromJson(Map<String, dynamic> json) {
    final proofs = json['proofs'];
    final proofCountFromPayload = int.tryParse(
      (json['proof_count'] ?? json['proofCount'] ?? '').toString(),
    );
    final derivedProofCount = proofs is List ? proofs.length : 0;

    return ManualPaymentModel(
      transactionId: (json['transaction_id'] ?? json['transactionId'] ?? '')
          .toString(),
      provider: (json['provider'] ?? '').toString(),
      amountFcfa:
          int.tryParse(
            (json['amount_fcfa'] ?? json['amountFcfa'] ?? 0).toString(),
          ) ??
          0,
      status: (json['status'] ?? 'PENDING').toString(),
      recipientNumber: json['recipient_number']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      refundRequired: json['refund_required'] == true,
      refundDoneAt: json['refund_done_at'] != null
          ? DateTime.tryParse(json['refund_done_at'].toString())
          : null,
      providerAvailable: json['provider_available'] == null
          ? true
          : json['provider_available'] == true,
      expiresAtAdmin: json['expires_at_admin'] != null
          ? DateTime.tryParse(json['expires_at_admin'].toString())
          : null,
      submittedProofCount: proofCountFromPayload ?? derivedProofCount,
      requestNumber:
          int.tryParse(
            (json['request_number'] ?? json['requestNumber'] ?? 0).toString(),
          ) ??
          0,
      cooldownUntil: json['cooldown_until'] != null
          ? DateTime.tryParse(json['cooldown_until'].toString())
          : null,
      cooldownCycle:
          int.tryParse(
            (json['cooldown_cycle'] ?? json['cooldownCycle'] ?? 0).toString(),
          ) ??
          0,
    );
  }
}
