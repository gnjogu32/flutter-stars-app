import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../widgets/search_overlay.dart';
import '../widgets/post_widget.dart';
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

  final List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 600) {
      _loadPosts();
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(15);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        final newPosts = snapshot.docs
            .map((doc) => PostModel.fromFirestoreDoc(doc))
            .toList();

        if (mounted) {
          setState(() {
            _posts.addAll(newPosts);
            _lastDocument = snapshot.docs.last;
            _hasMore = snapshot.docs.length >= 15;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadPosts();
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
            child: _posts.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<DocumentSnapshot>(
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
                  mutedPosts = List<String>.from(userData['mutedPosts'] ?? []);
                  mutedAuthors = List<String>.from(
                    userData['mutedAuthors'] ?? [],
                  );
                  blockedUsers = List<String>.from(
                    userData['blockedUsers'] ?? [],
                  );
                }

                final filteredPosts = _posts.where((post) {
                  return !mutedPosts.contains(post.postId) &&
                      !mutedAuthors.contains(post.authorId) &&
                      !blockedUsers.contains(post.authorId);
                }).toList();

                if (filteredPosts.isEmpty && !_isLoading) {
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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

                return ListView.builder(
                  controller: _scrollController,
                  // ignore: deprecated_member_use
                  cacheExtent: 2000.0, // Aggressive caching to remove blank screens
                  itemCount:
                      filteredPosts.length + 1 + (_hasMore ? 1 : 0),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return TrendingStreamSection(
                        currentUserId: _auth.currentUser?.uid ?? '',
                      );
                    }

                    final postIndex = index - 1;

                    if (postIndex == filteredPosts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return PostWidget(
                      key: ValueKey(filteredPosts[postIndex].postId),
                      post: filteredPosts[postIndex],
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
