import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post_model.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../services/share_service.dart';
import '../utils/animation_utils.dart';
import 'comments_bottom_sheet.dart';

class PostWidget extends StatefulWidget {
  final PostModel post;
  final String currentUserId;

  const PostWidget({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(widget.currentUserId);
  }

  Future<void> _toggleLike() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final notificationService = NotificationService();
    final userService = UserService();

    try {
      if (_isLiked) {
        // Unlike
        await firestore.collection('posts').doc(widget.post.postId).update({
          'likes': FieldValue.arrayRemove([widget.currentUserId]),
        });
      } else {
        // Like
        await firestore.collection('posts').doc(widget.post.postId).update({
          'likes': FieldValue.arrayUnion([widget.currentUserId]),
        });

        // Create like notification if not liking own post
        if (widget.currentUserId != widget.post.authorId) {
          final currentUser = await userService.getUser(widget.currentUserId);
          if (currentUser != null) {
            await notificationService.createNotification(
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

      setState(() {
        _isLiked = !_isLiked;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showShareDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Post',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.pop(context);
                ShareService.sharePost(widget.post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Share on WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareViaWhatsApp(widget.post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Share on Twitter'),
              onTap: () {
                Navigator.pop(context);
                ShareService.shareViaTwitter(widget.post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy to Clipboard'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Author info and time
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.post.authorImageUrl != null
                      ? NetworkImage(widget.post.authorImageUrl!)
                      : null,
                  child: widget.post.authorImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (widget.post.talent != null)
                        Text(
                          widget.post.talent!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Text(
                  timeago.format(widget.post.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Text(
              widget.post.content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            // Images
            if (widget.post.imageUrls.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.post.imageUrls.map((imageUrl) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          height: 200,
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 12),
            // Interactions
            Row(
              children: [
                // Like Button
                Expanded(
                  child: AnimationUtils.scaleButtonAnimation(
                    onTap: _toggleLike,
                    child: Row(
                      children: [
                        AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: _isLiked ? 1.2 : 1.0,
                          child: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.red : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: _isLiked ? Colors.red : null,
                                fontWeight: _isLiked
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                          child: Text('${widget.post.likeCount}'),
                        ),
                      ],
                    ),
                  ),
                ),
                // Comment Button
                Expanded(
                  child: AnimationUtils.scaleButtonAnimation(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => CommentsBottomSheet(
                          postId: widget.post.postId,
                          postAuthorId: widget.post.authorId,
                          currentUserId: widget.currentUserId,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.comment_outlined),
                        const SizedBox(width: 4),
                        Text('${widget.post.commentCount}'),
                      ],
                    ),
                  ),
                ),
                // Share Button
                Expanded(
                  child: AnimationUtils.scaleButtonAnimation(
                    onTap: () => _showShareDialog(),
                    child: const Row(
                      children: [
                        Icon(Icons.share_outlined),
                        SizedBox(width: 4),
                        Text('Share'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
