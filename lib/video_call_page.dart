import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String appId =
    '2c172bbcc1fb4ce4bcc95c6fc106e9b8'; // 👈 Thay bằng App ID thật
const String channelName = 'video_channel'; // hoặc dynamic theo user ID
const String? token = null; // Nếu không dùng token thì để null

class VideoCallPage extends StatefulWidget {
  final String userId;
  final String peerId;
  final String channelName;
  final int uid; // 👈 thêm
  const VideoCallPage({
    super.key,
    required this.userId,
    required this.peerId,
    required this.channelName,
    required this.uid,
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final String baseUrl = 'https://dhkptsocial-8d3v.onrender.com';
  late RtcEngine _engine;
  int? _remoteUid;
  bool _isReady = false; // ✅ Thêm biến này

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<String> fetchAgoraToken(String channelName, int uid) async {
    final uri =
        Uri.parse('$baseUrl/agora/token?channelName=$channelName&uid=$uid');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['token'];
    } else {
      throw Exception('Lỗi khi lấy token từ server');
    }
  }

  Future<void> initAgora() async {
    debugPrint('[CALL] Bắt đầu xin quyền camera/mic');
    await [Permission.camera, Permission.microphone].request();
    debugPrint('[CALL] Đã xin quyền xong');

    _engine = createAgoraRtcEngine();
    debugPrint('[CALL] Đã tạo engine');

    await _engine.initialize(RtcEngineContext(appId: appId));
    debugPrint('[CALL] Đã initialize engine');

    await _engine.enableVideo();
    debugPrint('[CALL] Đã enableVideo');

    await _engine.enableLocalVideo(true);
    debugPrint('[CALL] Đã enableLocalVideo');

    await _engine.startPreview();
    debugPrint('[CALL] Đã startPreview');

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (conn, remoteUid, elapsed) {
          debugPrint('[CALL] onUserJoined: $remoteUid');
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (conn, remoteUid, reason) {
          debugPrint('[CALL] onUserOffline: $remoteUid');
          setState(() {
            _remoteUid = null;
          });
        },
        onError: (err, msg) {
          debugPrint('[CALL] Agora error: $err, $msg');
        },
        onJoinChannelSuccess: (conn, uid) {
          debugPrint('[CALL] JoinChannelSuccess: $uid');
        },
      ),
    );

    final int uid = widget.uid;
    final agoraToken = await fetchAgoraToken(widget.channelName, uid);
    await _engine.joinChannel(
      token: agoraToken,
      channelId: widget.channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
    debugPrint('[CALL] Đã joinChannel');
    debugPrint(
        '[CALL] Chuẩn bị joinChannel với UID: ${generateUid(widget.userId)}');

    setState(() {
      _isReady = true;
    });
    debugPrint('[CALL] _isReady = true');
  }

  int generateUid(String userId) {
  // In để chắc chắn giá trị đúng!
  print('🧾 generateUid from: $userId');
  if (userId == '67e668e065abde6d8d9b7350') return 1; // máy gọi
  if (userId == '6785fc7b76300153dc080776') return 2; // máy nhận
  return 999; 
}

  @override
  void dispose() {
    if (_isReady) {
      _engine.leaveChannel();
      _engine.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Video Call')),
      body: Stack(
        children: [
          Center(
            child: _remoteUid == null
                ? const Text('Chờ người kia tham gia...')
                : AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: _remoteUid), 
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: SizedBox(
              width: 120,
              height: 160,
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine,
                  canvas:
                      VideoCanvas(uid: generateUid(widget.userId)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
