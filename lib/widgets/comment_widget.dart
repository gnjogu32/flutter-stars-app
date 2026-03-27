import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../utils/auth_guard.dart';
import 'expandable_text.dart';

class CommentWidget extends StatefulWidget {
  final CommentModel comment;
  final String currentUserId;
  final VoidCallback onDelete;
  final void Function(CommentModel, String)? onReply;

  const CommentWidget({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.onDelete,
    this.onReply,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  late bool _isLiked;
  bool _showReplies = false;
  final CommentService _commentService = CommentService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLikedBy(widget.currentUserId);
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }
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

  void _editComment() {
    final controller = TextEditingController(text: widget.comment.content);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: InputDecoration(
            hintText: 'Edit your comment...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (controller.text.trim().isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Comment cannot be empty')),
                );
                return;
              }

              try {
                await _commentService.updateComment(
                  commentId: widget.comment.commentId,
                  content: controller.text.trim(),
                  authorId: widget.currentUserId,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Comment updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
              controller.dispose();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editComment();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteComment();
              },
            ),
          ],
        ),
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
                  onPressed: _showMoreOptions,
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Comment content with edited indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExpandableText(
                widget.comment.content,
                style: Theme.of(context).textTheme.bodyMedium,
                trimLines: 3,
              ),
              if (widget.comment.isEdited)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'edited ${timeago.format(widget.comment.editedAt ?? widget.comment.updatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Actions: Like + Reply
          Row(
            children: [
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
              if (widget.onReply != null) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () =>
                      widget.onReply!(widget.comment, widget.comment.commentId),
                  child: Row(
                    children: [
                      Icon(
                        Icons.reply,
                        size: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          // Replies section — root comments only
          if (widget.comment.parentId.isEmpty)
            StreamBuilder<List<CommentModel>>(
              stream: _commentService.getReplies(widget.comment.commentId),
              builder: (context, snapshot) {
                final replies = snapshot.data ?? [];
                if (replies.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setState(() => _showReplies = !_showReplies),
                      child: Text(
                        _showReplies
                            ? 'Hide replies'
                            : 'View ${replies.length} '
                                  '${replies.length == 1 ? 'reply' : 'replies'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_showReplies) ...[
                      const SizedBox(height: 8),
                      ...replies.map(
                        (reply) => _ReplyItem(
                          reply: reply,
                          currentUserId: widget.currentUserId,
                          onReply: widget.onReply,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Indented reply row (no further nesting) ────────────────────────────────
class _ReplyItem extends StatefulWidget {
  final CommentModel reply;
  final String currentUserId;
  final void Function(CommentModel, String)? onReply;

  const _ReplyItem({
    required this.reply,
    required this.currentUserId,
    this.onReply,
  });
  @override
  State<_ReplyItem> createState() => _ReplyItemState();
}

class _ReplyItemState extends State<_ReplyItem> {
  late bool _isLiked;
  final CommentService _commentService = CommentService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reply.isLikedBy(widget.currentUserId);
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }
    try {
      if (_isLiked) {
        await _commentService.unlikeComment(
          commentId: widget.reply.commentId,
          userId: widget.currentUserId,
        );
      } else {
        await _commentService.likeComment(
          commentId: widget.reply.commentId,
          userId: widget.currentUserId,
        );
      }
      if (mounted) setState(() => _isLiked = !_isLiked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 6, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: widget.reply.authorImageUrl != null
                          ? NetworkImage(widget.reply.authorImageUrl!)
                          : null,
                      child: widget.reply.authorImageUrl == null
                          ? const Icon(Icons.person, size: 12)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.reply.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      timeago.format(widget.reply.createdAt),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (widget.reply.replyToName != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '@${widget.reply.replyToName} ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: widget.reply.content,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    widget.reply.content,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 12,
                        color: _isLiked ? Colors.red : null,
                      ),
                      if (widget.reply.likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${widget.reply.likeCount}',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.onReply != null) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => widget.onReply!(
                      widget.reply,
                      widget.reply.parentId.isEmpty
                          ? widget.reply.commentId
                          : widget.reply.parentId,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.reply,
                          size: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reply',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
