import 'package:flutter/material.dart';
import 'package:ticket_app/bottom_nav_test.dart';
import 'package:ticket_app/socket_service.dart';

class HomeWrapper extends StatefulWidget {
  final String userId;
  const HomeWrapper({super.key, required this.userId});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  @override
  void initState() {
    super.initState();

    // 👇 Gọi init SocketService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SocketService().init(widget.userId, context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return NavigationTest(); // Giao diện chính của bạn
  }
}
