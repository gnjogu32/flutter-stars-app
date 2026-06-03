import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  const FullScreenVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.startPosition,
    this.post,
    this.currentUserId,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isMuted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Enable immersive mode and landscape orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
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
  void dispose() {
    // Restore system UI and orientation
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
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
                right: widget.post != null
                    ? 80
                    : 20, // Leave space for sidebar if present
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

            // Interactions Sidebar (Similar to Reels)
            if (_showControls &&
                widget.post != null &&
                widget.currentUserId != null)
              Positioned(
                right: 16,
                bottom: 100,
                child: VideoInteractionsSidebar(
                  post: widget.post!,
                  currentUserId: widget.currentUserId!,
                  isMuted: _isMuted,
                  onToggleMute: _toggleMute,
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
