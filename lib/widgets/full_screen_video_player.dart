import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:starpage/models/post_model.dart';
import 'package:starpage/models/user_model.dart';
import 'package:starpage/widgets/video_interactions_sidebar.dart';
import 'package:starpage/widgets/expandable_text.dart';
import 'package:starpage/screens/profile_screen.dart';
import 'package:starpage/widgets/comments_bottom_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:starpage/services/notification_service.dart';
import 'package:starpage/services/post_service.dart';
import 'package:starpage/widgets/keyboard_prompt_banner.dart';
import '../utils/screen_awake_controller.dart';
import '../utils/mention_utils.dart';
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
  // Cache for shuffled blocks to ensure smooth scrolling
  final Map<int, List<PostModel>> _shuffledBlocksCache = {};

  @override
  void initState() {
    super.initState();
    // Start from index 0 to enforce "Load from bottom upward" flow
    _videos = widget.playlist ?? (widget.post != null ? [widget.post!] : []);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

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

  @override
  void didUpdateWidget(FullScreenVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playlist != null && widget.playlist != oldWidget.playlist) {
      setState(() {
        _videos = widget.playlist!;
      });
    }
  }

  void _preloadAdjacent(int index) {
    if (_videos.length <= 1) return;

    // Preload next 3 and previous 1 for seamless navigation
    final indicesToPreload = [index + 1, index + 2, index + 3, index - 1];

    for (int i in indicesToPreload) {
      if (i < 0) continue;

      // Avoid preloading the same video multiple times if the list is small
      final post = _getVideoAtGlobalIndex(i, _videos);
      final currentPost = _getVideoAtGlobalIndex(index, _videos);
      if (post.postId == currentPost.postId) continue;

      if (!_preloadedControllers.containsKey(i)) {
        final url = post.videoUrl;
        if (url != null && url.isNotEmpty) {
          final controller = VideoPlayerController.networkUrl(
            Uri.parse(url),
          );
          _preloadedControllers[i] = controller;
          controller.initialize().then((_) {
            if (mounted) setState(() {});
          });
        }
      }
    }
    // Cleanup distant ones
    _preloadedControllers.removeWhere((i, controller) {
      if ((i - index).abs() > 5) {
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
          .limit(41) // Load 41 to have a nice set
          .get();

      final discovery = snapshot.docs
          .map((doc) => PostModel.fromJson(doc.data()))
          .where((v) => (v.videoUrl ?? '').isNotEmpty)
          .toList();

      if (mounted) {
        // Different Author Fix: Ensure the post that was actually tapped is included
        // in the list, even if it wasn't in the top 41 most recent results.
        if (widget.post != null) {
          final bool alreadyPresent = discovery.any((p) => p.postId == widget.post!.postId);
          if (!alreadyPresent) {
            discovery.add(widget.post!);
          }
        }

        setState(() {
          _videos = discovery;
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

    // Silence and pause ALL controllers on dispose to prevent audio leaks
    _preloadedControllers.forEach((_, c) {
      c.setVolume(0);
      c.pause();
      // ONLY dispose if we created it locally (not borrowed from feed)
      if (c != widget.manualController) {
        c.dispose();
      }
    });

    super.dispose();
  }

  bool _isPopping = false;

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
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (_isPopping) return false;

          // Detect downward overscroll at the start of the playlist to "go back"
          if (notification is ScrollUpdateNotification &&
              _currentIndex == 0 &&
              notification.metrics.pixels < -100) {
            _isPopping = true;
            // Immediate silence and pause for stability
            _preloadedControllers.forEach((_, c) {
              c.pause();
              c.setVolume(0);
            });
            Navigator.of(context).pop();
            return true;
          }
          return false;
        },
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          onPageChanged: (index) {
            if (!mounted) return;
            setState(() {
              _currentIndex = index;
            });
            _preloadAdjacent(index);
          },
          itemBuilder: (context, index) {
            final post = _getVideoAtGlobalIndex(index, _videos);
            return _FullScreenVideoItem(
              key: ValueKey('fs_${post.postId}_$index'),
              post: post,
              autoPlay: index == _currentIndex,
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

  /// Map global index to a specific video with block-based shuffling for seamless discovery.
  PostModel _getVideoAtGlobalIndex(int index, List<PostModel> source) {
    if (source.isEmpty) return PostModel.empty();
    final int length = source.length;
    final int blockIndex = index ~/ length;
    final int localIndex = index % length;

    // Stable block-shuffle logic
    final int blockSeed = _sessionSeed ^ blockIndex;

    if (!_shuffledBlocksCache.containsKey(blockIndex) ||
        _shuffledBlocksCache[blockIndex]!.length != length) {
      final blockList = List<PostModel>.from(source);

      // Pinned Position Optimization: Ensure the initial post stays at its global
      // index when discovery loads, preventing black screen flickers and mapping shifts.
      // This also ensures the correct Author details are shown for the tapped video.
      final int initialBlockIndex = widget.initialIndex ~/ length;
      final int initialLocalIndex = widget.initialIndex % length;

      if (blockIndex == initialBlockIndex && widget.playlist == null && widget.post != null) {
         final String targetPostId = widget.post!.postId;
         
         // Shuffle first
         blockList.shuffle(Random(blockSeed));

         // Then find the target post in the shuffled list and move it to the correct local index
         final int currentPos = blockList.indexWhere((p) => p.postId == targetPostId);
         if (currentPos != -1 && currentPos != initialLocalIndex) {
            final temp = blockList[initialLocalIndex];
            blockList[initialLocalIndex] = blockList[currentPos];
            blockList[currentPos] = temp;
         }
      } else {
         blockList.shuffle(Random(blockSeed));
      }

      _shuffledBlocksCache[blockIndex] = blockList;

      if (_shuffledBlocksCache.length > 5) {
        _shuffledBlocksCache.remove(_shuffledBlocksCache.keys.first);
      }
    }

    return _shuffledBlocksCache[blockIndex]![localIndex];
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

class _FullScreenVideoItemState extends State<_FullScreenVideoItem>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
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
  bool _isPageVisible = false;
  bool _isCommentSheetOpen = false;

  @override
  bool get wantKeepAlive => true;

  static const List<String> _quickEmojis = [
    '😀', '😁', '😂', '🤣', '😊', '😍', '🥳', '😎', '🤔', '👏', '🔥', '💯', '✨', '🙌', '👍', '🙏', '❤️', '💙', '💚', '🎉', '😢', '😡', '🤝', '💫',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewCount = widget.post.videoViewCount;

    // Sync-init to prevent black frame when manualController is provided
    if (widget.manualController != null) {
      _controller = widget.manualController!;
      _isInitialized = _controller.value.isInitialized;
    }

    _initializeController();
  }

  Future<void> _initializeController() async {
    if (widget.manualController != null) {
      if (_isInitialized) {
        _controller.addListener(_videoListener);
        _isMuted = false;

        // Ensure settings are correct for immersive playback
        if (_controller.value.volume != 1.0) {
          _controller.setVolume(1.0);
        }
        if (!_controller.value.isLooping) {
          _controller.setLooping(true);
        }

        if (widget.autoPlay) {
          // Force play even if it thinks it's playing to ensure surface sync
          _controller.play();
          ScreenAwakeController.acquire();
        }

        if (mounted) {
          setState(() {
            _showControls = true;
          });
          _startHideTimer();
        }
      }
      return;
    }

    final url = widget.post.videoUrl;
    if (url == null || url.isEmpty) return;

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
    );
    try {
      await _controller.initialize();
      if (!mounted) {
        _controller.setVolume(0);
        _controller.pause();
        _controller.dispose();
        return;
      }

      await _controller.setLooping(true);
      await _controller.setVolume(1.0); // Ensure audible
      _controller.addListener(_videoListener);

      if (widget.startPosition != null) {
        await _controller.seekTo(widget.startPosition!);
      }

      setState(() {
        _isInitialized = true;
      });

      // Defensive check: only play if STILL active after async initialization
      if (widget.autoPlay && mounted) {
        _controller.play();
        _showControls = true; // Show initially
        _startHideTimer();
        ScreenAwakeController.acquire();
        _trackView();
      } else {
        _controller.pause();
      }
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
          _showControls = false; // This will hide progress controls only
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
    if (!mounted || !_isInitialized) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    if (position >= duration && duration > Duration.zero) {
      if (!_controller.value.isLooping && !_isVideoEnded) {
        setState(() {
          _isVideoEnded = true;
          _showControls = true;
        });
      }
    } else if (position < duration && _isVideoEnded) {
      setState(() => _isVideoEnded = false);
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
    WidgetsBinding.instance.removeObserver(this);
    _indicatorTimer?.cancel();
    if (_isInitialized) {
      _controller.removeListener(_videoListener);

      // Always pause on dispose to prevent ghost audio
      if (_controller.value.isPlaying) {
        _controller.pause();
        ScreenAwakeController.release();
      }

      // ONLY dispose if we own the controller (it's not the borrowed manualController)
      if (widget.manualController == null) {
        _controller.dispose();
      }
    } else if (widget.manualController == null) {
      // Still initializing or failed, and we own it
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_controller.value.isPlaying) {
        _controller.pause();
        ScreenAwakeController.release();
      }
    } else if (state == AppLifecycleState.resumed) {
      // For simplicity in immersive, we resume if it's the active one.
      if (widget.autoPlay && !_controller.value.isPlaying) {
        _controller.play();
        ScreenAwakeController.acquire();
      }
    }
  }

  void _togglePlay() {
    if (!mounted) return;
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
        _showControls = true;
        ScreenAwakeController.acquire();
      }
      _showPlayPauseIndicator = true;
      _showMuteIndicator = false;
    });

    if (_controller.value.isPlaying) {
      _startHideTimer();
    } else {
      _indicatorTimer?.cancel();
    }
  }

  void _toggleMute() {
    if (!mounted) return;
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

  void _showShareOptions() {
    final theme = Theme.of(context);
    final currentUserId = widget.currentUserId ?? '';

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
              title: const Text('Share to...'),
              onTap: () {
                Navigator.pop(context);
                _sharePost();
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
                currentUserId)
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

    // Strict Security: Only the original content creator can download
    final currentUserId = widget.currentUserId ?? '';
    final originalAuthorId =
        widget.post.originalAuthorId ?? widget.post.authorId;
    if (originalAuthorId != currentUserId) {
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

  void _onOpenProfile() {
    final userId = (widget.post.originalAuthorId ?? widget.post.authorId)
        .trim();
    if (userId.isEmpty) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  void _openComments() async {
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
          postAuthorId: (widget.post.originalAuthorId ?? widget.post.authorId),
          currentUserId: widget.currentUserId ?? '',
          postContent: widget.post.content,
          scrollController: scrollController,
        ),
      ),
    );
    if (mounted) setState(() => _isCommentSheetOpen = false);
  }

  Future<void> _repostToFeed({String caption = ''}) async {
    final currentUserId = widget.currentUserId ?? '';
    if (_isReposting) return;
    if (currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    setState(() => _isReposting = true);

    try {
      final userService = UserService();
      final postService = PostService();
      final analyticsService = AnalyticsService();
      final notificationService = NotificationService();

      final currentUser = await userService.getUser(currentUserId);
      if (currentUser == null) {
        throw Exception('Could not load your profile for reposting.');
      }

      final actorName = currentUser.displayName.trim().isEmpty
          ? 'Someone'
          : currentUser.displayName.trim();

      // Check if already reposted
      final alreadyReposted = await postService.hasUserReposted(widget.post.postId, currentUserId);

      if (alreadyReposted) {
        await postService.undoRepost(
          originalPostId: widget.post.postId,
          reposterId: currentUserId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Repost removed ✓')),
          );
        }
      } else {
        final repostId = await postService.repostPost(
          originalPost: widget.post,
          reposterId: currentUserId,
          reposterName: actorName,
          reposterUsername: currentUser.username,
          reposterImageUrl: currentUser.profileImageUrl,
          repostCaption: caption,
        );

        final ownerId = (widget.post.originalAuthorId ?? widget.post.authorId).trim();
        await analyticsService.trackRepost(widget.post.postId, ownerId, currentUserId);

        if (currentUserId != widget.post.authorId) {
          try {
            await notificationService.createNotification(
              userId: widget.post.authorId,
              triggeredBy: currentUserId,
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reposted to your feed ✓')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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

    focusNode.addListener(() => hasFocus.value = focusNode.hasFocus);

    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
              final currentUserId = widget.currentUserId ?? '';
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

          final theme = Theme.of(context);
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Repost',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const KeyboardPromptBanner(
                    visible: true,
                    text: 'Add a repost caption before sharing.',
                    icon: Icons.repeat_outlined,
                  ),
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
                          autofocus: true,
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, textController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Repost Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            if ((widget.post.originalAuthorId ?? widget.post.authorId) ==
                currentUserId)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download Video'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadVideo();
                },
              ),
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
    super.build(context);
    final ownerName = (widget.post.originalAuthorName ?? widget.post.authorName)
        .trim();

    return VisibilityDetector(
      key: ValueKey('fs_vis_${widget.post.postId}'),
      onVisibilityChanged: (info) {
        if (!mounted || _isCommentSheetOpen) return;
        final visible = info.visibleFraction > 0.8;
        if (visible != _isPageVisible) {
          setState(() {
            _isPageVisible = visible;
          });
          if (visible) {
            if (widget.autoPlay && !_controller.value.isPlaying) {
              _controller.play();
              ScreenAwakeController.acquire();
            }
          } else {
            if (_controller.value.isPlaying) {
              _controller.pause();
              ScreenAwakeController.release();
            }
          }
        }
      },
      child: GestureDetector(
        onTap: _togglePlay,
        onLongPress: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        onDoubleTapDown: (details) {
          // Center area double tap for Like remains if needed
        },
        child: Stack(
          children: [
            Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.white))
                  : _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: RepaintBoundary(
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

          // Mute/Unmute/Play/Pause Indicator
          if (_showMuteIndicator || _showPlayPauseIndicator)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
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
                      color: Colors.transparent,
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
                      color: Colors.transparent,
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
          if (_isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 32, 80, 24), // Increased right padding for sidebar
                decoration: const BoxDecoration(
                  color: Colors.transparent,
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
                                  const SizedBox(width: 8),
                                  StreamBuilder<DocumentSnapshot>(
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
                                      return Text(
                                        '$viewCount views',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              if (widget.post.content.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ExpandableText(
                                  widget.post.content,
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
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
                      ],
                    ),
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: !_showControls,
                        child: Column(
                          children: [
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
                  ],
                ),
              ),
            ),

          if (widget.currentUserId != null)
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
                onShareTap: _showShareOptions,
              ),
            ),
        ],
      ),
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
