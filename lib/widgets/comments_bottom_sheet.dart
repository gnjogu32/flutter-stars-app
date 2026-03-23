import 'package:flutter/material.dart';
import '../models/comment_model.dart';
import '../services/comment_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/auth_guard.dart';
import 'comment_widget.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _commentController = TextEditingController();
  final CommentService _commentService = CommentService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  bool _isPosting = false;
  CommentModel? _replyingTo;

  bool get _isGuest => widget.currentUserId.isEmpty;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a comment')));
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final userData = await _userService.getUser(currentUser.uid);
      if (userData == null) {
        throw Exception('User profile not found');
      }

      await _commentService.addComment(
        postId: widget.postId,
        authorId: currentUser.uid,
        authorName: userData.displayName,
        authorImageUrl: userData.profileImageUrl,
        content: _commentController.text.trim(),
        postAuthorId: widget.postAuthorId,
        parentId: _replyingTo?.commentId ?? '',
        replyToName: _replyingTo?.authorName,
      );

      _commentController.clear();
      if (mounted) {
        setState(() => _replyingTo = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment posted!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _commentService.deleteComment(
        commentId: commentId,
        postId: widget.postId,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment deleted')));
      }
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
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
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final comments = snapshot.data ?? [];

                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          'No comments yet. Be the first to comment!',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        return CommentWidget(
                          comment: comments[index],
                          currentUserId: widget.currentUserId,
                          onDelete: () =>
                              _deleteComment(comments[index].commentId),
                          onReply: _isGuest
                              ? null
                              : (comment) {
                                  setState(() => _replyingTo = comment);
                                  _commentController.clear();
                                },
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: _isGuest
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Log in to add comments and replies.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await AuthGuard.show(context);
                            },
                            child: const Text('Log in'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_replyingTo != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Replying to ${_replyingTo!.authorName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _replyingTo = null),
                                    child: const Icon(Icons.close, size: 16),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    hintText: _replyingTo != null
                                        ? 'Reply to ${_replyingTo!.authorName}...'
                                        : 'Add a comment...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                    fillColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  maxLines: null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _isPosting ? null : _postComment,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
