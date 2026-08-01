import 'dart:async';
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
import 'package:visibility_detector/visibility_detector.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../services/analytics_service.dart';
import '../utils/screen_awake_controller.dart';
import '../utils/auth_guard.dart';
import '../utils/constants.dart';
import '../utils/mention_utils.dart';
import '../services/share_service.dart';
import '../services/user_service.dart';
import '../widgets/expandable_text.dart';
import '../widgets/repost_dialog.dart';
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

class ReelsScreenState extends State<ReelsScreen> with WidgetsBindingObserver {
  late final FirebaseFirestore _firestore;
  static const int _infiniteLoopOffset = 0;
  late final PageController _pageController;
  int _activeIndex = _infiniteLoopOffset;
  bool _tabVisible = false;

  final Map<int, VideoPlayerController> _preloadedControllers = {};
  List<PostModel>? _cachedReels;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _firestore = widget.firestore ?? FirebaseFirestore.instance;
    _tabVisible = widget.tabActiveNotifier.value;
    _pageController = PageController(initialPage: _infiniteLoopOffset);
    widget.tabActiveNotifier.addListener(_onTabVisibilityChanged);
  }

  void _onTabVisibilityChanged() {
    final visible = widget.tabActiveNotifier.value;
    if (mounted) {
      setState(() => _tabVisible = visible);

      // Ghost Audio Prevention: If tab becomes invisible, silence all preloaded controllers immediately
      if (!visible) {
        for (final controller in _preloadedControllers.values) {
          controller.setVolume(0);
          controller.pause();
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      for (final controller in _preloadedControllers.values) {
        controller.setVolume(0);
        controller.pause();
      }
    }
  }

  void refreshReels() {
    _disposeAllPreloaded();
    setState(() {
      _cachedReels = null;
      _activeIndex = _infiniteLoopOffset;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_infiniteLoopOffset);
    }
  }

  void _disposeAllPreloaded() {
    for (final controller in _preloadedControllers.values) {
      controller.setVolume(0);
      controller.pause();
      controller.dispose();
    }
    _preloadedControllers.clear();
  }

  void _preloadAdjacent(int index, List<PostModel> reels) {
    if (reels.isEmpty) {
      return;
    }
    final indicesToPreload = [index, index + 1];
    _preloadedControllers.removeWhere((idx, controller) {
      if (!indicesToPreload.contains(idx)) {
        controller.setVolume(0);
        controller.pause();
        controller.dispose();
        return true;
      }
      return false;
    });
    for (final idx in indicesToPreload) {
      if (idx < 0 || idx >= reels.length) {
        continue;
      }
      if (!_preloadedControllers.containsKey(idx)) {
        final post = reels[idx];
        if (post.videoUrl != null && post.videoUrl!.isNotEmpty) {
          final controller =
              VideoPlayerController.networkUrl(Uri.parse(post.videoUrl!));
          _preloadedControllers[idx] = controller;
          controller.initialize().then((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    widget.tabActiveNotifier.removeListener(_onTabVisibilityChanged);
    _pageController.dispose();
    for (final controller in _preloadedControllers.values) {
      controller.setVolume(0);
      controller.pause();
      controller.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedReels == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError && _cachedReels == null) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (snapshot.hasData) {
            final latestReels = (snapshot.data?.docs ?? [])
                .map(
                  (doc) =>
                      PostModel.fromJson(doc.data() as Map<String, dynamic>),
                )
                .where((post) => (post.videoUrl ?? '').trim().isNotEmpty)
                .toList();
            if (_cachedReels == null || _cachedReels!.isEmpty) {
              _cachedReels = latestReels;
            } else {
              final existingIds = _cachedReels!.map((r) => r.postId).toSet();
              final newItems = latestReels
                  .where((r) => !existingIds.contains(r.postId))
                  .toList();
              if (newItems.isNotEmpty) {
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
          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _activeIndex = index);
                  _preloadAdjacent(index, reels);
                },
                itemCount: reels.length,
                itemBuilder: (context, index) {
                  final reel = reels[index];
                  return _ReelItem(
                    key: ValueKey('reel_${reel.postId}_$index'),
                    post: reel,
                    isActive: _tabVisible && index == _activeIndex,
                    currentUserId: currentUserId,
                    preloadedController: _preloadedControllers[index],
                    onOpenProfile: () {
                      final userId = (reel.originalAuthorId ?? reel.authorId)
                          .trim();
                      if (userId.isEmpty) {
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: userId),
                        ),
                      );
                    },
                  );
                },
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Vistas',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
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
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isReposting = false;
  bool _isSaved = false;
  bool _isMuted = false;
  bool _showLikeHeart = false;
  bool _showProgress = false;
  late AnimationController _heartAnimationController;
  Timer? _progressTimer;
  bool _isPageVisible = false;
  bool _isCommentSheetOpen = false;
  bool _isHoldingWakelock = false;

  @override
  bool get wantKeepAlive => true;

  void _acquireWakelock() {
    if (!_isHoldingWakelock) {
      ScreenAwakeController.acquire();
      _isHoldingWakelock = true;
    }
  }

  void _releaseWakelock() {
    if (_isHoldingWakelock) {
      ScreenAwakeController.release();
      _isHoldingWakelock = false;
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showProgress = false);
      }
    });
  }

  String get _ownerId =>
      (widget.post.originalAuthorId ?? widget.post.authorId).trim();
  String get _activeUserId => widget.currentUserId.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLiked = widget.post.isLikedBy(_activeUserId);
    _likeCount = widget.post.likeCount;
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkSavedStatus();
    _initializeVideo();
  }

  Future<void> _checkSavedStatus() async {
    if (_activeUserId.isEmpty) {
      return;
    }
    try {
      final userService = UserService();
      final savedIds = await userService.getSavedPostIds(_activeUserId);
      if (mounted) {
        setState(() => _isSaved = savedIds.contains(widget.post.postId));
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (_activeUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);
    try {
      if (wasSaved) {
        await UserService().unsavePost(_activeUserId, widget.post.postId);
      } else {
        await UserService().savePost(_activeUserId, widget.post.postId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaved = wasSaved);
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.preloadedController != null) {
      _videoController = widget.preloadedController!;
      _isInitialized = _videoController.value.isInitialized;
    } else {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.post.videoUrl!),
      );
    }
    try {
      if (!_isInitialized) {
        await _videoController.initialize();
      }
      if (!mounted) {
        _videoController.setVolume(0);
        _videoController.pause();
        _releaseWakelock();
        return;
      }
      await _videoController.setLooping(true);
      await _videoController.setVolume(_isMuted ? 0.0 : 1.0);
      setState(() => _isInitialized = true);
      if (widget.isActive && _isPageVisible) {
        _videoController.play();
        _acquireWakelock();
        AnalyticsService().trackView(widget.post.postId, _ownerId);
        if (mounted) {
          setState(() => _showProgress = true);
        }
        _startProgressTimer();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
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
      _videoController = widget.preloadedController!;
      _isInitialized = _videoController.value.isInitialized;
    }
    if (widget.isActive && !oldWidget.isActive) {
      if (_isInitialized && _isPageVisible) {
        _videoController.setVolume(_isMuted ? 0.0 : 1.0);
        _videoController.play();
        _acquireWakelock();
        setState(() => _showProgress = true);
        _startProgressTimer();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      if (_isInitialized) {
        _videoController.setVolume(0);
        _videoController.pause();
        _releaseWakelock();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
        _releaseWakelock();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isActive &&
          _isPageVisible &&
          !_videoController.value.isPlaying) {
        _videoController.play();
        _acquireWakelock();
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating || !mounted) {
      return;
    }
    if (!await AuthGuard.check(context, _activeUserId)) {
      return;
    }
    final wasLiked = _isLiked;
    setState(() {
      _isLikeUpdating = true;
      _isLiked = !wasLiked;
      _likeCount = wasLiked ? (_likeCount - 1) : _likeCount + 1;
    });
    try {
      if (wasLiked) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.postId)
            .update({
          'likes': FieldValue.arrayRemove([_activeUserId]),
        });
        await AnalyticsService().trackUnlike(widget.post.postId, _activeUserId);
      } else {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.postId)
            .update({
          'likes': FieldValue.arrayUnion([_activeUserId]),
        });
        await AnalyticsService().trackLike(
          widget.post.postId,
          _ownerId,
          _activeUserId,
        );
        if (_activeUserId != _ownerId) {
          final currentUser = await UserService().getUser(_activeUserId);
          if (currentUser != null) {
            await NotificationService().createNotification(
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = wasLiked ? (_likeCount + 1) : (_likeCount - 1);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLikeUpdating = false);
      }
    }
  }

  void _confirmRepost() async {
    final result = await RepostDialog.show(
      context,
      post: widget.post,
      currentUserId: _activeUserId,
    );

    if (result != null && mounted) {
      setState(() => _isReposting = true);
      try {
        final currentUser = await UserService().getUser(_activeUserId);
        if (currentUser == null) throw Exception('Profile not found');
        await PostService().repostPost(
          originalPost: widget.post,
          reposterId: _activeUserId,
          reposterName: currentUser.displayName,
          reposterUsername: currentUser.username,
          reposterImageUrl: currentUser.profileImageUrl,
          repostCaption: result,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reposted! ✓')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isReposting = false);
      }
    }
  }

  void _openComments({bool autoFocus = false}) async {
    setState(() => _isCommentSheetOpen = true);
    await showModalBottomSheet(
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
          postAuthorId: _ownerId,
          currentUserId: _activeUserId,
          postContent: widget.post.content,
          scrollController: scrollController,
          autoFocus: autoFocus,
        ),
      ),
    );
    if (mounted) {
      setState(() => _isCommentSheetOpen = false);
    }
  }

  void _showMoreOptions() {
    final ownerName =
        (widget.post.originalAuthorName ?? widget.post.authorName).trim();
    final isAuthor = widget.post.authorId == _activeUserId;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
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
              if (isAuthor) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit Post'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context)
                        .pushNamed('/edit-post', arguments: widget.post);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirmed = await showDialog<bool>(
                      context: this.context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Post'),
                        content: const Text(
                          'Are you sure? This cannot be undone.',
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
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await PostService().deletePost(widget.post);
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(content: Text('Post deleted')),
                        );
                      }
                    }
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Report Post'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post reported.')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: Text('Mute $ownerName'),
                  onTap: () async {
                    Navigator.pop(context);
                    await UserService().muteAuthor(_activeUserId, _ownerId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Muted $ownerName')),
                      );
                    }
                  },
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showShareOptions() {
    final isAuthor =
        (widget.post.originalAuthorId ?? widget.post.authorId) == _activeUserId;
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
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
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy Link'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(
                    ClipboardData(
                      text: AppConstants.postUrl(widget.post.postId),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied ✓')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share via...'),
                onTap: () {
                  Navigator.pop(context);
                  ShareService.sharePost(widget.post);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post details copied for sharing ✓'),
                    ),
                  );
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
              if (isAuthor)
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Download Video'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadVideo();
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadVideo() async {
    if (widget.post.videoUrl == null || widget.post.videoUrl!.isEmpty) {
      return;
    }
    final isAuthor =
        (widget.post.originalAuthorId ?? widget.post.authorId) == _activeUserId;
    if (!isAuthor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the author can download this video.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Downloading video...')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  void _skip(int seconds) {
    if (!_isInitialized) {
      return;
    }
    _videoController.seekTo(
      _videoController.value.position + Duration(seconds: seconds),
    );
    setState(() => _showProgress = true);
    _startProgressTimer();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController.setVolume(_isMuted ? 0 : 1);
      _showProgress = true;
    });
    _startProgressTimer();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _heartAnimationController.dispose();
    _releaseWakelock();
    // If the controller was preloaded, the parent (ReelsScreenState) will dispose it.
    // However, if we created it locally in _initializeVideo, we MUST dispose it.
    if (widget.preloadedController == null && _isInitialized) {
      _videoController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ownerName =
        (widget.post.originalAuthorName ?? widget.post.authorName).trim();
    return VisibilityDetector(
      key: ValueKey('reel_vis_${widget.post.postId}_${widget.isActive}'),
      onVisibilityChanged: (info) {
        if (!mounted || _isCommentSheetOpen) {
          return;
        }
        final visible = info.visibleFraction > 0.5;
        if (visible != _isPageVisible) {
          setState(() => _isPageVisible = visible);
          if (visible) {
            if (widget.isActive &&
                _isInitialized &&
                !_videoController.value.isPlaying) {
              _videoController.setVolume(_isMuted ? 0.0 : 1.0);
              _videoController.play();
              _acquireWakelock();
              setState(() => _showProgress = true);
              _startProgressTimer();
            }
          } else {
            if (_isInitialized) {
              _videoController.setVolume(0);
              _videoController.pause();
              _releaseWakelock();
            }
          }
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.postId)
            .snapshots(),
        builder: (context, snapshot) {
          int viewCount = widget.post.videoViewCount;
          int likeCount = _likeCount;
          int commentCount = widget.post.commentCount;
          int repostCount = widget.post.repostCount;
          bool isLiked = _isLiked;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            viewCount = data['videoViewCount'] ?? 0;
            final List likes = data['likes'] as List? ?? [];
            likeCount = likes.length;
            commentCount = data['commentCount'] ?? 0;
            repostCount = data['repostCount'] ?? 0;
            isLiked = likes.contains(_activeUserId);
            if (!_isLikeUpdating) {
              _isLiked = isLiked;
              _likeCount = likeCount;
            }
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Seamless Handover Layer: Show placeholder while initializing
              if (!_isInitialized || !_videoController.value.isInitialized)
                Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: widget.post.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.post.imageUrls.first,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white24,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                ),

              if (_isInitialized && _videoController.value.isInitialized)
                GestureDetector(
                  onDoubleTap: _handleDoubleTap,
                  onTap: () {
                    setState(() {
                      _showProgress = true;
                      if (_videoController.value.isPlaying) {
                        _videoController.pause();
                        _releaseWakelock();
                      } else {
                        _videoController.play();
                        _acquireWakelock();
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
                ),
              if (_showLikeHeart)
                Center(
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.0, end: 1.2).animate(
                      CurvedAnimation(
                        parent: _heartAnimationController,
                        curve: Curves.elasticOut,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 100,
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InteractionButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      iconColor: isLiked ? Colors.redAccent : Colors.white,
                      label: '$likeCount',
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 4),
                    _InteractionButton(
                      icon: Icons.comment_outlined,
                      label: '$commentCount',
                      onTap: () => _openComments(autoFocus: false),
                    ),
                    const SizedBox(height: 4),
                    _InteractionButton(
                      icon: Icons.repeat,
                      label: _isReposting ? '...' : '$repostCount',
                      onTap: _confirmRepost,
                    ),
                    const SizedBox(height: 4),
                    _InteractionButton(
                      icon: Icons.share_outlined,
                      label: '',
                      onTap: _showShareOptions,
                    ),
                    const SizedBox(height: 4),
                    _InteractionButton(
                      icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      iconColor: _isSaved ? Colors.amberAccent : Colors.white,
                      label: '',
                      onTap: _toggleSave,
                    ),
                    const SizedBox(height: 4),
                    _InteractionButton(
                      icon: Icons.more_vert,
                      label: '',
                      onTap: _showMoreOptions,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                bottom: 40,
                right: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onOpenProfile,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: (widget.post.originalAuthorImageUrl ??
                                        widget.post.authorImageUrl) !=
                                    null
                                ? CachedNetworkImageProvider(
                                    widget.post.originalAuthorImageUrl ??
                                        widget.post.authorImageUrl!,
                                  )
                                : null,
                            child: (widget.post.originalAuthorImageUrl ??
                                        widget.post.authorImageUrl) ==
                                    null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: widget.onOpenProfile,
                            child: Text(
                              ownerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$viewCount views',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExpandableText(
                      widget.post.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      trimLines: 3,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: _showProgress ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black45],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isInitialized) ...[
                          VideoProgressIndicator(
                            _videoController,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _skip(-10),
                                    child: const Icon(
                                      Icons.replay_10,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ValueListenableBuilder(
                                    valueListenable: _videoController,
                                    builder:
                                        (context, VideoPlayerValue value, child) =>
                                            Text(
                                      '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () => _skip(10),
                                    child: const Icon(
                                      Icons.forward_10,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _toggleMute,
                                child: Icon(
                                  _isMuted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
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
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor ?? Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
