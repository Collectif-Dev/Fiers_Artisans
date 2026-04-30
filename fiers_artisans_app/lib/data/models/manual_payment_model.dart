class ManualPaymentModel {
  final String transactionId;
  final String provider;
  final int amountFcfa;
  final String status;
  final String? recipientNumber;
  final DateTime? expiresAtAdmin;

  const ManualPaymentModel({
    required this.transactionId,
    required this.provider,
    required this.amountFcfa,
    required this.status,
    this.recipientNumber,
    this.expiresAtAdmin,
  });

  bool get isRejected => status == 'REJECTED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isPendingAdmin => status == 'PENDING_ADMIN';

  factory ManualPaymentModel.fromJson(Map<String, dynamic> json) {
    return ManualPaymentModel(
      transactionId: (json['transaction_id'] ?? json['transactionId'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      amountFcfa: int.tryParse((json['amount_fcfa'] ?? json['amountFcfa'] ?? 0).toString()) ?? 0,
      status: (json['status'] ?? 'PENDING').toString(),
      recipientNumber: json['recipient_number']?.toString(),
      expiresAtAdmin: json['expires_at_admin'] != null
          ? DateTime.tryParse(json['expires_at_admin'].toString())
          : null,
    );
  }
}
