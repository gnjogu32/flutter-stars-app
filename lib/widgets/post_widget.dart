import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gal/gal.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/post_model.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../services/share_service.dart';
import '../utils/animation_utils.dart';
import '../utils/auth_guard.dart';
// import '../utils/screen_awake_controller.dart';
import '../screens/profile_screen.dart';
import 'comments_bottom_sheet.dart';
import 'expandable_text.dart';
import 'keyboard_prompt_banner.dart';
import 'video_player_widget.dart';
import 'audio_player_widget.dart';

class PostWidget extends StatefulWidget {
  final PostModel post;
  final String currentUserId;

  const PostWidget({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
    int? _realtimeViewCount;
    Stream<DocumentSnapshot>? _viewCountStream;
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isReposting = false;
  // _videoViewCount removed for AGP 9+ compatibility

  static const List<String> _quickEmojis = [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '🥳',
    '😎',
    '🤔',
    '👏',
    '🔥',
    '💯',
    '✨',
    '🙌',
    '👍',
    '🙏',
    '❤️',
    '💙',
    '💚',
    '🎉',
    '😢',
    '😡',
    '🤝',
    '💫',
  ];

  bool get _isSharedPost =>
      (widget.post.originalAuthorId ?? '').trim().isNotEmpty;

  String get _ownerId => _isSharedPost
      ? widget.post.originalAuthorId!.trim()
      : widget.post.authorId;

  void _showPostDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Post Caption/Content
                    if (widget.post.repostCaption != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original post by ${widget.post.originalAuthorName ?? 'Unknown'}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            ExpandableText(
                              widget.post.content,
                              style: Theme.of(context).textTheme.bodySmall,
                              trimLines: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your caption:',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      ExpandableText(
                        widget.post.repostCaption!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        trimLines: 5,
                      ),
                    ] else ...[
                      ExpandableText(
                        widget.post.content,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 16),
                        trimLines: 10,
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: Theme.of(context).dividerColor),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimationUtils.scaleButtonAnimation(
                          onTap: _toggleLike,
                          child: Semantics(
                            label: _isLiked ? 'Unlike post' : 'Like post',
                            button: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  scale: _isLiked ? 1.2 : 1.0,
                                  child: Icon(
                                    _isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _isLiked ? Colors.red : null,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: Theme.of(context).textTheme.bodyLarge!
                                      .copyWith(
                                        color: _isLiked ? Colors.red : null,
                                        fontWeight: _isLiked
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                  child: Text('$_likeCount'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: AnimationUtils.scaleButtonAnimation(
                          onTap: () async {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => CommentsBottomSheet(
                                postId: widget.post.postId,
                                postAuthorId: _ownerId,
                                currentUserId: widget.currentUserId,
                              ),
                            );
                          },
                          child: Semantics(
                            label: 'View comments',
                            button: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.comment_outlined, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.post.commentCount}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: AnimationUtils.scaleButtonAnimation(
                          onTap: _repostToFeed,
                          child: Semantics(
                            label: 'Repost to your feed',
                            button: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.repeat, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.post.repostCount}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: AnimationUtils.scaleButtonAnimation(
                          onTap: () => _showShareDialog(),
                          child: Semantics(
                            label: 'Share post',
                            button: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.share_outlined, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  'Share',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Author section at the very bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _openAuthorProfile,
                      child: CircleAvatar(
                        backgroundImage: _ownerImageUrl != null
                            ? NetworkImage(_ownerImageUrl!)
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.post.talent != null)
                              Text(
                                widget.post.talent!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
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
        ),
      ),
    );
  }

  String get _ownerName => _isSharedPost
      ? (widget.post.originalAuthorName ?? widget.post.authorName).trim()
      : widget.post.authorName;

  String? get _ownerImageUrl => _isSharedPost
      ? widget.post.originalAuthorImageUrl
      : widget.post.authorImageUrl;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(widget.currentUserId);
    _likeCount = widget.post.likeCount;
    // _videoViewCount removed for AGP 9+ compatibility
    if (_ownerId != widget.currentUserId) {
      _checkFollowState();
    }

    // Real-time view count for video posts
    if (widget.post.videoUrl != null && widget.post.videoUrl!.isNotEmpty) {
      _viewCountStream = FirebaseFirestore.instance
          .collection('post_analytics')
          .doc('${widget.post.postId}:analytics')
          .snapshots();
      _viewCountStream!.listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>?;
          setState(() {
            _realtimeViewCount = (data?['viewCount'] as int?) ?? 0;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isLikeUpdating) {
      _isLiked = widget.post.isLikedBy(widget.currentUserId);
      _likeCount = widget.post.likeCount;
    }
    // _videoViewCount removed for AGP 9+ compatibility
  }

  // _incrementVideoViewCount removed for AGP 9+ compatibility

  Future<void> _checkFollowState() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final following = List<String>.from(data['following'] ?? []);
        setState(() {
          _isFollowing = following.contains(_ownerId);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
    if (!await AuthGuard.check(context, widget.currentUserId)) return;
    setState(() => _isFollowLoading = true);
    try {
      final userService = UserService();
      if (_isFollowing) {
        await userService.unfollowUser(widget.currentUserId, _ownerId);
      } else {
        await userService.followUser(widget.currentUserId, _ownerId);
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

  Widget _buildFollowButton() {
    return SizedBox(
      height: 26,
      child: OutlinedButton(
        onPressed: _isFollowLoading ? null : _toggleFollow,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
    );
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating) return;
    if (!await AuthGuard.check(context, widget.currentUserId)) return;

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final notificationService = NotificationService();
    final userService = UserService();

    final wasLiked = _isLiked;
    final previousLikeCount = _likeCount;

    setState(() {
      _isLikeUpdating = true;
      _isLiked = !wasLiked;
      _likeCount = wasLiked
          ? (_likeCount > 0 ? _likeCount - 1 : 0)
          : _likeCount + 1;
    });

    try {
      if (wasLiked) {
        // Unlike
        await firestore.collection('posts').doc(widget.post.postId).update({
          'likes': FieldValue.arrayRemove([widget.currentUserId]),
        });
      } else {
        // Like
        await firestore.collection('posts').doc(widget.post.postId).update({
          'likes': FieldValue.arrayUnion([widget.currentUserId]),
        });

        // Create like notification if not liking own post
        if (widget.currentUserId != _ownerId) {
          final currentUser = await userService.getUser(widget.currentUserId);
          if (currentUser != null) {
            await notificationService.createNotification(
              userId: _ownerId,
              triggeredBy: widget.currentUserId,
              triggeredByName: currentUser.displayName,
              triggeredByImageUrl: currentUser.profileImageUrl,
              type: 'like_post',
              postId: widget.post.postId,
              content: '${currentUser.displayName} liked your post',
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLikeUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLikeUpdating = false;
          _isLiked = wasLiked;
          _likeCount = previousLikeCount;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showShareDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Post',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: Text(_isReposting ? 'Reposting...' : 'Repost to Feed'),
              enabled: !_isReposting,
              onTap: () {
                Navigator.pop(context);
                _confirmRepost();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.pop(context);
                ShareService.sharePost(widget.post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Share on WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareViaWhatsApp(widget.post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Share on Twitter'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareViaTwitter(widget.post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy to Clipboard'),
              onTap: () {
                Navigator.pop(context);
                _confirmCopyToClipboard();
              },
            ),
          ],
        ),
      ),
    );
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
      final notificationService = NotificationService();

      final currentUser = await userService.getUser(widget.currentUserId);
      if (currentUser == null) {
        throw Exception('Could not load your profile for reposting.');
      }

      final actorName = currentUser.displayName.trim().isEmpty
          ? 'Someone'
          : currentUser.displayName.trim();

      await postService.repostPost(
        originalPost: widget.post,
        reposterId: widget.currentUserId,
        reposterName: actorName,
        reposterImageUrl: currentUser.profileImageUrl,
        repostCaption: caption,
      );

      if (widget.currentUserId != widget.post.authorId) {
        try {
          await notificationService.createNotification(
            userId: widget.post.authorId,
            triggeredBy: widget.currentUserId,
            triggeredByName: actorName,
            triggeredByImageUrl: currentUser.profileImageUrl,
            type: 'repost_post',
            postId: widget.post.postId,
            content: '$actorName reposted your content',
          );
        } catch (e) {
          debugPrint('Repost notification skipped: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reposted to your feed ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to repost: $e')));
    } finally {
      if (mounted) {
        setState(() => _isReposting = false);
      }
    }
  }

  void _editPost() {
    debugPrint('_editPost called for post: ${widget.post.postId}');
    debugPrint('Post content: ${widget.post.content}');
    debugPrint('Navigating to /edit-post with arguments');
    Navigator.of(context).pushNamed('/edit-post', arguments: widget.post);
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
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

    if (confirmed == true && mounted) {
      try {
        final postService = PostService();
        await postService.deletePost(widget.post);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
        }
      }
    }
  }

  Future<void> _confirmRepost() async {
    final textController = TextEditingController();
    final focusNode = FocusNode();
    final hasFocus = ValueNotifier(false);
    var showEmojiPanel = false;

    focusNode.addListener(() {
      hasFocus.value = focusNode.hasFocus;
    });

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Repost'),
          content: ValueListenableBuilder<bool>(
            valueListenable: hasFocus,
            builder: (context, value, child) {
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final composerBottomInset = showEmojiPanel ? 0.0 : keyboardInset;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: composerBottomInset),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KeyboardPromptBanner(
                        visible: keyboardInset > 0 && !showEmojiPanel,
                        text: 'Add a repost caption before sharing.',
                        icon: Icons.repeat_outlined,
                      ),
                      if (keyboardInset > 0 && !showEmojiPanel)
                        const SizedBox(height: 12),
                      const Text(
                        'Add an optional caption to your repost:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setDialogState(
                                () => showEmojiPanel = !showEmojiPanel,
                              );
                              if (showEmojiPanel) {
                                focusNode.unfocus();
                                SystemChannels.textInput.invokeMethod(
                                  'TextInput.hide',
                                );
                              } else {
                                FocusScope.of(context).requestFocus(focusNode);
                              }
                            },
                            icon: Icon(
                              showEmojiPanel
                                  ? Icons.keyboard_outlined
                                  : Icons.emoji_emotions_outlined,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: textController,
                              focusNode: focusNode,
                              onTap: () {
                                if (showEmojiPanel) {
                                  setDialogState(() => showEmojiPanel = false);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Write something...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                              maxLines: 3,
                              maxLength: 280,
                            ),
                          ),
                        ],
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        height: showEmojiPanel ? 180 : 0,
                        child: showEmojiPanel
                            ? GridView.builder(
                                padding: const EdgeInsets.only(top: 8),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 8,
                                      childAspectRatio: 1.2,
                                    ),
                                itemCount: _quickEmojis.length,
                                itemBuilder: (context, index) {
                                  final emoji = _quickEmojis[index];
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      final currentText = textController.text;
                                      final currentSelection =
                                          textController.selection;
                                      final start = currentSelection.start >= 0
                                          ? currentSelection.start
                                          : currentText.length;
                                      final end = currentSelection.end >= 0
                                          ? currentSelection.end
                                          : currentText.length;
                                      final newText = currentText.replaceRange(
                                        start,
                                        end,
                                        emoji,
                                      );
                                      textController.value = TextEditingValue(
                                        text: newText,
                                        selection: TextSelection.collapsed(
                                          offset: start + emoji.length,
                                        ),
                                      );
                                    },
                                    child: Center(
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, textController.text),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('Repost'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await _repostToFeed(caption: result.trim());
    }
    hasFocus.dispose();
    focusNode.dispose();
    textController.dispose();
  }

  Future<void> _confirmCopyToClipboard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy to Clipboard'),
        content: const Text('Are you sure you want to copy this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ShareService.copyToClipboard(widget.post);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
      }
    }
  }

  Future<void> _saveImageToGallery(String imageUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Saving image…')));
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      await Gal.putImageBytes(bytes, album: 'Starpage');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(content: Text('Image saved ✓')));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  void _showImageOptions(String imageUrl) {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Author Profile'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _openAuthorProfile();
              },
            ),
            if (_ownerId == widget.currentUserId)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Save Image'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _saveImageToGallery(imageUrl);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openAuthorProfile() {
    if (_ownerId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: _ownerId)),
    );
  }

  Future<void> _openCommentsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsBottomSheet(
        postId: widget.post.postId,
        postAuthorId: _ownerId,
        currentUserId: widget.currentUserId,
      ),
    );
  }

  Widget _buildFeedInteractionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveFeedInteractions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final isCompact = constraints.maxWidth < 380;
        final columns = isCompact ? 2 : 4;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        final actions = [
          _buildFeedInteractionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            label: '$_likeCount',
            iconColor: _isLiked ? Colors.red : null,
            onTap: _toggleLike,
          ),
          _buildFeedInteractionButton(
            icon: Icons.comment_outlined,
            label: '${widget.post.commentCount}',
            onTap: _openCommentsSheet,
          ),
          _buildFeedInteractionButton(
            icon: Icons.repeat,
            label: '${widget.post.repostCount}',
            onTap: _repostToFeed,
          ),
          _buildFeedInteractionButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: _showShareDialog,
          ),
        ];

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map((action) => SizedBox(width: itemWidth, child: action))
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
      final viewsToShow = _realtimeViewCount ?? widget.post.videoViewCount;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                      Expanded(
                        child: AnimationUtils.scaleButtonAnimation(
                          onTap: () async {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => CommentsBottomSheet(
                                postId: widget.post.postId,
                                postAuthorId: _ownerId,
                                currentUserId: widget.currentUserId,
                              ),
                            );
                          },
                          child: Semantics(
                            label: 'View comments',
                            button: true,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.comment_outlined, size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.post.commentCount}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (widget.post.videoUrl != null && widget.post.videoUrl!.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.visibility, size: 22, color: Colors.blueGrey),
                                  const SizedBox(width: 4),
                                  Text('$viewsToShow', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                              Text(
                                _ownerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_isSharedPost)
                                Text(
                                  'Shared by ${widget.post.authorName}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (widget.post.talent != null)
                                Text(
                                  widget.post.talent!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_ownerId != widget.currentUserId) ...[
                        const SizedBox(width: 8),
                        Semantics(
                          label: _isFollowing
                              ? 'Unfollow $_ownerName'
                              : 'Follow $_ownerName',
                          button: true,
                          child: _buildFollowButton(),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  timeago.format(widget.post.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                // Menu button for post owner
                if (widget.post.authorId == widget.currentUserId)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editPost();
                      } else if (value == 'delete') {
                        _deletePost();
                      }
                    },
                    itemBuilder: (context) => [
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
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Original Content (for reposts, show as attribution)
            if (widget.post.repostCaption != null) ...[
              GestureDetector(
                onTap: _showPostDetailsSheet,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original post by ${widget.post.originalAuthorName ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ExpandableText(
                        widget.post.content,
                        style: Theme.of(context).textTheme.bodySmall,
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ExpandableText(
                        widget.post.repostCaption!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              // Regular post content
              GestureDetector(
                onTap: _showPostDetailsSheet,
                child: ExpandableText(
                  widget.post.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  trimLines: 3,
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Audio player
            if (widget.post.audioUrl != null && widget.post.audioUrl!.isNotEmpty) ...[
              AudioPlayerWidget(audioUrl: widget.post.audioUrl!),
              const SizedBox(height: 12),
            ],
            // Video player
            if (widget.post.videoUrl != null && widget.post.videoUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: VideoPlayerWidget(
                  videoUrl: widget.post.videoUrl!,
                  autoPlay: false,
                  looping: false,
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Images
            if (widget.post.imageUrls.isNotEmpty)
              widget.post.imageUrls.length == 1
                  ? GestureDetector(
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
                      onLongPress: () =>
                          _showImageOptions(widget.post.imageUrls.first),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 420),
                          color: Colors.black.withValues(alpha: 0.04),
                          child: Image.network(
                            widget.post.imageUrls.first,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                height: 220,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox(
                                height: 220,
                                child: Center(
                                  child: Icon(Icons.broken_image, size: 36),
                                ),
                              );
                            },
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
                              onLongPress: () => _showImageOptions(imageUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  height: 200,
                                  width: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            const SizedBox(height: 12),
            _buildResponsiveFeedInteractions(),
          ],
        ),
      ),
    );
  }
}

// ── Fullscreen image gallery ───────────────────────────────────────────────
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
  bool _isSaving = false;

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

  Future<void> _saveCurrentImage() async {
    setState(() => _isSaving = true);
    try {
      final url = widget.imageUrls[_currentIndex];
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      await Gal.putImageBytes(bytes, album: 'Starpage');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image saved ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
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
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (widget.canSaveImages)
            IconButton(
              tooltip: 'Save image',
              onPressed: _isSaving ? null : _saveCurrentImage,
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
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.imageUrls[index],
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
                      size: 48,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// Audio player widget removed for build troubleshooting

// ── Video player widget ────────────────────────────────────────────────────
// Video player widget removed for AGP 9+ compatibility
