class ManualPaymentModel {
  final String transactionId;
  final String provider;
  final int amountFcfa;
  final String status;
  final String? recipientNumber;
  final String? rejectionReason;
  final bool refundRequired;
  final bool providerAvailable;
  final DateTime? expiresAtAdmin;

  const ManualPaymentModel({
    required this.transactionId,
    required this.provider,
    required this.amountFcfa,
    required this.status,
    this.recipientNumber,
    this.rejectionReason,
    this.refundRequired = false,
    this.providerAvailable = true,
    this.expiresAtAdmin,
  });

  bool get isRejected => status == 'REJECTED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isPendingAdmin => status == 'PENDING_ADMIN';
  bool get isPending => status == 'PENDING';
  bool get canInitiateNewTransaction => isRejected || status == 'EXPIRED';

  factory ManualPaymentModel.fromJson(Map<String, dynamic> json) {
    return ManualPaymentModel(
      transactionId: (json['transaction_id'] ?? json['transactionId'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      amountFcfa: int.tryParse((json['amount_fcfa'] ?? json['amountFcfa'] ?? 0).toString()) ?? 0,
      status: (json['status'] ?? 'PENDING').toString(),
      recipientNumber: json['recipient_number']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      refundRequired: json['refund_required'] == true,
      providerAvailable: json['provider_available'] == null
          ? true
          : json['provider_available'] == true,
      expiresAtAdmin: json['expires_at_admin'] != null
          ? DateTime.tryParse(json['expires_at_admin'].toString())
          : null,
    );
  }
}
