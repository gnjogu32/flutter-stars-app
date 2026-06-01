import 'package:flutter/material.dart';
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

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  late bool _isMuted;
  bool _showOverlay = true;
  bool _playEventDispatched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.muted;
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
        _showOverlay = true;
        ScreenAwakeController.release();
      } else {
        _controller.play();
        _showOverlay = false;
        _dispatchPlayEvent();
        ScreenAwakeController.acquire();
      }
    });
  }

  void pause() {
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
          if (_showOverlay && widget.showControls) _buildControlsOverlay(),
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
              onPressed: () => setMuted(!_isMuted),
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
                final currentPosition = _controller.value.position;
                _controller.pause();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FullScreenVideoPlayer(
                      videoUrl: widget.videoUrl,
                      startPosition: currentPosition,
                      post: widget.post,
                      currentUserId: widget.currentUserId,
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
