import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../widgets/post_widget.dart';
import '../widgets/trending_section.dart';
import '../widgets/author_profile_avatar.dart';

class HomeScreen extends StatefulWidget {
  final ValueNotifier<bool>? tabActiveNotifier;
  const HomeScreen({super.key, this.tabActiveNotifier});

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
  bool _isTabVisible = true;

  @override
  void initState() {
    super.initState();
    _isTabVisible = widget.tabActiveNotifier?.value ?? true;
    widget.tabActiveNotifier?.addListener(_onTabActiveChanged);
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  void _onTabActiveChanged() {
    if (mounted) {
      setState(() {
        _isTabVisible = widget.tabActiveNotifier!.value;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 1000) {
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
          .limit(25);

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
            _hasMore = snapshot.docs.length >= 25;
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
    widget.tabActiveNotifier?.removeListener(_onTabActiveChanged);
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
    try {
      final Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(15);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        final newPosts = snapshot.docs
            .map((doc) => PostModel.fromFirestoreDoc(doc))
            .toList();

        if (mounted) {
          setState(() {
            _posts.clear();
            _posts.addAll(newPosts);
            _lastDocument = snapshot.docs.last;
            _hasMore = snapshot.docs.length >= 15;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
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
            floating: true,
            snap: true,
            elevation: 0,
          ),
        ],
        body: RefreshIndicator(
          key: _refreshKey,
          onRefresh: _refresh,
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('users')
                .doc(_auth.currentUser?.uid ?? 'guest')
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                debugPrint('User snapshot error: ${userSnapshot.error}');
              }

              final List<String> mutedPosts;
              final List<String> mutedAuthors;
              final List<String> blockedUsers;
              final bool autoPlayEnabled;

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
                autoPlayEnabled = userData['autoPlayEnabled'] ?? true;
              } else {
                mutedPosts = [];
                mutedAuthors = [];
                blockedUsers = [];
                autoPlayEnabled = true;
              }

              final filteredPosts = _posts.where((post) {
                return !mutedPosts.contains(post.postId) &&
                    !mutedAuthors.contains(post.authorId) &&
                    !blockedUsers.contains(post.authorId);
              }).toList();

              if (filteredPosts.isEmpty) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
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
                // ignore: deprecated_member_use
                cacheExtent: 3000.0, // Increased for smoother scrolling
                itemCount: filteredPosts.length + 1 + (_hasMore ? 1 : 0),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                addAutomaticKeepAlives: true,
                addRepaintBoundaries: true,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return TrendingStreamSection(
                      currentUserId: _auth.currentUser?.uid ?? '',
                      autoPlayEnabled: autoPlayEnabled,
                      isTabVisible: _isTabVisible,
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
                    isTabVisible: _isTabVisible,
                    autoPlayEnabled: autoPlayEnabled,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
