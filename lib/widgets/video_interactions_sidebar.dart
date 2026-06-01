import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../models/post_model.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';
import '../utils/auth_guard.dart';
import 'post_details_sheet.dart';

class VideoInteractionsSidebar extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final bool isMuted;
  final VoidCallback onToggleMute;

  const VideoInteractionsSidebar({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.isMuted,
    required this.onToggleMute,
  });

  @override
  State<VideoInteractionsSidebar> createState() =>
      _VideoInteractionsSidebarState();
}

class _VideoInteractionsSidebarState extends State<VideoInteractionsSidebar> {
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(widget.currentUserId);
    _likeCount = widget.post.likeCount;
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating) return;
    if (!await AuthGuard.check(context, widget.currentUserId)) return;

    final wasLiked = _isLiked;
    setState(() {
      _isLikeUpdating = true;
      _isLiked = !wasLiked;
      _likeCount = wasLiked ? (_likeCount - 1) : _likeCount + 1;
    });

    try {
      if (wasLiked) {
        await PostService().unlikePost(
          widget.post.postId,
          widget.currentUserId,
        );
      } else {
        await PostService().likePost(widget.post.postId, widget.currentUserId);
        if (widget.currentUserId != widget.post.authorId) {
          final currentUser = await UserService().getUser(widget.currentUserId);
          if (currentUser != null) {
            await NotificationService().createNotification(
              userId: widget.post.authorId,
              triggeredBy: widget.currentUserId,
              triggeredByName: currentUser.displayName,
              triggeredByImageUrl: currentUser.profileImageUrl,
              type: 'like_post',
              postId: widget.post.postId,
              content: '${currentUser.displayName} liked your post',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = wasLiked ? (_likeCount + 1) : (_likeCount - 1);
        });
      }
    } finally {
      if (mounted) setState(() => _isLikeUpdating = false);
    }
  }

  void _openDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => PostDetailsSheet(
          post: widget.post,
          currentUserId: widget.currentUserId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _share() {
    ShareService.sharePost(widget.post);
  }

  Future<void> _download() async {
    if (widget.post.videoUrl == null || widget.post.videoUrl!.isEmpty) return;

    if ((widget.post.originalAuthorId ?? widget.post.authorId) !=
        widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the original author can download this video.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Downloading video...')));

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.post.videoUrl!));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await tempFile.writeAsBytes(bytes);

      await Gal.putVideo(tempFile.path, album: 'Starpage');

      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Video saved ✓')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _InteractionButton(
          icon: widget.isMuted ? Icons.volume_off : Icons.volume_up,
          label: widget.isMuted ? 'Muted' : 'Mute',
          onTap: widget.onToggleMute,
        ),
        const SizedBox(height: 14),
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
          onTap: _openDetails,
        ),
        const SizedBox(height: 14),
        _InteractionButton(
          icon: Icons.repeat,
          label: '${widget.post.repostCount}',
          onTap: _openDetails, // Reuse details for repost/comment actions
        ),
        const SizedBox(height: 14),
        _InteractionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: _share,
        ),
        if ((widget.post.originalAuthorId ?? widget.post.authorId) ==
            widget.currentUserId) ...[
          const SizedBox(height: 14),
          _InteractionButton(
            icon: Icons.download_outlined,
            label: 'Save',
            onTap: _download,
          ),
        ],
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
                  fontSize: 10,
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
