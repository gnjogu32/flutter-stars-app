import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../widgets/search_overlay.dart';
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
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  Stream<QuerySnapshot>? _postsStream;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon.png', height: 28, width: 28),
            const SizedBox(width: 8),
            const Text('Starpage', style: TextStyle(fontWeight: FontWeight.bold)),
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
                return ListView.builder(
                  itemCount: posts.length + 1, // +1 for trending section
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return TrendingStreamSection(
                        currentUserId: _auth.currentUser?.uid ?? '',
                      );
                    }
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
          if (_showSearch)
            SearchOverlay(onClose: () => setState(() => _showSearch = false)),
        ],
      ),
    );
  }
}
