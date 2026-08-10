import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../services/analytics_service.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/post_widget.dart';
import '../widgets/post_details_sheet.dart';
import '../widgets/video_grid_thumbnail.dart';
import 'analytics_dashboard_screen.dart';
import 'chat_screen.dart';
import 'followers_following_screen.dart';
import '../utils/constants.dart';

enum _ProfileMediaFolder { all, photos, videos, saved }

enum _ProfileSearchType { posts, stars }

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
  final UserService _userService = UserService();
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  bool _isBlocked = false;
  bool _isLoadingBlock = false;
  _ProfileMediaFolder _selectedFolder = _ProfileMediaFolder.all;
  bool _isGridView = true;
  String _searchQuery = '';
  _ProfileSearchType _searchType = _ProfileSearchType.posts;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _mediaSectionKey = GlobalKey();

  // Cached futures/streams to prevent jumpy UI during rebuilds
  Stream<Map<String, dynamic>>? _analyticsStream;

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
    _analyticsStream = _analyticsService.getAuthorSummaryStream(userId);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Please try again.')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Please try again.')),
        );
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

  void _scrollToMediaSection() {
    final context = _mediaSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showShareOptions(String userId) {
    final theme = Theme.of(context);
    final profileUrl = AppConstants.profileUrl(userId);
    final alternativeUrl =
        'https://${AppConstants.secondaryDomain}/profile/$userId';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Share Profile',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Profile Link (.me)'),
              subtitle: Text(profileUrl, style: const TextStyle(fontSize: 10)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: profileUrl));
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Profile link copied ✓')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy Profile Link (.org)'),
              subtitle: Text(
                alternativeUrl,
                style: const TextStyle(fontSize: 10),
              ),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: alternativeUrl));
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Alternative link copied ✓')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text('Copy Formatted Invite'),
              onTap: () {
                Navigator.pop(context);
                final shareText =
                    'Check out this talented star on ${AppConstants.appName}! ⭐\n\nProfile: $profileUrl';
                Clipboard.setData(ClipboardData(text: shareText));
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Invite copied ✓')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('Show Profile QR'),
              onTap: () {
                Navigator.pop(context);
                // Placeholder for QR feature
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('QR feature coming soon!')),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
        title: Text(isOwnProfile ? 'My Profile' : 'Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Profile',
            onPressed: () => _showShareOptions(effectiveUserId),
          ),
          if (isOwnProfile) ...[
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
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

          return _searchType == _ProfileSearchType.posts
              ? StreamBuilder<QuerySnapshot>(
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
                        (!postsSnapshot.hasData ||
                            postsSnapshot.data!.docs.isEmpty)
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
                          (post) =>
                              _matchesSelectedFolder(post, user.savedPosts),
                        )
                        .where(
                          (post) =>
                              _searchQuery.isEmpty ||
                              post.content.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ),
                        )
                        .toList();

                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildProfileHeader(user, isOwnProfile),
                        ),
                        SliverToBoxAdapter(
                          child: Divider(key: _mediaSectionKey),
                        ),
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
                )
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildProfileHeader(user, isOwnProfile),
                    ),
                    SliverToBoxAdapter(child: Divider(key: _mediaSectionKey)),
                    SliverToBoxAdapter(
                      child: _buildFolderSection(isOwnProfile, 0),
                    ),
                    _buildStarsSliverList(),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, bool isOwnProfile) {
    return Column(
      children: [
        // Cover Photo
        GestureDetector(
          onTap: user.coverImageUrl == null || user.coverImageUrl!.isEmpty
              ? null
              : () => _openProfilePhotoViewer(
                  user.coverImageUrl,
                  '${user.displayName}\'s Cover',
                  isOwnProfile,
                ),
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              image:
                  user.coverImageUrl != null && user.coverImageUrl!.isNotEmpty
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(user.coverImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: user.coverImageUrl == null || user.coverImageUrl!.isEmpty
                ? Center(
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                      size: 40,
                    ),
                  )
                : null,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // Profile Image
                GestureDetector(
                  onTap:
                      user.profileImageUrl == null ||
                          user.profileImageUrl!.isEmpty
                      ? null
                      : () => _openProfilePhotoViewer(
                          user.profileImageUrl,
                          user.displayName,
                          isOwnProfile,
                        ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 4,
                      ),
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
                ),
                const SizedBox(height: 8),
                // Name
                Text(
                  user.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                // Joining Date
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Joined ${DateFormat('MMMM yyyy').format(user.createdAt)}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Birthday
                if (user.birthday != null &&
                    (user.birthdayPublic || isOwnProfile))
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cake, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Born ${DateFormat('MMMM dd, yyyy').format(user.birthday!)}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                        if (isOwnProfile) ...[
                          const SizedBox(width: 8),
                          Icon(
                            user.birthdayPublic
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 12,
                            color: Colors.grey,
                          ),
                        ],
                      ],
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
                              _searchType = _ProfileSearchType.posts;
                            });
                            _scrollToMediaSection();
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
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[800]
                                      : Colors.grey[300])
                                : Theme.of(context).colorScheme.primary,
                          ),
                          child: _isLoadingFollow
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildFolderSection(bool isOwnProfile, int visibleCount) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar & Type Toggle
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: _searchType == _ProfileSearchType.posts
                        ? 'Search posts...'
                        : 'Search stars...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilterChip(
                      label: const Text(
                        'Posts',
                        style: TextStyle(fontSize: 12),
                      ),
                      selected: _searchType == _ProfileSearchType.posts,
                      onSelected: (selected) {
                        if (selected) {
                          setState(
                            () => _searchType = _ProfileSearchType.posts,
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text(
                        'Stars',
                        style: TextStyle(fontSize: 12),
                      ),
                      selected: _searchType == _ProfileSearchType.stars,
                      onSelected: (selected) {
                        if (selected) {
                          setState(
                            () => _searchType = _ProfileSearchType.stars,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    return StreamBuilder<Map<String, dynamic>>(
      stream: _analyticsStream,
      builder: (context, analyticsSnapshot) {
        if (analyticsSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final analytics = analyticsSnapshot.data ?? const {};
        final totalEngagements = analytics['totalEngagements'] ?? 0;
        final engagementRate = ((analytics['avgEngagementRate'] ?? 0.0) as num)
            .toDouble();

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
              const Spacer(),
            ],
          ),
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

  Widget _buildStarsSliverList() {
    if (_searchQuery.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'Search for talented stars...',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: _searchQuery)
          .where('displayName', isLessThan: '${_searchQuery}z')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final users =
            snapshot.data?.docs
                .map((doc) => UserModel.fromFirestoreDoc(doc))
                .toList() ??
            [];

        if (users.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No stars found matching your search.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildUserSearchCard(users[index]),
            childCount: users.length,
          ),
        );
      },
    );
  }

  Widget _buildUserSearchCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user.profileImageUrl != null
              ? CachedNetworkImageProvider(user.profileImageUrl!)
              : null,
          child: user.profileImageUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(user.talent ?? 'Creative Star'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.uid)),
          );
        },
      ),
    );
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
              Stack(
                fit: StackFit.expand,
                children: [
                  VideoGridThumbnail(videoUrl: post.videoUrl!),
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
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
