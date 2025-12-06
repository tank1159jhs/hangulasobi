import 'package:flutter/material.dart';
import 'beginner/beginner_screen.dart';
import 'intermediate/intermediate_screen.dart';
import 'advanced/advanced_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const BeginnerScreen(), // 초급 - 인형뽑기
    const IntermediateScreen(), // 중급 - 단어비
    const AdvancedScreen(), // 고급 - 컨베이어벨트
  ];

  final List<Color> _tabColors = [
    Colors.pink.shade100, // 초급 - 파스텔 핑크
    Colors.blue.shade100, // 중급 - 파스텔 블루
    Colors.purple.shade100, // 고급 - 파스텔 퍼플
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tabColors[_currentIndex],
      body: SafeArea(
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          selectedItemColor: _getSelectedColor(_currentIndex),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.toys),
              label: '初級',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.games),
              label: '中級',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events),
              label: '上級',
            ),
          ],
        ),
      ),
    );
  }

  Color _getSelectedColor(int index) {
    switch (index) {
      case 0:
        return Colors.pink.shade300;
      case 1:
        return Colors.blue.shade300;
      case 2:
        return Colors.purple.shade300;
      default:
        return Colors.pink.shade300;
    }
  }
}
