import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/secure_storage.dart';
import '../data/models/conversation_model.dart';
import '../data/models/message_model.dart';
import '../data/repositories/chat_repository.dart';
import '../services/chat_realtime_service.dart';

class ChatState {
  final List<ConversationModel> conversations;
  final Map<String, List<MessageModel>> messagesByConversation;
  final bool isLoading;
  final String? activeConversationId;
  final String? errorMessage;
  final bool authRequired;

  const ChatState({
    this.conversations = const [],
    this.messagesByConversation = const {},
    this.isLoading = false,
    this.activeConversationId,
    this.errorMessage,
    this.authRequired = false,
  });

  List<MessageModel> messagesFor(String conversationId) =>
      messagesByConversation[conversationId] ?? const [];

  bool isMessagesLoading(String conversationId) =>
      isLoading && activeConversationId == conversationId;

  ConversationModel? conversationById(String conversationId) {
    for (final conversation in conversations) {
      if (conversation.id == conversationId) {
        return conversation;
      }
    }
    return null;
  }

  ChatState copyWith({
    List<ConversationModel>? conversations,
    Map<String, List<MessageModel>>? messagesByConversation,
    bool? isLoading,
    String? activeConversationId,
    String? errorMessage,
    bool? authRequired,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      messagesByConversation:
          messagesByConversation ?? this.messagesByConversation,
      isLoading: isLoading ?? this.isLoading,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      errorMessage: errorMessage,
      authRequired: authRequired ?? this.authRequired,
    );
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repo = ChatRepository();
  final ChatRealtimeService _realtime = ChatRealtimeService();

  StreamSubscription<Map<String, dynamic>>? _newMessageSub;
  StreamSubscription<Map<String, dynamic>>? _messagesReadSub;
  StreamSubscription<Map<String, dynamic>>? _participantAvailabilitySub;
  String? _currentUserId;

  ChatNotifier() : super(const ChatState()) {
    unawaited(_initializeRealtime());
  }

  @override
  void dispose() {
    _newMessageSub?.cancel();
    _messagesReadSub?.cancel();
    _participantAvailabilitySub?.cancel();
    super.dispose();
  }

  Future<void> _initializeRealtime() async {
    _currentUserId = await SecureStorage.getUserId();
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      return;
    }

    await _realtime.connect(userId: _currentUserId!);

    await _newMessageSub?.cancel();
    await _messagesReadSub?.cancel();
    await _participantAvailabilitySub?.cancel();

    _newMessageSub = _realtime.newMessages.listen(_onSocketNewMessage);
    _messagesReadSub = _realtime.messagesRead.listen(_onSocketMessagesRead);
    _participantAvailabilitySub = _realtime.participantAvailabilityUpdates
        .listen(_onSocketParticipantAvailabilityUpdated);
  }

  Future<void> _ensureRealtimeConnected() async {
    if (_currentUserId == null ||
        _currentUserId!.isEmpty ||
        !_realtime.isConnected) {
      await _initializeRealtime();
    }
  }

