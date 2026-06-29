import 'dart:async';
import 'dart:io';
import 'dart:math';
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
  final FirebaseFirestore? firestore;

  const ReelsScreen({
    super.key,
    required this.tabActiveNotifier,
    this.firestore,
  });

  @override
  State<ReelsScreen> createState() => ReelsScreenState();
}

class ReelsScreenState extends State<ReelsScreen> {
  late final FirebaseFirestore _firestore;
  static const int _infiniteLoopOffset = 10000;
  int _refreshSeed = Random().nextInt(1000000);
  late final PageController _pageController;
  int _activeIndex = _infiniteLoopOffset;
  // Tracks whether this tab is the currently visible one.
  bool _tabVisible = false;

  final Map<int, VideoPlayerController> _preloadedControllers = {};
  // Cache for shuffled blocks to ensure smooth scrolling
  final Map<int, List<PostModel>> _shuffledBlocksCache = {};
  List<PostModel>? _cachedReels;

  @override
  void initState() {
    super.initState();
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _tabVisible = widget.tabActiveNotifier.value;
    _pageController = PageController(initialPage: _infiniteLoopOffset);
    widget.tabActiveNotifier.addListener(_onTabVisibilityChanged);
  }

  @visibleForTesting
  int get refreshSeed => _refreshSeed;

  void refreshReels() {
    _disposeAllPreloaded();
    _shuffledBlocksCache.clear();
    setState(() {
      _refreshSeed = Random().nextInt(1000000);
      _cachedReels = null;
      _activeIndex = _infiniteLoopOffset;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_infiniteLoopOffset);
    }
  }

  void _disposeAllPreloaded() {
    for (final controller in _preloadedControllers.values) {
      controller.dispose();
    }
    _preloadedControllers.clear();
  }

  void _preloadAdjacent(int index, List<PostModel> reels) {
    if (reels.isEmpty) return;

    // We preload the current, next and previous to ensure zero-lag swipes
    final indicesToPreload = [index, index + 1, index - 1];

    // Clean up controllers far away from current index
    _preloadedControllers.removeWhere((idx, controller) {
      if (!indicesToPreload.contains(idx)) {
        controller.dispose();
        return true;
      }
      return false;
    });

    for (final idx in indicesToPreload) {
      if (!_preloadedControllers.containsKey(idx)) {
        final post = _getReelAtGlobalIndex(idx, reels);
        if (post.videoUrl != null && post.videoUrl!.isNotEmpty) {
          final controller = VideoPlayerController.networkUrl(
            Uri.parse(post.videoUrl!),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          _preloadedControllers[idx] = controller;
          controller.initialize().then((_) {
            if (mounted) setState(() {});
          });
        }
      }
    }
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
          if (snapshot.connectionState == ConnectionState.waiting && _cachedReels == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError && _cachedReels == null) {
            return Center(
              child: Text(
                'Error loading reels: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.hasData) {
            final latestReels = (snapshot.data?.docs ?? [])
                .map(
                  (doc) => PostModel.fromJson(doc.data() as Map<String, dynamic>),
                )
                .where((post) => (post.videoUrl ?? '').trim().isNotEmpty)
                .toList();

            // Initial load or refresh
            if (_cachedReels == null || _cachedReels!.isEmpty) {
              _cachedReels = latestReels;
            } else {
              // Background update: only add truly new items to avoid jumping
              final existingIds = _cachedReels!.map((r) => r.postId).toSet();
              final newItems = latestReels.where((r) => !existingIds.contains(r.postId)).toList();
              if (newItems.isNotEmpty) {
                // Add new items but don't re-shuffle current block yet to prevent jumping
                _cachedReels!.addAll(newItems);
              }
            }
          }

          final reels = _cachedReels ?? [];

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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            onPageChanged: (index) {
              setState(() => _activeIndex = index);
              _preloadAdjacent(index, reels);
            },
            itemBuilder: (context, index) {
              final reel = _getReelAtGlobalIndex(index, reels);
              return _ReelItem(
                key: ValueKey('reel_${reel.postId}_$index'),
                post: reel,
                isActive: _tabVisible && index == _activeIndex,
                currentUserId: currentUserId,
                preloadedController: _preloadedControllers[index],
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

  PostModel _getReelAtGlobalIndex(int index, List<PostModel> source) {
    if (source.isEmpty) return PostModel.empty();

    final int length = source.length;
    final int localIndex = ((index % length) + length) % length;

    // Use floor division so negative indexes map to stable shuffle blocks too.
    final int blockIndex = index >= 0
        ? (index ~/ length)
        : -(((-index - 1) ~/ length) + 1);
    final int blockSeed = _refreshSeed ^ blockIndex;

    // Use cached block list if available to avoid expensive shuffling on every build frame.
    if (!_shuffledBlocksCache.containsKey(blockIndex) ||
        _shuffledBlocksCache[blockIndex]!.length != source.length) {
      final blockList = List<PostModel>.from(source);
      blockList.shuffle(Random(blockSeed));
      _shuffledBlocksCache[blockIndex] = blockList;

      // Keep cache size manageable
      if (_shuffledBlocksCache.length > 5) {
        _shuffledBlocksCache.remove(_shuffledBlocksCache.keys.first);
      }
    }

    return _shuffledBlocksCache[blockIndex]![localIndex];
  }
}

class _ReelItem extends StatefulWidget {
  final PostModel post;
  final bool isActive;
  final VoidCallback onOpenProfile;
  final String currentUserId;
  final VideoPlayerController? preloadedController;

  const _ReelItem({
    super.key,
    required this.post,
    required this.isActive,
    required this.onOpenProfile,
    required this.currentUserId,
    this.preloadedController,
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
  final bool _showDetails = true; // Sidebar/Details stay persistent
  bool _showProgress = true;
  late AnimationController _heartAnimationController;
  Timer? _progressTimer;

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showProgress = false);
      }
    });
  }

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
    if (widget.preloadedController != null) {
      _videoController = widget.preloadedController!;
      _isInitialized = _videoController.value.isInitialized;
    } else {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.post.videoUrl!),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    }

    try {
      if (!_isInitialized) {
        await _videoController.initialize();
      }
      await _videoController.setLooping(true); // Loop Vistas indefinitely
      await _videoController.setVolume(1.0);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.isActive) {
          _videoController.play();
          ScreenAwakeController.acquire();
          AnalyticsService().trackView(widget.post.postId, _ownerId);
        }

        _videoController.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint('Error initializing reel video: $e');
    }
  }

