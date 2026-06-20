import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../widgets/search_overlay.dart';
import '../widgets/post_widget.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/trending_section.dart';
import '../widgets/author_profile_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  Stream<QuerySnapshot>? _postsStream;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _postsStream = _buildPostsStream();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
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
        leading: const AuthorProfileAvatar(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon.png', height: 28, width: 28),
            const SizedBox(width: 8),
            const Text(
              'Starpage',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              setState(() => _showSearch = true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Post',
            onPressed: () {
              Navigator.of(context).pushNamed('/create-post');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
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
                      (doc) => PostModel.fromJson(
                        doc.data() as Map<String, dynamic>,
                      ),
                    )
                    .toList();

                return StreamBuilder<DocumentSnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.uid ?? 'guest')
                      .snapshots(),
                  builder: (context, userSnapshot) {
                    List<String> mutedPosts = [];
                    List<String> mutedAuthors = [];
                    List<String> blockedUsers = [];

                    if (userSnapshot.hasData && userSnapshot.data!.exists) {
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      mutedPosts = List<String>.from(
                        userData['mutedPosts'] ?? [],
                      );
                      mutedAuthors = List<String>.from(
                        userData['mutedAuthors'] ?? [],
                      );
                      blockedUsers = List<String>.from(
                        userData['blockedUsers'] ?? [],
                      );
                    }

                    final filteredPosts = posts.where((post) {
                      return !mutedPosts.contains(post.postId) &&
                          !mutedAuthors.contains(post.authorId) &&
                          !blockedUsers.contains(post.authorId);
                    }).toList();

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          filteredPosts.length + 1, // +1 for trending section
                      physics: const ClampingScrollPhysics(),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return TrendingStreamSection(
                            currentUserId: _auth.currentUser?.uid ?? '',
                          );
                        }
                        final postIndex = index - 1;
                        return PostWidget(
                          key: ValueKey(filteredPosts[postIndex].postId),
                          post: filteredPosts[postIndex],
                          currentUserId: _auth.currentUser?.uid ?? '',
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_showSearch)
            SearchOverlay(onClose: () => setState(() => _showSearch = false)),
        ],
      ),
    );
  }
}
