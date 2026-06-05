import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/comment_service.dart';
import '../services/user_service.dart';
import 'comment_thread_widget.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;
  final String? postContent;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
    this.postContent,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final CommentService _commentService = CommentService();
  final UserService _userService = UserService();
  UserModel? _currentUser;
  String? _replyToCommentId;
  String? _replyToName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    // Automatically focus when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _focusNode.requestFocus();
            SystemChannels.textInput.invokeMethod('TextInput.show');
          }
        });
      }
    });
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

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String replyToName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToName = replyToName;
    });
    // Add small delay to ensure keyboard pops up correctly
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _focusNode.requestFocus();
        // Force show keyboard
        SystemChannels.textInput.invokeMethod('TextInput.show');
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToName = null;
    });
  }

  Future<void> _sendComment() async {
    if (_controller.text.trim().isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
    });
    try {
      await _commentService.addComment(
        postId: widget.postId,
        authorId: widget.currentUserId,
        authorName: _currentUser?.displayName ?? 'User',
        authorImageUrl: _currentUser?.profileImageUrl,
        content: _controller.text.trim(),
        postAuthorId: widget.postAuthorId,
        parentId: _replyToCommentId ?? '',
        replyToName: _replyToName,
      );
      _controller.clear();
      _cancelReply();
      _focusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = theme.colorScheme.surface;
    final textFieldColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.grey[100];

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Comments',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            if (_replyToName != null)
              Container(
                color: isDark
                    ? theme.colorScheme.surfaceContainerHigh
                    : Colors.grey[100],
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to $_replyToName',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    InkWell(
                      onTap: _cancelReply,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<List<CommentModel>>(
                stream: _commentService.getCommentsByPost(widget.postId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    );
                  }
                  final comments = snapshot.data ?? [];

                  return ListView.builder(
                    itemCount:
                        comments.length + (widget.postContent != null ? 1 : 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      if (widget.postContent != null && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.postContent!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                            ],
                          ),
                        );
                      }

                      final commentIndex = widget.postContent != null
                          ? index - 1
                          : index;
                      if (comments.isEmpty && widget.postContent == null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 32.0),
                            child: Text(
                              'No comments yet.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        );
                      }

                      if (commentIndex >= comments.length) {
                        return const SizedBox.shrink();
                      }

                      final comment = comments[commentIndex];
                      return CommentThreadWidget(
                        comment: comment,
                        currentUserId: widget.currentUserId,
                        postId: widget.postId,
                        onDelete: () {},
                        onReply: (c, parentId) {
                          _startReply(parentId, c.authorName);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                left: 16,
                right: 16,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: _replyToName != null
                            ? 'Write a reply...'
                            : 'Add a comment...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: textFieldColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSending)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.send, color: theme.colorScheme.primary),
                      onPressed: _sendComment,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
