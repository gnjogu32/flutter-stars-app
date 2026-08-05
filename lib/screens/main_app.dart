import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';
import '../utils/auth_guard.dart';
import 'home_screen.dart';
import 'discover_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'reels_screen.dart';

class MainApp extends StatefulWidget {
  final int initialIndex;
  final int initialSubIndex;
  const MainApp({super.key, this.initialIndex = 0, this.initialSubIndex = 0});

  static MainAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainAppState>();

  @override
  State<MainApp> createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  late int _selectedIndex;
  late final List<Widget> _screens;
  final ValueNotifier<bool> _homeTabActive = ValueNotifier(true);
  final ValueNotifier<bool> _reelsTabActive = ValueNotifier(false);
  final ValueNotifier<bool> _discoverTabActive = ValueNotifier(false);
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<ReelsScreenState> _reelsKey = GlobalKey<ReelsScreenState>();

  void setSelectedIndex(int index, {bool refresh = false}) {
    final wasHome = _selectedIndex == 0;
    final wasReels = _selectedIndex == 1;

    if (index == 0 && wasHome && !refresh) {
      _homeKey.currentState?.scrollToTop();
      return;
    }

    _homeTabActive.value = index == 0;
    _reelsTabActive.value = index == 1;
    _discoverTabActive.value = index == 2;
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
    _homeTabActive.value = _selectedIndex == 0;
    _reelsTabActive.value = _selectedIndex == 1;
    _discoverTabActive.value = _selectedIndex == 2;

    _screens = [
      HomeScreen(key: _homeKey, tabActiveNotifier: _homeTabActive),
      ReelsScreen(key: _reelsKey, tabActiveNotifier: _reelsTabActive),
      DiscoverScreen(
        tabActiveNotifier: _discoverTabActive,
        initialTabIndex: widget.initialSubIndex,
      ),
      const MessagesScreen(),
      const NotificationsScreen(),
    ];
  }

  @override
  void dispose() {
    _homeTabActive.dispose();
    _reelsTabActive.dispose();
    _discoverTabActive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 0.0),
        child: SizedBox(
          height: 65,
          width: 65,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/create-post');
            },
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            elevation: 4,
            child: const Icon(Icons.add, size: 35),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) async {
          // Protected tabs: Messages(3), Notifications(4)
          const protectedTabs = {3, 4};
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
            label: 'View stars short videos(Vistas)',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
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
        ],
      ),
    );
  }
}
