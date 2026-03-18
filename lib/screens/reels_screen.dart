import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/post_model.dart';
import '../utils/screen_awake_controller.dart';
import 'profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  final ValueNotifier<bool> tabActiveNotifier;

  const ReelsScreen({super.key, required this.tabActiveNotifier});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PageController _pageController = PageController();
  int _activeIndex = 0;
  // Tracks whether this tab is the currently visible one.
  bool _tabVisible = false;

  @override
  void initState() {
    super.initState();
    _tabVisible = widget.tabActiveNotifier.value;
    widget.tabActiveNotifier.addListener(_onTabVisibilityChanged);
  }

  void _onTabVisibilityChanged() {
    final visible = widget.tabActiveNotifier.value;
    if (mounted) setState(() => _tabVisible = visible);
  }

  @override
  void dispose() {
    widget.tabActiveNotifier.removeListener(_onTabVisibilityChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .where('videoUrl', isNull: false)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading reels: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            );
          }

          final reels =
              (snapshot.data?.docs ?? [])
                  .map(
                    (doc) =>
                        PostModel.fromJson(doc.data() as Map<String, dynamic>),
                  )
                  .where((post) => (post.videoUrl ?? '').trim().isNotEmpty)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (reels.isEmpty) {
            return const Center(
              child: Text(
                'No reels yet',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            onPageChanged: (index) {
              setState(() => _activeIndex = index);
            },
            itemBuilder: (context, index) {
              final reel = reels[index];
              return _ReelItem(
                post: reel,
                isActive: _tabVisible && index == _activeIndex,
                onOpenProfile: () {
                  final userId = (reel.originalAuthorId ?? reel.authorId)
                      .trim();
                  if (userId.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: userId),
                    ),
                  );
                },
              );
            },
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

  const _ReelItem({
    required this.post,
    required this.isActive,
    required this.onOpenProfile,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _holdsScreenAwake = false;

  void _syncScreenAwakeWithPlayback() {
    if (!_isInitialized) return;
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying && !_holdsScreenAwake) {
      ScreenAwakeController.acquire();
      _holdsScreenAwake = true;
    } else if (!isPlaying && _holdsScreenAwake) {
      ScreenAwakeController.release();
      _holdsScreenAwake = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.post.videoUrl!))
          ..addListener(_syncScreenAwakeWithPlayback)
          ..setLooping(true)
          ..initialize().then((_) async {
            if (!mounted) return;
            setState(() => _isInitialized = true);
            if (widget.isActive) {
              await _controller.play();
              _syncScreenAwakeWithPlayback();
            }
          });
  }

  @override
  void didUpdateWidget(covariant _ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInitialized) return;

    if (widget.isActive && !oldWidget.isActive) {
      _controller.play();
      _syncScreenAwakeWithPlayback();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.pause();
      _syncScreenAwakeWithPlayback();
    }
  }

  @override
  void dispose() {
    if (_holdsScreenAwake) {
      ScreenAwakeController.release();
      _holdsScreenAwake = false;
    }
    _controller.removeListener(_syncScreenAwakeWithPlayback);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ownerName = (widget.post.originalAuthorName ?? widget.post.authorName)
        .trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isInitialized)
          GestureDetector(
            onTap: () {
              if (_controller.value.isPlaying) {
                _controller.pause();
                _syncScreenAwakeWithPlayback();
              } else {
                _controller.play();
                _syncScreenAwakeWithPlayback();
              }
            },
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onOpenProfile,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            (widget.post.originalAuthorImageUrl ??
                                    widget.post.authorImageUrl) !=
                                null
                            ? NetworkImage(
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
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                if (widget.post.content.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.post.content,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_isInitialized) ...[
                  const SizedBox(height: 8),
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
