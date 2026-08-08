import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import 'full_screen_video_player.dart';
import '../utils/screen_awake_controller.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final BoxFit fit;
  final double? aspectRatio;
  final VoidCallback? onVideoEnd;
  final VoidCallback? onPlay;
  final VoidCallback? onDoubleTap;
  final bool muted;
  final PostModel? post;
  final String? currentUserId;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.looping = true,
    this.showControls = true,
    this.fit = BoxFit.contain,
    this.aspectRatio,
    this.onVideoEnd,
    this.onPlay,
    this.onDoubleTap,
    this.muted = false,
    this.post,
    this.currentUserId,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  late bool _isMuted;
  bool _showOverlay = true;
  bool _showPlayPauseIndicator = false;
  Timer? _indicatorTimer;
  bool _playEventDispatched = false;
  String? _error;
  bool _ignoreVisibilityPause = false;
  bool _isHoldingWakelock = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMuted = widget.muted;
    _initializeController();
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

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _controller.setLooping(true);
          _controller.setVolume(_isMuted ? 0 : 1);
          if (widget.autoPlay) {
            _controller.play();
            _showOverlay = false;
            _dispatchPlayEvent();
            _acquireWakelock();
          }
        });

        _controller.addListener(() {
          if (_controller.value.position >= _controller.value.duration &&
              !_controller.value.isLooping &&
              _controller.value.isPlaying == false) {
            widget.onVideoEnd?.call();
            _releaseWakelock();
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error loading video');
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _releaseWakelock();
      _controller.dispose();
      _isInitialized = false;
      _initializeController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _indicatorTimer?.cancel();
    _releaseWakelock();
    if (!_ignoreVisibilityPause) {
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
      if (!_ignoreVisibilityPause && _controller.value.isPlaying) {
        _controller.pause();
        _releaseWakelock();
      }
    }
  }

  void _togglePlay() {
    _indicatorTimer?.cancel();
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showOverlay = true;
        _releaseWakelock();
      } else {
        _controller.play();
        _showOverlay = false;
        _dispatchPlayEvent();
        _acquireWakelock();
      }
      _showPlayPauseIndicator = true;
    });

    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showPlayPauseIndicator = false);
    });
  }

  Future<void> _handleTap() async {
    if (widget.post != null) {
      _ignoreVisibilityPause = true;
      _controller.setVolume(1.0);
      _controller.play();
      _dispatchPlayEvent();
      _acquireWakelock();

      final currentPosition = _controller.value.position;
      if (mounted) {
        setState(() {
          _isMuted = false;
          _showOverlay = false;
        });
      }

      if (!mounted || widget.post == null) return;
      Navigator.of(context)
          .push(
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black.withValues(alpha: 0.1),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  FullScreenVideoPlayer(
                    post: widget.post!,
                    currentUserId: widget.currentUserId,
                    startPosition: currentPosition,
                    inheritedController: _controller,
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          )
          .then((_) {
            if (mounted) {
              _controller.setVolume(0.0);
              _controller.pause();
              _releaseWakelock();
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) {
                  _ignoreVisibilityPause = false;
                  _isMuted = true;
                  if (_controller.value.isPlaying) {
                    _controller.pause();
                    _controller.setVolume(0.0);
                    _releaseWakelock();
                  }
                  setState(() {});
                }
              });
            } else {
              // The background widget was disposed while FullScreen was open!
              // We must dispose the controller now as we are the last ones with a reference.
              _controller.dispose();
            }
          });
    } else {
      _togglePlay();
    }
  }

  void pause() {
    if (_ignoreVisibilityPause) return;
    if (_isInitialized && _controller.value.isPlaying) {
      _controller.pause();
      if (mounted) setState(() => _showOverlay = true);
      _releaseWakelock();
    }
  }

  void play() {
    if (_isInitialized && !_controller.value.isPlaying) {
      _controller.play();
      if (mounted) setState(() => _showOverlay = false);
      _dispatchPlayEvent();
      _acquireWakelock();
    }
  }

  void _dispatchPlayEvent() {
    if (!_playEventDispatched) {
      widget.onPlay?.call();
      _playEventDispatched = true;
    }
  }

  void setMuted(bool mute) {
    if (_isInitialized) {
      setState(() {
        _isMuted = mute;
        _controller.setVolume(mute ? 0 : 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double ratio =
        widget.aspectRatio ??
        (_isInitialized ? _controller.value.aspectRatio : 16 / 9);

    if (_error != null) {
      return AspectRatio(
        aspectRatio: ratio,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white24,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Loading / Placeholder Layer
          if (!_isInitialized)
            Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: widget.post != null && widget.post!.imageUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.post!.imageUrls.first,
                      fit: widget.fit,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white24,
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white24,
                      ),
                    ),
            ),

          if (_isInitialized)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              onDoubleTap: widget.onDoubleTap,
              onLongPress: _togglePlay,
              child: RepaintBoundary(child: VideoPlayer(_controller)),
            ),

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
          if (_showPlayPauseIndicator)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          if (widget.showControls &&
              _showOverlay &&
              !_controller.value.isPlaying)
            Center(
              child: IconButton(
                icon: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white70,
                  size: 60,
                ),
                onPressed: _handleTap,
              ),
            ),
          if (widget.showControls && _showOverlay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.red,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, VideoPlayerValue value, child) =>
                              Text(
                                _formatDuration(value.position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                        ),
                        const Text(
                          ' / ',
                          style: TextStyle(color: Colors.white30, fontSize: 10),
                        ),
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setMuted(!_isMuted),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }
}
