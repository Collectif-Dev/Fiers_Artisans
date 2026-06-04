import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final ApiClient _api = ApiClient();

  Map<String, dynamic> _asDataMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      if (payload['data'] is Map<String, dynamic>) {
        return payload['data'] as Map<String, dynamic>;
      }
      return payload;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asDataList(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map<String, dynamic> && payload['data'] is List) {
      return payload['data'] as List;
    }
    return <dynamic>[];
  }

  Future<List<ConversationModel>> getConversations() async {
    final response = await _api.get(ApiEndpoints.conversations);
    final list = _asDataList(response.data);
    return list.map((e) => ConversationModel.fromJson(e)).toList();
  }

  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int page = 1,
  }) async {
    final response = await _api.get(
      ApiEndpoints.messages(conversationId),
      queryParameters: {'page': page, 'limit': 50},
    );
    final list = _asDataList(response.data);
    return list.map((e) => MessageModel.fromJson(e)).toList();
  }

  /// Send a message via REST (reliable path).
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    String? type,
    String? mediaUrl,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (type != null) body['type'] = type;
    if (mediaUrl != null) body['mediaUrl'] = mediaUrl;

    final response = await _api.post(
      ApiEndpoints.messages(conversationId),
      data: body,
    );
    return MessageModel.fromJson(_asDataMap(response.data));
  }

  /// Create a new conversation with a participant.
  Future<ConversationModel> createConversation(String participantId) async {
    final response = await _api.post(
      ApiEndpoints.conversations,
      data: {'participantId': participantId},
    );
    return ConversationModel.fromJson(_asDataMap(response.data));
  }

  /// Mark all messages in a conversation as read.
  Future<void> markAsRead(String conversationId) async {
    await _api.put(ApiEndpoints.conversationRead(conversationId));
  }
}
