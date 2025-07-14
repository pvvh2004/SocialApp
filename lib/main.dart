import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ticket_app/home_wrapper.dart';
import 'login_page.dart';
import 'bottom_nav_test.dart';
import 'socket_service.dart'; // 👈 Thêm import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasLogin = prefs.containsKey('customerId');
  final userId = prefs.getString('customerId');

  runApp(MyApp(hasLogin: hasLogin, userId: userId));
}

class MyApp extends StatelessWidget {
  final bool hasLogin;
  final String? userId;

  const MyApp({super.key, required this.hasLogin, required this.userId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: hasLogin
          ? HomeWrapper(userId: userId!) 
          : const LoginPage(),
    );
  }
}
