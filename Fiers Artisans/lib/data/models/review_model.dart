class ReviewModel {
  final String id;
  final String clientId;
  final String artisanId;
  final String? clientName;
  final int rating;
  final String? comment;
  final String? artisanReply;
  final DateTime? artisanReplyAt;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.clientId,
    required this.artisanId,
    this.clientName,
    required this.rating,
    this.comment,
    this.artisanReply,
    this.artisanReplyAt,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? json['clientId']?.toString() ?? '',
      artisanId: json['artisan_id']?.toString() ?? json['artisanId']?.toString() ?? '',
      clientName: json['client']?['first_name'] ?? json['clientName'] ?? json['client']?['firstName'],
      rating: json['rating'] ?? 0,
      comment: json['comment'],
        artisanReply: json['artisan_reply'] ?? json['artisanReply'],
        artisanReplyAt: json['artisan_reply_at'] != null
          ? DateTime.tryParse(json['artisan_reply_at'])
          : json['artisanReplyAt'] != null
            ? DateTime.tryParse(json['artisanReplyAt'])
            : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
    );
  }
}
