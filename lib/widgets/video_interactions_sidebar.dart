import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../services/notification_service.dart';
import '../services/share_service.dart';
import '../services/analytics_service.dart';
import '../utils/auth_guard.dart';
import 'post_details_sheet.dart';

class VideoInteractionsSidebar extends StatefulWidget {
  final PostModel post;
  final String currentUserId;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback? onCommentTap;
  final VoidCallback? onMoreTap;
  final VoidCallback? onRepostTap;
  final VoidCallback? onShareTap;

  const VideoInteractionsSidebar({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.isMuted,
    required this.onToggleMute,
    this.onCommentTap,
    this.onMoreTap,
    this.onRepostTap,
    this.onShareTap,
  });

  @override
  State<VideoInteractionsSidebar> createState() =>
      _VideoInteractionsSidebarState();
}

class _VideoInteractionsSidebarState extends State<VideoInteractionsSidebar> {
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isSaved = false;
  final AnalyticsService _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(widget.currentUserId);
    _likeCount = widget.post.likeCount;
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    if (widget.currentUserId.isEmpty) return;
    try {
      final userService = UserService();
      final savedIds = await userService.getSavedPostIds(widget.currentUserId);
      if (mounted) {
        setState(() {
          _isSaved = savedIds.contains(widget.post.postId);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);

    try {
      final userService = UserService();
      if (wasSaved) {
        await userService.unsavePost(widget.currentUserId, widget.post.postId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Removed from Saved ✓')));
        }
      } else {
        await userService.savePost(widget.currentUserId, widget.post.postId);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Added to Saved ✓')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaved = wasSaved);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
        await _analyticsService.trackUnlike(
          widget.post.postId,
          widget.currentUserId,
        );
      } else {
        await PostService().likePost(widget.post.postId, widget.currentUserId);
        await _analyticsService.trackLike(
          widget.post.postId,
          (widget.post.originalAuthorId ?? widget.post.authorId).trim(),
          widget.currentUserId,
        );
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
    if (widget.onCommentTap != null) {
      widget.onCommentTap!();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) => PostDetailsSheet(
          post: widget.post,
          currentUserId: widget.currentUserId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _openComments() {
    if (widget.onCommentTap != null) {
      widget.onCommentTap!();
    } else {
      _openDetails();
    }
  }

  void _openRepost() {
    if (widget.onRepostTap != null) {
      widget.onRepostTap!();
    } else {
      _openDetails();
    }
  }

  void _share() {
    if (widget.onShareTap != null) {
      widget.onShareTap!();
    } else {
      ShareService.sharePost(widget.post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
          label: '${widget.post.repostCount}',
          onTap: _openRepost, // Reuse details for repost/comment actions
        ),
        const SizedBox(height: 14),
        _InteractionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: _share,
        ),
        const SizedBox(height: 14),
        _InteractionButton(
          icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
          iconColor: _isSaved ? Colors.amberAccent : Colors.white,
          label: _isSaved ? 'Saved' : 'Save',
          onTap: _toggleSave,
        ),
        if (widget.onMoreTap != null) ...[
          const SizedBox(height: 14),
          _InteractionButton(
            icon: Icons.more_vert,
            label: 'More',
            onTap: widget.onMoreTap!,
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: iconColor ?? Colors.white,
                size: 22,
              ),
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
