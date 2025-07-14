// lib/services/socket_service.dart
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../video_call_page.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  String? currentUserId;
  final String baseUrl = 'http://10.21.8.109:1324';

  void init(String userId, BuildContext context) {
    if (socket != null && socket!.connected) return;

    currentUserId = userId;
    socket = IO.io(baseUrl, {
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
    });

    socket!.onConnect((_) {
      debugPrint("✅ SocketService connected");
      socket!.emit('join', userId);
    });

    socket!.on('inviteVideoCall', (data) {
      final from = data['from'];
      final to = data['to'];
      final channel = data['channel'];

      if (to == currentUserId) {
        debugPrint('📞 [GLOBAL] Nhận cuộc gọi từ $from (channel: $channel)');

        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => VideoCallPage(
              userId: userId,
              peerId: from,
              channelName: channel,
              uid: data['calleeUid'] ?? 2, 
            ),
          ),
        );
      }
    });

    socket!.onDisconnect((_) => debugPrint("❌ Socket disconnected"));
    socket!.onError((e) => debugPrint("❌ Socket error: $e"));

    socket!.connect();
  }

  IO.Socket? getSocket() => socket;

  void dispose() {
    socket?.disconnect();
    socket?.clearListeners();
    socket = null;
  }
}
