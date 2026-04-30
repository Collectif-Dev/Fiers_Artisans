import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../core/storage/secure_storage.dart';

class ChatRealtimeService {
  static final ChatRealtimeService _instance = ChatRealtimeService._internal();

  factory ChatRealtimeService() => _instance;

  ChatRealtimeService._internal();

  io.Socket? _socket;
  String? _connectedUserId;
  final Set<String> _joinedConversationIds = <String>{};

  final _newMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _messagesReadController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _participantAvailabilityController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _domainEventController =
      StreamController<ChatRealtimeEvent>.broadcast();

  Stream<Map<String, dynamic>> get newMessages => _newMessageController.stream;
  Stream<Map<String, dynamic>> get messagesRead =>
      _messagesReadController.stream;
  Stream<Map<String, dynamic>> get participantAvailabilityUpdates =>
      _participantAvailabilityController.stream;
  Stream<ChatRealtimeEvent> get domainEvents => _domainEventController.stream;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect({required String userId}) async {
    if (_connectedUserId == userId && isConnected) {
      return;
    }

    if (_connectedUserId != userId) {
      disconnect();
    }

    final token = await SecureStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      debugPrint('[ChatRealtime] missing access token, socket not connected');
      return;
    }

    final socket = io.io(
      '${AppConfig.wsBaseUrl}/ws/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders(<String, dynamic>{
            'Authorization': 'Bearer $token',
          })
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket = socket;
    _connectedUserId = userId;

    socket.onConnect((_) {
      for (final conversationId in _joinedConversationIds) {
        socket.emit('joinConversation', <String, dynamic>{
          'conversationId': conversationId,
        });
      }
      debugPrint('[ChatRealtime] connected');
    });

    socket.onDisconnect((_) {
      debugPrint('[ChatRealtime] disconnected');
    });

    socket.onConnectError((err) {
      debugPrint('[ChatRealtime] connect error: $err');
    });

    socket.onError((err) {
      debugPrint('[ChatRealtime] socket error: $err');
    });

    socket.on('newMessage', (payload) {
      final parsed = _toMap(payload);
      if (parsed.isNotEmpty) {
        _newMessageController.add(parsed);
      }
    });

    socket.on('messagesRead', (payload) {
      final parsed = _toMap(payload);
      if (parsed.isNotEmpty) {
        _messagesReadController.add(parsed);
      }
    });

    socket.on('participantAvailabilityUpdated', (payload) {
      final parsed = _toMap(payload);
      if (parsed.isNotEmpty) {
        _participantAvailabilityController.add(parsed);
      }
    });

    _bindDomainEvent(socket, 'notificationCreated');
    _bindDomainEvent(socket, 'notificationRead');
    _bindDomainEvent(socket, 'notificationsReadAll');
    _bindDomainEvent(socket, 'userProfileUpdated');
    _bindDomainEvent(socket, 'favoriteStatusUpdated');
    _bindDomainEvent(socket, 'artisanProfileUpdated');
    _bindDomainEvent(socket, 'artisanReviewsUpdated');
    _bindDomainEvent(socket, 'artisanPortfolioUpdated');
    _bindDomainEvent(socket, 'subscriptionStatusUpdated');
    _bindDomainEvent(socket, 'artisanSubscriptionUpdated');
    _bindDomainEvent(socket, 'verificationStatusUpdated');
    _bindDomainEvent(socket, 'manualPaymentUpdated');
  }

  void joinConversation(String conversationId) {
    _joinedConversationIds.add(conversationId);
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('joinConversation', <String, dynamic>{
        'conversationId': conversationId,
      });
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket?.disconnect();
    _socket = null;
    _connectedUserId = null;
    _joinedConversationIds.clear();
  }

  Map<String, dynamic> _toMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) {
      return payload.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  void _bindDomainEvent(io.Socket socket, String eventName) {
    socket.on(eventName, (payload) {
      final parsed = _toMap(payload);
      _domainEventController.add(
        ChatRealtimeEvent(event: eventName, payload: parsed),
      );
    });
  }
}

class ChatRealtimeEvent {
  final String event;
  final Map<String, dynamic> payload;

  const ChatRealtimeEvent({required this.event, required this.payload});
}
