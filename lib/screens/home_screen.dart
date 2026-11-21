import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../widgets/post_widget.dart';
import '../widgets/post_skeleton.dart';
import '../widgets/trending_section.dart';
import '../widgets/author_profile_avatar.dart';
import '../widgets/search_lens_overlay.dart';

class HomeScreen extends StatefulWidget {
  final ValueNotifier<bool>? tabActiveNotifier;
  const HomeScreen({super.key, this.tabActiveNotifier});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  late final TabController _tabController;

  final List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  bool _isTabVisible = true;
  String _selectedTalentCategory = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
    _tabController.dispose();
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
      final query = _firestore
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

  List<PostModel> _getForYouPosts(
    List<String> mutedPosts,
    List<String> mutedAuthors,
    List<String> blockedUsers,
    List<String> following,
    String currentUserId,
  ) {
    return _posts.where((post) {
      final isMuted =
          mutedPosts.contains(post.postId) ||
          mutedAuthors.contains(post.authorId) ||
          blockedUsers.contains(post.authorId);
      if (isMuted) return false;

      if (post.visibility == 'followers') {
        final isAuthor = post.authorId == currentUserId;
        final isFollowing = following.contains(post.authorId);
        return isAuthor || isFollowing;
      }

      return true;
    }).toList();
  }

  List<PostModel> _getFollowingPosts(
    List<String> mutedPosts,
    List<String> mutedAuthors,
    List<String> blockedUsers,
    List<String> following,
    String currentUserId,
  ) {
    return _posts.where((post) {
      final isMuted =
          mutedPosts.contains(post.postId) ||
          mutedAuthors.contains(post.authorId) ||
          blockedUsers.contains(post.authorId);
      if (isMuted) return false;

      final isAuthor = post.authorId == currentUserId;
      final isFollowing = following.contains(post.authorId);
      return isAuthor || isFollowing;
    }).toList();
  }

  List<PostModel> _getTrendingPosts(
    List<String> mutedPosts,
    List<String> mutedAuthors,
    List<String> blockedUsers,
    List<String> following,
    String currentUserId,
  ) {
    final list = _getForYouPosts(
      mutedPosts,
      mutedAuthors,
      blockedUsers,
      following,
      currentUserId,
    );
    list.sort((a, b) {
      final scoreA = a.likeCount * 2 + a.commentCount * 3 + a.repostCount * 2;
      final scoreB = b.likeCount * 2 + b.commentCount * 3 + b.repostCount * 2;
      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Widget _buildPostListView({
    required List<PostModel> posts,
    required String currentUserId,
    required bool autoPlayEnabled,
    bool showTrendingHeader = false,
    String emptyMessage = 'No posts yet. Follow talented stars to see their work!',
  }) {
    if (posts.isEmpty) {
      if (_isLoading) {
        return const PostFeedSkeleton(count: 3);
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final headerCount = showTrendingHeader ? 1 : 0;

    return RefreshIndicator(
      key: showTrendingHeader ? _refreshKey : null,
      onRefresh: _refresh,
      child: ListView.builder(
        scrollCacheExtent: const ScrollCacheExtent.pixels(3500.0),
        itemCount: posts.length + headerCount + (_hasMore ? 1 : 0),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          if (showTrendingHeader && index == 0) {
            return TrendingStreamSection(
              currentUserId: currentUserId,
              autoPlayEnabled: autoPlayEnabled,
              isTabVisible: _isTabVisible,
            );
          }

          final postIndex = index - headerCount;

          if (postIndex == posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: PostSkeleton(),
            );
          }

          return PostWidget(
            key: ValueKey(posts[postIndex].postId),
            post: posts[postIndex],
            currentUserId: currentUserId,
            isTabVisible: _isTabVisible,
            autoPlayEnabled: autoPlayEnabled,
          );
        },
      ),
    );
  }

  Widget _buildDiscoverTab({
    required List<PostModel> posts,
    required String currentUserId,
    required bool autoPlayEnabled,
  }) {
    final filteredPosts = _selectedTalentCategory == 'All'
        ? posts
        : posts.where((p) => p.talent == _selectedTalentCategory).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'All',
                'Art',
                'Music',
                'Writing',
                'Dance',
                'Photography',
                'Fashion',
                'Comedy',
                'Acting',
                'Sports',
                'Gaming',
              ].map((talent) {
                final isSelected = _selectedTalentCategory == talent;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    label: Text(talent, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedTalentCategory = talent;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: _buildPostListView(
            posts: filteredPosts,
            currentUserId: currentUserId,
            autoPlayEnabled: autoPlayEnabled,
            emptyMessage: 'No posts in $_selectedTalentCategory category yet.',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1116) : const Color(0xFFF2F2F7),
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
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search lens suggestions',
                onPressed: () => SearchLensOverlay.show(context),
              ),
            ],
            floating: true,
            snap: true,
            pinned: true,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'For You'),
                Tab(text: 'Following'),
                Tab(text: 'Trending'),
              ],
            ),
          ),
        ],
        body: StreamBuilder<DocumentSnapshot>(
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
            final List<String> following;
            final bool autoPlayEnabled;
            final String currentUserId = _auth.currentUser?.uid ?? 'guest';

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
              following = List<String>.from(userData['following'] ?? []);
              autoPlayEnabled = userData['autoPlayEnabled'] ?? true;
            } else {
              mutedPosts = [];
              mutedAuthors = [];
              blockedUsers = [];
              following = [];
              autoPlayEnabled = true;
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildPostListView(
                  posts: _getForYouPosts(
                    mutedPosts,
                    mutedAuthors,
                    blockedUsers,
                    following,
                    currentUserId,
                  ),
                  currentUserId: currentUserId,
                  autoPlayEnabled: autoPlayEnabled,
                  showTrendingHeader: true,
                ),
                _buildPostListView(
                  posts: _getFollowingPosts(
                    mutedPosts,
                    mutedAuthors,
                    blockedUsers,
                    following,
                    currentUserId,
                  ),
                  currentUserId: currentUserId,
                  autoPlayEnabled: autoPlayEnabled,
                  emptyMessage:
                      'No posts from creators you follow yet.\nFollow talented stars to see their work here!',
                ),
                _buildPostListView(
                  posts: _getTrendingPosts(
                    mutedPosts,
                    mutedAuthors,
                    blockedUsers,
                    following,
                    currentUserId,
                  ),
                  currentUserId: currentUserId,
                  autoPlayEnabled: autoPlayEnabled,
                  emptyMessage: 'No trending posts right now.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
