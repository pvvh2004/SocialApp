import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String id;
  final String name;
  final String username;
  final String avatar;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'],
      name: json['name'],
      username: json['username'],
      avatar: json['avatar'] ?? '',
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String? customerId;

  final String baseUrl =
      'https://dhkptsocial-8d3v.onrender.com'; 
  List<UserModel> randomUsers = [];
  List<UserModel> mayKnowUsers = [];
  List<UserModel> searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadCustomerId();
  }
  Future<void> logout(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('customerId'); 
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginPage()),
    (route) => false,
  );
}
  Future<void> _loadCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    customerId = prefs.getString('customerId');

    if (customerId != null) {
      fetchSuggestions();
    } else {
      print("Chưa đăng nhập hoặc chưa lưu customerId");
    }
  }
  Future<void> fetchSuggestions() async {
    try {
      final randomRes = await http
          .get(Uri.parse('$baseUrl/search/random?userId=$customerId'));
      final mayKnowRes = await http
          .get(Uri.parse('$baseUrl/search/may-know?userId=$customerId'));

      if (randomRes.statusCode == 200 && mayKnowRes.statusCode == 200) {
        setState(() {
          randomUsers = (jsonDecode(randomRes.body)['data'] as List)
              .map((u) => UserModel.fromJson(u))
              .toList();
          mayKnowUsers = (jsonDecode(mayKnowRes.body)['data'] as List)
              .map((u) => UserModel.fromJson(u))
              .toList();
        });
      }
    } catch (e) {
      print("Lỗi fetch đề xuất: $e");
    }
  }

  Future<void> handleSearch(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    try {
      final res = await http.get(
          Uri.parse('$baseUrl/search/users?query=$keyword&userId=$customerId'));
      if (res.statusCode == 200) {
        setState(() {
          searchResults = (jsonDecode(res.body)['data'] as List)
              .map((u) => UserModel.fromJson(u))
              .toList();
        });
      }
    } catch (e) {
      print("Lỗi tìm kiếm: $e");
    }
  }

  Widget buildUserList(List<UserModel> users) {
    return ListView.builder(
      itemCount: users.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, index) {
        final user = users[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            onTap: () {
              print("Xem chi tiết user: ${user.id}");
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: user.avatar.isNotEmpty
                      ? NetworkImage('$baseUrl/files/download/${user.avatar}')
                      : const AssetImage('assets/naruto.jpg') as ImageProvider,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 7, 7, 7))),
                    const SizedBox(height: 4),
                    Text(user.username,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7893FF),
  title: const Text(
    'Tìm kiếm',
    style: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),
  actions: [
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () => logout(context),
    ),
  ],
  elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ĐÃ XOÁ Text("Tìm kiếm") ở đây
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: handleSearch,
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                decoration: InputDecoration(
                  hintText: 'Nhập thông tin tìm kiếm',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF0F4FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
              ),
              const SizedBox(height: 30),
              if (!isSearching) ...[
                const Text('Đề xuất',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 0, 0))),
                const SizedBox(height: 8),
                buildUserList(randomUsers),
                const SizedBox(height: 24),
                const Text('Những người bạn có thể biết',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 0, 0))),
                const SizedBox(height: 8),
                buildUserList(mayKnowUsers),
              ] else ...[
                const Text('Kết quả tìm kiếm',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 8),
                searchResults.isNotEmpty
                    ? buildUserList(searchResults)
                    : const Text("Không tìm thấy kết quả",
                        style: TextStyle(color: Colors.grey)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
