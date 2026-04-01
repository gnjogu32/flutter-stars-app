import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/post_model.dart';
import '../services/notification_service.dart';
import '../services/repost_queue_service.dart';
import '../services/analytics_service.dart';
import '../utils/screen_awake_controller.dart';
import '../utils/auth_guard.dart';
import '../services/share_service.dart';
import '../services/user_service.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/expandable_text.dart';
import '../widgets/keyboard_prompt_banner.dart';
import 'profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  final ValueNotifier<bool> tabActiveNotifier;

  const ReelsScreen({super.key, required this.tabActiveNotifier});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PageController _pageController = PageController();
  int _activeIndex = 0;
  // Tracks whether this tab is the currently visible one.
  bool _tabVisible = false;

  @override
  void initState() {
    super.initState();
    _tabVisible = widget.tabActiveNotifier.value;
    widget.tabActiveNotifier.addListener(_onTabVisibilityChanged);
  }

  void _onTabVisibilityChanged() {
    final visible = widget.tabActiveNotifier.value;
    if (mounted) setState(() => _tabVisible = visible);
  }

  @override
  void dispose() {
    widget.tabActiveNotifier.removeListener(_onTabVisibilityChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .where('videoUrl', isNull: false)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading reels: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            );
          }

          final reels = (snapshot.data?.docs ?? [])
              .map(
                (doc) => PostModel.fromJson(doc.data() as Map<String, dynamic>),
              )
              .where((post) => (post.videoUrl ?? '').trim().isNotEmpty)
              .toList();

          if (reels.isEmpty) {
            return const Center(
              child: Text(
                'No reels yet',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }

          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            onPageChanged: (index) {
              setState(() => _activeIndex = index);
              // Track view for the visible reel
              final analyticsService = AnalyticsService();
              final currentReel = reels[index];
              analyticsService.trackView(
                currentReel.postId,
                currentReel.authorId,
              );
            },
            itemBuilder: (context, index) {
              final reel = reels[index];
              return _ReelItem(
                post: reel,
                isActive: _tabVisible && index == _activeIndex,
                currentUserId: currentUserId,
                onOpenProfile: () {
                  final userId = (reel.originalAuthorId ?? reel.authorId)
                      .trim();
                  if (userId.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: userId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final PostModel post;
  final bool isActive;
  final VoidCallback onOpenProfile;
  final String currentUserId;

  const _ReelItem({
    required this.post,
    required this.isActive,
    required this.onOpenProfile,
    required this.currentUserId,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _holdsScreenAwake = false;
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isReposting = false;

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

  String get _activeUserId => widget.currentUserId.trim();

  bool get _canInteract => _activeUserId.isNotEmpty;

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

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(_activeUserId);
    _likeCount = widget.post.likeCount;
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.post.videoUrl!))
          ..addListener(_syncScreenAwakeWithPlayback)
          ..setLooping(true)
          ..initialize().then((_) async {
            if (!mounted) return;
            setState(() => _isInitialized = true);
            if (widget.isActive) {
              await _controller.play();
              _syncScreenAwakeWithPlayback();
            }
          });
  }

  @override
  void didUpdateWidget(covariant _ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isLikeUpdating) {
      _isLiked = widget.post.isLikedBy(_activeUserId);
      _likeCount = widget.post.likeCount;
    }

    if (!_isInitialized) return;

    if (widget.isActive && !oldWidget.isActive) {
      _controller.play();
      _syncScreenAwakeWithPlayback();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.pause();
      _syncScreenAwakeWithPlayback();
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating) return;
    if (!await AuthGuard.check(context, _activeUserId)) return;

    final notificationService = NotificationService();
    final userService = UserService();
    final analyticsService = AnalyticsService();
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
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.postId)
            .update({
              'likes': FieldValue.arrayRemove([_activeUserId]),
            });
        // Track unlike in analytics
        await analyticsService.trackUnlike(widget.post.postId, _activeUserId);
      } else {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.postId)
            .update({
              'likes': FieldValue.arrayUnion([_activeUserId]),
            });
        // Track like in analytics
        await analyticsService.trackLike(
          widget.post.postId,
          _ownerId,
          _activeUserId,
        );

        if (_activeUserId != _ownerId) {
          final currentUser = await userService.getUser(_activeUserId);
          if (currentUser != null) {
            await notificationService.createNotification(
              userId: _ownerId,
              triggeredBy: _activeUserId,
              triggeredByName: currentUser.displayName,
              triggeredByImageUrl: currentUser.profileImageUrl,
              type: 'like_post',
              postId: widget.post.postId,
              content: '${currentUser.displayName} liked your post',
            );
          }
        }
      }

      if (!mounted) return;
      setState(() => _isLikeUpdating = false);
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _repostToFeed({
    String caption = '',
    DateTime? scheduleTime,
  }) async {
    if (_isReposting) return;
    if (_activeUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    setState(() => _isReposting = true);

    try {
      final userService = UserService();
      final queueService = RepostQueueService();
      final analyticsService = AnalyticsService();
      final notificationService = NotificationService();

      final currentUser = await userService.getUser(_activeUserId);
      if (currentUser == null) {
        throw Exception('Could not load your profile for reposting.');
      }

      final actorName = currentUser.displayName.trim().isEmpty
          ? 'Someone'
          : currentUser.displayName.trim();

      // If scheduling for future, queue it; otherwise post immediately
      await queueService.queueRepost(
        userId: _activeUserId,
        postId: widget.post.postId,
        originalAuthorId: widget.post.authorId,
        userName: actorName,
        userImageUrl: currentUser.profileImageUrl,
        post: widget.post,
        caption: caption,
        scheduleTime: scheduleTime, // Null = post immediately
      );

      // Track repost in analytics (regardless of schedule)
      await analyticsService.trackRepost(
        widget.post.postId,
        _ownerId,
        _activeUserId,
      );

      if (_activeUserId != widget.post.authorId &&
          (scheduleTime == null ||
              scheduleTime.isBefore(
                DateTime.now().add(Duration(seconds: 1)),
              ))) {
        try {
          await notificationService.createNotification(
            userId: widget.post.authorId,
            triggeredBy: _activeUserId,
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
      if (scheduleTime != null && scheduleTime.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Repost scheduled for ${scheduleTime.year}-${scheduleTime.month}-${scheduleTime.day} ✓',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reposted to your feed ✓')),
        );
      }
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

  Future<void> _confirmRepost() async {
    if (_isReposting) return;
    final textController = TextEditingController();
    final focusNode = FocusNode();
    final hasFocus = ValueNotifier(false);
    var showEmojiPanel = false;
    DateTime? scheduleTime;

    focusNode.addListener(() {
      hasFocus.value = focusNode.hasFocus;
    });

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                        text:
                            'Add a repost caption before sharing or scheduling.',
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
                              setState(() => showEmojiPanel = !showEmojiPanel);
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
                                  setState(() => showEmojiPanel = false);
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
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Schedule (Optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.maxFinite,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                    const Duration(days: 1),
                                  ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (date != null && context.mounted) {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: const TimeOfDay(
                                      hour: 9,
                                      minute: 0,
                                    ),
                                  );
                                  if (time != null) {
                                    setState(() {
                                      scheduleTime = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                }
                              },
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                scheduleTime == null
                                    ? 'Post now'
                                    : 'Scheduled: ${scheduleTime!.year}-${scheduleTime!.month}-${scheduleTime!.day} ${scheduleTime!.hour}:${scheduleTime!.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                            if (scheduleTime != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => scheduleTime = null),
                                child: const Text('Remove schedule'),
                              ),
                          ],
                        ),
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
      await _repostToFeed(caption: result.trim(), scheduleTime: scheduleTime);
    }
    hasFocus.dispose();
    focusNode.dispose();
    textController.dispose();
  }

  Future<void> _openComments() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenCommentsPage(
          postId: widget.post.postId,
          postAuthorId: _ownerId,
          currentUserId: _activeUserId,
        ),
      ),
    );
  }
