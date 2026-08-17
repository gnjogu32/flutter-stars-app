import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../models/post_model.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';
import '../utils/auth_guard.dart';
import '../widgets/expandable_text.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/video_interactions_sidebar.dart';
import 'repost_dialog.dart';
import '../screens/profile_screen.dart';
import '../utils/screen_awake_controller.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final PostModel post;
  final String? currentUserId;
  final bool autoPlay;
  final Duration? startPosition;
  final VideoPlayerController? inheritedController;

  const FullScreenVideoPlayer({
    super.key,
    required this.post,
    this.currentUserId,
    this.autoPlay = true,
    this.startPosition,
    this.inheritedController,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late PageController _pageController;
  final List<PostModel> _posts = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _posts.add(widget.post);
    _pageController = PageController();
    _fetchMoreVideos();
  }

  Future<void> _fetchMoreVideos() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('postType', isEqualTo: 'video')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final newPosts = snapshot.docs
          .map((doc) => PostModel.fromJson(doc.data()))
          .where((p) => p.postId != widget.post.postId)
          .toList();

      if (mounted) {
        setState(() {
          _posts.addAll(newPosts);
          _isLoadingMore = false;
          _hasMore = newPosts.length >= 15;
        });
      }
    } catch (e) {
      debugPrint('Error fetching more videos for immersive feed: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _activeIndex = index);
          if (index >= _posts.length - 5) {
            _fetchMoreVideos();
          }
        },
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          return _ImmersiveVideoItem(
            post: _posts[index],
            currentUserId: widget.currentUserId,
            autoPlay: index == _activeIndex,
            initialPosition: index == 0 ? widget.startPosition : null,
            inheritedController: index == 0 ? widget.inheritedController : null,
          );
        },
      ),
    );
  }
}

class _ImmersiveVideoItem extends StatefulWidget {
  final PostModel post;
  final String? currentUserId;
  final bool autoPlay;
  final Duration? initialPosition;
  final VideoPlayerController? inheritedController;

  const _ImmersiveVideoItem({
    required this.post,
    this.currentUserId,
    required this.autoPlay,
    this.initialPosition,
    this.inheritedController,
  });

  @override
  State<_ImmersiveVideoItem> createState() => _ImmersiveVideoItemState();
}