  Future<void> loadConversations() async {
    await _ensureRealtimeConnected();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final convos = await _repo.getConversations();
      for (final convo in convos) {
        _realtime.joinConversation(convo.id);
      }
      state = state.copyWith(
        conversations: convos,
        isLoading: false,
        authRequired: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        authRequired: _isUnauthorizedError(e),
        errorMessage: 'Impossible de charger les conversations.',
      );
    }
  }

  Future<void> loadMessages(String conversationId) async {
    await _ensureRealtimeConnected();
    state = state.copyWith(
      isLoading: true,
      activeConversationId: conversationId,
      errorMessage: null,
    );

    try {
      final msgs = await _repo.getMessages(conversationId);
      _realtime.joinConversation(conversationId);
      state = state.copyWith(
        messagesByConversation: {
          ...state.messagesByConversation,
          conversationId: msgs,
        },
        isLoading: false,
        authRequired: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        authRequired: _isUnauthorizedError(e),
        errorMessage: 'Impossible de charger les messages.',
      );
    }
  }

  void addMessage(MessageModel message) {
    final existing = state.messagesFor(message.conversationId);
    if (existing.any((m) => m.id == message.id)) {
      return;
    }

    state = state.copyWith(
      messagesByConversation: {
        ...state.messagesByConversation,
        message.conversationId: [...existing, message],
      },
    );
  }

  void removeMessage(String messageId) {
    final updatedMessages = <String, List<MessageModel>>{};
    for (final entry in state.messagesByConversation.entries) {
      updatedMessages[entry.key] = entry.value
          .where((m) => m.id != messageId)
          .toList();
    }
    state = state.copyWith(messagesByConversation: updatedMessages);
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    required String tempId,
  }) async {
    await _ensureRealtimeConnected();
    try {
      final sent = await _repo.sendMessage(
        conversationId: conversationId,
        content: content,
      );

      final current = state.messagesFor(conversationId);
      final updated = current.map((m) {
        if (m.id == tempId) return sent;
        return m;
      }).toList();

      state = state.copyWith(
        messagesByConversation: {
          ...state.messagesByConversation,
          conversationId: updated,
        },
        authRequired: false,
      );

      _applyConversationPreview(sent);
      return sent;
    } catch (e) {
      state = state.copyWith(
        authRequired: _isUnauthorizedError(e),
        errorMessage: 'Envoi du message impossible.',
      );
      rethrow;
    }
  }

  Future<ConversationModel> createConversation(String participantId) async {
    await _ensureRealtimeConnected();
    try {
      final convo = await _repo.createConversation(participantId);
      _realtime.joinConversation(convo.id);
      final merged = _upsertConversation(state.conversations, convo);
      state = state.copyWith(conversations: merged, authRequired: false);
      return convo;
    } catch (e) {
      state = state.copyWith(
        authRequired: _isUnauthorizedError(e),
        errorMessage: 'Impossible de demarrer la conversation.',
      );
      rethrow;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _repo.markAsRead(conversationId);

      final updatedConversations = state.conversations.map((c) {
        if (c.id != conversationId) return c;
        return ConversationModel(
          id: c.id,
          participantId: c.participantId,
          participantName: c.participantName,
          participantAvatarUrl: c.participantAvatarUrl,
          participantRole: c.participantRole,
          participantIsAvailable: c.participantIsAvailable,
          lastMessage: c.lastMessage,
          lastMessageAt: c.lastMessageAt,
          unreadCount: 0,
        );
      }).toList();

      final currentConversationMessages = state.messagesFor(conversationId);
      final updatedMessages = currentConversationMessages.map((m) {
        if (m.senderId == _currentUserId) return m;
        return MessageModel(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          content: m.content,
          type: m.type,
          createdAt: m.createdAt,
          isRead: true,
        );
      }).toList();

      state = state.copyWith(
        conversations: updatedConversations,
        messagesByConversation: {
          ...state.messagesByConversation,
          conversationId: updatedMessages,
        },
      );
    } catch (_) {
      // Non-blocking: keep UI responsive even if read receipt fails.
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  bool _isUnauthorizedError(Object error) {
    if (error is DioException) {
      return error.response?.statusCode == 401;
    }
    return error.toString().contains('401');
  }

  List<ConversationModel> _upsertConversation(
    List<ConversationModel> current,
    ConversationModel incoming,
  ) {
    final idx = current.indexWhere((c) => c.id == incoming.id);
    if (idx == -1) {
      return [incoming, ...current];
    }
    final updated = [...current];
    updated[idx] = incoming;
    return updated;
  }

  void _onSocketNewMessage(Map<String, dynamic> payload) {
    final message = MessageModel.fromJson(payload);

    if (message.id.isEmpty || message.conversationId.isEmpty) {
      return;
    }

    final currentMessages = state.messagesFor(message.conversationId);
    final messageExists = currentMessages.any((m) => m.id == message.id);

    if (!messageExists) {
      state = state.copyWith(
        messagesByConversation: {
          ...state.messagesByConversation,
          message.conversationId: [...currentMessages, message],
        },
      );
    }

    _applyConversationPreview(message);

    final isActiveConversation =
        state.activeConversationId == message.conversationId;
    if (isActiveConversation && message.senderId != _currentUserId) {
      unawaited(markAsRead(message.conversationId));
    }

    if (state.conversations.every((c) => c.id != message.conversationId)) {
      unawaited(loadConversations());
    }
  }

  void _onSocketMessagesRead(Map<String, dynamic> payload) {
    final conversationId = payload['conversationId']?.toString();
    final readerUserId = payload['userId']?.toString();
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }

    if (readerUserId == _currentUserId) {
      final updatedConversations = state.conversations.map((c) {
        if (c.id != conversationId) return c;
        return ConversationModel(
          id: c.id,
          participantId: c.participantId,
          participantName: c.participantName,
          participantAvatarUrl: c.participantAvatarUrl,
          participantRole: c.participantRole,
          participantIsAvailable: c.participantIsAvailable,
          lastMessage: c.lastMessage,
          lastMessageAt: c.lastMessageAt,
          unreadCount: 0,
        );
      }).toList();
      state = state.copyWith(conversations: updatedConversations);
    }
  }

  void _applyConversationPreview(MessageModel message) {
    final updated = state.conversations.map((c) {
      if (c.id != message.conversationId) return c;

      final shouldIncrementUnread =
          message.senderId != _currentUserId &&
          state.activeConversationId != message.conversationId;

      return ConversationModel(
        id: c.id,
        participantId: c.participantId,
        participantName: c.participantName,
        participantAvatarUrl: c.participantAvatarUrl,
        participantRole: c.participantRole,
        participantIsAvailable: c.participantIsAvailable,
        lastMessage: message.content,
        lastMessageAt: message.createdAt,
        unreadCount: shouldIncrementUnread ? c.unreadCount + 1 : c.unreadCount,
      );
    }).toList();

    state = state.copyWith(conversations: updated);
  }

  void _onSocketParticipantAvailabilityUpdated(Map<String, dynamic> payload) {
    final participantId = payload['participantId']?.toString();
    if (participantId == null || participantId.isEmpty) {
      return;
    }

    final availabilityRaw = payload['participantIsAvailable'];
    bool? isAvailable;
    if (availabilityRaw is bool) {
      isAvailable = availabilityRaw;
    } else if (availabilityRaw is String) {
      if (availabilityRaw == 'true') {
        isAvailable = true;
      } else if (availabilityRaw == 'false') {
        isAvailable = false;
      }
    }

    if (isAvailable == null) {
      return;
    }

    final updatedConversations = state.conversations.map((c) {
      if (c.participantId != participantId) {
        return c;
      }

      return ConversationModel(
        id: c.id,
        participantId: c.participantId,
        participantName: c.participantName,
        participantAvatarUrl: c.participantAvatarUrl,
        participantRole: c.participantRole,
        participantIsAvailable: isAvailable,
        lastMessage: c.lastMessage,
        lastMessageAt: c.lastMessageAt,
        unreadCount: c.unreadCount,
      );
    }).toList();

    state = state.copyWith(conversations: updatedConversations);
  }
}
