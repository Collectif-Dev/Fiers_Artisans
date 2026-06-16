import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../core/storage/secure_storage.dart';

class MapVisibilityRealtimeService {
  static final MapVisibilityRealtimeService _instance =
      MapVisibilityRealtimeService._internal();

  factory MapVisibilityRealtimeService() => _instance;

  MapVisibilityRealtimeService._internal();

  io.Socket? _socket;
  String? _joinedCategoryId;
  String? _joinedSubcategoryId;

  final _visibilityController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get visibilityUpdates =>
      _visibilityController.stream;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    if (isConnected) {
      return;
    }

    final token = await SecureStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      debugPrint('[MapRealtime] missing access token, socket not connected');
      return;
    }

    final socket = io.io(
      '${AppConfig.wsBaseUrl}/ws/map-visibility',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders(<String, String>{
            'Authorization': 'Bearer $token',
          })
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket = socket;

    socket.onConnect((_) {
      debugPrint('[MapRealtime] connected');
      _syncRooms();
    });

    socket.onDisconnect((_) {
      debugPrint('[MapRealtime] disconnected');
    });

    socket.onConnectError((err) {
      debugPrint('[MapRealtime] connect error: $err');
    });

    socket.onError((err) {
      debugPrint('[MapRealtime] socket error: $err');
    });

    socket.on('artisanVisibilityUpdated', (payload) {
      final parsed = _toMap(payload);
      if (parsed.isNotEmpty) {
        _visibilityController.add(parsed);
      }
    });
  }

  void updateFilterRooms({String? categoryId, String? subcategoryId}) {
    final hadCategory = _joinedCategoryId != null;
    final hadSubcategory = _joinedSubcategoryId != null;

    if (hadCategory && _joinedCategoryId != categoryId) {
      _socket?.emit('leaveCategoryRoom', <String, dynamic>{
        'categoryId': _joinedCategoryId,
      });
    }

    if (hadSubcategory && _joinedSubcategoryId != subcategoryId) {
      _socket?.emit('leaveCategoryRoom', <String, dynamic>{
        'subcategoryId': _joinedSubcategoryId,
      });
    }

    _joinedCategoryId = categoryId;
    _joinedSubcategoryId = subcategoryId;

    _syncRooms();
  }

  void _syncRooms() {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return;
    }

    socket.emit('joinCategoryRoom', <String, dynamic>{
      if (_joinedCategoryId != null) 'categoryId': _joinedCategoryId,
      if (_joinedSubcategoryId != null) 'subcategoryId': _joinedSubcategoryId,
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket?.disconnect();
    _socket = null;
    _joinedCategoryId = null;
    _joinedSubcategoryId = null;
  }

  Map<String, dynamic> _toMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) {
      return payload.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
