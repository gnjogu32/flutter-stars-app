import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/comment_service.dart';
import '../services/user_service.dart';
import '../utils/auth_guard.dart';
import '../utils/time_utils.dart';
import 'package:starpage/screens/profile_screen.dart';
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
  UserModel? _currentUser;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLikedBy(widget.currentUserId);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (widget.currentUserId.isNotEmpty) {
      final user = await _userService.getUser(widget.currentUserId);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
  }

  Future<void> _showReplyDialog(
    CommentModel parent,
    String parentId, {
    String? replyToName,
  }) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1D23) : null,
        title: Text(
          replyToName != null ? 'Reply to @$replyToName' : 'Reply',
          style: TextStyle(color: textColor),
        ),
        content: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          maxLines: null,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Write your reply...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
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
              final text = controller.text.trim();
              if (text.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Reply cannot be empty')),
                );
                return;
              }
              try {
                await CommentService().addComment(
                  postId: parent.postId,
                  authorId: widget.currentUserId,
                  authorName: _currentUser?.displayName ?? 'User',
                  authorImageUrl: _currentUser?.profileImageUrl,
                  content: text,
                  postAuthorId: parent.authorId,
                  parentId: parentId,
                  replyToName: replyToName,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Reply posted')),
                  );
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
    focusNode.dispose();
    controller.dispose();
  }

  late bool _isLiked;
  bool _showReplies = false;
  final CommentService _commentService = CommentService();
  final Set<String> _hiddenCommentIds = {};

  void _openAuthorProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
    );
  }

  void _copyComment(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  void _hideComment(String commentId) {
    setState(() {
      _hiddenCommentIds.add(commentId);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Comment hidden')));
  }

  void _showActionMenu(CommentModel comment) {
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
                  _editComment();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment();
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
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final textColor = isDark ? Colors.white : Colors.black87;

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1D23) : null,
            title: Text('Edit Comment', style: TextStyle(color: textColor)),
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
                            color: isDark ? Colors.white70 : Colors.black54,
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
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Edit your comment...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
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
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
    focusNode.dispose();
    controller.dispose();
  }

  void _showMoreOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1D23) : null,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: isDark ? Colors.white70 : null),
              title: Text(
                'Edit',
                style: TextStyle(color: isDark ? Colors.white : null),
              ),
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
    if (_hiddenCommentIds.contains(widget.comment.commentId)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23272F) : Colors.white;
    final borderColor = isDark ? const Color(0xFF353A45) : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onLongPress: () => _showActionMenu(widget.comment),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Card(
          color: cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment header: Author info and time
                Row(
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
                    const SizedBox(width: 8),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            _openAuthorProfile(widget.comment.authorId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.comment.authorName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              TimeUtils.formatShorthand(
                                widget.comment.createdAt,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.comment.authorId == widget.currentUserId)
                      IconButton(
                        iconSize: 16,
                        icon: Icon(
                          Icons.more_vert,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                      trimLines: 3,
                    ),
                    if (widget.comment.isEdited)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'edited ${TimeUtils.formatShorthand(widget.comment.editedAt ?? widget.comment.updatedAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontSize: 10,
                            color: isDark ? Colors.white70 : Colors.black54,
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
                      onTap: () {
                        if (widget.onReply != null) {
                          widget.onReply!(
                            widget.comment,
                            widget.comment.commentId,
                          );
                        } else {
                          _showReplyDialog(
                            widget.comment,
                            widget.comment.commentId,
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Reply',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Replies section — root comments only
                if (widget.comment.parentId.isEmpty)
                  StreamBuilder<List<CommentModel>>(
                    stream: _commentService.getReplies(
                      widget.comment.commentId,
                    ),
                    builder: (context, snapshot) {
                      final replies = snapshot.data ?? [];
                      if (replies.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _showReplies = !_showReplies),
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
                            ...replies
                                .where(
                                  (r) =>
                                      !_hiddenCommentIds.contains(r.commentId),
                                )
                                .map(
                                  (reply) => _ReplyItem(
                                    reply: reply,
                                    currentUserId: widget.currentUserId,
                                    onReply: widget.onReply,
                                    onLongPress: () => _showActionMenu(reply),
                                  ),
                                ),
                          ],
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Indented reply row (no further nesting) ────────────────────────────────
class _ReplyItem extends StatefulWidget {
  final CommentModel reply;
  final String currentUserId;
  final void Function(CommentModel, String)? onReply;
  final VoidCallback? onLongPress;

  const _ReplyItem({
    required this.reply,
    required this.currentUserId,
    this.onReply,
    this.onLongPress,
  });
  @override
  State<_ReplyItem> createState() => _ReplyItemState();
}

class _ReplyItemState extends State<_ReplyItem> {
  late bool _isLiked;
  final CommentService _commentService = CommentService();
  final UserService _userService = UserService();
  UserModel? _currentUser;

  void _openAuthorProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
    );
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reply.isLikedBy(widget.currentUserId);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    if (widget.currentUserId.isNotEmpty) {
      final user = await _userService.getUser(widget.currentUserId);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23272F) : Colors.grey[50];
    final borderColor = isDark ? const Color(0xFF353A45) : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, top: 6, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 46,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: borderColor, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _openAuthorProfile(widget.reply.authorId),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundImage:
                                  widget.reply.authorImageUrl != null
                                  ? CachedNetworkImageProvider(
                                      widget.reply.authorImageUrl!,
                                    )
                                  : null,
                              child: widget.reply.authorImageUrl == null
                                  ? const Icon(Icons.person, size: 12)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  _openAuthorProfile(widget.reply.authorId),
                              child: Text(
                                widget.reply.authorName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            TimeUtils.formatShorthand(widget.reply.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              TextSpan(
                                text: widget.reply.content,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          widget.reply.content,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: textColor,
                          ),
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          final parentId = widget.reply.parentId.isEmpty
                              ? widget.reply.commentId
                              : widget.reply.parentId;
                          final replyToName = widget.reply.authorName;
                          final controller = TextEditingController();
                          final focusNode = FocusNode();
                          final messenger = ScaffoldMessenger.of(context);
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final textColor = isDark
                              ? Colors.white
                              : Colors.black87;
                          await showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor: isDark
                                  ? const Color(0xFF1A1D23)
                                  : null,
                              title: Text(
                                'Reply to @$replyToName',
                                style: TextStyle(color: textColor),
                              ),
                              content: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                autofocus: true,
                                maxLines: null,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Write your reply...',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
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
                                    final text = controller.text.trim();
                                    if (text.isEmpty) {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Reply cannot be empty',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    try {
                                      await CommentService().addComment(
                                        postId: widget.reply.postId,
                                        authorId: widget.currentUserId,
                                        authorName:
                                            _currentUser?.displayName ?? 'User',
                                        authorImageUrl:
                                            _currentUser?.profileImageUrl,
                                        content: text,
                                        postAuthorId: widget.reply.authorId,
                                        parentId: parentId,
                                        replyToName: replyToName,
                                      );
                                      if (mounted) {
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text('Reply posted'),
                                          ),
                                        );
                                      }
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  },
                                  child: const Text('Reply'),
                                ),
                              ],
                            ),
                          );
                          focusNode.dispose();
                          controller.dispose();
                        },
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
