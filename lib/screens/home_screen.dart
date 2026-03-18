import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../services/notification_service.dart';
import 'discover_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import '../widgets/post_widget.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/trending_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  Stream<DocumentSnapshot>? _currentUserStream;
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  Stream<QuerySnapshot>? _postsStream;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _currentUserStream = _firestore.collection('users').doc(uid).snapshots();
    }
    _postsStream = _buildPostsStream();
  }

  Stream<QuerySnapshot> _buildPostsStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _refresh() async {
    setState(() {
      _postsStream = _buildPostsStream();
    });
    // Give the stream a moment to emit its first event
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Starpage'),
        centerTitle: true,
        elevation: 0,
        actions: [
          StreamBuilder<int>(
            stream: _auth.currentUser == null
                ? null
                : _notificationService.getUnreadCountStream(
                    _auth.currentUser!.uid,
                  ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const DiscoverScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.of(context).pushNamed('/edit-profile');
            },
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: _currentUserStream,
            builder: (context, snapshot) {
              String? photoUrl;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                photoUrl = data?['profileImageUrl'] as String?;
              }
              return GestureDetector(
                onTap: () {
                  final currentUserId = _auth.currentUser?.uid;
                  if (currentUserId == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(userId: currentUserId),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    backgroundColor: Colors.grey.shade300,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () {
              // Navigate to create post screen
              Navigator.of(context).pushNamed('/create-post');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refresh,
        child: StreamBuilder<QuerySnapshot>(
          stream: _postsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const PostFeedSkeleton();
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: const Center(
                      child: Text(
                        'No posts yet. Follow talented stars to see their work!',
                      ),
                    ),
                  ),
                ),
              );
            }

            final posts = snapshot.data!.docs
                .map(
                  (doc) =>
                      PostModel.fromJson(doc.data() as Map<String, dynamic>),
                )
                .toList();

            return ListView.builder(
              itemCount: posts.length + 1, // +1 for trending section
              physics: const ClampingScrollPhysics(),
              itemBuilder: (context, index) {
                // Show trending section at the top
                if (index == 0) {
                  return TrendingStreamSection(
                    currentUserId: _auth.currentUser?.uid ?? '',
                  );
                }

                // Adjust index for posts list
                final postIndex = index - 1;
                return PostWidget(
                  key: ValueKey(posts[postIndex].postId),
                  post: posts[postIndex],
                  currentUserId: _auth.currentUser?.uid ?? '',
                );
              },
            );
          },
        ),
      ),
    );
  }
}
