import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comment_model.dart';
import 'expandable_text.dart' as custom;
import '../utils/auth_guard.dart';
import '../services/comment_service.dart';
import '../utils/time_utils.dart';
import '../screens/profile_screen.dart';

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
  bool _isEditing = false;
  late TextEditingController _editController;
  late FocusNode _editFocusNode;
  bool _showEditEmojiPanel = false;
  bool _isSavingEdit = false;
  late bool _isLiked;
  final CommentService _commentService = CommentService();
  final Set<String> _hiddenCommentIds = {};

  void _openAuthorProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
    );
  }

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

  final Map<String, FocusNode> replyEditFocusNodes = {};
  final Map<String, bool> replyEditEmojiPanels = {};
  String? replyEditId;
  final Map<String, TextEditingController> replyEditControllers = {};

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.likes.contains(widget.currentUserId);
    _editController = TextEditingController(text: widget.comment.content);
    _editFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    for (var controller in replyEditControllers.values) {
      controller.dispose();
    }
    for (var node in replyEditFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _deleteComment() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1D23) : null,
        title: Text(
          'Delete Comment',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _commentService.deleteComment(
          commentId: widget.comment.commentId,
          postId: widget.postId,
        );
        widget.onDelete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  void _toggleLike() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
    });

    try {
      if (wasLiked) {
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
    } catch (e) {
      setState(() {
        _isLiked = wasLiked;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _startEdit() {
    setState(() {
      _isEditing = true;
      _editController.text = widget.comment.content;
      _showEditEmojiPanel = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_editFocusNode);
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _showEditEmojiPanel = false;
    });
    _editFocusNode.unfocus();
  }

  void _copyComment(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _hideComment(String commentId) {
    setState(() {
      _hiddenCommentIds.add(commentId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comment hidden')),
    );
  }

  void _showActionMenu(CommentModel comment, bool isReply) {
    final isAuthor = widget.currentUserId == comment.authorId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1D23) : null,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  if (isReply) {
                    startReplyEdit(comment);
                  } else {
                    _startEdit();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  if (isReply) {
                    deleteReply(comment.commentId);
                  } else {
                    _deleteComment();
                  }
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                _copyComment(comment.content);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Hide'),
              onTap: () {
                Navigator.pop(context);
                _hideComment(comment.commentId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEdit() async {
    if (_editController.text.trim().isEmpty || _isSavingEdit) return;

    setState(() {
      _isSavingEdit = true;
    });

    try {
      await _commentService.updateComment(
        commentId: widget.comment.commentId,
        content: _editController.text.trim(),
        authorId: widget.currentUserId,
      );
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSavingEdit = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingEdit = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hiddenCommentIds.contains(widget.comment.commentId)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: () => _showActionMenu(widget.comment, false),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openAuthorProfile(widget.comment.authorId),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: widget.comment.authorImageUrl != null
                        ? CachedNetworkImageProvider(
                            widget.comment.authorImageUrl!,
                          )
                        : null,
                    child: widget.comment.authorImageUrl == null
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _openAuthorProfile(widget.comment.authorId),
                            child: Text(
                              widget.comment.authorName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            TimeUtils.formatShorthand(widget.comment.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: secondaryTextColor,
                            ),
                          ),
                          if (widget.comment.isEdited) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(edited)',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (widget.currentUserId == widget.comment.authorId)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _startEdit();
                                if (value == 'delete') _deleteComment();
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              child: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: secondaryTextColor,
                              ),
                            ),
                        ],
                      ),
                      if (_isEditing)
                        Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showEditEmojiPanel =
                                          !_showEditEmojiPanel;
                                    });
                                    if (_showEditEmojiPanel) {
                                      SystemChannels.textInput.invokeMethod(
                                        'TextInput.hide',
                                      );
                                    } else {
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(_editFocusNode);
                                    }
                                  },
                                  icon: Icon(
                                    _showEditEmojiPanel
                                        ? Icons.keyboard
                                        : Icons.emoji_emotions_outlined,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _editController,
                                    focusNode: _editFocusNode,
                                    maxLines: null,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      hintText: 'Edit your comment...',
                                      hintStyle: TextStyle(
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_showEditEmojiPanel)
                              SizedBox(
                                height: 150,
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 8,
                                      ),
                                  itemCount: _quickEmojis.length,
                                  itemBuilder: (context, index) => InkWell(
                                    onTap: () {
                                      _editController.text +=
                                          _quickEmojis[index];
                                    },
                                    child: Center(
                                      child: Text(
                                        _quickEmojis[index],
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _cancelEdit,
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: _isSavingEdit ? null : _saveEdit,
                                  child: _isSavingEdit
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Save'),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        custom.ExpandableText(
                          widget.comment.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                          ),
                        ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (widget.currentUserId.isEmpty) {
                                AuthGuard.show(context);
                              } else {
                                // Use parentId if this is already a reply, otherwise use commentId
                                final pId = widget.comment.parentId.isEmpty
                                    ? widget.comment.commentId
                                    : widget.comment.parentId;
                                widget.onReply?.call(widget.comment, pId);
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  size: 16,
                                  color: secondaryTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reply',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: _toggleLike,
                            child: Row(
                              children: [
                                Icon(
                                  _isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                  color: _isLiked
                                      ? Colors.red
                                      : secondaryTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.comment.likes.length}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: secondaryTextColor,
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
          ),
        ),
        StreamBuilder<List<CommentModel>>(
          stream: _commentService.getReplies(widget.comment.commentId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            final replies = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.only(left: 32.0),
              child: Column(
                children: replies
                    .map((reply) => _buildReplyWidget(reply, theme))
                    .toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReplyWidget(CommentModel reply, ThemeData theme) {
    if (_hiddenCommentIds.contains(reply.commentId)) {
      return const SizedBox.shrink();
    }
    final bool isReplyLiked = reply.likes.contains(widget.currentUserId);
    final bool isEditingThisReply = replyEditId == reply.commentId;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;

    return GestureDetector(
      onLongPress: () => _showActionMenu(reply, true),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _openAuthorProfile(reply.authorId),
              child: CircleAvatar(
                radius: 12,
                backgroundImage: reply.authorImageUrl != null
                    ? CachedNetworkImageProvider(reply.authorImageUrl!)
                    : null,
                child: reply.authorImageUrl == null
                    ? const Icon(Icons.person, size: 12)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _openAuthorProfile(reply.authorId),
                        child: Text(
                          reply.authorName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        TimeUtils.formatShorthand(reply.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: secondaryTextColor,
                        ),
                      ),
                      const Spacer(),
                      if (widget.currentUserId == reply.authorId)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') startReplyEdit(reply);
                            if (value == 'delete') deleteReply(reply.commentId);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          child: Icon(
                            Icons.more_vert,
                            size: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                    ],
                  ),
                  if (isEditingThisReply)
                    _buildReplyEditField(reply)
                  else
                    Text(
                      reply.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                      ),
                    ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          // Use root comment ID as parent
                          final pId = reply.parentId.isEmpty
                              ? reply.commentId
                              : reply.parentId;
                          widget.onReply?.call(reply, pId);
                        },
                        child: Text(
                          'Reply',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _toggleReplyLike(reply, isReplyLiked),
                        child: Row(
                          children: [
                            Icon(
                              isReplyLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: isReplyLiked
                                  ? Colors.red
                                  : secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${reply.likes.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: secondaryTextColor,
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
      ),
    );
  }

  Widget _buildReplyEditField(CommentModel reply) {
    final controller = replyEditControllers[reply.commentId];
    final focusNode = replyEditFocusNodes[reply.commentId];
    final showEmoji = replyEditEmojiPanels[reply.commentId] ?? false;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;

    if (controller == null || focusNode == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: null,
                style: TextStyle(fontSize: 12, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Edit your reply...',
                  hintStyle: TextStyle(color: secondaryTextColor),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                size: 18,
                color: secondaryTextColor,
              ),
              onPressed: () {
                setState(() {
                  replyEditEmojiPanels[reply.commentId] = !showEmoji;
                });
              },
            ),
          ],
        ),
        if (showEmoji)
          SizedBox(
            height: 100,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemCount: _quickEmojis.length,
              itemBuilder: (context, index) => InkWell(
                onTap: () => controller.text += _quickEmojis[index],
                child: Center(child: Text(_quickEmojis[index])),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => cancelReplyEdit(reply.commentId),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            TextButton(
              onPressed: () => saveReplyEdit(reply),
              child: const Text('Save', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleReplyLike(CommentModel reply, bool isLiked) async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }
    try {
      if (isLiked) {
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
      setState(() {}); // StreamBuilder will pick up changes from Firestore
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void startReplyEdit(CommentModel reply) {
    setState(() {
      replyEditId = reply.commentId;
      replyEditControllers[reply.commentId] = TextEditingController(
        text: reply.content,
      );
      replyEditFocusNodes[reply.commentId] = FocusNode();
      replyEditEmojiPanels[reply.commentId] = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(
          context,
        ).requestFocus(replyEditFocusNodes[reply.commentId]);
      }
    });
  }

  void cancelReplyEdit(String commentId) {
    setState(() {
      replyEditId = null;
      replyEditControllers[commentId]?.dispose();
      replyEditFocusNodes[commentId]?.dispose();
      replyEditControllers.remove(commentId);
      replyEditFocusNodes.remove(commentId);
      replyEditEmojiPanels.remove(commentId);
    });
  }

  Future<void> saveReplyEdit(CommentModel reply) async {
    final controller = replyEditControllers[reply.commentId];
    if (controller == null || controller.text.trim().isEmpty) return;

    try {
      await _commentService.updateComment(
        commentId: reply.commentId,
        content: controller.text.trim(),
        authorId: widget.currentUserId,
      );
      cancelReplyEdit(reply.commentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void deleteReply(String commentId) async {
    try {
      await _commentService.deleteComment(
        commentId: commentId,
        postId: widget.postId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
