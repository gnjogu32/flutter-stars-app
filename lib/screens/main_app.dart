import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../utils/auth_guard.dart';
import 'home_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'trending_screen.dart';
import 'reels_screen.dart';

class MainApp extends StatefulWidget {
  final int initialIndex;
  const MainApp({super.key, this.initialIndex = 0});

  static MainAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainAppState>();

  @override
  State<MainApp> createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  late int _selectedIndex;
  late final List<Widget> _screens;
  final ValueNotifier<bool> _reelsTabActive = ValueNotifier(false);
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  final GlobalKey<ReelsScreenState> _reelsKey = GlobalKey<ReelsScreenState>();

  void setSelectedIndex(int index, {bool refresh = false}) {
    final wasReels = _selectedIndex == 1;
    _reelsTabActive.value = index == 1;
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1 && (refresh || wasReels)) {
      _reelsKey.currentState?.refreshReels();
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    final currentUser = FirebaseAuth.instance.currentUser;

    // Debug authentication state
    if (currentUser != null) {
      debugPrint('✅ User authenticated: ${currentUser.uid}');
      debugPrint('   Email: ${currentUser.email}');
      debugPrint('   Display Name: ${currentUser.displayName}');
    } else {
      debugPrint('❌ No user authenticated');
    }

    _screens = [
      const HomeScreen(),
      ReelsScreen(key: _reelsKey, tabActiveNotifier: _reelsTabActive),
      const DiscoverScreen(),
      const MessagesScreen(),
      const NotificationsScreen(),
      ProfileScreen(userId: currentUser?.uid ?? ''),
    ];
  }

  @override
  void dispose() {
    _reelsTabActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const TrendingScreen()),
          );
        },
        child: const Icon(Icons.trending_up),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) async {
          // Protected tabs: Messages(3), Notifications(4), Profile(5)
          const protectedTabs = {3, 4, 5};
          final currentUser = FirebaseAuth.instance.currentUser;
          if (protectedTabs.contains(index) && currentUser == null) {
            await AuthGuard.show(context);
            return;
          }
          setSelectedIndex(index);
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            label: 'Reels',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: FirebaseAuth.instance.currentUser != null
                  ? _chatService.getUnreadMessageCountStream(
                      FirebaseAuth.instance.currentUser!.uid,
                    )
                  : Stream.value(0),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.mail),
                );
              },
            ),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<int>(
              stream: FirebaseAuth.instance.currentUser != null
                  ? _notificationService.getUnreadCountStream(
                      FirebaseAuth.instance.currentUser!.uid,
                    )
                  : Stream.value(0),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.notifications),
                );
              },
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
