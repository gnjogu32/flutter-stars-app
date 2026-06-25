import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starpage/models/post_model.dart';
import 'package:starpage/widgets/video_interactions_sidebar.dart';
import 'package:starpage/widgets/expandable_text.dart';
import 'package:starpage/screens/profile_screen.dart';
import 'package:starpage/screens/full_screen_comments_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:starpage/services/repost_queue_service.dart';
import 'package:starpage/services/notification_service.dart';
import 'package:starpage/widgets/keyboard_prompt_banner.dart';
import '../utils/screen_awake_controller.dart';
import '../services/analytics_service.dart';
import '../services/user_service.dart';
import '../services/share_service.dart';
import '../utils/auth_guard.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final Duration? startPosition;
  final PostModel? post;
  final String? currentUserId;
  final List<PostModel>? playlist;
  final int initialIndex;
  final VideoPlayerController? manualController;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.startPosition,
    this.post,
    this.currentUserId,
    this.playlist,
    this.initialIndex = 0,
    this.manualController,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late PageController _pageController;
  late int _currentIndex;
  late List<PostModel> _videos;
  final int _sessionSeed = Random().nextInt(1000000);
  final Map<int, VideoPlayerController> _preloadedControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _videos = widget.playlist ?? (widget.post != null ? [widget.post!] : []);
    _pageController = PageController(initialPage: _currentIndex);

    // If we have a manual controller for the first item, cache it
    if (widget.manualController != null && _videos.isNotEmpty) {
      _preloadedControllers[_currentIndex] = widget.manualController!;
    }

    // Enable immersive mode and landscape orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    // Load discovery playlist for seamless vertical shuffle if starting from a single post
    if (widget.playlist == null && widget.post != null) {
      _loadDiscoveryPlaylist();
    } else {
      _preloadAdjacent(_currentIndex);
    }
  }

  void _reshuffle() {
    if (_videos.length <= 1) return;
    setState(() {
      _videos.shuffle(Random());
      _currentIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _preloadAdjacent(0);
  }

  void _preloadAdjacent(int index) {
    if (_videos.isEmpty) return;

    // Preload next 2 and previous 1 for seamless navigation
    final indicesToPreload = [index + 1, index + 2, index - 1];

    for (int i in indicesToPreload) {
      if (i < 0) continue;

      if (!_preloadedControllers.containsKey(i)) {
        final actualIdx = i % _videos.length;
        final url = _videos[actualIdx].videoUrl;
        if (url != null && url.isNotEmpty) {
          final controller = VideoPlayerController.networkUrl(Uri.parse(url));
          _preloadedControllers[i] = controller;
          controller.initialize().then((_) {
            if (mounted) setState(() {});
          });
        }
      }
    }
    // Cleanup distant ones
    _preloadedControllers.removeWhere((i, controller) {
      if ((i - index).abs() > 3) {
        controller.dispose();
        return true;
      }
      return false;
    });
  }

  Future<void> _loadDiscoveryPlaylist() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('postType', isEqualTo: 'video')
          .orderBy('createdAt', descending: true)
          .limit(40)
          .get();

      final moreVideos = snapshot.docs
          .map((doc) => PostModel.fromJson(doc.data()))
          .where(
            (p) =>
                p.postId != widget.post!.postId &&
                (p.videoUrl ?? '').isNotEmpty,
          )
          .toList();

      // Shuffle based on a session seed for consistent discovery
      moreVideos.shuffle(Random(_sessionSeed));

      if (mounted) {
        setState(() {
          _videos.addAll(moreVideos);
        });
        _preloadAdjacent(_currentIndex);
      }
    } catch (e) {
      debugPrint('Error loading discovery playlist: $e');
    }
  }

  @override
  void dispose() {
    // Restore system UI and orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pageController.dispose();
    _preloadedControllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'No video available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: () async {
          _reshuffle();
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index % _videos.length;
            });
            _preloadAdjacent(index);
          },
          itemBuilder: (context, index) {
            final actualIndex = index % _videos.length;
            final post = _videos[actualIndex];
            return _FullScreenVideoItem(
              key: ValueKey('fs_${post.postId}_$index'),
              post: post,
              autoPlay: actualIndex == _currentIndex,
              startPosition: index == widget.initialIndex
                  ? widget.startPosition
                  : null,
              currentUserId: widget.currentUserId,
              manualController: _preloadedControllers[index],
            );
          },
        ),
      ),
    );
  }
}

