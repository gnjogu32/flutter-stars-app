import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoGridThumbnail extends StatefulWidget {
  final String videoUrl;
  final bool isTabVisible;
  const VideoGridThumbnail({
    super.key,
    required this.videoUrl,
    this.isTabVisible = true,
  });

  @override
  State<VideoGridThumbnail> createState() => _VideoGridThumbnailState();
}

class _VideoGridThumbnailState extends State<VideoGridThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.isTabVisible) {
      _initializeController();
    }
  }

  @override
  void didUpdateWidget(VideoGridThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabVisible && !oldWidget.isTabVisible && !_isInitialized) {
      _initializeController();
    } else if (!widget.isTabVisible && oldWidget.isTabVisible) {
      _controller?.pause();
      _controller?.setVolume(0);
    }
  }

  Future<void> _initializeController() async {
    if (widget.videoUrl.isEmpty || _controller != null) return;
    
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _controller!.setVolume(0);
          _controller!.pause();
        });
      }
    } catch (e) {
      debugPrint('Error initializing video thumbnail: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (!_isInitialized || _controller == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
        ),
      );
    }

    return VideoPlayer(_controller!);
  }
}
