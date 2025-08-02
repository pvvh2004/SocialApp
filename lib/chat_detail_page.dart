import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ticket_app/socket_service.dart';
import 'package:ticket_app/video_call_page.dart';
import 'package:video_player/video_player.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class ChatDetailPage extends StatefulWidget {
  final dynamic contact;

  const ChatDetailPage({super.key, required this.contact});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  bool showEmoji = false;
  const String baseUrl = 'https://dhkptsocial-8d3v.onrender.com';
  final String baseUrl = 'https://dhkptsocial-8d3v.onrender.com';
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  IO.Socket? socket;
  List<dynamic> messages = [];
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 ChatDetailPage initState() called');
    _loadCurrentUserId();
  }

  @override
  void dispose() {
    try {
      debugPrint('🧹 Disposing socket...');
      socket?.emit('leave', currentUserId);
      debugPrint('📢 emit leave with userId: $currentUserId');
      socket?.clearListeners();
      socket?.disconnect();
      socket?.close();
      socket = null;
    } catch (e) {
      debugPrint("❌ Error in dispose: $e");
    }
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('customerId');
    if (id != null) {
      currentUserId = id;
      initSocket();
      await fetchMessages();
      setState(() {});
    }
  }

  void initSocket() {
    debugPrint('🛠️ initSocket() is called');
    if (socket != null) {
      debugPrint('🔌 Existing socket found, disconnecting...');
      socket!.clearListeners();
      socket!.disconnect();
      socket!.close();
      socket = null;
    }

    socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false, // 👈 quan trọng
      'reconnection': true,
    });

    socket!.onConnect((_) {
      debugPrint("✅ Socket connected: ${socket!.id}");
      socket!.emit('join', currentUserId);
      debugPrint("📢 emit 'join' with userId: $currentUserId");
    });
    socket!.on('inviteVideoCall', (data) async {
      debugPrint(
          '[CALL] Nhận inviteVideoCall: $data, currentUserId: $currentUserId');
      final from = data['from'];
      final to = data['to'];
      final channel = data['channel'];

      if (to == currentUserId) {
        debugPrint('[CALL] Đúng user, hiện dialog nhận cuộc gọi');
        final accept = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cuộc gọi đến'),
            content: Text('Bạn có muốn nhận cuộc gọi video từ $from không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Từ chối'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Nhận'),
              ),
            ],
          ),
        );
        if (accept == true) {
          debugPrint(
              '[CALL] Đã nhận cuộc gọi, join channel: $channel, userId: $currentUserId, peerId: $from');
          final callerUid = data['callerUid'];
          final calleeUid = data['calleeUid'];

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoCallPage(
                userId: currentUserId!,
                peerId: from,
                channelName: channel,
                uid: calleeUid, // 👈 máy nhận dùng uid từ lời mời
              ),
            ),
          );
        } else {
          debugPrint('[CALL] Từ chối cuộc gọi');
        }
      } else {
        debugPrint('[CALL] Không phải user này, bỏ qua');
      }
    });
    socket!.on('newMessage', (msg) {
      debugPrint('📩 Received newMessage: ${jsonEncode(msg)}');

      final isRelevant = (msg['sender'] == currentUserId &&
              msg['receiver'] == widget.contact['_id']) ||
          (msg['receiver'] == currentUserId &&
              msg['sender'] == widget.contact['_id']);

      // ✅ Dùng _id để kiểm tra trùng nếu có
      final isDuplicate =
          msg['_id'] != null && messages.any((m) => m['_id'] == msg['_id']);

      if (isRelevant && !isDuplicate) {
        setState(() {
          messages.add(msg);
        });
        scrollToBottom();
      } else if (isDuplicate) {
        debugPrint('⚠️ Bỏ qua tin nhắn trùng lặp qua socket');
      } else {
        debugPrint('⚠️ Không phải tin nhắn liên quan');
      }
    });

    socket!.onDisconnect((_) => debugPrint("❌ Socket disconnected"));
    socket!.onReconnect((_) => debugPrint("🔁 Reconnected"));
    socket!.onReconnectError((e) => debugPrint("⚠️ Reconnect error: $e"));
    socket!.onError((err) => debugPrint("❌ Socket error: $err"));

    socket!.connect(); // 👈 phải gọi connect() thủ công
  }

  Future<void> fetchMessages() async {
    if (currentUserId == null) return;
    final id = widget.contact['_id'];

    try {
      final res1 =
          await http.get(Uri.parse("$baseUrl/messages/$currentUserId/$id"));
      final res2 =
          await http.get(Uri.parse("$baseUrl/messages/$id/$currentUserId"));

      if (res1.statusCode == 200 && res2.statusCode == 200) {
        final list1 = jsonDecode(res1.body);
        final list2 = jsonDecode(res2.body);

        final combined = [...list1, ...list2];

        // Dùng Map để loại bỏ tin nhắn trùng (dựa trên _id)
        final Map<String, dynamic> uniqueMap = {};

        for (var msg in [...messages, ...combined]) {
          if (msg['_id'] != null) {
            uniqueMap[msg['_id']] = msg; // sẽ override nếu bị trùng
          }
        }

        final deduplicated = uniqueMap.values.toList();

        // Sắp xếp lại theo thời gian
        deduplicated.sort((a, b) => DateTime.parse(a['timestamp'])
            .compareTo(DateTime.parse(b['timestamp'])));

        setState(() => messages = deduplicated);
        scrollToBottom();
      } else {
        debugPrint('❌ Không thể fetch messages');
      }
    } catch (e) {
      debugPrint('❌ Lỗi khi fetch messages: $e');
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  void sendMessage() async {
    if (currentUserId == null) return;
    final content = controller.text.trim();
    if (content.isEmpty) return;
    if (showEmoji) {
      setState(() => showEmoji = false);
    }

    final msg = {
      'sender': currentUserId,
      'receiver': widget.contact['_id'],
      'content': content,
      'type': 'text',
      'timestamp': DateTime.now().toIso8601String(),
    };

    debugPrint("📤 Sending message: ${jsonEncode(msg)}");

    socket?.emit('sendMessage', msg);
    debugPrint("📢 emit 'sendMessage' with: ${jsonEncode(msg)}");
    controller.clear();
  }

  Future<void> pickAndSendMedia({required bool isVideo}) async {
    if (currentUserId == null) return;

    final picker = ImagePicker();
    final XFile? pickedFile = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null && controller.text.trim().isEmpty) return;

    List<Map<String, dynamic>> mediaList = [];

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/files/upload/mess'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        try {
          final fileId = jsonDecode(responseData)['file']['_id'];
          mediaList.add({
            'url': fileId,
            'type': isVideo ? 'video' : 'image',
          });
        } catch (e) {
          debugPrint('❌ Lỗi parse fileId: $e');
          return;
        }
      } else {
        debugPrint('❌ Upload thất bại: ${response.statusCode}');
        return;
      }
    }

    final content = controller.text.trim();
    if (mediaList.isEmpty && content.isEmpty) {
      debugPrint('❗Không có media hoặc text để gửi.');
      return;
    }

    // ✅ Chỉ tạo và gửi sau khi upload xong
    final msg = {
      'sender': currentUserId,
      'receiver': widget.contact['_id'],
      'type': mediaList.isNotEmpty ? mediaList.first['type'] : 'text',
      'content': content,
      'media': mediaList,
      'timestamp': DateTime.now().toIso8601String(),
    };
    controller.clear();
    scrollToBottom();
    socket?.emit('sendMessage', msg);
  }

  Future<void> sendMultipleImages() async {
    if (currentUserId == null) return;
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isEmpty && controller.text.trim().isEmpty) return;

    List<Map<String, dynamic>> mediaList = [];

    for (final picked in pickedFiles) {
      final file = File(picked.path);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/files/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();

        try {
          final fileId = jsonDecode(responseData)['file']['_id'];
          mediaList.add({
            'url': fileId,
            'type': 'image',
          });
        } catch (e) {
          debugPrint('❌ Lỗi upload: $e');
        }
      } else {
        debugPrint('❌ Upload thất bại: ${response.statusCode}');
      }
    }

    // Nếu không có ảnh và cũng không có text thì không gửi
    if (mediaList.isEmpty && controller.text.trim().isEmpty) {
      debugPrint(
          '❗Không có ảnh nào được upload thành công và không có nội dung.');
      return;
    }

    final msg = {
      'sender': currentUserId,
      'receiver': widget.contact['_id'],
      'type': mediaList.isNotEmpty ? 'image' : 'text',
      'content': controller.text.trim(),
      'media': mediaList,
      'timestamp': DateTime.now().toIso8601String(),
    };
    socket?.emit('sendMessage', msg);

    controller.clear();
    scrollToBottom();
  }

  bool shouldShowTimestamp(int index) {
    if (index == 0) return true;

    final prev = DateTime.parse(messages[index - 1]['timestamp']);
    final curr = DateTime.parse(messages[index]['timestamp']);

    // Hiển thị nếu cách nhau hơn 5 phút
    return curr.difference(prev).inMinutes > 5;
  }

  String formatTimestamp(String isoTime) {
    final dt = DateTime.parse(isoTime).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}";
  }

  void checkCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('customerId');
    if (id == null) {
      debugPrint("⚠️ [checkCustomerId] customerId chưa được lưu!");
    } else {
      debugPrint("✅ [checkCustomerId] customerId: $id");
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = widget.contact['avatar'] != null &&
        widget.contact['avatar'].toString().isNotEmpty;
    final contactName = widget.contact['name'] ?? 'Không rõ';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFF7893FF),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.video_call, color: Colors.white),
              onPressed: () {
                if (currentUserId != null) {
                  final channelName =
                      '${currentUserId}_${widget.contact['_id']}';
                  debugPrint(
                      '[CALL] Gửi inviteVideoCall: from=$currentUserId, to=${widget.contact['_id']}, channel=$channelName');
                  final callerUid = 1;
                  final calleeUid = 2;

                  socket?.emit('inviteVideoCall', {
                    'from': currentUserId,
                    'to': widget.contact['_id'],
                    'channel': channelName,
                    'callerUid': callerUid,
                    'calleeUid': calleeUid,
                  });

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoCallPage(
                        userId: currentUserId!,
                        peerId: widget.contact['_id'],
                        channelName: channelName,
                        uid: 1, // 👈 máy gọi luôn là 1
                      ),
                    ),
                  );
                }
              },
            ),
          ],
          title: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: hasAvatar
                    ? NetworkImage(
                        "$baseUrl/files/download/${widget.contact['avatar']}")
                    : const AssetImage("assets/image.jpg") as ImageProvider,
              ),
              const SizedBox(width: 12),
              Text(contactName, style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
      body: currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final msg = messages[index];
                      final isMe = msg['sender'] == currentUserId;
                      final showTime = shouldShowTimestamp(index);
                      final hasText =
                          (msg['content'] ?? '').toString().isNotEmpty;

                      final mediaWidgets = (msg['media'] != null &&
                              msg['media'] is List &&
                              msg['media'].isNotEmpty)
                          ? (msg['media'] as List).map<Widget>((file) {
                              final fileType = file['type'];
                              final fileId = file['url'];
                              final mediaUrl = fileType == 'video'
                                  ? '$baseUrl/files/stream/$fileId'
                                  : '$baseUrl/files/download/$fileId';

                              if (fileType == 'image') {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 200,
                                        maxHeight: 200,
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  FullscreenImagePage(
                                                      imageUrl: mediaUrl),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Image.network(
                                            mediaUrl,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )),
                                );
                              } else if (fileType == 'video') {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 200,
                                      maxHeight: 200,
                                    ),
                                    child: VideoPlayerWidget(url: mediaUrl),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }).toList()
                          : [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                formatTimestamp(msg['timestamp']),
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ),
                          Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (mediaWidgets.isNotEmpty && !hasText)
                                    ...mediaWidgets,
                                  if (hasText)
                                    Container(
                                      margin: const EdgeInsets.only(
                                          top: 4, bottom: 6),
                                      padding: const EdgeInsets.all(10),
                                      constraints:
                                          const BoxConstraints(maxWidth: 300),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? const Color(0xFF007AFF)
                                            : const Color(0xFFE5E5EA),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(18),
                                          topRight: const Radius.circular(18),
                                          bottomLeft:
                                              Radius.circular(isMe ? 18 : 0),
                                          bottomRight:
                                              Radius.circular(isMe ? 0 : 18),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ...mediaWidgets,
                                          Text(
                                            msg['content'],
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      color: Colors.white,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.camera_alt,
                                color: Colors.blue),
                            onPressed: () {
                              // TODO: Mở camera
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.image, color: Colors.blue),
                            onPressed: () => pickAndSendMedia(isVideo: false),
                          ),
                          IconButton(
                            icon: const Icon(Icons.mic, color: Colors.blue),
                            onPressed: () {
                              // TODO: Ghi âm
                            },
                          ),
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F3F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      onTap: () {
                                        if (showEmoji) {
                                          setState(() => showEmoji = false);
                                        }
                                      },
                                      onSubmitted: (_) => sendMessage(),
                                      style:
                                          const TextStyle(color: Colors.black),
                                      decoration: const InputDecoration(
                                        hintText: "Aa",
                                        hintStyle:
                                            TextStyle(color: Colors.grey),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.emoji_emotions,
                                        color: Colors.blue),
                                    onPressed: () {
                                      FocusScope.of(context).unfocus();
                                      setState(() => showEmoji = !showEmoji);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon:
                                const Icon(Icons.thumb_up, color: Colors.blue),
                            onPressed: () {
                              controller.text = '👍';
                              sendMessage();
                            },
                          ),
                        ],
                      ),
                    ),
                    Offstage(
                      offstage: !showEmoji,
                      child: SizedBox(
                        height: 260,
                        child: EmojiPicker(
                          onEmojiSelected: (category, emoji) {
                            controller.text += emoji.emoji;
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                          },
                          config: Config(
                            emojiViewConfig: const EmojiViewConfig(
                              backgroundColor: Color(0xFFF0F0F0),
                              emojiSizeMax: 32,
                              columns: 7,
                              verticalSpacing: 0,
                              horizontalSpacing: 0,
                              recentsLimit: 20,
                              noRecents: Text(
                                'Chưa có emoji nào',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              buttonMode: ButtonMode.MATERIAL,
                            ),
                            categoryViewConfig: const CategoryViewConfig(
                              backgroundColor: Color(0xFFF0F0F0),
                              indicatorColor: Color(0xFF7893FF),
                              iconColor: Colors.grey,
                              iconColorSelected: Color(0xFF7893FF),
                              backspaceColor: Color(0xFF7893FF),
                              initCategory: Category.SMILEYS,
                              tabIndicatorAnimDuration:
                                  Duration(milliseconds: 300),
                            ),
                            skinToneConfig: const SkinToneConfig(
                              dialogBackgroundColor: Colors.white,
                              indicatorColor: Color(0xFF7893FF),
                            ),
                            bottomActionBarConfig: const BottomActionBarConfig(
                              backgroundColor: Color(0xFF7893FF),
                              buttonIconColor: Colors.white,
                            ),
                            searchViewConfig: const SearchViewConfig(
                              backgroundColor: Color(0xFFF0F0F0),
                              buttonIconColor: Colors.black26,
                              hintText: 'Tìm emoji...',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      }).catchError((e) {
        debugPrint('❌ Video init error: $e');
        setState(() => _hasError = true);
      });
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Icon(Icons.error, color: Colors.red);
    }

    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const CircularProgressIndicator();
  }
}

class FullscreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullscreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }
}
