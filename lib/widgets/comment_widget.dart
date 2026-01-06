import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment_model.dart';
import '../services/comment_service.dart';

class CommentWidget extends StatefulWidget {
  final CommentModel comment;
  final String currentUserId;
  final VoidCallback onDelete;

  const CommentWidget({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.onDelete,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  late bool _isLiked;
  final CommentService _commentService = CommentService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLikedBy(widget.currentUserId);
  }

  Future<void> _toggleLike() async {
    try {
      if (_isLiked) {
        await _commentService.unlikeComment(
          commentId: widget.comment.commentId,
          userId: widget.currentUserId,
        );
      } else {
        await _commentService.likeComment(
          commentId: widget.comment.commentId,
          userId: widget.currentUserId,
        );
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

  void _deleteComment() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onDelete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment header: Author info and time
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: widget.comment.authorImageUrl != null
                    ? NetworkImage(widget.comment.authorImageUrl!)
                    : null,
                child: widget.comment.authorImageUrl == null
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      timeago.format(widget.comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (widget.comment.authorId == widget.currentUserId)
                IconButton(
                  iconSize: 16,
                  icon: const Icon(Icons.more_vert),
                  onPressed: _deleteComment,
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Comment content
          Text(
            widget.comment.content,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          // Like button
          GestureDetector(
            onTap: _toggleLike,
            child: Row(
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 14,
                  color: _isLiked ? Colors.red : null,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.comment.likeCount > 0
                      ? '${widget.comment.likeCount}'
                      : '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
