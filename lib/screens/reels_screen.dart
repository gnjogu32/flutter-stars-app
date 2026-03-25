import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/post_model.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../utils/screen_awake_controller.dart';
import '../utils/auth_guard.dart';
import '../services/share_service.dart';
import '../services/user_service.dart';
import '../widgets/comments_bottom_sheet.dart';
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
            .orderBy('createdAt', descending: true)
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

          final reels = (snapshot.data?.docs ?? [])
              .map(
                (doc) => PostModel.fromJson(doc.data() as Map<String, dynamic>),
              )
              .where((post) => (post.videoUrl ?? '').trim().isNotEmpty)
              .toList();

          if (reels.isEmpty) {
            return const Center(
              child: Text(
                'No reels yet',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }

          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

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
                currentUserId: currentUserId,
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
  final String currentUserId;

  const _ReelItem({
    required this.post,
    required this.isActive,
    required this.onOpenProfile,
    required this.currentUserId,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  late final VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _holdsScreenAwake = false;
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isReposting = false;

  bool get _isSharedPost =>
      (widget.post.originalAuthorId ?? '').trim().isNotEmpty;

  String get _ownerId => _isSharedPost
      ? widget.post.originalAuthorId!.trim()
      : widget.post.authorId;

  String get _activeUserId => widget.currentUserId.trim();

  bool get _canInteract => _activeUserId.isNotEmpty;

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
    _isLiked = widget.post.isLikedBy(_activeUserId);
    _likeCount = widget.post.likeCount;
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

    if (!_isLikeUpdating) {
      _isLiked = widget.post.isLikedBy(_activeUserId);
      _likeCount = widget.post.likeCount;
    }

    if (!_isInitialized) return;

    if (widget.isActive && !oldWidget.isActive) {
      _controller.play();
      _syncScreenAwakeWithPlayback();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.pause();
      _syncScreenAwakeWithPlayback();
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating) return;
    if (!await AuthGuard.check(context, _activeUserId)) return;

    final notificationService = NotificationService();
    final userService = UserService();
    final wasLiked = _isLiked;
    final previousLikeCount = _likeCount;

    setState(() {
      _isLikeUpdating = true;
      _isLiked = !wasLiked;
      _likeCount = wasLiked
          ? (_likeCount > 0 ? _likeCount - 1 : 0)
          : _likeCount + 1;
    });

    try {
      if (wasLiked) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.postId)
            .update({
              'likes': FieldValue.arrayRemove([_activeUserId]),
            });
      } else {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.postId)
            .update({
              'likes': FieldValue.arrayUnion([_activeUserId]),
            });

        if (_activeUserId != _ownerId) {
          final currentUser = await userService.getUser(_activeUserId);
          if (currentUser != null) {
            await notificationService.createNotification(
              userId: _ownerId,
              triggeredBy: _activeUserId,
              triggeredByName: currentUser.displayName,
              triggeredByImageUrl: currentUser.profileImageUrl,
              type: 'like_post',
              postId: widget.post.postId,
              content: '${currentUser.displayName} liked your post',
            );
          }
        }
      }

      if (!mounted) return;
      setState(() => _isLikeUpdating = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLikeUpdating = false;
        _isLiked = wasLiked;
        _likeCount = previousLikeCount;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _repostToFeed({String caption = ''}) async {
    if (_isReposting) return;
    if (_activeUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    setState(() => _isReposting = true);

    try {
      final userService = UserService();
      final postService = PostService();
      final notificationService = NotificationService();

      final currentUser = await userService.getUser(_activeUserId);
      if (currentUser == null) {
        throw Exception('Could not load your profile for reposting.');
      }

      final actorName = currentUser.displayName.trim().isEmpty
          ? 'Someone'
          : currentUser.displayName.trim();

      await postService.repostPost(
        originalPost: widget.post,
        reposterId: _activeUserId,
        reposterName: actorName,
        reposterImageUrl: currentUser.profileImageUrl,
        repostCaption: caption,
      );

      if (_activeUserId != widget.post.authorId) {
        try {
          await notificationService.createNotification(
            userId: widget.post.authorId,
            triggeredBy: _activeUserId,
            triggeredByName: actorName,
            triggeredByImageUrl: currentUser.profileImageUrl,
            type: 'repost_post',
            postId: widget.post.postId,
            content: '$actorName reposted your content',
          );
        } catch (e) {
          debugPrint('Repost notification skipped: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reposted to your feed ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to repost: $e')));
    } finally {
      if (mounted) {
        setState(() => _isReposting = false);
      }
    }
  }

  Future<void> _confirmRepost() async {
    if (_isReposting) return;
    final textController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add an optional caption to your repost:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: InputDecoration(
                hintText: 'Write something...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
              maxLength: 280,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, textController.text),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Repost'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _repostToFeed(caption: result.trim());
    }
    textController.dispose();
  }

  Future<void> _openComments() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsBottomSheet(
        postId: widget.post.postId,
        postAuthorId: _ownerId,
        currentUserId: _activeUserId,
      ),
    );
  }

  void _sharePost() {
    ShareService.sharePost(widget.post);
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
          right: 12,
          bottom: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InteractionButton(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                iconColor: _isLiked ? Colors.redAccent : Colors.white,
                label: '$_likeCount',
                onTap: _toggleLike,
              ),
              const SizedBox(height: 14),
              _InteractionButton(
                icon: Icons.comment_outlined,
                label: '${widget.post.commentCount}',
                onTap: _openComments,
              ),
              const SizedBox(height: 14),
              _InteractionButton(
                icon: Icons.repeat,
                label: _isReposting ? '...' : '${widget.post.repostCount}',
                onTap: _confirmRepost,
              ),
              const SizedBox(height: 14),
              _InteractionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: _sharePost,
              ),
              if (!_canInteract) ...[
                const SizedBox(height: 10),
                const Text(
                  'Sign in',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
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

class _InteractionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _InteractionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor ?? Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
