class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? type; // 'text' | 'image' | 'location'
  final DateTime createdAt;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.type = 'text',
    required this.createdAt,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      content: json['content'] ?? '',
      type: (json['type'] ?? 'TEXT').toString().toLowerCase(),
      createdAt: json['sentAt'] != null
          ? DateTime.parse(json['sentAt'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'conversationId': conversationId,
        'senderId': senderId,
        'content': content,
        'type': type,
      };
}
