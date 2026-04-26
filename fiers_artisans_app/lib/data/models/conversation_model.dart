class ConversationModel {
  final String id;
  final String participantId;
  final String participantName;
  final String? participantAvatarUrl;
  final String? participantRole;
  final bool? participantIsAvailable;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.participantId,
    required this.participantName,
    this.participantAvatarUrl,
    this.participantRole,
    this.participantIsAvailable,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final lastMsg = json['lastMessage'];
    return ConversationModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      participantId: json['participantId']?.toString() ?? '',
      participantName: json['participantName'] ?? 'Inconnu',
      participantAvatarUrl: json['participantAvatarUrl'],
      participantRole:
          json['participantRole']?.toString() ??
          json['participant_role']?.toString(),
      participantIsAvailable: json['participantIsAvailable'] is bool
          ? json['participantIsAvailable'] as bool
          : (json['participant_is_available'] is bool
                ? json['participant_is_available'] as bool
                : null),
      lastMessage: lastMsg is Map ? lastMsg['content'] : lastMsg?.toString(),
      lastMessageAt: lastMsg is Map && lastMsg['sentAt'] != null
          ? DateTime.tryParse(lastMsg['sentAt'])
          : json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'])
          : json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}