class _ImmersiveVideoItemState extends State<_ImmersiveVideoItem>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isReposting = false;
  bool _showProgress = false;
  bool _showLikeHeart = false;
  late AnimationController _heartAnimationController;
  Timer? _progressTimer;
  bool _isHoldingWakelock = false;
  bool _usingInherited = false;
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLiked = widget.post.isLikedBy(widget.currentUserId ?? '');
    _likeCount = widget.post.likeCount;
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initializePlayer();
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

  Future<void> _toggleLike() async {
    if (_isLikeUpdating || widget.currentUserId == null) {
      if (widget.currentUserId == null) await AuthGuard.show(context);
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
        await PostService().unlikePost(
          widget.post.postId,
          widget.currentUserId!,
        );
      } else {
        await PostService().likePost(widget.post.postId, widget.currentUserId!);
        if (widget.currentUserId != widget.post.authorId) {
          final currentUser = await UserService().getUser(
            widget.currentUserId!,
          );
          if (currentUser != null) {
            await NotificationService().createNotification(
              userId: widget.post.authorId,
              triggeredBy: widget.currentUserId!,
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLikeUpdating = false);
      }
    }
  }

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

  Future<void> _initializePlayer() async {
    if (widget.inheritedController != null) {
      _controller = widget.inheritedController!;
      _usingInherited = true;
      _isInitialized = _controller.value.isInitialized;
      if (widget.autoPlay && mounted) {
        _controller.play();
        _acquireWakelock();
      }
      if (mounted) setState(() {});
      return;
    }

    if (widget.post.videoUrl == null) return;
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.videoUrl!),
    );
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      if (widget.initialPosition != null) {
        await _controller.seekTo(widget.initialPosition!);
      }
      if (widget.autoPlay && mounted) {
        _controller.play();
        _acquireWakelock();
      }
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing immersive video: $e');
    }
  }

  @override
  void didUpdateWidget(_ImmersiveVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.autoPlay && !oldWidget.autoPlay) {
        _controller.play();
        _acquireWakelock();
      } else if (!widget.autoPlay && oldWidget.autoPlay) {
        _controller.pause();
        _releaseWakelock();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _releaseWakelock();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (widget.autoPlay && !_controller.value.isPlaying) {
        _controller.play();
        _acquireWakelock();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _heartAnimationController.dispose();
    if (_isInitialized) {
      _controller.pause();
      _releaseWakelock();
      if (!_usingInherited) {
        _controller.dispose();
      }
    }
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _showProgress = true;
      if (_controller.value.isPlaying) {
        _controller.pause();
        _releaseWakelock();
        _progressTimer?.cancel();
      } else {
        _controller.play();
        _acquireWakelock();
        _startProgressTimer();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
      _showProgress = true;
    });
    _startProgressTimer();
  }

  void _openComments({bool autoFocus = false}) async {
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
          postAuthorId: (widget.post.originalAuthorId ?? widget.post.authorId),
          currentUserId: widget.currentUserId ?? '',
          postContent: widget.post.content,
          scrollController: scrollController,
          autoFocus: autoFocus,
        ),
      ),
    );
  }

  Future<void> _repostToFeed({
    String caption = '',
    String visibility = 'public',
  }) async {
    if (_isReposting || widget.currentUserId == null) return;
    setState(() => _isReposting = true);
    try {
      final user = await UserService().getUser(widget.currentUserId!);
      if (user == null) throw Exception('User not found');
      await PostService().repostPost(
        originalPost: widget.post,
        reposterId: widget.currentUserId!,
        reposterName: user.displayName,
        reposterUsername: user.username,
        reposterImageUrl: user.profileImageUrl,
        repostCaption: caption,
        visibility: visibility,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reposted! ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isReposting = false);
    }
  }

  void _confirmRepost() async {
    final result = await RepostDialog.show(
      context,
      post: widget.post,
      currentUserId: widget.currentUserId!,
    );

    if (result != null) {
      _repostToFeed(caption: result.caption, visibility: result.visibility);
    }
  }

  void _showMoreOptions() {
    final isAuthor = widget.post.authorId == widget.currentUserId;
    final ownerName = (widget.post.originalAuthorName ?? widget.post.authorName)
        .trim();
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
                    Navigator.of(
                      context,
                    ).pushNamed('/edit-post', arguments: widget.post);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
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
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Post deleted')),
                        );
                        navigator.pop();
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
                    if (mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Post reported.')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: Text('Mute $ownerName'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    if (widget.currentUserId != null) {
                      await UserService().muteAuthor(
                        widget.currentUserId!,
                        widget.post.authorId,
                      );
                    }
                    if (mounted) {
                      messenger.showSnackBar(
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
              title: const Text('Copy Post Link'),
              onTap: () {
                Navigator.pop(context);
                final postUrl = AppConstants.postUrl(widget.post.postId);
                Clipboard.setData(ClipboardData(text: postUrl));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied ✓')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.pop(context);
                ShareService.sharePost(widget.post);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post details copied for sharing ✓'),
                    ),
                  );
                }
                // Track share in analytics
                if (widget.currentUserId != null) {
                  AnalyticsService().trackShare(
                    widget.post.postId,
                    widget.post.authorId,
                    widget.currentUserId!,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repost to Feed'),
              onTap: () {
                Navigator.pop(context);
                _confirmRepost();
              },
            ),
            if (widget.post.authorId == widget.currentUserId)
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

  void _skip(int seconds) {
    if (!_isInitialized) {
      return;
    }
    final currentPos = _controller.value.position;
    final newPos = currentPos + Duration(seconds: seconds);
    _controller.seekTo(newPos);
    setState(() => _showProgress = true);
    _startProgressTimer();
  }

  Future<void> _downloadVideo() async {
    if (widget.post.videoUrl == null || widget.post.videoUrl!.isEmpty) return;

    if (widget.post.authorId != widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the author can download this video.'),
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.postId)
          .snapshots(),
      builder: (context, snapshot) {
        int viewCount = widget.post.videoViewCount;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          viewCount = data['videoViewCount'] ?? 0;
        }

        return Stack(
          children: [
            // Seamless Handover Layer: Show placeholder while initializing
            if (!_isInitialized || !_controller.value.isInitialized)
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

            if (_isInitialized && _controller.value.isInitialized)
              GestureDetector(
                onDoubleTap: _handleDoubleTap,
                onTap: _togglePlay,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
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

            // Back button
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Sidebar
            if (widget.currentUserId != null)
              Positioned(
                right: 12,
                bottom: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoInteractionsSidebar(
                      post: widget.post,
                      currentUserId: widget.currentUserId!,
                      isMuted: _isMuted,
                      onToggleMute: _toggleMute,
                      onCommentTap: () => _openComments(autoFocus: false),
                      onRepostTap: _confirmRepost,
                      onMoreTap: _showMoreOptions,
                      onShareTap: _showShareOptions,
                    ),
                  ],
                ),
              ),

            // Bottom details
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ProfileScreen(userId: widget.post.authorId),
                          ),
                        ),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ProfileScreen(userId: widget.post.authorId),
                            ),
                          ),
                          child: Text(
                            widget.post.authorName,
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

            // Progress bar and controls at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showProgress ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showProgress,
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
                            _controller,
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
                                    valueListenable: _controller,
                                    builder:
                                        (
                                          context,
                                          VideoPlayerValue value,
                                          child,
                                        ) {
                                          return Text(
                                            '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
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
            ),
          ],
        );
      },
    );
  }
}
