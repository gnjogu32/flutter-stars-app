import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../models/post_model.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../services/share_service.dart';
import '../utils/animation_utils.dart';
import '../utils/auth_guard.dart';
import '../utils/screen_awake_controller.dart';
import '../screens/profile_screen.dart';
import 'comments_bottom_sheet.dart';
import 'expandable_text.dart';
import 'keyboard_prompt_banner.dart';
import 'full_screen_video_player.dart';

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
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isReposting = false;
  late int _videoViewCount;

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
                      Expanded(
                        child: AnimationUtils.scaleButtonAnimation(
                          onTap: () async {
                            Navigator.pop(context);
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
                      Expanded(
                        child: AnimationUtils.scaleButtonAnimation(
                          onTap: _repostToFeed,
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
                      Expanded(
                        child: AnimationUtils.scaleButtonAnimation(
                          onTap: () => _showShareDialog(),
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
    _videoViewCount = widget.post.videoViewCount;
    if (_ownerId != widget.currentUserId) {
      _checkFollowState();
    }
  }

  @override
  void didUpdateWidget(covariant PostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isLikeUpdating) {
      _isLiked = widget.post.isLikedBy(widget.currentUserId);
      _likeCount = widget.post.likeCount;
    }
    if (oldWidget.post.videoViewCount != widget.post.videoViewCount) {
      _videoViewCount = widget.post.videoViewCount;
    }
  }

  Future<void> _incrementVideoViewCount() async {
    if (widget.currentUserId.isEmpty || widget.post.postId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.postId)
          .update({'videoViewCount': FieldValue.increment(1)});
      if (mounted) {
        setState(() => _videoViewCount += 1);
      }
    } catch (e) {
      debugPrint('Video view count update skipped: $e');
    }
  }

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
                ? Colors.grey.shade400
                : Theme.of(context).colorScheme.primary,
          ),
          foregroundColor: _isFollowing ? Colors.grey.shade600 : null,
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Author info and time
            Row(
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        _buildFollowButton(),
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
            if (widget.post.audioUrl != null)
              _AudioPlayer(
                audioUrl: widget.post.audioUrl!,
                onOpenProfile: _openAuthorProfile,
                authorImageUrl: _ownerImageUrl,
                authorName: _ownerName,
                canSaveMedia: _ownerId == widget.currentUserId,
              ),
            if (widget.post.audioUrl != null) const SizedBox(height: 12),
            // Video player
            if (widget.post.videoUrl != null)
              _VideoPlayer(
                videoUrl: widget.post.videoUrl!,
                onOpenProfile: _openAuthorProfile,
                onOpenDetails: _showPostDetailsSheet,
                onFirstPlay: _incrementVideoViewCount,
                canSaveMedia: _ownerId == widget.currentUserId,
                enableFullscreen: true,
              ),
            if (widget.post.videoUrl != null) const SizedBox(height: 12),
            if (widget.post.videoUrl != null)
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_videoViewCount views',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            if (widget.post.videoUrl != null) const SizedBox(height: 12),
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

// ── Audio player widget ────────────────────────────────────────────────────
class _AudioPlayer extends StatefulWidget {
  final String audioUrl;
  final VoidCallback onOpenProfile;
  final String? authorImageUrl;
  final String authorName;
  final bool canSaveMedia;

  const _AudioPlayer({
    required this.audioUrl,
    required this.onOpenProfile,
    required this.authorImageUrl,
    required this.authorName,
    required this.canSaveMedia,
  });

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isSavingAudio = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });

    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAudio() async {
    if (_isSavingAudio) return;
    setState(() => _isSavingAudio = true);

    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      final uri = Uri.parse(widget.audioUrl);
      final path = uri.path.toLowerCase();
      final ext = path.endsWith('.m4a')
          ? 'm4a'
          : path.endsWith('.aac')
          ? 'aac'
          : path.endsWith('.wav')
          ? 'wav'
          : 'mp3';

      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);

      final targetDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Music/Starpage')
          : Directory('${Directory.systemTemp.path}/StarpageAudio');

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final file = File(
        '${targetDir.path}/starpage_audio_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Audio saved ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Audio save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBackground =
        widget.authorImageUrl != null && widget.authorImageUrl!.isNotEmpty;
    final sliderMax = _duration.inSeconds <= 0
        ? 1.0
        : _duration.inSeconds.toDouble();
    final sliderValue = _position.inSeconds.toDouble().clamp(0.0, sliderMax);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              image: hasBackground
                  ? DecorationImage(
                      image: NetworkImage(widget.authorImageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: hasBackground
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E1E1E), Color(0xFF3B3B3B)],
                    ),
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black45)),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: widget.onOpenProfile,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
              ),
            ),
          ),
          if (widget.canSaveMedia)
            Positioned(
              top: 10,
              left: 10,
              child: Material(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _isSavingAudio ? null : _saveAudio,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _isSavingAudio
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
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.authorName.trim().isEmpty
                        ? 'Audio by Author'
                        : 'Audio by ${widget.authorName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.white,
                          size: 34,
                        ),
                        onPressed: () async {
                          if (_isPlaying) {
                            await _audioPlayer.pause();
                          } else {
                            await _audioPlayer.setUrl(widget.audioUrl);
                            await _audioPlayer.play();
                          }
                        },
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white38,
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: sliderMax,
                            value: sliderValue,
                            onChanged: (value) async {
                              final newPosition = Duration(
                                seconds: value.toInt(),
                              );
                              await _audioPlayer.seek(newPosition);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Video player widget ────────────────────────────────────────────────────
class _VideoPlayer extends StatefulWidget {
  final bool enableFullscreen;
  final String videoUrl;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDetails;
  final Future<void> Function() onFirstPlay;
  final bool canSaveMedia;

  const _VideoPlayer({
    required this.videoUrl,
    required this.onOpenProfile,
    required this.onOpenDetails,
    required this.onFirstPlay,
    required this.canSaveMedia,
    this.enableFullscreen = true,
  });

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayer(videoUrl: widget.videoUrl),
      ),
    );
  }

  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isSavingVideo = false;
  bool _hasTrackedView = false;
  bool _holdsScreenAwake = false;

  void _syncScreenAwakeWithPlayback() {
    if (!_isInitialized) return;
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying && !_holdsScreenAwake) {
      ScreenAwakeController.acquire();
      _holdsScreenAwake = true;
    } else if (!isPlaying && _holdsScreenAwake) {
      ScreenAwakeController.release();
      _holdsScreenAwake = false;
    }
  }

  void _videoListener() {
    if (!mounted) return;
    _syncScreenAwakeWithPlayback();
    setState(() {
      // Rebuild on playback position/buffering changes.
    });
  }

  Future<void> _seekBy(Duration offset) async {
    final value = _controller.value;
    if (!value.isInitialized) return;

    final duration = value.duration;
    final target = value.position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    await _controller.seekTo(clamped);
  }

  Future<void> _togglePlayPause() async {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
      _syncScreenAwakeWithPlayback();
    } else {
      if (!_hasTrackedView) {
        _hasTrackedView = true;
        await widget.onFirstPlay();
      }
      await _controller.play();
      _syncScreenAwakeWithPlayback();
    }
  }

  Future<void> _saveVideo() async {
    setState(() => _isSavingVideo = true);
    try {
      final tempFile = File(
        '${Directory.systemTemp.path}/starpage_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.videoUrl));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      await tempFile.writeAsBytes(bytes);
      await Gal.putVideo(tempFile.path, album: 'Starpage');
      await tempFile.delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved to gallery ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingVideo = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize()
          .then((_) {
            if (!mounted) return;
            _controller.addListener(_videoListener);
            setState(() => _isInitialized = true);
          })
          .catchError((error) {
            debugPrint('Video initialization error: $error');
          });
  }

  @override
  void dispose() {
    if (_holdsScreenAwake) {
      ScreenAwakeController.release();
      _holdsScreenAwake = false;
    }
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: widget.onOpenDetails,
      onDoubleTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          // Video controls overlay
          if (_showControls)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black26,
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.replay_10,
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: () => _seekBy(const Duration(seconds: -10)),
                      ),
                      IconButton(
                        icon: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.white,
                          size: 56,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.forward_10,
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: () => _seekBy(const Duration(seconds: 10)),
                      ),
                      if (widget.enableFullscreen)
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 38,
                          ),
                          onPressed: _openFullScreen,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // Author details (bottom overlay)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onOpenProfile,
                    child: const CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person, color: Colors.white),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Author',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: widget.onOpenDetails,
                  ),
                ],
              ),
            ),
          ),
          // Right interactions column
          Positioned(
            right: 8,
            bottom: 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.redAccent,
                    size: 30,
                  ),
                  onPressed: () {}, // TODO: Hook up like action
                ),
                const SizedBox(height: 14),
                IconButton(
                  icon: const Icon(
                    Icons.comment_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {}, // TODO: Hook up comment action
                ),
                const SizedBox(height: 14),
                IconButton(
                  icon: const Icon(Icons.repeat, color: Colors.white, size: 28),
                  onPressed: () {}, // TODO: Hook up repost action
                ),
                const SizedBox(height: 14),
                IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {}, // TODO: Hook up share action
                ),
              ],
            ),
          ),
          // Profile and save icons (top corners)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: widget.onOpenProfile,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
              ),
            ),
          ),
          if (widget.canSaveMedia)
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _isSavingVideo ? null : _saveVideo,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _isSavingVideo
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download, color: Colors.white),
                  ),
                ),
              ),
            ),
          // Video progress bar (only with controls)
          if (_showControls)
            Positioned(
              bottom: 60,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Text(
                    _formatDuration(_controller.value.position),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                      ),
                      child: Slider(
                        min: 0,
                        max:
                            (_controller.value.duration.inMilliseconds <= 0
                                    ? 1
                                    : _controller.value.duration.inMilliseconds)
                                .toDouble(),
                        value: _controller.value.position.inMilliseconds
                            .clamp(
                              0,
                              _controller.value.duration.inMilliseconds <= 0
                                  ? 1
                                  : _controller.value.duration.inMilliseconds,
                            )
                            .toDouble(),
                        onChanged: (value) {
                          _controller.seekTo(
                            Duration(milliseconds: value.toInt()),
                          );
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatDuration(_controller.value.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
