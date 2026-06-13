import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:starpage/models/post_model.dart';
import 'package:starpage/widgets/video_interactions_sidebar.dart';
import 'package:starpage/widgets/expandable_text.dart';
import 'package:starpage/screens/profile_screen.dart';
import 'package:starpage/screens/full_screen_comments_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/screen_awake_controller.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final Duration? startPosition;
  final PostModel? post;
  final String? currentUserId;
  final List<PostModel>? playlist;
  final int initialIndex;

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.startPosition,
    this.post,
    this.currentUserId,
    this.playlist,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late PageController _pageController;
  late int _currentIndex;
  late List<PostModel> _videos;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _videos = widget.playlist ?? (widget.post != null ? [widget.post!] : []);
    _pageController = PageController(initialPage: _currentIndex);

    // Enable immersive mode and landscape orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    // Restore system UI and orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _pageController.dispose();
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
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final post = _videos[index];
          return _FullScreenVideoItem(
            key: ValueKey('fs_${post.postId}_$index'),
            post: post,
            autoPlay: index == _currentIndex,
            startPosition: index == widget.initialIndex
                ? widget.startPosition
                : null,
            currentUserId: widget.currentUserId,
          );
        },
      ),
    );
  }
}

class _FullScreenVideoItem extends StatefulWidget {
  final PostModel post;
  final bool autoPlay;
  final Duration? startPosition;
  final String? currentUserId;

  const _FullScreenVideoItem({
    super.key,
    required this.post,
    required this.autoPlay,
    this.startPosition,
    this.currentUserId,
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
  Timer? _indicatorTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
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
          _showControls = false;
          ScreenAwakeController.acquire();
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

  void _videoListener() {
    if (_isInitialized) {
      final position = _controller.value.position;
      final duration = _controller.value.duration;

      if (position >= duration && duration > Duration.zero) {
        if (!_isVideoEnded) {
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

    if (widget.autoPlay && !oldWidget.autoPlay) {
      if (!_controller.value.isPlaying) {
        if (_isVideoEnded) {
          _controller.seekTo(Duration.zero);
        }
        _controller.play();
        ScreenAwakeController.acquire();
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
    _indicatorTimer?.cancel();
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
        _showControls = false;
        ScreenAwakeController.acquire();
      }
      _showPlayPauseIndicator = true;
      _showMuteIndicator = false;
    });

    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showPlayPauseIndicator = false);
      }
    });
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
    _indicatorTimer?.cancel();
    setState(() {
      _showSkipForward = forward;
      _showSkipBackward = !forward;
      _showMuteIndicator = false;
      _showPlayPauseIndicator = false;
    });

    _indicatorTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showSkipForward = false;
          _showSkipBackward = false;
        });
      }
    });
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
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth * 0.35) {
          // Rewind
          final newPos =
              _controller.value.position - const Duration(seconds: 10);
          _controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
          _showSkipIndicator(forward: false);
        } else if (details.globalPosition.dx > screenWidth * 0.65) {
          // Forward
          final newPos =
              _controller.value.position + const Duration(seconds: 10);
          _controller.seekTo(newPos);
          _showSkipIndicator(forward: true);
        }
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

          // Skip Backward Indicator
          if (_showSkipBackward)
            Positioned(
              left: 50,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fast_rewind, color: Colors.white, size: 40),
                    const SizedBox(height: 4),
                    const Text('10s',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // Skip Forward Indicator
          if (_showSkipForward)
            Positioned(
              right: 50,
              top: 0,
              bottom: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fast_forward,
                        color: Colors.white, size: 40),
                    const SizedBox(height: 4),
                    const Text('10s',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
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
                                    '${widget.post.videoViewCount} views',
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

          // Interactions Sidebar
          if (_showControls && widget.currentUserId != null)
            Positioned(
              right: 16,
              bottom: 100,
              child: VideoInteractionsSidebar(
                post: widget.post,
                currentUserId: widget.currentUserId!,
                isMuted: _isMuted,
                onToggleMute: _toggleMute,
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
