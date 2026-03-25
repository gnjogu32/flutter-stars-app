import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../utils/animation_utils.dart';
import '../widgets/post_widget.dart';
import 'analytics_dashboard_screen.dart';
import 'chat_screen.dart';
import 'repost_queue_screen.dart';

enum _ProfileMediaFolder { all, photos, videos, audio }

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
  _ProfileMediaFolder _selectedFolder = _ProfileMediaFolder.all;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _checkFollowStatus();
    }
  }

  Future<void> _checkFollowStatus() async {
    if (_auth.currentUser?.uid == null) return;

    final effectiveUserId = widget.userId.isEmpty
        ? (_auth.currentUser?.uid ?? '')
        : widget.userId;

    if (effectiveUserId.isEmpty || effectiveUserId == _auth.currentUser?.uid) {
      if (mounted) {
        setState(() {
          _isFollowing = false;
        });
      }
      return;
    }

    try {
      final currentUser = await _userService.getUser(_auth.currentUser!.uid);
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

  Future<void> _navigateToChat(UserModel user) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    if (user.uid.isEmpty || user.uid == currentUserId) return;

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
    // If userId is empty, use current user's ID
    final effectiveUserId = widget.userId.isEmpty
        ? (_auth.currentUser?.uid ?? '')
        : widget.userId;

    final isOwnProfile = effectiveUserId == _auth.currentUser?.uid;

    // Debug output
    if (kDebugMode) {
      print('ProfileScreen - widget.userId: "${widget.userId}"');
      print('ProfileScreen - effectiveUserId: "$effectiveUserId"');
      print('ProfileScreen - currentUser?.uid: "${_auth.currentUser?.uid}"');
      print('ProfileScreen - isOwnProfile: $isOwnProfile');
    }

    // If still no user ID, show loading or auth error
    if (effectiveUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          centerTitle: true,
          elevation: 0,
        ),
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
              SizedBox(height: 8),
              Text('Please wait while we load your profile.'),
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
        actions: isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  tooltip: 'Analytics Dashboard',
                  onPressed: _openAnalyticsDashboard,
                ),
                IconButton(
                  icon: const Icon(Icons.schedule_send),
                  tooltip: 'Repost Queue',
                  onPressed: _openRepostQueue,
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    _showLogoutDialog(context);
                  },
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _firestore
              .collection('users')
              .doc(effectiveUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('User not found'),
                  ],
                ),
              );
            }

            final user = UserModel.fromFirestoreDoc(snapshot.data!);

            return Column(
              children: [
                // Profile Header
                _buildProfileHeader(user, isOwnProfile),
                const Divider(),
                // User Posts
                _buildUserPosts(user.uid, isOwnProfile),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, bool isOwnProfile) {
    return AnimationUtils.slideUpAnimation(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Image
            AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: 1.0,
              child: GestureDetector(
                onTap:
                    user.profileImageUrl == null ||
                        user.profileImageUrl!.isEmpty
                    ? null
                    : () => _openProfilePhotoViewer(
                        user.profileImageUrl,
                        user.displayName,
                        isOwnProfile,
                      ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user.profileImageUrl != null
                      ? NetworkImage(user.profileImageUrl!)
                      : null,
                  child: user.profileImageUrl == null
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
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
            // Stats - Get post count from stream
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
                    _buildStat('Posts', postCount),
                    _buildStat('Followers', user.followerCount),
                    _buildStat('Following', user.followingCount),
                  ],
                );
              },
            ),
            if (isOwnProfile) _buildQuickSummaryCards(user.uid),
            const SizedBox(height: 20),
            // Edit Profile / Follow Button & Message Button
            if (isOwnProfile)
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/edit-profile');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
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
                            ? Colors.grey[300]
                            : Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    ? Colors.black
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildQuickSummaryCards(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsService.getAuthorSummary(userId),
      builder: (context, analyticsSnapshot) {
        return FutureBuilder<Map<String, int>>(
          future: _repostQueueService.getRepostStats(userId),
          builder: (context, repostSnapshot) {
            if (analyticsSnapshot.connectionState == ConnectionState.waiting ||
                repostSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
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

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFolder = folder;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesSelectedFolder(PostModel post) {
    switch (_selectedFolder) {
      case _ProfileMediaFolder.all:
        return true;
      case _ProfileMediaFolder.photos:
        return post.imageUrls.isNotEmpty;
      case _ProfileMediaFolder.videos:
        return post.videoUrl != null && post.videoUrl!.isNotEmpty;
      case _ProfileMediaFolder.audio:
        return post.audioUrl != null && post.audioUrl!.isNotEmpty;
    }
  }

  Widget _buildUserPosts(String userId, bool isOwnProfile) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allPosts = (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            ? <PostModel>[]
            : snapshot.data!.docs
                  .map(
                    (doc) =>
                        PostModel.fromJson(doc.data() as Map<String, dynamic>),
                  )
                  .toList();

        final filteredPosts = allPosts.where(_matchesSelectedFolder).toList();

        final folderSection = Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOwnProfile ? 'Author Media Folders' : 'Media',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
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
                  const SizedBox(width: 10),
                  _buildFolderCard(
                    label: 'Audio',
                    icon: Icons.folder_open_outlined,
                    folder: _ProfileMediaFolder.audio,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedFolder == _ProfileMediaFolder.all,
                    onSelected: (_) {
                      setState(() {
                        _selectedFolder = _ProfileMediaFolder.all;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: Text('${filteredPosts.length} visible'),
                    selected: false,
                    onSelected: null,
                  ),
                ],
              ),
            ],
          ),
        );

        if (filteredPosts.isEmpty) {
          return Column(
            children: [
              folderSection,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _selectedFolder == _ProfileMediaFolder.all
                      ? 'No posts yet'
                      : 'No ${_selectedFolder.name} posts yet',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            folderSection,
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                return PostWidget(
                  post: filteredPosts[index],
                  currentUserId: _auth.currentUser?.uid ?? '',
                );
              },
            ),
          ],
        );
      },
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
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 56,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
