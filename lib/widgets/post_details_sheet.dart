import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/share_service.dart';
import '../screens/profile_screen.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/expandable_text.dart';
import '../widgets/comments_bottom_sheet.dart';
import 'repost_dialog.dart';

class PostDetailsSheet extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final ScrollController scrollController;

  const PostDetailsSheet({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.scrollController,
  });

  @override
  State<PostDetailsSheet> createState() => _PostDetailsSheetState();
}

class _PostDetailsSheetState extends State<PostDetailsSheet>
    with TickerProviderStateMixin {
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isSaved = false;
  bool _isReposting = false;
  bool _showLikeHeart = false;
  late AnimationController _heartAnimationController;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.likes.contains(widget.currentUserId);
    _likeCount = widget.post.likes.length;
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

  Future<void> _checkIfSaved() async {
    final saved = await _userService.isPostSaved(
      widget.currentUserId,
      widget.post.postId,
    );
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating) return;
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
      if (_isLiked) {
        await _postService.likePost(widget.post.postId, widget.currentUserId);
      } else {
        await _postService.unlikePost(widget.post.postId, widget.currentUserId);
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

  void _openComments({bool autoFocus = false}) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => CommentsBottomSheet(
          postId: widget.post.postId,
          postAuthorId: widget.post.authorId,
          currentUserId: widget.currentUserId,
          postContent: widget.post.content,
          scrollController: scrollController,
          autoFocus: autoFocus,
        ),
      ),
    );
  }

  Future<void> _toggleSave() async {
    final newState = !_isSaved;
    setState(() => _isSaved = newState);
    try {
      if (newState) {
        await _userService.savePost(widget.currentUserId, widget.post.postId);
      } else {
        await _userService.unsavePost(widget.currentUserId, widget.post.postId);
      }
    } catch (e) {
      if (mounted) setState(() => _isSaved = !newState);
    }
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
    setState(() => _isReposting = true);
    try {
      final currentUser = await _userService.getUser(widget.currentUserId);
      if (currentUser == null) {
        throw Exception('Your profile was not found.');
      }

      await _postService.repostPost(
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

  void _showShareOptions() {
    final theme = Theme.of(context);
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
              'Share Post',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
            if ((widget.post.originalAuthorId ?? widget.post.authorId) ==
                    widget.currentUserId &&
                widget.post.videoUrl != null)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download Video'),
                onTap: () {
                  Navigator.pop(context);
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
    final theme = Theme.of(context);
    final ownerName = widget.post.originalAuthorName ?? widget.post.authorName;
    final ownerImageUrl =
        widget.post.originalAuthorImageUrl ?? widget.post.authorImageUrl;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.post.repostCaption != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original post by $ownerName',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ExpandableText(
                          widget.post.content,
                          style: theme.textTheme.bodySmall,
                          trimLines: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your caption:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpandableText(
                    widget.post.repostCaption!,
                    style: theme.textTheme.bodyMedium,
                    trimLines: 5,
                  ),
                ] else ...[
                  ExpandableText(
                    widget.post.content,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                    trimLines: 10,
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.post.imageUrls.isNotEmpty) ...[
                  ...widget.post.imageUrls.map(
                    (url) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onDoubleTap: _handleDoubleTap,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.broken_image),
                              ),
                            ),
                            if (_showLikeHeart)
                              ScaleTransition(
                                scale: Tween<double>(begin: 0.0, end: 1.2)
                                    .animate(
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
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.post.audioUrl != null &&
                    widget.post.audioUrl!.isNotEmpty) ...[
                  AudioPlayerWidget(audioUrl: widget.post.audioUrl!),
                  const SizedBox(height: 16),
                ],
                if (widget.post.videoUrl != null &&
                    widget.post.videoUrl!.isNotEmpty) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: VideoPlayerWidget(
                          videoUrl: widget.post.videoUrl!,
                          autoPlay: true,
                          looping: true,
                          post: widget.post,
                          currentUserId: widget.currentUserId,
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
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          StreamBuilder<DocumentSnapshot>(
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
              return DefaultTabController(
                length: 5,
                child: TabBar(
                  onTap: (index) {
                    if (index == 0) _toggleLike();
                    if (index == 1) _openComments(autoFocus: false);
                    if (index == 2) _confirmRepost();
                    if (index == 3) _toggleSave();
                    if (index == 4) _showShareOptions();
                  },
                  indicatorColor: Colors.transparent,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  dividerColor: Colors.transparent,
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: theme.textTheme.labelSmall,
                  tabs: [
                    Tab(
                      height: 48,
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : null,
                        size: 20,
                      ),
                      child: Text(
                        '$likeCount',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Tab(
                      height: 48,
                      icon: const Icon(Icons.comment_outlined, size: 20),
                      child: Text(
                        '$commentCount',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Tab(
                      height: 48,
                      icon: const Icon(Icons.repeat, size: 20),
                      child: Text(
                        '$repostCount',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Tab(
                      height: 48,
                      icon: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 20,
                      ),
                      child: const SizedBox.shrink(),
                    ),
                    const Tab(
                      height: 48,
                      icon: Icon(Icons.share_outlined, size: 20),
                      child: SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(userId: widget.post.authorId),
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: ownerImageUrl != null
                        ? CachedNetworkImageProvider(ownerImageUrl)
                        : null,
                    child: ownerImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ownerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.post.talent != null)
                        Text(
                          widget.post.talent!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
