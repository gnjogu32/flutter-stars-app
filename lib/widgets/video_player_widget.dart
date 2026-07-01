import 'package:flutter/material.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
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
  bool _ignoreVisibilityPause =
      false; // Flag to allow seamless portal transitions

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMuted = widget.muted;
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
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
            ScreenAwakeController.acquire();
          }
        });

        _controller.addListener(() {
          if (_controller.value.position >= _controller.value.duration &&
              !_controller.value.isLooping &&
              _controller.value.isPlaying == false) {
            widget.onVideoEnd?.call();
            ScreenAwakeController.release();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading video';
        });
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller.dispose();
      _isInitialized = false;
      _initializeController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _indicatorTimer?.cancel();
    if (_isInitialized && _controller.value.isPlaying) {
      ScreenAwakeController.release();
    }
    _controller.dispose();
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
      // Inline videos only autostart if they were playing before or if they are "active"
      // But for feeds, VisibilityDetector usually handles this.
      // We'll leave it to VisibilityDetector to avoid playing all videos at once.
    }
  }

  void _togglePlay() {
    _indicatorTimer?.cancel();
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showOverlay = true;
        ScreenAwakeController.release();
      } else {
        _controller.play();
        _showOverlay = false;
        _dispatchPlayEvent();
        ScreenAwakeController.acquire();
      }
      _showPlayPauseIndicator = true;
    });

    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showPlayPauseIndicator = false);
      }
    });
  }

  void pause() {
    if (_ignoreVisibilityPause) {
      return; // Prevent autopause during portal handoff
    }

    if (_isInitialized && _controller.value.isPlaying) {
      _controller.pause();
      if (mounted) {
        setState(() {
          _showOverlay = true;
        });
      }
      ScreenAwakeController.release();
    }
  }

  void play() {
    if (_isInitialized && !_controller.value.isPlaying) {
      _controller.play();
      if (mounted) {
        setState(() {
          _showOverlay = false;
        });
      }
      _dispatchPlayEvent();
      ScreenAwakeController.acquire();
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
    if (_error != null) {
      return Container(
        height: 200,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final double ratio = widget.aspectRatio ?? _controller.value.aspectRatio;

    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              if (widget.post != null) {
                // Instant Autostart: Trigger playback and un-mute before transition
                // We set the flag immediately to block any VisibilityDetector autopause
                _ignoreVisibilityPause = true;

                final currentPosition = _controller.value.position;
                _controller.setVolume(1.0);
                _controller.play();
                ScreenAwakeController.acquire();

                // Use a faster transition for "Instantaneous" feel
                if (!mounted) return;
                await Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                      FullScreenVideoPlayer(
                        videoUrl: widget.videoUrl,
                        startPosition: currentPosition,
                        post: widget.post,
                        currentUserId: widget.currentUserId,
                        manualController: _controller,
                      ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 250),
                  ),
                );

                // Restore state when returning to feed
                _ignoreVisibilityPause = false;
                if (mounted) {
                  // Ensure audio returns to muted for feed browsing
                  _controller.setVolume(0.0);
                  setState(() {});
                }
              } else {
                _togglePlay();
              }
            },
            onLongPress: _togglePlay,
            child: RepaintBoundary(
              child: VideoPlayer(_controller),
            ),
          ),

          // Buffering Indicator
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

          // Play/Pause Indicator
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
                          builder: (context, VideoPlayerValue value, child) {
                            return Text(
                              _formatDuration(value.position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            );
                          },
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
          // Standalone Mute Button for feed visibility
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
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
