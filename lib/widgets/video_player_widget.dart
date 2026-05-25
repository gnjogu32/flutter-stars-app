import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'full_screen_video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool looping;
  final bool showControls;
  final BoxFit fit;
  final double? aspectRatio;
  final VoidCallback? onVideoEnd;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.looping = true,
    this.showControls = true,
    this.fit = BoxFit.contain,
    this.aspectRatio,
    this.onVideoEnd,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _showOverlay = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _controller.setLooping(widget.looping);
          if (widget.autoPlay) {
            _controller.play();
            _showOverlay = false;
          }
        });

        _controller.addListener(() {
          if (_controller.value.position >= _controller.value.duration &&
              !_controller.value.isLooping) {
            widget.onVideoEnd?.call();
          }
          if (mounted) setState(() {});
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
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showOverlay = true;
      } else {
        _controller.play();
        _showOverlay = false;
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
            onTap: () {
              if (widget.showControls) {
                setState(() => _showOverlay = !_showOverlay);
              } else {
                _togglePlay();
              }
            },
            child: VideoPlayer(_controller),
          ),
          if (_showOverlay && widget.showControls)
            _buildControlsOverlay(),
          if (widget.showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white70,
              ),
              onPressed: _toggleMute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black38,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 30),
              onPressed: () {
                _controller.seekTo(
                  _controller.value.position - const Duration(seconds: 10),
                );
              },
            ),
            IconButton(
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
              onPressed: _togglePlay,
            ),
            IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 30),
              onPressed: () {
                _controller.seekTo(
                  _controller.value.position + const Duration(seconds: 10),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white, size: 30),
              onPressed: () {
                _controller.pause();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FullScreenVideoPlayer(
                      videoUrl: widget.videoUrl,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
