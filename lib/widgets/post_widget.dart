import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gal/gal.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../services/share_service.dart';
import '../services/analytics_service.dart';
import '../utils/auth_guard.dart';
import '../utils/time_utils.dart';
import '../utils/mention_utils.dart';
// import '../utils/screen_awake_controller.dart';
import '../screens/profile_screen.dart';
import 'comments_bottom_sheet.dart';
import 'post_details_sheet.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'expandable_text.dart';
import 'keyboard_prompt_banner.dart';
import 'video_player_widget.dart';
import 'audio_player_widget.dart';

class PostWidget extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final bool isTabVisible;
  final bool autoPlayEnabled;

  const PostWidget({
    super.key,
    required this.post,
    required this.currentUserId,
    this.isTabVisible = true,
    this.autoPlayEnabled = true,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late bool _isLiked;
  late int _likeCount;
  late int _viewCount;
  bool _isLikeUpdating = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isReposting = false;
  bool _isMutedLocally = false;
  bool _isDeleting = false;
  bool _isReposted = false;
  bool _showLikeHeart = false;
  bool _isCommentSheetOpen = false;
  late AnimationController _heartAnimationController;

  final GlobalKey<VideoPlayerWidgetState> _videoPlayerKey =
      GlobalKey<VideoPlayerWidgetState>();
  final GlobalKey<AudioPlayerWidgetState> _audioPlayerKey =
      GlobalKey<AudioPlayerWidgetState>();

  @override
  bool get wantKeepAlive => true;

  static const List<String> _quickEmojis = [
    '😀', '😁', '😂', '🤣', '😊', '😍', '🥳', '😎', '🤔', '👏', '🔥', '💯', '✨', '🙌', '👍', '🙏', '❤️', '💙', '💚', '🎉', '😢', '😡', '🤝', '💫',
  ];

  bool get _isSharedPost =>
      (widget.post.originalAuthorId ?? '').trim().isNotEmpty;

  String get _ownerId => _isSharedPost
      ? widget.post.originalAuthorId!.trim()
      : widget.post.authorId;

  String get _ownerName => _isSharedPost
      ? (widget.post.originalAuthorName ?? widget.post.authorName).trim()
      : widget.post.authorName;

  String? get _ownerImageUrl => _isSharedPost
      ? widget.post.originalAuthorImageUrl
      : widget.post.authorImageUrl;

  void _showPostDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => PostDetailsSheet(
          post: widget.post,
          currentUserId: widget.currentUserId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(widget.currentUserId);
    _likeCount = widget.post.likeCount;
    _viewCount = widget.post.videoViewCount;
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkRepostStatus();
    if (_ownerId != widget.currentUserId) {
      _checkFollowState();
    }
  }

  Future<void> _checkRepostStatus() async {
    if (widget.currentUserId.isEmpty) return;
    final hasReposted = await PostService().hasUserReposted(widget.post.postId, widget.currentUserId);
    if (mounted) {
      setState(() {
        _isReposted = hasReposted;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerKey.currentState?.pause();
    _audioPlayerKey.currentState?.pause();
    _heartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleDoubleTap() async {
    if (!_isLiked) {
      await _toggleLike();
    }
    if (mounted) {
      setState(() => _showLikeHeart = true);
      _heartAnimationController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _showLikeHeart = false);
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
    // Only update view count from widget if it's strictly greater to avoid race conditions with local increments
    if (widget.post.videoViewCount > _viewCount) {
      _viewCount = widget.post.videoViewCount;
    }

    // Handle tab visibility changes: pause if tab is hidden
    if (!widget.isTabVisible && oldWidget.isTabVisible) {
      _videoPlayerKey.currentState?.pause();
      _audioPlayerKey.currentState?.pause();
    }
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

  Future<void> _showShareOptions() async {
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
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Share on WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareViaWhatsApp(widget.post);
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
                  _downloadVideo();
                },
              ),
            const SizedBox(height: 20),
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

      // Check if already reposted
      if (_isReposted) {
        await postService.undoRepost(
          originalPostId: widget.post.postId,
          reposterId: widget.currentUserId,
        );
        if (mounted) {
          setState(() => _isReposted = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Repost removed ✓')),
          );
        }
      } else {
        final repostId = await postService.repostPost(
          originalPost: widget.post,
          reposterId: widget.currentUserId,
          reposterName: actorName,
          reposterUsername: currentUser.username,
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
              postId: repostId,
              content: '$actorName reposted your content',
            );
          } catch (e) {
            debugPrint('Repost notification skipped: $e');
          }
        }

        if (mounted) {
          setState(() => _isReposted = true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reposted to your feed ✓')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isReposting = false);
      }
    }
  }

  Future<void> _toggleSave() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    try {
      final userService = UserService();
      final savedIds = await userService.getSavedPostIds(widget.currentUserId);
      final bool isSaved = savedIds.contains(widget.post.postId);

      if (isSaved) {
        await userService.unsavePost(widget.currentUserId, widget.post.postId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Removed from Saved ✓')));
        }
      } else {
        await userService.savePost(widget.currentUserId, widget.post.postId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Added to Saved ✓')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _editPost() {
    debugPrint('_editPost called for post: ${widget.post.postId}');
    debugPrint('Post content: ${widget.post.content}');
    debugPrint('Navigating to /edit-post with arguments');
    Navigator.of(context).pushNamed('/edit-post', arguments: widget.post);
  }

  Future<void> _downloadVideo() async {
    if (widget.post.videoUrl == null || widget.post.videoUrl!.isEmpty) return;

    // Strict Security: Only the original content creator can download
    final originalAuthorId =
        widget.post.originalAuthorId ?? widget.post.authorId;
    if (originalAuthorId != widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the original author can download this video.'),
        ),
      );
      return;
    }

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
      setState(() => _isDeleting = true);
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
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
        }
      }
    }
  }

  Future<void> _mutePost() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mute Post'),
        content: const Text(
          'Are you sure you want to hide this post from your feed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Mute'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isMutedLocally = true);
      try {
        await UserService().mutePost(widget.currentUserId, widget.post.postId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Post muted ✓')));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isMutedLocally = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _muteAuthor() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mute $_ownerName'),
        content: Text(
          'Are you sure you want to hide all posts from $_ownerName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Mute'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isMutedLocally = true);
      try {
        await UserService().muteAuthor(widget.currentUserId, _ownerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Posts from $_ownerName muted ✓')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isMutedLocally = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      builder: (context) {
        bool listenerAdded = false;
        // Mention state
        List<UserModel> mentionableUsers = [];
        List<UserModel> filteredMentionUsers = [];
        String? activeMentionQuery;
        bool isLoadingMentionUsers = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {

          Future<void> ensureMentionableUsersLoaded() async {
            if (mentionableUsers.isNotEmpty || isLoadingMentionUsers) return;
            isLoadingMentionUsers = true;
            try {
              final users = await UserService().getAllUsers();
              mentionableUsers = users;
            } finally {
              isLoadingMentionUsers = false;
            }
          }

          void handleMentionInputChanged() async {
            final query = MentionUtils.activeMentionQuery(
              textController.text,
              textController.selection,
            );

            if (query == null) {
              if (activeMentionQuery != null || filteredMentionUsers.isNotEmpty) {
                setDialogState(() {
                  activeMentionQuery = null;
                  filteredMentionUsers = const [];
                });
              }
              return;
            }

            await ensureMentionableUsersLoaded();
            final normalizedQuery = query.toLowerCase();
            final currentUserId = widget.currentUserId;
            final matchingUsers = mentionableUsers
                .where((user) {
                  if (user.uid == currentUserId) return false;
                  final handle = user.username ??
                      MentionUtils.normalizeDisplayNameToHandle(user.displayName);
                  return normalizedQuery.isEmpty ||
                      handle.startsWith(normalizedQuery) ||
                      user.displayName.toLowerCase().contains(normalizedQuery);
                })
                .take(5)
                .toList();

            setDialogState(() {
              activeMentionQuery = query;
              filteredMentionUsers = matchingUsers;
            });
          }

          if (!listenerAdded) {
            textController.addListener(handleMentionInputChanged);
            listenerAdded = true;
          }

          void insertMentionHandle(String handle) {
            final nextValue = MentionUtils.insertMention(
              text: textController.text,
              selection: textController.selection,
              handle: handle,
            );
            textController.value = nextValue;
            setDialogState(() {
              activeMentionQuery = null;
              filteredMentionUsers = const [];
            });
          }

          Widget buildMentionSuggestions() {
            if (activeMentionQuery == null) return const SizedBox.shrink();
            final theme = Theme.of(context);
            final showFollowers =
                'followers'.startsWith(activeMentionQuery!.toLowerCase());
            if (!showFollowers && filteredMentionUsers.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showFollowers)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.campaign_outlined),
                      title: const Text('@followers'),
                      onTap: () => insertMentionHandle('followers'),
                    ),
                  ...filteredMentionUsers.map((user) {
                    final handle = user.username ??
                        MentionUtils.normalizeDisplayNameToHandle(user.displayName);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundImage: user.profileImageUrl != null
                            ? CachedNetworkImageProvider(user.profileImageUrl!)
                            : null,
                        child: user.profileImageUrl == null
                            ? const Icon(Icons.person, size: 14)
                            : null,
                      ),
                      title: Text(user.displayName, style: const TextStyle(fontSize: 12)),
                      subtitle: Text('@$handle', style: const TextStyle(fontSize: 10)),
                      onTap: () => insertMentionHandle(handle),
                    );
                  }),
                ],
              ),
            );
          }

          return AlertDialog(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        buildMentionSuggestions(),
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
          );
        },
      );
    },
  );

    if (result != null && mounted) {
      await _repostToFeed(caption: result.trim());
    }
    hasFocus.dispose();
    focusNode.dispose();
    textController.dispose();
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
            if ((widget.post.originalAuthorId ?? widget.post.authorId) ==
                widget.currentUserId)
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

  void _openGallery(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageGallery(
          imageUrls: widget.post.imageUrls,
          initialIndex: index,
          canSaveImages:
              (widget.post.originalAuthorId ?? widget.post.authorId) ==
              widget.currentUserId,
        ),
      ),
    );
  }

  Widget _buildGridItem(String url, int index, double width, double height) {
    return GestureDetector(
      onTap: () => _openGallery(index),
      onLongPress: () => _showImageOptions(url),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheHeight: 600,
        memCacheWidth: 600,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.black12,
          child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    final urls = widget.post.imageUrls;
    if (urls.isEmpty) return const SizedBox.shrink();

    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => _openGallery(0),
        onLongPress: () => _showImageOptions(urls.first),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 420),
            color: Colors.black.withValues(alpha: 0.04),
            child: CachedNetworkImage(
              imageUrl: urls.first,
              fit: BoxFit.contain,
              memCacheHeight: 800,
              placeholder: (context, url) => const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => const SizedBox(
                height: 220,
                child: Center(child: Icon(Icons.broken_image, size: 36)),
              ),
            ),
          ),
        ),
      );
    }

    // Grid layout for multiple images
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = 2.0;
          final double totalWidth = constraints.maxWidth;

          if (urls.length == 2) {
            final double itemWidth = (totalWidth - spacing) / 2;
            return Row(
              children: [
                _buildGridItem(urls[0], 0, itemWidth, 200),
                const SizedBox(width: spacing),
                _buildGridItem(urls[1], 1, itemWidth, 200),
              ],
            );
          } else if (urls.length == 3) {
            final double itemWidth = (totalWidth - spacing) / 2;
            return Column(
              children: [
                _buildGridItem(urls[0], 0, totalWidth, 200),
                const SizedBox(height: spacing),
                Row(
                  children: [
                    _buildGridItem(urls[1], 1, itemWidth, 150),
                    const SizedBox(width: spacing),
                    _buildGridItem(urls[2], 2, itemWidth, 150),
                  ],
                ),
              ],
            );
          } else {
            // 4 or more images
            final double itemWidth = (totalWidth - spacing) / 2;
            return Column(
              children: [
                Row(
                  children: [
                    _buildGridItem(urls[0], 0, itemWidth, 150),
                    const SizedBox(width: spacing),
                    _buildGridItem(urls[1], 1, itemWidth, 150),
                  ],
                ),
                const SizedBox(height: spacing),
                Row(
                  children: [
                    _buildGridItem(urls[2], 2, itemWidth, 150),
                    const SizedBox(width: spacing),
                    Stack(
                      children: [
                        _buildGridItem(urls[3], 3, itemWidth, 150),
                        if (urls.length > 4)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () => _openGallery(3),
                              child: Container(
                                color: Colors.black45,
                                child: Center(
                                  child: Text(
                                    '+${urls.length - 4}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Future<void> _openCommentsSheet({String? postContent}) async {
    if (!mounted) return;
    setState(() => _isCommentSheetOpen = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => CommentsBottomSheet(
          postId: widget.post.postId,
          postAuthorId: _ownerId,
          currentUserId: widget.currentUserId,
          postContent: postContent,
          scrollController: scrollController,
        ),
      ),
    );
    if (mounted) setState(() => _isCommentSheetOpen = false);
  }

  Widget _buildResponsiveFeedInteractions() {
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.postId)
          .snapshots(),
      builder: (context, snapshot) {
        // Use stream data if available, fallback to widget.post
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
          
          // Sync local state for optimistic UI if needed, but carefully
          if (!_isLikeUpdating) {
            _isLiked = isLiked;
            _likeCount = likeCount;
          }
        }

        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: DefaultTabController(
            length: 4,
            child: TabBar(
              onTap: (index) {
                if (index == 0) _toggleLike();
                if (index == 1) {
                  _openCommentsSheet(postContent: widget.post.content);
                }
                if (index == 2) _confirmRepost();
                if (index == 3) _showShareOptions();
              },
              indicatorColor: Colors.transparent,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: theme.textTheme.labelSmall,
              indicatorWeight: 0.1,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  height: 48,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : null,
                    size: 20,
                  ),
                  child: Text('$likeCount', style: const TextStyle(fontSize: 10)),
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
                const Tab(
                  height: 48,
                  icon: Icon(Icons.share_outlined, size: 20),
                  child: Text('Share', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isMutedLocally) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: _isDeleting ? 0.4 : 1.0,
            duration: const Duration(milliseconds: 300),
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
                      child: Semantics(
                        label: 'View profile of $_ownerName',
                        button: true,
                        child: CircleAvatar(
                          backgroundImage: _ownerImageUrl != null
                              ? CachedNetworkImageProvider(_ownerImageUrl!)
                              : null,
                          child: _ownerImageUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
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
                      TimeUtils.formatShorthand(widget.post.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    // Menu button for post management
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editPost();
                        } else if (value == 'delete') {
                          _deletePost();
                        } else if (value == 'download') {
                          _downloadVideo();
                        } else if (value == 'save') {
                          _toggleSave();
                        } else if (value == 'mute_post') {
                          _mutePost();
                        } else if (value == 'mute_author') {
                          _muteAuthor();
                        }
                      },
                      itemBuilder: (context) => [
                        // Save is available for everyone
                        const PopupMenuItem(
                          value: 'save',
                          child: Row(
                            children: [
                              Icon(Icons.bookmark_border),
                              SizedBox(width: 8),
                              Text('Save / Unsave'),
                            ],
                          ),
                        ),
                        if (widget.post.videoUrl != null &&
                            widget.post.videoUrl!.isNotEmpty &&
                            (widget.post.originalAuthorId ??
                                    widget.post.authorId) ==
                                widget.currentUserId)
                          const PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download),
                                SizedBox(width: 8),
                                Text('Download Video'),
                              ],
                            ),
                          ),
                        if (widget.post.authorId == widget.currentUserId) ...[
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
                        ] else ...[
                          const PopupMenuItem(
                            value: 'mute_post',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_off_outlined),
                                SizedBox(width: 8),
                                Text('Mute this post'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'mute_author',
                            child: Row(
                              children: [
                                const Icon(Icons.person_off_outlined),
                                const SizedBox(width: 8),
                                Text('Mute $_ownerName'),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Wrap content in GestureDetector for double tap
                GestureDetector(
                  onDoubleTap: _handleDoubleTap,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  onTap: _showPostDetailsSheet,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
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
                                onTap: _showPostDetailsSheet,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        // Regular post post content
                        ExpandableText(
                          widget.post.content,
                          style: Theme.of(context).textTheme.bodyMedium,
                          trimLines: 3,
                          onTap: _showPostDetailsSheet,
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Audio player
                      if (widget.post.audioUrl != null &&
                          widget.post.audioUrl!.isNotEmpty) ...[
                        VisibilityDetector(
                          key: ValueKey('post_audio_${widget.post.postId}'),
                          onVisibilityChanged: (info) {
                            if (!widget.isTabVisible || _isCommentSheetOpen) return;
                            if (info.visibleFraction < 0.3) {
                              _audioPlayerKey.currentState?.pause();
                            }
                          },
                          child: AudioPlayerWidget(
                            key: _audioPlayerKey,
                            audioUrl: widget.post.audioUrl!,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Video player
                      if (widget.post.videoUrl != null &&
                          widget.post.videoUrl!.isNotEmpty) ...[
                        VisibilityDetector(
                          key: ValueKey('post_video_${widget.post.postId}'),
                          onVisibilityChanged: (info) {
                            if (!widget.isTabVisible || _isCommentSheetOpen) return;
                            if (info.visibleFraction > 0.8) {
                              if (widget.autoPlayEnabled) {
                                _videoPlayerKey.currentState?.play();
                              }
                            } else if (info.visibleFraction < 0.2) {
                              _videoPlayerKey.currentState?.pause();
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: VideoPlayerWidget(
                              key: _videoPlayerKey,
                              videoUrl: widget.post.videoUrl!,
                              autoPlay: widget.autoPlayEnabled,
                              looping: true,
                              muted: true, // Start muted for inline playback
                              post: widget.post,
                              currentUserId: widget.currentUserId,
                              onPlay: () {
                                AnalyticsService().trackView(
                                  widget.post.postId,
                                  widget.post.authorId,
                                );
                                if (mounted) {
                                  setState(() {
                                    _viewCount++;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                          child: StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('posts')
                                .doc(widget.post.postId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              int viewCount = _viewCount;
                              if (snapshot.hasData && snapshot.data!.exists) {
                                viewCount = snapshot.data!.get('videoViewCount') ?? 0;
                                _viewCount = viewCount;
                              }
                              return Row(
                                children: [
                                  const Icon(
                                    Icons.remove_red_eye_outlined,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$viewCount views',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Images
                      _buildImageGallery(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildResponsiveFeedInteractions(),
              ],
            ),
          ),
        ),
          // Deleting Overlay
          if (_isDeleting)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 8),
                      Text(
                        'Deleting...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Heart Animation Overlay
          if (_showLikeHeart)
            Positioned.fill(
              child: Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.0, end: 1.2).animate(
                    CurvedAnimation(
                      parent: _heartAnimationController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 100,
                    shadows: [
                      Shadow(blurRadius: 10, color: Colors.black45)
                    ],
                  ),
                ),
              ),
            ),
        ],
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
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
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