class _FullScreenVideoItem extends StatefulWidget {
  final PostModel post;
  final bool autoPlay;
  final Duration? startPosition;
  final String? currentUserId;
  final VideoPlayerController? manualController;

  const _FullScreenVideoItem({
    super.key,
    required this.post,
    required this.autoPlay,
    this.startPosition,
    this.currentUserId,
    this.manualController,
  });

  @override
  State<_FullScreenVideoItem> createState() => _FullScreenVideoItemState();
}

class _FullScreenVideoItemState extends State<_FullScreenVideoItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isMuted = false;
  bool _showMuteIndicator = false;
  bool _showPlayPauseIndicator = false;
  bool _showSkipForward = false;
  bool _showSkipBackward = false;
  bool _isVideoEnded = false;
  bool _isReposting = false;
  late int _viewCount;
  Timer? _indicatorTimer;
  String? _error;

  static const List<String> _quickEmojis = [
    '😀', '😁', '😂', '🤣', '😊', '😍', '🥳', '😎', '🤔', '👏', '🔥', '💯', '✨', '🙌', '👍', '🙏', '❤️', '💙', '💚', '🎉', '😢', '😡', '🤝', '💫',
  ];

  @override
  void initState() {
    super.initState();
    _viewCount = widget.post.videoViewCount;
    _initializeController();
  }

  Future<void> _initializeController() async {
    if (widget.manualController != null) {
      _controller = widget.manualController!;
      _isInitialized = _controller.value.isInitialized;
      if (_isInitialized) {
        _controller.addListener(_videoListener);
        // Sync volume, playback and auto-replay for immersive experience
        _isMuted = false;
        _controller.setVolume(1.0);
        _controller.setLooping(true);

        setState(() {
          if (widget.autoPlay) {
            _controller.play();
            _showControls = true; // Show initially
            _startHideTimer();
            ScreenAwakeController.acquire();
          }
        });
      }
      return;
    }

    final url = widget.post.videoUrl;
    if (url == null || url.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _controller.initialize();
      if (!mounted) {
        _controller.dispose();
        return;
      }

      await _controller.setLooping(true);
      _controller.addListener(_videoListener);

      if (widget.startPosition != null) {
        await _controller.seekTo(widget.startPosition!);
      }

      setState(() {
        _isInitialized = true;
        if (widget.autoPlay) {
          _controller.play();
          _showControls = true; // Show initially
          _startHideTimer();
          ScreenAwakeController.acquire();
          _trackView();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading video: $e';
        });
      }
    }
  }

  void _startHideTimer({int durationMs = 3000}) {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(Duration(milliseconds: durationMs), () {
      if (mounted) {
        setState(() {
          _showPlayPauseIndicator = false;
          _showSkipForward = false;
          _showSkipBackward = false;
          _showMuteIndicator = false;
          _showControls = false;
        });
      }
    });
  }

  void _trackView() {
    final ownerId = (widget.post.originalAuthorId ?? widget.post.authorId)
        .trim();
    if (ownerId.isNotEmpty) {
      AnalyticsService().trackView(widget.post.postId, ownerId);
      setState(() {
        _viewCount++;
      });
    }
  }

  void _videoListener() {
    if (_isInitialized) {
      final position = _controller.value.position;
      final duration = _controller.value.duration;

      if (position >= duration && duration > Duration.zero) {
        if (!_controller.value.isLooping && !_isVideoEnded) {
          setState(() {
            _isVideoEnded = true;
            _showControls = true; // Show controls to reveal replay button
          });
        }
      } else if (position < duration && _isVideoEnded) {
        setState(() => _isVideoEnded = false);
      }
    }
  }

  @override
  void didUpdateWidget(_FullScreenVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInitialized) return;

    if (widget.post.videoViewCount > _viewCount) {
      _viewCount = widget.post.videoViewCount;
    }

    if (widget.autoPlay && !oldWidget.autoPlay) {
      if (!_controller.value.isPlaying) {
        if (_isVideoEnded) {
          _controller.seekTo(Duration.zero);
        }
        _controller.play();
        setState(() => _showControls = true);
        _startHideTimer();
        ScreenAwakeController.acquire();
        _trackView();
      }
    } else if (!widget.autoPlay && oldWidget.autoPlay) {
      if (_controller.value.isPlaying) {
        _controller.pause();
        ScreenAwakeController.release();
      }
    }
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    if (_isInitialized) {
      _controller.removeListener(_videoListener);
      if (_controller.value.isPlaying) {
        ScreenAwakeController.release();
      }
      _controller.pause();
      _controller.dispose();
    } else {
      // Still initializing or failed
      _controller.dispose();
    }
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        ScreenAwakeController.release();
      } else {
        if (_isVideoEnded) {
          _controller.seekTo(Duration.zero);
          _isVideoEnded = false;
        }
        _controller.play();
        _showControls = true; // Keep visible for a few seconds
        ScreenAwakeController.acquire();
      }
      _showPlayPauseIndicator = true;
      _showMuteIndicator = false;
    });

    _startHideTimer();
  }

  void _toggleMute() {
    _indicatorTimer?.cancel();
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
      _showMuteIndicator = true;
      _showPlayPauseIndicator = false;
      _showSkipForward = false;
      _showSkipBackward = false;
    });

    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showMuteIndicator = false);
      }
    });
  }

  void _showSkipIndicator({required bool forward}) {
    setState(() {
      _showSkipForward = forward;
      _showSkipBackward = !forward;
      _showMuteIndicator = false;
      _showPlayPauseIndicator = true; // Show play/pause button too
      _showControls = true;
    });

    _startHideTimer();
  }

  Future<void> _skipBackward() async {
    final wasPlaying = _controller.value.isPlaying;
    final newPos = _controller.value.position - const Duration(seconds: 10);

    // Continuous Flow: Seek without awaiting to keep UI/playback engine reactive
    _controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);

    if (_isVideoEnded) {
      setState(() => _isVideoEnded = false);
    }
    if (wasPlaying) {
      _controller.play();
    }
    _showSkipIndicator(forward: false);
  }

  Future<void> _skipForward() async {
    final wasPlaying = _controller.value.isPlaying;
    final newPos = _controller.value.position + const Duration(seconds: 10);

    // Continuous Flow: Seek without awaiting to keep UI/playback engine reactive
    _controller.seekTo(newPos);

    if (wasPlaying) {
      _controller.play();
    }
    _showSkipIndicator(forward: true);
  }

  void _sharePost() {
    ShareService.sharePost(widget.post);
    // Track share in analytics
    final currentUserId = widget.currentUserId ?? '';
    if (currentUserId.isNotEmpty) {
      final ownerId =
          (widget.post.originalAuthorId ?? widget.post.authorId).trim();
      AnalyticsService().trackShare(widget.post.postId, ownerId, currentUserId);
    }
  }

  void _onOpenProfile() {
    final userId = (widget.post.originalAuthorId ?? widget.post.authorId)
        .trim();
    if (userId.isEmpty) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  void _openComments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenCommentsPage(
          postId: widget.post.postId,
          postAuthorId: (widget.post.originalAuthorId ?? widget.post.authorId),
          currentUserId: widget.currentUserId ?? '',
          postContent: widget.post.content,
        ),
      ),
    );
  }

  Future<void> _repostToFeed({String caption = '', DateTime? scheduleTime}) async {
    final currentUserId = widget.currentUserId ?? '';
    if (_isReposting) return;
    if (currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    setState(() => _isReposting = true);

    try {
      final userService = UserService();
      final queueService = RepostQueueService();
      final analyticsService = AnalyticsService();
      final notificationService = NotificationService();

      final currentUser = await userService.getUser(currentUserId);
      if (currentUser == null) {
        throw Exception('Could not load your profile for reposting.');
      }

      final actorName = currentUser.displayName.trim().isEmpty
          ? 'Someone'
          : currentUser.displayName.trim();

      await queueService.queueRepost(
        userId: currentUserId,
        postId: widget.post.postId,
        originalAuthorId: widget.post.authorId,
        userName: actorName,
        userImageUrl: currentUser.profileImageUrl,
        post: widget.post,
        caption: caption,
        scheduleTime: scheduleTime,
      );

      final ownerId = (widget.post.originalAuthorId ?? widget.post.authorId).trim();
      await analyticsService.trackRepost(widget.post.postId, ownerId, currentUserId);

      if (currentUserId != widget.post.authorId &&
          (scheduleTime == null || scheduleTime.isBefore(DateTime.now().add(const Duration(seconds: 1))))) {
        try {
          await notificationService.createNotification(
            userId: widget.post.authorId,
            triggeredBy: currentUserId,
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
          SnackBar(content: Text('Repost scheduled ✓')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reposted to your feed ✓')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to repost: $e')));
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

    focusNode.addListener(() => hasFocus.value = focusNode.hasFocus);

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KeyboardPromptBanner(
                        visible: keyboardInset > 0 && !showEmojiPanel,
                        text: 'Add a repost caption.',
                        icon: Icons.repeat_outlined,
                      ),
                      const SizedBox(height: 12),
                      const Text('Add an optional caption:', style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setDialogState(() => showEmojiPanel = !showEmojiPanel);
                              if (showEmojiPanel) {
                                focusNode.unfocus();
                                SystemChannels.textInput.invokeMethod('TextInput.hide');
                              } else {
                                FocusScope.of(context).requestFocus(focusNode);
                              }
                            },
                            icon: Icon(showEmojiPanel ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined),
                          ),
                          Expanded(
                            child: TextField(
                              controller: textController,
                              focusNode: focusNode,
                              onTap: () { if (showEmojiPanel) setDialogState(() => showEmojiPanel = false); },
                              decoration: InputDecoration(
                                hintText: 'Write something...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                        child: showEmojiPanel ? GridView.builder(
                          padding: const EdgeInsets.only(top: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                final currentSelection = textController.selection;
                                final start = currentSelection.start >= 0 ? currentSelection.start : currentText.length;
                                final end = currentSelection.end >= 0 ? currentSelection.end : currentText.length;
                                final newText = currentText.replaceRange(start, end, emoji);
                                textController.value = TextEditingValue(
                                  text: newText,
                                  selection: TextSelection.collapsed(offset: start + emoji.length),
                                );
                              },
                              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                            );
                          },
                        ) : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const Text('Schedule (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null && context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (time != null) {
                              setDialogState(() => scheduleTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                            }
                          }
                        },
                        icon: const Icon(Icons.schedule),
                        label: Text(scheduleTime == null ? 'Post now' : 'Scheduled: ${scheduleTime!.year}-${scheduleTime!.month}-${scheduleTime!.day}'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
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

  void _showMoreOptions() {
    final currentUserId = widget.currentUserId ?? '';
    if (currentUserId.isEmpty) {
      AuthGuard.show(context);
      return;
    }

    final ownerId = (widget.post.originalAuthorId ?? widget.post.authorId)
        .trim();
    final ownerName = (widget.post.originalAuthorName ?? widget.post.authorName)
        .trim();

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
            StatefulBuilder(
              builder: (context, setSheetState) => SwitchListTile(
                secondary: const Icon(Icons.replay_circle_filled_outlined),
                title: const Text('Auto Replay'),
                subtitle: const Text('Loop video automatically'),
                value: _controller.value.isLooping,
                onChanged: (val) async {
                  await _controller.setLooping(val);
                  setSheetState(() {});
                  if (mounted) setState(() {});
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Mute this post'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: this.context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Mute Post'),
                    content: const Text(
                      'Are you sure you want to hide this post from your feed?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                        child: const Text('Mute'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await UserService().mutePost(
                    currentUserId,
                    widget.post.postId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Post muted ✓')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: Text('Mute $ownerName'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: this.context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Mute $ownerName'),
                    content: Text(
                      'Are you sure you want to hide all posts from $ownerName?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                        child: const Text('Mute'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await UserService().muteAuthor(currentUserId, ownerId);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Posts from $ownerName muted ✓')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined, color: Colors.red),
              title: Text(
                'Block $ownerName',
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: this.context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Block $ownerName'),
                    content: Text(
                      'Block $ownerName? They will no longer be able to message you or see your notifications.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Block'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await UserService().blockUser(currentUserId, ownerId);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('$ownerName blocked ✓')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerName = (widget.post.originalAuthorName ?? widget.post.authorName)
        .trim();

    return GestureDetector(
      onTap: _togglePlay,
      onLongPress: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      onDoubleTapDown: (details) {
        // Center area double tap for Like remains if needed (but currently not explicitly implemented in this gesture detector)
        // We can add Like logic here or just leave it for unified center double tap if we want.
      },
      child: Stack(
        children: [
          Center(
            child: _error != null
                ? Text(_error!, style: const TextStyle(color: Colors.white))
                : _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
          ),

          // Mute/Unmute/Play/Pause Indicator
          if (_showMuteIndicator || _showPlayPauseIndicator)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showMuteIndicator
                      ? (_isMuted ? Icons.volume_off : Icons.volume_up)
                      : (_isVideoEnded
                            ? Icons.replay
                            : (_controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow)),
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

          // Skip Backward Button / Indicator
          if (_showSkipBackward || _showControls)
            Positioned(
              left: 60,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _skipBackward,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.replay_10,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),

          // Skip Forward Button / Indicator
          if (_showSkipForward || _showControls)
            Positioned(
              right: 80, // Offset more to avoid sidebar conflict
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _skipForward,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.forward_10,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),

          // Buffering Indicator
          if (_isInitialized)
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, VideoPlayerValue value, child) {
                if (value.isBuffering) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

          // Back Button (Always visible when controls are shown)
          if (_showControls)
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

          // Center Play/Pause Button
          if (_showControls && _isInitialized)
            Center(
              child: IconButton(
                icon: Icon(
                  _isVideoEnded
                      ? Icons.replay_circle_filled
                      : (_controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled),
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 80,
                ),
                onPressed: _togglePlay,
              ),
            ),

          // Bottom Details & Progress bar
          if (_showControls && _isInitialized)
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _onOpenProfile,
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
                                    '$_viewCount views',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 60), // Space for sidebar
                      ],
                    ),
                    const SizedBox(height: 12),
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.red,
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, VideoPlayerValue value, child) {
                            return Text(
                              _formatDuration(value.position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                        const Text(
                          ' / ',
                          style: TextStyle(color: Colors.white30, fontSize: 12),
                        ),
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _toggleMute,
                          child: Icon(
                            _isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (_showControls && widget.currentUserId != null)
            Positioned(
              right: 16,
              bottom: 100,
              child: VideoInteractionsSidebar(
                post: widget.post,
                currentUserId: widget.currentUserId!,
                isMuted: _isMuted,
                onToggleMute: _toggleMute,
                onCommentTap: _openComments,
                onRepostTap: _confirmRepost,
                onMoreTap: _showMoreOptions,
                onShareTap: _sharePost,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
