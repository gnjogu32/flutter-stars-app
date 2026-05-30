import 'package:flutter/material.dart';
import 'package:starpage/models/post_model.dart';
import 'package:starpage/widgets/comments_bottom_sheet.dart';
import 'package:starpage/services/user_service.dart';
import 'package:starpage/services/post_service.dart';
import 'package:starpage/services/notification_service.dart';
import 'package:starpage/services/share_service.dart';
import 'package:starpage/utils/auth_guard.dart';
import 'package:starpage/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:starpage/widgets/expandable_text.dart';

class PostDetailsSheet extends StatefulWidget {
  final PostModel post;
  final ScrollController? scrollController;
  final String currentUserId;

  const PostDetailsSheet({
    super.key,
    required this.post,
    this.scrollController,
    required this.currentUserId,
  });

  @override
  State<PostDetailsSheet> createState() => _PostDetailsSheetState();
}

class _PostDetailsSheetState extends State<PostDetailsSheet> {
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isReposting = false;

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

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsBottomSheet(
        postId: widget.post.postId,
        postAuthorId: widget.post.authorId,
        currentUserId: widget.currentUserId,
        postContent: widget.post.content,
      ),
    );
  }

  Future<void> _repost() async {
    if (_isReposting) return;
    setState(() => _isReposting = true);
    try {
      final userService = UserService();
      final currentUser = await userService.getUser(widget.currentUserId);
      if (currentUser == null) throw Exception('Profile not found');

      await PostService().repostPost(
        originalPost: widget.post,
        reposterId: widget.currentUserId,
        reposterName: currentUser.displayName,
        reposterImageUrl: currentUser.profileImageUrl,
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reposted ✓')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isReposting = false);
    }
  }

  void _share() {
    ShareService.sharePost(widget.post);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ownerName = widget.post.originalAuthorName ?? widget.post.authorName;
    final ownerImageUrl =
        widget.post.originalAuthorImageUrl ?? widget.post.authorImageUrl;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.post.repostCaption != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original post by $ownerName',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ExpandableText(
                          widget.post.content,
                          style: theme.textTheme.bodySmall,
                          trimLines: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your caption:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpandableText(
                    widget.post.repostCaption!,
                    style: theme.textTheme.bodyMedium,
                    trimLines: 5,
                  ),
                ] else ...[
                  ExpandableText(
                    widget.post.content,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                    trimLines: 10,
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // Interaction TabBar (Consistent with Feed)
          DefaultTabController(
            length: 4,
            child: TabBar(
              onTap: (index) {
                if (index == 0) _toggleLike();
                if (index == 1) _openComments();
                if (index == 2) _repost();
                if (index == 3) _share();
              },
              indicatorColor: Colors.transparent,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              dividerColor: Colors.transparent,
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: theme.textTheme.labelSmall,
              tabs: [
                Tab(
                  height: 48,
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : null,
                    size: 20,
                  ),
                  child: Text(
                    '$_likeCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                Tab(
                  height: 48,
                  icon: const Icon(Icons.comment_outlined, size: 20),
                  child: Text(
                    '${widget.post.commentCount}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                Tab(
                  height: 48,
                  icon: const Icon(Icons.repeat, size: 20),
                  child: Text(
                    '${widget.post.repostCount}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                const Tab(
                  height: 48,
                  icon: Icon(Icons.share_outlined, size: 20),
                  child: Text('Share', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),

          // Author section at the very bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(userId: widget.post.authorId),
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: ownerImageUrl != null
                        ? CachedNetworkImageProvider(ownerImageUrl)
                        : null,
                    child: ownerImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ownerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.post.talent != null)
                        Text(
                          widget.post.talent!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
