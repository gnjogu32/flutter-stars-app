import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gal/gal.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/chat_service.dart';
import '../services/repost_queue_service.dart';
import '../services/user_service.dart';
import '../widgets/post_widget.dart';
import '../widgets/post_details_sheet.dart';
import 'analytics_dashboard_screen.dart';
import 'chat_screen.dart';
import 'followers_following_screen.dart';
import 'repost_queue_screen.dart';

enum _ProfileMediaFolder { all, photos, videos, saved }

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AnalyticsService _analyticsService = AnalyticsService();
  final ChatService _chatService = ChatService();
  final RepostQueueService _repostQueueService = RepostQueueService();
  final UserService _userService = UserService();
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  bool _isBlocked = false;
  bool _isLoadingBlock = false;
  _ProfileMediaFolder _selectedFolder = _ProfileMediaFolder.all;
  bool _isGridView = true;

  // Cached futures to prevent jumpy UI during rebuilds
  Future<Map<String, dynamic>>? _analyticsFuture;
  Future<Map<String, int>>? _repostStatsFuture;

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _initProfile();
    }
  }

  void _initProfile() {
    final effectiveUserId = widget.userId.isEmpty
        ? (_auth.currentUser?.uid ?? '')
        : widget.userId;

    if (effectiveUserId.isNotEmpty) {
      _checkFollowStatus(effectiveUserId);
      _checkBlockStatus(effectiveUserId);
      _loadSummaries(effectiveUserId);
    }
  }

  Future<void> _checkBlockStatus(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || targetUserId == currentUserId) return;

    try {
      final blocked = await _userService.isUserBlocked(
        currentUserId,
        targetUserId,
      );
      if (mounted) {
        setState(() => _isBlocked = blocked);
      }
    } catch (_) {}
  }

  void _loadSummaries(String userId) {
    _analyticsFuture = _analyticsService.getAuthorSummary(userId);
    _repostStatsFuture = _repostQueueService.getRepostStats(userId);
  }

  Future<void> _checkFollowStatus(String effectiveUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || effectiveUserId == currentUserId) {
      if (mounted) setState(() => _isFollowing = false);
      return;
    }

    try {
      final currentUser = await _userService.getUser(currentUserId);
      if (currentUser != null && mounted) {
        setState(() {
          _isFollowing = currentUser.following.contains(effectiveUserId);
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow(UserModel user) async {
    if (_auth.currentUser?.uid == null) return;
    if (_auth.currentUser!.uid == user.uid) return;

    setState(() {
      _isLoadingFollow = true;
    });

    try {
      if (_isFollowing) {
        await _userService.unfollowUser(_auth.currentUser!.uid, widget.userId);
      } else {
        await _userService.followUser(_auth.currentUser!.uid, widget.userId);
      }

      setState(() {
        _isFollowing = !_isFollowing;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });
      }
    }
  }

  Future<void> _toggleBlock(UserModel user) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId == user.uid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isBlocked ? 'Unblock User' : 'Block User'),
        content: Text(
          _isBlocked
              ? 'Are you sure you want to unblock ${user.displayName}?'
              : 'Are you sure you want to block ${user.displayName}? They will no longer be able to message you or see your notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: _isBlocked ? Colors.blue : Colors.red,
            ),
            child: Text(_isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoadingBlock = true);

    try {
      if (_isBlocked) {
        await _userService.unblockUser(currentUserId, user.uid);
      } else {
        await _userService.blockUser(currentUserId, user.uid);
      }
      if (mounted) {
        setState(() {
          _isBlocked = !_isBlocked;
          if (_isBlocked) _isFollowing = false; // Blocking unfollows
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingBlock = false);
    }
  }

  Future<void> _navigateToChat(UserModel user) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    if (user.uid.isEmpty || user.uid == currentUserId) return;

    if (_isBlocked) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unblock user to message.')));
      return;
    }

    try {
      final conversationId = await _chatService.startConversation(
        currentUserId: currentUserId,
        targetUserId: user.uid,
        targetUserName: user.displayName,
        targetUserImageUrl: user.profileImageUrl,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId,
            otherUserId: user.uid,
            otherUserName: user.displayName,
            otherUserImageUrl: user.profileImageUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
    }
  }

  void _openProfilePhotoViewer(
    String? imageUrl,
    String displayName,
    bool canSaveImage,
  ) {
    if (imageUrl == null || imageUrl.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ProfilePhotoViewer(
          imageUrl: imageUrl,
          displayName: displayName,
          canSaveImage: canSaveImage,
        ),
      ),
    );
  }

  void _openAnalyticsDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AnalyticsDashboardScreen()),
    );
  }

  void _openRepostQueue() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const RepostQueueScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUserId = widget.userId.isEmpty
        ? (_auth.currentUser?.uid ?? '')
        : widget.userId;

    final isOwnProfile = effectiveUserId == _auth.currentUser?.uid;

    if (effectiveUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile'), centerTitle: true),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (isOwnProfile) ...[
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Analytics Dashboard',
              onPressed: _openAnalyticsDashboard,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _showLogoutDialog(context),
            ),
          ] else
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(effectiveUserId)
                  .snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists) {
                  return const SizedBox.shrink();
                }
                final user = UserModel.fromFirestoreDoc(userSnap.data!);
                return PopupMenuButton<String>(
                  enabled: !_isLoadingBlock,
                  onSelected: (val) {
                    if (val == 'block') _toggleBlock(user);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'block',
                      child: _isLoadingBlock
                          ? const Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Text(
                              _isBlocked ? 'Unblock User' : 'Block User',
                              style: TextStyle(
                                color: _isBlocked ? Colors.blue : Colors.red,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(effectiveUserId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting &&
              !userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userSnapshot.hasError ||
              !userSnapshot.hasData ||
              !userSnapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    userSnapshot.hasError
                        ? 'Error: ${userSnapshot.error}'
                        : 'User not found',
                  ),
                ],
              ),
            );
          }

          final user = UserModel.fromFirestoreDoc(userSnapshot.data!);

          return StreamBuilder<QuerySnapshot>(
            stream: _selectedFolder == _ProfileMediaFolder.saved
                ? _firestore
                      .collection('posts')
                      .orderBy('createdAt', descending: true)
                      .snapshots()
                : _firestore
                      .collection('posts')
                      .where('authorId', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
            builder: (context, postsSnapshot) {
              final allPosts =
                  (!postsSnapshot.hasData || postsSnapshot.data!.docs.isEmpty)
                  ? <PostModel>[]
                  : postsSnapshot.data!.docs
                        .map(
                          (doc) => PostModel.fromJson(
                            doc.data() as Map<String, dynamic>,
                          ),
                        )
                        .toList();

              final filteredPosts = allPosts
                  .where(
                    (post) => _matchesSelectedFolder(post, user.savedPosts),
                  )
                  .toList();

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(user, isOwnProfile),
                  ),
                  const SliverToBoxAdapter(child: Divider()),
                  SliverToBoxAdapter(
                    child: _buildFolderSection(
                      isOwnProfile,
                      filteredPosts.length,
                    ),
                  ),
                  if (postsSnapshot.connectionState ==
                          ConnectionState.waiting &&
                      !postsSnapshot.hasData)
                    const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  else if (filteredPosts.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 48,
                        ),
                        child: Center(
                          child: Text(
                            _selectedFolder == _ProfileMediaFolder.all
                                ? 'No posts yet'
                                : 'No ${_selectedFolder.name} posts yet',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else if (_isGridView)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                              childAspectRatio: 1,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildGridPostItem(filteredPosts[index]),
                          childCount: filteredPosts.length,
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => PostWidget(
                          post: filteredPosts[index],
                          currentUserId: _auth.currentUser?.uid ?? '',
                        ),
                        childCount: filteredPosts.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, bool isOwnProfile) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile Image
          GestureDetector(
            onTap: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
                ? null
                : () => _openProfilePhotoViewer(
                    user.profileImageUrl,
                    user.displayName,
                    isOwnProfile,
                  ),
            child: CircleAvatar(
              radius: 50,
              backgroundImage: user.profileImageUrl != null
                  ? CachedNetworkImageProvider(user.profileImageUrl!)
                  : null,
              child: user.profileImageUrl == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            user.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          // Username
          if (user.username != null)
            Text(
              '@${user.username}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
          // Talent
          if (user.talent != null)
            Text(
              user.talent!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          // Bio
          if (user.bio != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                user.bio!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 16),
          // Stats row
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('posts')
                .where('authorId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, postSnapshot) {
              final postCount = postSnapshot.hasData
                  ? postSnapshot.data!.docs.length
                  : 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat(
                    'Posts',
                    postCount,
                    onTap: () {
                      setState(() {
                        _isGridView = false;
                        _selectedFolder = _ProfileMediaFolder.all;
                      });
                    },
                  ),
                  _buildStat(
                    'Followers',
                    user.followerCount,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FollowersFollowingScreen(
                            userId: user.uid,
                            initialTabIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildStat(
                    'Following',
                    user.followingCount,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => FollowersFollowingScreen(
                            userId: user.uid,
                            initialTabIndex: 1,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          if (isOwnProfile) _buildQuickSummaryCards(user.uid),
          const SizedBox(height: 20),
          // Action buttons
          if (isOwnProfile)
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/edit-profile');
                },
                child: const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _isLoadingFollow
                        ? null
                        : () => _toggleFollow(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey[300])
                          : Theme.of(context).colorScheme.primary,
                    ),
                    child: _isLoadingFollow
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isFollowing
                                  ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white70
                                        : Colors.black87)
                                  : Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToChat(user),
                    icon: const Icon(Icons.mail),
                    label: const Text(
                      'Message',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFolderSection(bool isOwnProfile, int visibleCount) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOwnProfile ? 'Author Media Folders' : 'Media',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFolderCard(
                  label: 'Photos',
                  icon: Icons.folder_copy_outlined,
                  folder: _ProfileMediaFolder.photos,
                ),
                const SizedBox(width: 10),
                _buildFolderCard(
                  label: 'Videos',
                  icon: Icons.folder_special_outlined,
                  folder: _ProfileMediaFolder.videos,
                ),
                if (isOwnProfile) ...[
                  const SizedBox(width: 10),
                  _buildFolderCard(
                    label: 'Saved',
                    icon: Icons.bookmark_border_outlined,
                    folder: _ProfileMediaFolder.saved,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedFolder == _ProfileMediaFolder.all,
                      onSelected: (_) => setState(
                        () => _selectedFolder = _ProfileMediaFolder.all,
                      ),
                    ),
                    ChoiceChip(
                      label: Text('$visibleCount visible'),
                      selected: false,
                      onSelected: null,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isGridView ? Icons.grid_view : Icons.view_agenda_outlined,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => setState(() => _isGridView = !_isGridView),
                tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, int count, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(count.toString(), style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildQuickSummaryCards(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsFuture,
      builder: (context, analyticsSnapshot) {
        return FutureBuilder<Map<String, int>>(
          future: _repostStatsFuture,
          builder: (context, repostSnapshot) {
            if (analyticsSnapshot.connectionState == ConnectionState.waiting ||
                repostSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final analytics = analyticsSnapshot.data ?? const {};
            final reposts =
                repostSnapshot.data ??
                const {'pending': 0, 'sent': 0, 'failed': 0};

            final totalEngagements = analytics['totalEngagements'] ?? 0;
            final engagementRate =
                ((analytics['avgEngagementRate'] ?? 0.0) as num).toDouble();

            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickSummaryCard(
                      title: 'Engagements',
                      value: '$totalEngagements',
                      subtitle:
                          '${(engagementRate * 100).toStringAsFixed(1)}% rate',
                      icon: Icons.trending_up,
                      onTap: _openAnalyticsDashboard,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickSummaryCard(
                      title: 'Repost Queue',
                      value: '${reposts['pending'] ?? 0} pending',
                      subtitle: '${reposts['sent'] ?? 0} sent',
                      icon: Icons.schedule_send,
                      onTap: _openRepostQueue,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderCard({
    required String label,
    required IconData icon,
    required _ProfileMediaFolder folder,
  }) {
    final isSelected = _selectedFolder == folder;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFolder = folder;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 100, // Fixed width for scrollable row
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesSelectedFolder(PostModel post, List<String> savedIds) {
    switch (_selectedFolder) {
      case _ProfileMediaFolder.all:
        return true;
      case _ProfileMediaFolder.photos:
        return post.imageUrls.isNotEmpty;
      case _ProfileMediaFolder.videos:
        return post.videoUrl != null && post.videoUrl!.isNotEmpty;
      case _ProfileMediaFolder.saved:
        return savedIds.contains(post.postId);
    }
  }

  Widget _buildGridPostItem(PostModel post) {
    final String? thumbnailUrl = post.imageUrls.isNotEmpty
        ? post.imageUrls.first
        : null;
    final bool isVideo =
        post.postType == 'video' ||
        (post.videoUrl != null && post.videoUrl!.isNotEmpty);

    return GestureDetector(
      onTap: () {
        // When tapping a grid item, show post details
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => DraggableScrollableSheet(
            expand: false,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            initialChildSize: 0.9,
            builder: (context, scrollController) => PostDetailsSheet(
              post: post,
              currentUserId: _auth.currentUser?.uid ?? '',
              scrollController: scrollController,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.black12),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.broken_image),
              )
            else if (isVideo)
              Container(
                color: Colors.black87,
                child: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white70,
                  size: 32,
                ),
              )
            else
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(8),
                child: Text(
                  post.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            if (isVideo && thumbnailUrl != null)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            if (post.imageUrls.length > 1)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.copy, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(this.context);
              Navigator.pop(context);

              // Navigate immediately — logout (token cleanup + signOut) runs in background
              navigator.pushNamedAndRemoveUntil('/login', (route) => false);
              AuthService().logout().ignore();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoViewer extends StatefulWidget {
  final String imageUrl;
  final String displayName;
  final bool canSaveImage;

  const _ProfilePhotoViewer({
    required this.imageUrl,
    required this.displayName,
    required this.canSaveImage,
  });

  @override
  State<_ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<_ProfilePhotoViewer> {
  bool _isSaving = false;

  Future<void> _saveProfilePhoto() async {
    setState(() => _isSaving = true);
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.imageUrl));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      await Gal.putImageBytes(bytes, album: 'Starpage');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo saved ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.displayName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.canSaveImage)
            IconButton(
              tooltip: 'Save profile photo',
              onPressed: _isSaving ? null : _saveProfilePhoto,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download, color: Colors.white),
            ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 56),
            ),
          ),
        ),
      ),
    );
  }
}
