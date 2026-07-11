import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/comment_service.dart';
import '../services/user_service.dart';
import '../widgets/comment_thread_widget.dart' as custom;
import '../utils/auth_guard.dart';
import '../utils/mention_utils.dart';

class FullScreenCommentsPage extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;
  final String? postContent;

  const FullScreenCommentsPage({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
    this.postContent,
  });

  @override
  State<FullScreenCommentsPage> createState() => _FullScreenCommentsPageState();
}

class _FullScreenCommentsPageState extends State<FullScreenCommentsPage> {
  final CommentService _commentService = CommentService();
  final UserService _userService = UserService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  UserModel? _currentUser;

  // Reply state
  CommentModel? _replyTo;
  String? _replyParentId;

  List<UserModel> _mentionableUsers = const [];
  List<UserModel> _filteredMentionUsers = const [];
  String? _activeMentionQuery;
  bool _isLoadingMentionUsers = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _commentController.addListener(_handleMentionInputChanged);
    // Automatically focus when page opens
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
      if (mounted) setState(() => _currentUser = user);
    }
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty || _isSending) return;
    if (!await AuthGuard.check(context, widget.currentUserId)) return;
    setState(() => _isSending = true);
    try {
      await _commentService.addComment(
        postId: widget.postId,
        authorId: widget.currentUserId,
        authorName: _currentUser?.displayName ?? 'User',
        authorUsername: _currentUser?.username,
        authorImageUrl: _currentUser?.profileImageUrl,
        content: _commentController.text.trim(),
        postAuthorId: widget.postAuthorId,
        parentId: _replyParentId ?? '',
        replyToName: _replyTo?.authorName,
      );
      _commentController.clear();
      setState(() {
        _replyTo = null;
        _replyParentId = null;
      });
      _focusNode.unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
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

    if (confirmed == true && mounted) {
      try {
        await _commentService.deleteComment(
          commentId: comment.commentId,
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
          ).showSnackBar(SnackBar(content: Text('Error deleting comment: $e')));
        }
      }
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_handleMentionInputChanged);
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _ensureMentionableUsersLoaded() async {
    if (_mentionableUsers.isNotEmpty || _isLoadingMentionUsers) return;
    _isLoadingMentionUsers = true;
    try {
      final users = await _userService.getAllUsers();
      if (!mounted) return;
      setState(() => _mentionableUsers = users);
    } finally {
      _isLoadingMentionUsers = false;
    }
  }

  Future<void> _handleMentionInputChanged() async {
    final query = MentionUtils.activeMentionQuery(
      _commentController.text,
      _commentController.selection,
    );
    if (query == null) {
      if (_activeMentionQuery != null || _filteredMentionUsers.isNotEmpty) {
        setState(() {
          _activeMentionQuery = null;
          _filteredMentionUsers = const [];
        });
      }
      return;
    }
    await _ensureMentionableUsersLoaded();
    if (!mounted) return;
    final normalizedQuery = query.toLowerCase();
    final matchingUsers = _mentionableUsers.where((user) {
      if (user.uid == widget.currentUserId) return false;
      final handle = user.username ?? MentionUtils.normalizeDisplayNameToHandle(user.displayName);
      return normalizedQuery.isEmpty || handle.startsWith(normalizedQuery) || user.displayName.toLowerCase().contains(normalizedQuery);
    }).take(5).toList();
    setState(() {
      _activeMentionQuery = query;
      _filteredMentionUsers = matchingUsers;
    });
  }

  void _insertMentionHandle(String handle) {
    final nextValue = MentionUtils.insertMention(text: _commentController.text, selection: _commentController.selection, handle: handle);
    _commentController.value = nextValue;
    setState(() {
      _activeMentionQuery = null;
      _filteredMentionUsers = const [];
    });
  }

  Widget _buildMentionSuggestions() {
    if (_activeMentionQuery == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final showFollowers = 'followers'.startsWith(_activeMentionQuery!.toLowerCase());
    if (!showFollowers && _filteredMentionUsers.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFollowers)
            ListTile(dense: true, leading: const Icon(Icons.campaign_outlined), title: const Text('@followers'), onTap: () => _insertMentionHandle('followers')),
          ..._filteredMentionUsers.map((user) {
            final handle = user.username ?? MentionUtils.normalizeDisplayNameToHandle(user.displayName);
            return ListTile(
              dense: true,
              leading: CircleAvatar(radius: 14, backgroundImage: user.profileImageUrl != null ? CachedNetworkImageProvider(user.profileImageUrl!) : null, child: user.profileImageUrl == null ? const Icon(Icons.person, size: 14) : null),
              title: Text(user.displayName, style: const TextStyle(fontSize: 12)),
              subtitle: Text('@$handle', style: const TextStyle(fontSize: 10)),
              onTap: () => _insertMentionHandle(handle),
            );
          }),
        ],
      ),
    );
  }

  void _setReply(CommentModel replyTo, String parentId) {
    setState(() {
      _replyTo = replyTo;
      _replyParentId = parentId;
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
      _replyTo = null;
      _replyParentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _commentService.getCommentsByPost(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount:
                      comments.length + (widget.postContent != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (widget.postContent != null && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.postContent!,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w500),
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
                      return const Center(child: Text('No comments yet.'));
                    }

                    if (commentIndex >= comments.length) {
                      return const SizedBox.shrink();
                    }

                    final comment = comments[commentIndex];
                    return custom.CommentThreadWidget(
                      comment: comment,
                      currentUserId: widget.currentUserId,
                      postId: widget.postId,
                      onDelete: () => _deleteComment(comment),
                      onReply: _setReply,
                    );
                  },
                );
              },
            ),
          ),
          if (_replyTo != null)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${_replyTo!.authorName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelReply,
                    tooltip: 'Cancel reply',
                  ),
                ],
              ),
            ),
          _buildMentionSuggestions(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _replyTo != null
                            ? 'Write a reply...'
                            : 'Write a comment...',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      enabled: !_isSending,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _isSending ? null : _sendComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
