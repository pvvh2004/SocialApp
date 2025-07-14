import 'chat_list_page.dart';
import 'search_page.dart';
import 'package:flutter/material.dart';

class NavigationTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RightBottomVerticalNav();
  }
}

class RightBottomVerticalNav extends StatefulWidget  {
  @override
  _RightBottomVerticalNavState createState() => _RightBottomVerticalNavState();
}

class _RightBottomVerticalNavState extends State<RightBottomVerticalNav> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isExpanded = false;
  
  final List<Widget> _views = [
    SearchPage(),
    ChatListPage(),
  ];

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
      _isExpanded = false;
    });
  }

  Widget _buildNavItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;

    return AnimatedOpacity(
      opacity: _isExpanded ? 1 : 0,
      duration: Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => _onNavTap(index),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFF7893ff) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _views[_selectedIndex], // Gọi view thật
          // Thanh nav bên phải dưới
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AnimatedSize(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isExpanded) _buildNavItem(Icons.search, 0),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFF7893ff),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _isExpanded ? Icons.close : Icons.menu,
                                color: Colors.white,
                              ),
                            ),
                        ),
                         if (_isExpanded) _buildNavItem(Icons.chat, 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
