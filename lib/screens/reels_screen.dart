import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'full_screen_comments_page.dart';

import '../models/post_model.dart';
import '../services/notification_service.dart';
import '../services/repost_queue_service.dart';
import '../services/analytics_service.dart';
import '../utils/screen_awake_controller.dart';
import '../utils/auth_guard.dart';
import '../services/share_service.dart';
import '../services/user_service.dart';
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

  void _onReelEnd() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuad,
      );
    }
  }

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
            .where('postType', isEqualTo: 'video')
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
            physics: const BouncingScrollPhysics(),
            itemCount: reels.length,
            onPageChanged: (index) {
              setState(() => _activeIndex = index);
            },
            itemBuilder: (context, index) {
              final reel = reels[index];
              return _ReelItem(
                post: reel,
                isActive: _tabVisible && index == _activeIndex,
                currentUserId: currentUserId,
                onVideoEnd: _onReelEnd,
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
  final VoidCallback? onVideoEnd;

  const _ReelItem({
    required this.post,
    required this.isActive,
    required this.onOpenProfile,
    required this.currentUserId,
    this.onVideoEnd,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isReposting = false;
  bool _isMuted = false;
  bool _showLikeHeart = false;
  bool _showDetails = true;
  bool _endEventDispatched = false;
  late AnimationController _heartAnimationController;

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

  // Video player logic removed for AGP 9+ compatibility

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(_activeUserId);
    _likeCount = widget.post.likeCount;
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.videoUrl!),
    );
    try {
      await _videoController.initialize();
      await _videoController.setLooping(
        false,
      ); // Change to false for sequence playback
      if (mounted) {
        setState(() => _isInitialized = true);
        if (widget.isActive) {
          _videoController.play();
          ScreenAwakeController.acquire();
          // Track view for the first reel if active
          AnalyticsService().trackView(widget.post.postId, _ownerId);
        }

        _videoController.addListener(() {
          if (_isInitialized && !_videoController.value.isLooping) {
            final position = _videoController.value.position;
            final duration = _videoController.value.duration;
            if (position >= duration &&
                duration > Duration.zero &&
                !_endEventDispatched) {
              _endEventDispatched = true;
              widget.onVideoEnd?.call();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing reel video: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isLikeUpdating) {
      _isLiked = widget.post.isLikedBy(_activeUserId);
      _likeCount = widget.post.likeCount;
    }

    if (widget.isActive && !oldWidget.isActive) {
      _endEventDispatched = false;
      _videoController.play();
      ScreenAwakeController.acquire();
      AnalyticsService().trackView(widget.post.postId, _ownerId);
    } else if (!widget.isActive && oldWidget.isActive) {
      _videoController.pause();
      ScreenAwakeController.release();
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
          postContent: widget.post.content,
        ),
      ),
    );
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
    if (_isInitialized && _videoController.value.isPlaying) {
      ScreenAwakeController.release();
    }
    _videoController.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController.setVolume(_isMuted ? 0 : 1);
    });
  }

  Future<void> _downloadVideo() async {
    if (widget.post.videoUrl == null || widget.post.videoUrl!.isEmpty) return;

    // Strict Security: Only the original content creator can download
    final originalAuthorId =
        widget.post.originalAuthorId ?? widget.post.authorId;
    if (originalAuthorId != _activeUserId) {
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

  Future<void> _handleDoubleTap() async {
    if (!_isLiked) {
      await _toggleLike();
    }
    setState(() => _showLikeHeart = true);
    _heartAnimationController.forward(from: 0).then((_) {
      setState(() => _showLikeHeart = false);
    });
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
            onDoubleTap: _handleDoubleTap,
            onTap: () {
              setState(() {
                _showDetails = !_showDetails;
                if (_videoController.value.isPlaying) {
                  _videoController.pause();
                  ScreenAwakeController.release();
                } else {
                  _videoController.play();
                  ScreenAwakeController.acquire();
                }
              });
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Double tap heart animation
        if (_showLikeHeart)
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.2).animate(
                CurvedAnimation(
                  parent: _heartAnimationController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 100),
            ),
          ),

        AnimatedOpacity(
          opacity: _showDetails ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !_showDetails,
            child: Stack(
              children: [
                Positioned(
                  right: 12,
                  bottom: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _InteractionButton(
                        icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                        label: _isMuted ? 'Muted' : 'Mute',
                        onTap: _toggleMute,
                      ),
                      const SizedBox(height: 14),
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
                        label: _isReposting
                            ? '...'
                            : '${widget.post.repostCount}',
                        onTap: _confirmRepost,
                      ),
                      const SizedBox(height: 14),
                      _InteractionButton(
                        icon: Icons.share_outlined,
                        label: 'Share',
                        onTap: _sharePost,
                      ),
                      if ((widget.post.originalAuthorId ??
                              widget.post.authorId) ==
                          _activeUserId) ...[
                        const SizedBox(height: 14),
                        _InteractionButton(
                          icon: Icons.download_outlined,
                          label: 'Download',
                          onTap: _downloadVideo,
                        ),
                      ],
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
                  right: 60, // Leave space for the interaction sidebar
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
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
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
                                        ? CachedNetworkImageProvider(
                                            widget
                                                    .post
                                                    .originalAuthorImageUrl ??
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
                                onTap: _openComments,
                              ),
                            ],
                            if (_isInitialized)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: VideoProgressIndicator(
                                  _videoController,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                    playedColor: Colors.white,
                                    bufferedColor: Colors.white24,
                                    backgroundColor: Colors.white12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
    final theme = Theme.of(context);
    final content = widget.post.content.trim();

    return SafeArea(
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Interactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(content, style: theme.textTheme.bodyMedium),
              ),
            ),
          const Divider(height: 1),
          DefaultTabController(
            length: 4,
            child: TabBar(
              onTap: (index) {
                if (index == 0) _handleLike();
                if (index == 1) _handleComments();
                if (index == 2) _handleRepost();
                if (index == 3) {
                  widget.onShare();
                  Navigator.of(context).pop();
                }
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
                  height: 60,
                  icon: Icon(
                    widget.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: widget.isLiked ? Colors.redAccent : null,
                    size: 24,
                  ),
                  child: Text(
                    '${widget.likeCount}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Tab(
                  height: 60,
                  icon: const Icon(Icons.comment_outlined, size: 24),
                  child: Text(
                    '${widget.post.commentCount}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Tab(
                  height: 60,
                  icon: const Icon(Icons.repeat, size: 24),
                  child: Text(
                    widget.isReposting ? '...' : '${widget.post.repostCount}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const Tab(
                  height: 60,
                  icon: Icon(Icons.share_outlined, size: 24),
                  child: Text('Share', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
