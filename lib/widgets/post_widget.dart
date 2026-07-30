import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/share_service.dart';
import '../utils/time_utils.dart';
import '../utils/auth_guard.dart';
import '../utils/mention_utils.dart';
import '../screens/profile_screen.dart';
import 'video_player_widget.dart';
import 'audio_player_widget.dart';
import 'expandable_text.dart';
import 'comments_bottom_sheet.dart';
import 'keyboard_prompt_banner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'repost_dialog.dart';
import 'post_details_sheet.dart';

class PostWidget extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final bool autoPlayEnabled;
  final bool isTabVisible;
  final bool isImmersive;

  const PostWidget({
    super.key,
    required this.post,
    required this.currentUserId,
    this.autoPlayEnabled = true,
    this.isTabVisible = true,
    this.isImmersive = false,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isSaved = false;
  bool _isReposting = false;
  bool _showLikeHeart = false;
  late AnimationController _heartAnimationController;
  final GlobalKey<VideoPlayerWidgetState> _videoKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(widget.currentUserId);
    _likeCount = widget.post.likeCount;
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkIfSaved();
  }

  void _handleDoubleTap() async {
    if (!_isLiked) {
      await _toggleLike();
    }
    setState(() => _showLikeHeart = true);
    _heartAnimationController.forward(from: 0).then((_) {
      setState(() => _showLikeHeart = false);
    });
  }

  String get _ownerId =>
      (widget.post.originalAuthorId ?? widget.post.authorId).trim();
  String get _ownerName =>
      (widget.post.originalAuthorName ?? widget.post.authorName).trim();
  String? get _ownerImageUrl =>
      widget.post.originalAuthorImageUrl ?? widget.post.authorImageUrl;
  bool get _isSharedPost => widget.post.originalPostId != null;

  Future<void> _checkIfSaved() async {
    final saved = await UserService().isPostSaved(
      widget.currentUserId,
      widget.post.postId,
    );
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating || widget.currentUserId.isEmpty) {
      if (widget.currentUserId.isEmpty) await AuthGuard.show(context);
      return;
    }

    setState(() {
      _isLikeUpdating = true;
      if (_isLiked) {
        _isLiked = false;
        _likeCount--;
      } else {
        _isLiked = true;
        _likeCount++;
      }
    });

    try {
      final postService = PostService();
      if (_isLiked) {
        await postService.likePost(widget.post.postId, widget.currentUserId);
      } else {
        await postService.unlikePost(widget.post.postId, widget.currentUserId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_isLiked) {
            _isLiked = false;
            _likeCount--;
          } else {
            _isLiked = true;
            _likeCount++;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _isLikeUpdating = false);
    }
  }

  Future<void> _toggleSave() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }
    final newState = !_isSaved;
    setState(() => _isSaved = newState);
    try {
      if (newState) {
        await UserService().savePost(widget.currentUserId, widget.post.postId);
      } else {
        await UserService().unsavePost(
          widget.currentUserId,
          widget.post.postId,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSaved = !newState);
    }
  }

  void _showPostDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => PostDetailsSheet(
          post: widget.post,
          currentUserId: widget.currentUserId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _confirmRepost() async {
    final result = await RepostDialog.show(
      context,
      post: widget.post,
      currentUserId: widget.currentUserId,
    );

    if (result != null && mounted) {
      await _repostToFeed(caption: result.trim());
    }
  }

  Future<void> _repostToFeed({String caption = ''}) async {
    if (_isReposting) return;
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }
    setState(() => _isReposting = true);
    try {
      final userService = UserService();
      final postService = PostService();
      final currentUser = await userService.getUser(widget.currentUserId);
      if (currentUser == null) throw Exception('Your profile was not found.');

      await postService.repostPost(
        originalPost: widget.post,
        reposterId: widget.currentUserId,
        reposterName: currentUser.displayName,
        reposterUsername: currentUser.username,
        reposterImageUrl: currentUser.profileImageUrl,
        repostCaption: caption,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reposted successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reposting: $e')));
      }
    } finally {
      if (mounted) setState(() => _isReposting = false);
    }
  }

  void _showShareDialog() {
    final isAuthor =
        (widget.post.originalAuthorId ?? widget.post.authorId) ==
        widget.currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
              'Share Post',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(context);
                ShareService.copyToClipboard(widget.post);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard ✓')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.pop(context);
                ShareService.sharePost(widget.post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repost'),
              onTap: () {
                Navigator.pop(context);
                _confirmRepost();
              },
            ),
            if (isAuthor && widget.post.videoUrl != null)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download Video'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadVideo();
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadVideo() async {
    if (widget.post.videoUrl == null || widget.post.videoUrl!.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Downloading video...')));
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.post.videoUrl!));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await tempFile.writeAsBytes(bytes);
      await Gal.putVideo(tempFile.path, album: 'Starpage');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video saved to gallery ✓')),
      );
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  void _editPost() {
    Navigator.of(context).pushNamed('/edit-post', arguments: widget.post);
  }

  void _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PostService().deletePost(widget.post);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post deleted')));
      }
    }
  }

  void _muteAuthor() async {
    await UserService().muteAuthor(widget.currentUserId, _ownerId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Muted $_ownerName')));
    }
  }

  void _mutePost() async {
    await UserService().mutePost(widget.currentUserId, widget.post.postId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post muted')));
    }
  }

  void _reportPost() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post reported. Thank you for keeping Starpage safe.'),
      ),
    );
  }

  void _openAuthorProfile() {
    if (_ownerId.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: _ownerId)),
    );
  }

  Future<void> _openCommentsSheet({bool autoFocus = false}) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => CommentsBottomSheet(
          postId: widget.post.postId,
          postAuthorId: _ownerId,
          currentUserId: widget.currentUserId,
          postContent: widget.post.content,
          scrollController: scrollController,
          autoFocus: autoFocus,
        ),
      ),
    );
  }

  Widget _buildPostInteractionBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.postId)
          .snapshots(),
      builder: (context, snapshot) {
        int likeCount = _likeCount;
        int commentCount = widget.post.commentCount;
        int repostCount = widget.post.repostCount;
        bool isLiked = _isLiked;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final List likes = data['likes'] as List? ?? [];
          likeCount = likes.length;
          commentCount = data['commentCount'] ?? 0;
          repostCount = data['repostCount'] ?? 0;
          isLiked = likes.contains(widget.currentUserId);

          if (!_isLikeUpdating) {
            _isLiked = isLiked;
            _likeCount = likeCount;
          }
        }

        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBarItem(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: '$likeCount',
                color: isLiked ? Colors.red : null,
                onTap: _toggleLike,
              ),
              _buildBarItem(
                icon: Icons.comment_outlined,
                label: '$commentCount',
                onTap: () => _openCommentsSheet(autoFocus: true),
              ),
              _buildBarItem(
                icon: Icons.repeat,
                label: '$repostCount',
                onTap: _confirmRepost,
              ),
              _buildBarItem(
                icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: '',
                color: _isSaved ? Colors.amber : null,
                onTap: _toggleSave,
              ),
              _buildBarItem(
                icon: Icons.share_outlined,
                label: '',
                onTap: _showShareDialog,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImmersivePost(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Media
          if (widget.post.videoUrl != null && widget.post.videoUrl!.isNotEmpty)
            Center(
              child: VideoPlayerWidget(
                key: _videoKey,
                videoUrl: widget.post.videoUrl!,
                post: widget.post,
                currentUserId: widget.currentUserId,
                autoPlay: true,
                fit: BoxFit.contain,
              ),
            )
          else if (widget.post.imageUrls.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => _FullScreenImageGallery(
                      imageUrls: widget.post.imageUrls,
                      initialIndex: 0,
                      canSaveImages: _ownerId == widget.currentUserId,
                    ),
                  ),
                );
              },
              child: CachedNetworkImage(
                imageUrl: widget.post.imageUrls.first,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white24),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? [const Color(0xFF0F1116), const Color(0xFF1A1D23)]
                    : [const Color(0xFFF5F5F7), const Color(0xFFEEEEEE)],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    widget.post.content,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // Bottom Gradient Overlay for readability
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // Content & Interactions
          Positioned(
            left: 16,
            right: 80,
            bottom: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _openAuthorProfile,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: _ownerImageUrl != null
                            ? CachedNetworkImageProvider(_ownerImageUrl!)
                            : null,
                        child: _ownerImageUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _ownerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.post.talent != null)
                              Text(
                                widget.post.talent!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.post.videoUrl != null || widget.post.imageUrls.isNotEmpty)
                  ExpandableText(
                    widget.post.content,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    trimLines: 3,
                  ),
                if (widget.post.audioUrl != null && widget.post.audioUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: AudioPlayerWidget(audioUrl: widget.post.audioUrl!),
                  ),
              ],
            ),
          ),

          // Right Sidebar Interactions
          Positioned(
            right: 12,
            bottom: 30,
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.postId)
                  .snapshots(),
              builder: (context, snapshot) {
                int likeCount = _likeCount;
                int commentCount = widget.post.commentCount;
                int repostCount = widget.post.repostCount;
                bool isLiked = _isLiked;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final List likes = data['likes'] as List? ?? [];
                  likeCount = likes.length;
                  commentCount = data['commentCount'] ?? 0;
                  repostCount = data['repostCount'] ?? 0;
                  isLiked = likes.contains(widget.currentUserId);

                  if (!_isLikeUpdating) {
                    _isLiked = isLiked;
                    _likeCount = likeCount;
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSidebarItem(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: '$likeCount',
                      color: isLiked ? Colors.redAccent : Colors.white,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarItem(
                      icon: Icons.comment_outlined,
                      label: '$commentCount',
                      onTap: () => _openCommentsSheet(autoFocus: true),
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarItem(
                      icon: Icons.repeat,
                      label: '$repostCount',
                      onTap: _confirmRepost,
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarItem(
                      icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      label: '',
                      color: _isSaved ? Colors.amberAccent : Colors.white,
                      onTap: _toggleSave,
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarItem(
                      icon: Icons.share_outlined,
                      label: '',
                      onTap: _showShareDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildSidebarItem(
                      icon: Icons.more_vert,
                      label: '',
                      onTap: () {
                        // Show a generic options menu or use the existing logic
                        _showImmersiveMoreOptions(context);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showImmersiveMoreOptions(BuildContext context) {
    final isAuthor = widget.post.authorId == widget.currentUserId;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  _editPost();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost();
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Mute Author'),
                onTap: () {
                  Navigator.pop(context);
                  _muteAuthor();
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: color ?? theme.colorScheme.onSurfaceVariant,
                ),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color ?? theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _heartAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    
    if (widget.isImmersive) {
      return _buildImmersivePost(context);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _openAuthorProfile,
                  child: CircleAvatar(
                    backgroundImage: _ownerImageUrl != null
                        ? CachedNetworkImageProvider(_ownerImageUrl!)
                        : null,
                    child: _ownerImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _openAuthorProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ownerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_isSharedPost)
                          Text(
                            'Shared by ${widget.post.authorName}',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (widget.post.talent != null)
                          Text(
                            widget.post.talent!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  TimeUtils.formatShorthand(widget.post.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editPost();
                    } else if (value == 'delete') {
                      _deletePost();
                    } else if (value == 'mute_author') {
                      _muteAuthor();
                    } else if (value == 'mute_post') {
                      _mutePost();
                    } else if (value == 'report') {
                      _reportPost();
                    }
                  },
                  itemBuilder: (context) {
                    final isAuthor =
                        widget.post.authorId == widget.currentUserId;
                    return [
                      if (isAuthor) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const PopupMenuItem(
                          value: 'mute_author',
                          child: Row(
                            children: [
                              Icon(Icons.person_off_outlined),
                              SizedBox(width: 8),
                              Text('Mute Author'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'mute_post',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off_outlined),
                              SizedBox(width: 8),
                              Text('Mute Post'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(
                                Icons.report_problem_outlined,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Text('Report Post'),
                            ],
                          ),
                        ),
                      ],
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.post.repostCaption != null) ...[
              GestureDetector(
                onTap: _showPostDetailsSheet,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original post by ${widget.post.originalAuthorName ?? 'Unknown'}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ExpandableText(
                        widget.post.content,
                        style: theme.textTheme.bodySmall,
                        trimLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _showPostDetailsSheet,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your caption:',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ExpandableText(
                        widget.post.repostCaption!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        trimLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              GestureDetector(
                onTap: _showPostDetailsSheet,
                child: ExpandableText(
                  widget.post.content,
                  style: theme.textTheme.bodyMedium,
                  trimLines: 3,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.post.audioUrl != null &&
                widget.post.audioUrl!.isNotEmpty) ...[
              AudioPlayerWidget(audioUrl: widget.post.audioUrl!),
              const SizedBox(height: 12),
            ],
            if (widget.post.videoUrl != null &&
                widget.post.videoUrl!.isNotEmpty) ...[
              VisibilityDetector(
                key: ValueKey('feed_video_${widget.post.postId}'),
                onVisibilityChanged: (info) {
                  if (!mounted) return;
                  if (info.visibleFraction > 0.8) {
                    if (widget.autoPlayEnabled && widget.isTabVisible) {
                      _videoKey.currentState?.play();
                    }
                  } else {
                    _videoKey.currentState?.pause();
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: VideoPlayerWidget(
                        key: _videoKey,
                        videoUrl: widget.post.videoUrl!,
                        post: widget.post,
                        currentUserId: widget.currentUserId,
                        autoPlay: false,
                        onDoubleTap: _handleDoubleTap,
                      ),
                    ),
                    if (_showLikeHeart)
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.0, end: 1.2).animate(
                          CurvedAnimation(
                            parent: _heartAnimationController,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.post.imageUrls.isNotEmpty)
              widget.post.imageUrls.length == 1
                  ? GestureDetector(
                      onDoubleTap: _handleDoubleTap,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => _FullScreenImageGallery(
                              imageUrls: widget.post.imageUrls,
                              initialIndex: 0,
                              canSaveImages: _ownerId == widget.currentUserId,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 420),
                          color: Colors.black.withValues(alpha: 0.04),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CachedNetworkImage(
                                imageUrl: widget.post.imageUrls.first,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const SizedBox(
                                  height: 220,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                              ),
                              if (_showLikeHeart)
                                ScaleTransition(
                                  scale: Tween<double>(begin: 0.0, end: 1.2).animate(
                                    CurvedAnimation(
                                      parent: _heartAnimationController,
                                      curve: Curves.elasticOut,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.favorite,
                                    color: Colors.white,
                                    size: 80,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.post.imageUrls.asMap().entries.map((
                          entry,
                        ) {
                          final idx = entry.key;
                          final imageUrl = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onDoubleTap: _handleDoubleTap,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        _FullScreenImageGallery(
                                          imageUrls: widget.post.imageUrls,
                                          initialIndex: idx,
                                          canSaveImages:
                                              _ownerId == widget.currentUserId,
                                        ),
                                  ),
                                );
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      height: 200,
                                      width: 200,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        height: 200,
                                        width: 200,
                                        color: Colors.black12,
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_showLikeHeart)
                                    ScaleTransition(
                                      scale: Tween<double>(begin: 0.0, end: 1.2).animate(
                                        CurvedAnimation(
                                          parent: _heartAnimationController,
                                          curve: Curves.elasticOut,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Colors.white,
                                        size: 60,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            const SizedBox(height: 12),
            _buildPostInteractionBar(),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final bool canSaveImages;
  const _FullScreenImageGallery({
    required this.imageUrls,
    required this.initialIndex,
    required this.canSaveImages,
  });
  @override
  State<_FullScreenImageGallery> createState() =>
      _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<_FullScreenImageGallery> {
  late final PageController _pageController;
  late int _currentIndex;
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: widget.imageUrls[index],
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ),
    );
  }
}