// --- Fullscreen Comments Page ---
class FullScreenCommentsPage extends StatelessWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;

  const FullScreenCommentsPage({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Comments'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CommentsBottomSheet(
          postId: postId,
          postAuthorId: postAuthorId,
          currentUserId: currentUserId,
        ),
      ),
    );
  }
}

  Future<void> _openInteractionsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.42,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.42, 0.85],
        builder: (context, scrollController) => _ReelInteractionsSheet(
          post: widget.post,
          isLiked: _isLiked,
          likeCount: _likeCount,
          isReposting: _isReposting,
          onLike: _toggleLike,
          onComments: _openComments,
          onRepost: _confirmRepost,
          onShare: _sharePost,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _sharePost() {
    ShareService.sharePost(widget.post);
    // Track share in analytics
    final analyticsService = AnalyticsService();
    if (_activeUserId.isNotEmpty) {
      analyticsService.trackShare(widget.post.postId, _ownerId, _activeUserId);
    }
  }

  @override
  void dispose() {
    if (_holdsScreenAwake) {
      ScreenAwakeController.release();
      _holdsScreenAwake = false;
    }
    _controller.removeListener(_syncScreenAwakeWithPlayback);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerName = (widget.post.originalAuthorName ?? widget.post.authorName)
        .trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isInitialized)
          GestureDetector(
            onTap: () {
              if (_controller.value.isPlaying) {
                _controller.pause();
                _syncScreenAwakeWithPlayback();
              } else {
                _controller.play();
                _syncScreenAwakeWithPlayback();
              }
            },
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InteractionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                iconColor: _isLiked ? Colors.redAccent : Colors.white,
                label: '$_likeCount',
                onTap: _toggleLike,
              ),
              const SizedBox(height: 14),
              _InteractionButton(
                icon: Icons.comment_outlined,
                label: '${widget.post.commentCount}',
                onTap: _openInteractionsSheet,
              ),
              const SizedBox(height: 14),
              _InteractionButton(
                icon: Icons.repeat,
                label: _isReposting ? '...' : '${widget.post.repostCount}',
                onTap: _confirmRepost,
              ),
              const SizedBox(height: 14),
              _InteractionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: _sharePost,
              ),
              if (!_canInteract) ...[
                const SizedBox(height: 10),
                const Text(
                  'Sign in',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onOpenProfile,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            (widget.post.originalAuthorImageUrl ??
                                    widget.post.authorImageUrl) !=
                                null
                            ? NetworkImage(
                                widget.post.originalAuthorImageUrl ??
                                    widget.post.authorImageUrl!,
                              )
                            : null,
                        child:
                            (widget.post.originalAuthorImageUrl ??
                                    widget.post.authorImageUrl) ==
                                null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ownerName.isEmpty ? 'Unknown' : ownerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${widget.post.videoViewCount} views',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                if (widget.post.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ExpandableText(
                    widget.post.content,
                    style: const TextStyle(color: Colors.white),
                    trimLines: 3,
                    actionStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_isInitialized) ...[
                  const SizedBox(height: 8),
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor ?? Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelInteractionsSheet extends StatefulWidget {
  final PostModel post;
  final bool isLiked;
  final int likeCount;
  final bool isReposting;
  final Future<void> Function() onLike;
  final Future<void> Function() onComments;
  final Future<void> Function() onRepost;
  final VoidCallback onShare;
  final ScrollController scrollController;

  const _ReelInteractionsSheet({
    required this.post,
    required this.isLiked,
    required this.likeCount,
    required this.isReposting,
    required this.onLike,
    required this.onComments,
    required this.onRepost,
    required this.onShare,
    required this.scrollController,
  });

  @override
  State<_ReelInteractionsSheet> createState() => _ReelInteractionsSheetState();
}

class _ReelInteractionsSheetState extends State<_ReelInteractionsSheet> {
  Future<void> _handleLike() async {
    await widget.onLike();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleComments() async {
    Navigator.of(context).pop();
    await widget.onComments();
  }

  Future<void> _handleRepost() async {
    Navigator.of(context).pop();
    await widget.onRepost();
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.post.content.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView(
          controller: widget.scrollController,
          children: [
            const Text(
              'Interactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (content.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (content.isNotEmpty) const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                widget.isLiked ? Icons.favorite : Icons.favorite_border,
                color: widget.isLiked ? Colors.redAccent : null,
              ),
              title: const Text('Like'),
              trailing: Text('${widget.likeCount}'),
              onTap: _handleLike,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.comment_outlined),
              title: const Text('Comments'),
              trailing: Text('${widget.post.commentCount}'),
              onTap: _handleComments,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat),
              title: const Text('Repost'),
              trailing: Text(
                widget.isReposting ? '...' : '${widget.post.repostCount}',
              ),
              onTap: _handleRepost,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                widget.onShare();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
