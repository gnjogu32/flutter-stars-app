import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:starpage/models/post_model.dart';
import 'package:starpage/widgets/video_interactions_sidebar.dart';
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
  Timer? _muteIndicatorTimer;
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
      if (widget.startPosition != null) {
        await _controller.seekTo(widget.startPosition!);
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
          if (widget.autoPlay) {
            _controller.play();
            _showControls = false;
            ScreenAwakeController.acquire();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading video: $e';
        });
      }
    }
  }

  @override
  void didUpdateWidget(_FullScreenVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay && !oldWidget.autoPlay) {
      _controller.play();
      ScreenAwakeController.acquire();
    } else if (!widget.autoPlay && oldWidget.autoPlay) {
      _controller.pause();
      ScreenAwakeController.release();
    }
  }

  @override
  void dispose() {
    _muteIndicatorTimer?.cancel();
    if (_isInitialized && _controller.value.isPlaying) {
      ScreenAwakeController.release();
    }
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showControls = true;
        ScreenAwakeController.release();
      } else {
        _controller.play();
        _showControls = false;
        ScreenAwakeController.acquire();
      }
    });
  }

  void _toggleMute() {
    _muteIndicatorTimer?.cancel();
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
      _showMuteIndicator = true;
    });

    _muteIndicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showMuteIndicator = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleMute,
      onLongPress: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      onDoubleTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 2) {
          // Rewind
          _controller.seekTo(
            _controller.value.position - const Duration(seconds: 10),
          );
        } else {
          // Forward
          _controller.seekTo(
            _controller.value.position + const Duration(seconds: 10),
          );
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

          // Mute/Unmute Indicator
          if (_showMuteIndicator)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 40,
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
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 80,
                ),
                onPressed: _togglePlay,
              ),
            ),

          // Bottom Progress bar and duration
          if (_showControls && _isInitialized)
            Positioned(
              bottom: 20,
              left: 20,
              right: 80,
              child: Column(
                children: [
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, VideoPlayerValue value, child) {
                          return Text(
                            _formatDuration(value.position),
                            style: const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                      Text(
                        _formatDuration(_controller.value.duration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
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
