import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/user_service.dart';
import '../utils/auth_guard.dart';
import '../widgets/author_profile_avatar.dart';
import '../widgets/post_widget.dart';
import '../widgets/video_grid_thumbnail.dart';
import 'profile_screen.dart';
import 'hashtag_feed_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _selectedTalentFilter = 'All';
  List<String> _trendingHashtags = [];
  List<PostModel>? _cachedDiscoveryPosts;

  final List<String> talents = [
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
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchFocusNode.addListener(_handleFocusChanged);
    _loadTrendingHashtags();
  }

  Future<void> _loadTrendingHashtags() async {
    try {
      // Basic logic: get unique hashtags from recent posts
      final snapshot = await _firestore.collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      final Set<String> tags = {};
      for (var doc in snapshot.docs) {
        final post = PostModel.fromJson(doc.data());
        tags.addAll(post.hashtags);
      }
      
      if (mounted) {
        setState(() {
          _trendingHashtags = tags.toList().take(10).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading trending hashtags: $e');
    }
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.removeListener(_handleFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            leading: const AuthorProfileAvatar(),
            title: const Text('Discover'),
            centerTitle: true,
            floating: true,
            pinned: true,
            snap: true,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Stars'),
                Tab(text: 'Posts'),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _tabController.index == 0 
                        ? 'Search talented stars...' 
                        : 'Search posts or #hashtags...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                
                // Trending Hashtags
                if (_trendingHashtags.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Text(
                          'Trending Tags',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: _trendingHashtags.map((tag) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ActionChip(
                                label: Text('#$tag'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => HashtagFeedScreen(hashtag: tag),
                                    ),
                                  );
                                },
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                labelStyle: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),

                // Talent Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: talents.map((talent) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(talent),
                          selected: _selectedTalentFilter == talent,
                          onSelected: (selected) {
                            setState(() {
                              _selectedTalentFilter = talent;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUsersList(),
            _buildPostsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    Query query = _firestore.collection('posts');

    // Apply talent filter
    if (_selectedTalentFilter != 'All') {
      query = query.where('talent', isEqualTo: _selectedTalentFilter);
    }
    
    query = query.orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedDiscoveryPosts == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError && _cachedDiscoveryPosts == null) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.hasData) {
          final latestPosts = snapshot.data!.docs
              .map((doc) => PostModel.fromJson(doc.data() as Map<String, dynamic>))
              .toList();

          if (_cachedDiscoveryPosts == null || _cachedDiscoveryPosts!.isEmpty) {
            _cachedDiscoveryPosts = latestPosts;
          } else {
            // Background update: only add truly new items to avoid jumping
            final existingIds = _cachedDiscoveryPosts!.map((p) => p.postId).toSet();
            final newItems = latestPosts.where((p) => !existingIds.contains(p.postId)).toList();
            if (newItems.isNotEmpty) {
              // Add new items but don't re-shuffle current block yet to prevent jumping
              _cachedDiscoveryPosts!.insertAll(0, newItems);
            }
          }
        }

        final filteredPosts = _cachedDiscoveryPosts ?? [];

        var searchedPosts = filteredPosts;

        // Apply search filter (Keyword or Hashtag)
        if (_searchController.text.isNotEmpty) {
          final searchTerm = _searchController.text.toLowerCase();
          searchedPosts = filteredPosts.where((post) {
            final contentMatch = post.content.toLowerCase().contains(searchTerm);
            final hashtagMatch = post.hashtags.any((tag) => tag.contains(searchTerm.replaceAll('#', '')));
            final authorMatch = post.authorName.toLowerCase().contains(searchTerm);
            return contentMatch || hashtagMatch || authorMatch;
          }).toList();
        }

        if (searchedPosts.isEmpty) {
          return const Center(
            child: Text('No posts found matching your search.'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _cachedDiscoveryPosts = null;
            });
            await Future.delayed(const Duration(milliseconds: 400));
          },
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: searchedPosts.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final post = searchedPosts[index];
              return _DiscoveryGridItem(
                post: post,
                allPosts: searchedPosts,
                initialIndex: index,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUsersList() {
    Query query = _firestore.collection('users');

    // Apply talent filter
    if (_selectedTalentFilter != 'All') {
      query = query.where('talent', isEqualTo: _selectedTalentFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No talented stars found in this category.'),
          );
        }

        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

        return StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('users')
              .doc(currentUserId.isEmpty ? 'guest' : currentUserId)
              .snapshots(),
          builder: (context, userSnapshot) {
            List<String> blockedUsers = [];
            List<String> mutedAuthors = [];

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              blockedUsers = List<String>.from(userData['blockedUsers'] ?? []);
              mutedAuthors = List<String>.from(userData['mutedAuthors'] ?? []);
            }

            var users = snapshot.data!.docs
                .map((doc) => UserModel.fromFirestoreDoc(doc))
                .toList();

            // Apply search filter
            if (_searchController.text.isNotEmpty) {
              users = users
                  .where(
                    (user) => user.displayName.toLowerCase().contains(
                      _searchController.text.toLowerCase(),
                    ),
                  )
                  .toList();
            }

            final filteredUsers = users.where((user) {
              return !blockedUsers.contains(user.uid) &&
                  !mutedAuthors.contains(user.uid);
            }).toList();

            if (filteredUsers.isEmpty) {
              return const Center(
                child: Text('No talented stars found in this category.'),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                // The stream handles updates, but we can force a rebuild or just wait
                await Future.delayed(const Duration(milliseconds: 400));
                if (mounted) setState(() {});
              },
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return _buildUserCard(user);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return _UserCard(user: user);
  }
}

class _DiscoveryGridItem extends StatelessWidget {
  final PostModel post;
  final List<PostModel> allPosts;
  final int initialIndex;

  const _DiscoveryGridItem({
    required this.post,
    required this.allPosts,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasVideo = post.videoUrl != null && post.videoUrl!.isNotEmpty;
    final hasImages = post.imageUrls.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => _ImmersiveDiscoveryFeed(
              posts: allPosts,
              initialIndex: initialIndex,
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImages)
            CachedNetworkImage(
              imageUrl: post.imageUrls.first,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
            )
          else if (hasVideo)
            Stack(
              fit: StackFit.expand,
              children: [
                VideoGridThumbnail(videoUrl: post.videoUrl!),
                Container(
                  color: Colors.black26,
                  child: Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 30,
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  post.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          if (hasVideo)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.videocam, color: Colors.white, size: 16),
            ),
          if (post.imageUrls.length > 1)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.copy, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }
}

class _ImmersiveDiscoveryFeed extends StatelessWidget {
  final List<PostModel> posts;
  final int initialIndex;

  const _ImmersiveDiscoveryFeed({
    required this.posts,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: posts.length,
        controller: PageController(initialPage: initialIndex),
        itemBuilder: (context, index) {
          return PostWidget(
            post: posts[index],
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            isImmersive: true,
          );
        },
      ),
    );
  }
}

// ── Per-user card with inline follow state ─────────────────────────────────
class _UserCard extends StatefulWidget {
  final UserModel user;
  const _UserCard({required this.user});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard>
    with AutomaticKeepAliveClientMixin {
  final _auth = FirebaseAuth.instance;
  final _userService = UserService();
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkFollowState();
  }

  Future<void> _checkFollowState() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null || currentUid == widget.user.uid) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      if (doc.exists && mounted) {
        final following = List<String>.from(
          (doc.data()! as Map)['following'] ?? [],
        );
        setState(() => _isFollowing = following.contains(widget.user.uid));
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final currentUid = _auth.currentUser?.uid;
    if (_isFollowLoading) return;
    if (currentUid == null) {
      await AuthGuard.show(context);
      return;
    }
    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        await _userService.unfollowUser(currentUid, widget.user.uid);
      } else {
        await _userService.followUser(currentUid, widget.user.uid);
      }
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _isFollowLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFollowLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUid = _auth.currentUser?.uid;
    final isOwnProfile = currentUid == widget.user.uid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: widget.user.uid),
              ),
            );
          },
          child: CircleAvatar(
            backgroundImage: widget.user.profileImageUrl != null
                ? CachedNetworkImageProvider(widget.user.profileImageUrl!)
                : null,
            child: widget.user.profileImageUrl == null
                ? const Icon(Icons.person)
                : null,
          ),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(userId: widget.user.uid),
                    ),
                  );
                },
                child: Text(
                  widget.user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (!isOwnProfile) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 26,
                child: OutlinedButton(
                  onPressed: _isFollowLoading ? null : _toggleFollow,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: _isFollowing
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade700
                                : Colors.grey.shade400)
                          : Theme.of(context).colorScheme.primary,
                    ),
                    foregroundColor: _isFollowing
                        ? (Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600)
                        : null,
                  ),
                  child: _isFollowLoading
                      ? SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Text(_isFollowing ? 'Following' : 'Follow'),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.user.talent != null) Text(widget.user.talent!),
            if (widget.user.bio != null) Text(widget.user.bio!),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: widget.user.uid),
              ),
            );
          },
          child: const Text('View'),
        ),
      ),
    );
  }
}
