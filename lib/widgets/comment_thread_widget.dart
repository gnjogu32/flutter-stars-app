import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../utils/auth_guard.dart';
import 'expandable_text.dart';

class CommentThreadWidget extends StatefulWidget {
  final CommentModel comment;
  final String currentUserId;
  final String postId;
  final VoidCallback onDelete;
  final void Function(CommentModel, String)? onReply;

  const CommentThreadWidget({
    super.key,
    required this.comment,
    required this.currentUserId,
    required this.postId,
    required this.onDelete,
    this.onReply,
  });

  @override
  State<CommentThreadWidget> createState() => _CommentThreadWidgetState();
}

class _CommentThreadWidgetState extends State<CommentThreadWidget> {
  late bool _isLiked;
  bool _showReplies = false;
  final CommentService _commentService = CommentService();

  static const List<String> _quickEmojis = [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '🥳',
    '😎',
    '🤔',
    '👏',
    '🔥',
    '💯',
    '✨',
    '🙌',
    '👍',
    '🙏',
    '❤️',
    '💙',
    '💚',
    '🎉',
    '😢',
    '😡',
    '🤝',
    '💫',
  ];

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

  Future<void> _editComment() async {
    final controller = TextEditingController(text: widget.comment.content);
    final focusNode = FocusNode();
    final messenger = ScaffoldMessenger.of(context);
    var showEmojiPanel = false;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final keyboardInset = MediaQuery.viewInsetsOf(dialogContext).bottom;
          final composerBottomInset = showEmojiPanel ? 0.0 : keyboardInset;
          return AlertDialog(
            title: const Text('Edit Comment'),
            content: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: composerBottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            setDialogState(
                              () => showEmojiPanel = !showEmojiPanel,
                            );
                            if (showEmojiPanel) {
                              focusNode.unfocus();
                              SystemChannels.textInput.invokeMethod(
                                'TextInput.hide',
                              );
                            } else {
                              FocusScope.of(
                                dialogContext,
                              ).requestFocus(focusNode);
                            }
                          },
                          icon: Icon(
                            showEmojiPanel
                                ? Icons.keyboard_outlined
                                : Icons.emoji_emotions_outlined,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onTap: () {
                              if (showEmojiPanel) {
                                setDialogState(() => showEmojiPanel = false);
                              }
                            },
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: 'Edit your comment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      height: showEmojiPanel ? 180 : 0,
                      child: showEmojiPanel
                          ? GridView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8,
                                    childAspectRatio: 1.2,
                                  ),
                              itemCount: _quickEmojis.length,
                              itemBuilder: (context, index) {
                                final emoji = _quickEmojis[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    final currentText = controller.text;
                                    final currentSelection =
                                        controller.selection;
                                    final start = currentSelection.start >= 0
                                        ? currentSelection.start
                                        : currentText.length;
                                    final end = currentSelection.end >= 0
                                        ? currentSelection.end
                                        : currentText.length;
                                    final newText = currentText.replaceRange(
                                      start,
                                      end,
                                      emoji,
                                    );
                                    controller.value = TextEditingValue(
                                      text: newText,
                                      selection: TextSelection.collapsed(
                                        offset: start + emoji.length,
                                      ),
                                    );
                                  },
                                  child: Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                );
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await _commentService.updateComment(
                    commentId: widget.comment.commentId,
                    content: controller.text.trim(),
                    authorId: widget.currentUserId,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Comment updated')),
                  );
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    focusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Main comment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundImage: widget.comment.authorImageUrl != null
                        ? NetworkImage(widget.comment.authorImageUrl!)
                        : null,
                    radius: 16,
                    child: widget.comment.authorImageUrl == null
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.comment.authorName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeago.format(widget.comment.createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.textTheme.labelSmall?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (widget.comment.replyToName != null)
                          Text(
                            'Replying to ${widget.comment.replyToName}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ExpandableText(
                          widget.comment.content,
                          style: theme.textTheme.bodySmall,
                          trimLines: 3,
                        ),
                        if (widget.comment.isEdited)
                          Text(
                            'Edited ${timeago.format(widget.comment.editedAt ?? widget.comment.createdAt)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: _toggleLike,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_outline,
                          size: 16,
                          color: _isLiked
                              ? Colors.red
                              : theme.textTheme.labelSmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.comment.likes.length.toString(),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () {
                      if (widget.currentUserId.isEmpty) {
                        AuthGuard.show(context);
                      } else {
                        widget.onReply?.call(
                          widget.comment,
                          widget.comment.commentId,
                        );
                      }
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.reply, size: 16),
                        SizedBox(width: 4),
                        Text('Reply'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (widget.currentUserId == widget.comment.authorId)
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          onTap: _editComment,
                          child: const Row(
                            children: [
                              Icon(Icons.edit, size: 16),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          onTap: _deleteComment,
                          child: const Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        Divider(height: 1, indent: 40, endIndent: 12),
        // Replies stream
        StreamBuilder<List<CommentModel>>(
          stream: _commentService.getReplies(widget.comment.commentId),
          builder: (context, snapshot) {
            final replies = snapshot.data ?? [];
            if (replies.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(left: 24, top: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_showReplies)
                    InkWell(
                      onTap: () => setState(() => _showReplies = true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    ...replies.map(
                      (reply) => Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 8),
                        child: _buildReplyWidget(reply, theme),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _showReplies = false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Hide replies',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReplyWidget(CommentModel reply, ThemeData theme) {
    bool replyIsLiked = reply.isLikedBy(widget.currentUserId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage: reply.authorImageUrl != null
                  ? NetworkImage(reply.authorImageUrl!)
                  : null,
              radius: 14,
              child: reply.authorImageUrl == null
                  ? const Icon(Icons.person, size: 14)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        reply.authorName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeago.format(reply.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.textTheme.labelSmall?.color?.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(reply.content, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          if (widget.currentUserId.isEmpty) {
                            await AuthGuard.show(context);
                            return;
                          }
                          try {
                            if (replyIsLiked) {
                              await _commentService.unlikeComment(
                                commentId: reply.commentId,
                                userId: widget.currentUserId,
                              );
                            } else {
                              await _commentService.likeComment(
                                commentId: reply.commentId,
                                userId: widget.currentUserId,
                              );
                            }
                            setState(() {
                              replyIsLiked = !replyIsLiked;
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              replyIsLiked
                                  ? Icons.favorite
                                  : Icons.favorite_outline,
                              size: 12,
                              color: replyIsLiked
                                  ? Colors.red
                                  : theme.textTheme.labelSmall?.color,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              reply.likes.length.toString(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          if (widget.currentUserId.isEmpty) {
                            AuthGuard.show(context);
                          } else {
                            widget.onReply?.call(
                              reply,
                              widget.comment.commentId,
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Reply',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