  void _videoListener() {
    // Basic listener for future extensions
  }

  @override
  void didUpdateWidget(covariant _ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isLikeUpdating) {
      _isLiked = widget.post.isLikedBy(_activeUserId);
      _likeCount = widget.post.likeCount;
    }

    if (widget.preloadedController != null &&
        _videoController != widget.preloadedController) {
      _videoController.removeListener(_videoListener);
      _videoController = widget.preloadedController!;
      _isInitialized = _videoController.value.isInitialized;
      _videoController.addListener(_videoListener);
    }

    if (widget.isActive && !oldWidget.isActive) {
      if (_isInitialized) {
        _videoController.play();
        ScreenAwakeController.acquire();
        AnalyticsService().trackView(widget.post.postId, _ownerId);
        setState(() => _showProgress = true);
        _startProgressTimer();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      if (_isInitialized) {
        _videoController.pause();
        ScreenAwakeController.release();
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating) return;
    if (!mounted) return;
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
    _progressTimer?.cancel();
    if (_isInitialized && _videoController.value.isPlaying) {
      ScreenAwakeController.release();
    }
    _videoController.removeListener(_videoListener);
    // ONLY dispose if we created it locally
    if (widget.preloadedController == null) {
      _videoController.dispose();
    }
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
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _handleDoubleTap,
            onTap: () {
              setState(() {
                _showProgress = true;
                if (_videoController.value.isPlaying) {
                  _videoController.pause();
                  ScreenAwakeController.release();
                  _progressTimer?.cancel();
                } else {
                  _videoController.play();
                  ScreenAwakeController.acquire();
                  _startProgressTimer();
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
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
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
                                    ? CachedNetworkImageProvider(
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
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4.0,
                                      color: Colors.black54,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${widget.post.videoViewCount} views',
                              style: const TextStyle(
                                color: Colors.white70,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4.0,
                                    color: Colors.black54,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.post.content.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ExpandableText(
                            widget.post.content,
                            style: const TextStyle(
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black54,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            trimLines: 3,
                            actionStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black54,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            onTap: _openComments,
                          ),
                        ],
                        if (_isInitialized)
                          AnimatedOpacity(
                            opacity: _showProgress ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: IgnorePointer(
                              ignoring: !_showProgress,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  children: [
                                    VideoProgressIndicator(
                                      _videoController,
                                      allowScrubbing: true,
                                      colors: const VideoProgressColors(
                                        playedColor: Colors.white,
                                        bufferedColor: Colors.white24,
                                        backgroundColor: Colors.white12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        ValueListenableBuilder(
                                          valueListenable: _videoController,
                                          builder:
                                              (
                                                context,
                                                VideoPlayerValue value,
                                                child,
                                              ) {
                                                return Text(
                                                  _formatDuration(
                                                    value.position,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 10,
                                                  ),
                                                );
                                              },
                                        ),
                                        const Text(
                                          ' / ',
                                          style: TextStyle(
                                            color: Colors.white30,
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(
                                            _videoController.value.duration,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: _toggleMute,
                                          child: Icon(
                                            _isMuted
                                                ? Icons.volume_off
                                                : Icons.volume_up,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ],
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: iconColor ?? Colors.white,
                size: 22,
                shadows: const [
                  Shadow(
                    blurRadius: 4.0,
                    color: Colors.black54,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black54,
                      offset: Offset(0, 1),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          const SizedBox(height: 12),
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
