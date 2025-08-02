// chat_list_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_detail_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final String baseUrl = 'https://dhkptsocial-8d3v.onrender.com';
  String? currentUserId;
  List<dynamic> contacts = [];
  Map<String, dynamic> lastMessages = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('customerId');
    if (id != null) {
      setState(() {
        currentUserId = id;
      });
      fetchContacts();
    }
  }

  Future<void> fetchContacts() async {
    if (currentUserId == null) return;
    final res = await http.get(Uri.parse(
        "$baseUrl/users/mutual-follows?currentUserId=$currentUserId"));
    if (res.statusCode == 200) {
      final users = jsonDecode(res.body);
      setState(() => contacts = users);

      for (var contact in users) {
        final res2 = await http.get(Uri.parse(
            "$baseUrl/messages/lastMessage/$currentUserId/${contact['_id']}"));
        if (res2.statusCode == 200) {
          setState(() {
            lastMessages[contact['_id']] = jsonDecode(res2.body);
          });
        }
      }
    }
  }

  void openChat(BuildContext context, dynamic contact) async {
    setState(() => isLoading = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(contact: contact),
      ),
    );
    await fetchContacts();
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Messenger",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF7893FF),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10.0, horizontal: 20.0),
                  onTap: () => openChat(context, contact),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundImage: contact['avatar'] != null &&
                            contact['avatar'].toString().isNotEmpty
                        ? NetworkImage(
                            "$baseUrl/files/download/${contact['avatar']}")
                        : const AssetImage("assets/image.jpg") as ImageProvider,
                  ),
                  title: Text(contact['name'],
                      style:
                          const TextStyle(color: Colors.black, fontSize: 20)),
                  subtitle: Text(
                    lastMessages[contact['_id']]?['content'] ??
                        'No messages yet',
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
    );
  }
}
