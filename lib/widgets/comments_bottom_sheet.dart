import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import '../services/comment_service.dart';
import '../services/user_service.dart';
import '../services/media_service.dart';
import '../utils/mention_utils.dart';
import '../utils/auth_guard.dart';
import '../utils/time_utils.dart';

class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String currentUserId;
  final String? postContent;
  final bool autoFocus;
  final ScrollController? scrollController;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.currentUserId,
    this.postContent,
    this.autoFocus = false,
    this.scrollController,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final CommentService _commentService = CommentService();
  final UserService _userService = UserService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final MediaService _mediaService = MediaService();
  bool _isSending = false;

  CommentModel? _replyTo;
  XFile? _selectedMedia;
  bool _isSelectedVideo = false;
  String? _selectedGifUrl;
  bool _isUploading = false;
  final Set<String> _expandedCommentIds = {};

  List<UserModel> _mentionableUsers = [];
  List<UserModel> _filteredMentionUsers = [];
  String? _activeMentionQuery;
  bool _isLoadingMentionUsers = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_handleMentionInputChanged);
    if (widget.autoFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_handleMentionInputChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _ensureMentionableUsersLoaded() async {
    if (_mentionableUsers.isNotEmpty || _isLoadingMentionUsers) return;
    _isLoadingMentionUsers = true;
    try {
      final users = await _userService.getAllUsers();
      if (mounted) setState(() => _mentionableUsers = users);
    } finally {
      _isLoadingMentionUsers = false;
    }
  }

  void _handleMentionInputChanged() async {
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
    final matchingUsers = _mentionableUsers
        .where((user) {
          if (user.uid == widget.currentUserId) return false;
          final handle =
              user.username ??
              MentionUtils.normalizeDisplayNameToHandle(user.displayName);
          return normalizedQuery.isEmpty ||
              handle.startsWith(normalizedQuery) ||
              user.displayName.toLowerCase().contains(normalizedQuery);
        })
        .take(5)
        .toList();
    setState(() {
      _activeMentionQuery = query;
      _filteredMentionUsers = matchingUsers;
    });
  }

  void _insertMentionHandle(String handle) {
    _commentController.value = MentionUtils.insertMention(
      text: _commentController.text,
      selection: _commentController.selection,
      handle: handle,
    );
    setState(() {
      _activeMentionQuery = null;
      _filteredMentionUsers = const [];
    });
    _commentFocusNode.requestFocus();
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty && _selectedMedia == null && _selectedGifUrl == null) {
      return;
    }
    if (!await AuthGuard.check(context, widget.currentUserId)) return;
    setState(() => _isSending = true);
    try {
      String? imageUrl = _selectedGifUrl;
      String? videoUrl;

      if (_selectedMedia != null) {
        setState(() => _isUploading = true);
        final downloadUrl = await _mediaService.uploadCommentMedia(
          widget.postId,
          _selectedMedia!,
        );
        if (_isSelectedVideo) {
          videoUrl = downloadUrl;
        } else {
          imageUrl = downloadUrl;
        }
        setState(() => _isUploading = false);
      }

      final currentUser = await _userService.getUser(widget.currentUserId);
      if (currentUser == null) throw Exception('Profile not found');
      final parentId = _replyTo != null
          ? (_replyTo!.parentId.isEmpty
              ? _replyTo!.commentId
              : _replyTo!.parentId)
          : '';

      await _commentService.addComment(
        postId: widget.postId,
        authorId: widget.currentUserId,
        authorName: currentUser.displayName,
        authorUsername: currentUser.username,
        authorImageUrl: currentUser.profileImageUrl,
        content: content,
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        postAuthorId: widget.postAuthorId,
        parentId: parentId,
        replyToName: _replyTo?.authorName,
      );

      if (parentId.isNotEmpty) {
        _expandedCommentIds.add(parentId);
      }

      _commentController.clear();
      setState(() {
        _replyTo = null;
        _selectedMedia = null;
        _isSelectedVideo = false;
        _selectedGifUrl = null;
        _isSending = false;
      });
      _commentFocusNode.unfocus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isUploading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    final media = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, imageQuality: 70);

    if (media != null) {
      setState(() {
        _selectedMedia = media;
        _isSelectedVideo = isVideo;
        _selectedGifUrl = null;
      });
    }
  }

  void _showMediaSourceSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick Image'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Pick Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGifPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GifPickerSheet(
        onGifSelected: (url) {
          setState(() {
            _selectedGifUrl = url;
            _selectedMedia = null;
          });
        },
      ),
    );
  }

  void _editComment(BuildContext context, CommentModel comment) async {
    final controller = TextEditingController(text: comment.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Edit your comment...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newContent != null &&
        newContent.isNotEmpty &&
        newContent != comment.content) {
      await _commentService.updateComment(
        commentId: comment.commentId,
        content: newContent,
        authorId: widget.currentUserId,
      );
    }
  }

  Widget _buildMentionSuggestions() {
    if (_activeMentionQuery == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final showFollowers =
        'followers'.startsWith(_activeMentionQuery!.toLowerCase());

    if (!showFollowers && _filteredMentionUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      color: theme.colorScheme.surface,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (showFollowers)
            ListTile(
              dense: true,
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('@followers'),
              onTap: () => _insertMentionHandle('followers'),
            ),
          ..._filteredMentionUsers.map((user) {
            final handle =
                user.username ??
                MentionUtils.normalizeDisplayNameToHandle(user.displayName);
            return ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundImage: user.profileImageUrl != null
                    ? CachedNetworkImageProvider(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person, size: 14)
                    : null,
              ),
              title: Text(user.displayName, style: const TextStyle(fontSize: 13)),
              subtitle: Text('@$handle', style: const TextStyle(fontSize: 11)),
              onTap: () => _insertMentionHandle(handle),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (widget.postContent != null && widget.postContent!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to post:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.postContent!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
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
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No comments yet. Start the conversation!',
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: widget.scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: comments.length,
                    itemBuilder: (context, index) => _CommentItem(
                      comment: comments[index],
                      currentUserId: widget.currentUserId,
                      isExpanded: _expandedCommentIds.contains(
                        comments[index].commentId,
                      ),
                      onToggleExpand: (expanded) {
                        setState(() {
                          if (expanded) {
                            _expandedCommentIds.add(comments[index].commentId);
                          } else {
                            _expandedCommentIds.remove(
                              comments[index].commentId,
                            );
                          }
                        });
                      },
                      onReply: (comment) {
                        setState(() => _replyTo = comment);
                        _commentFocusNode.requestFocus();
                      },
                      commentService: _commentService,
                    ),
                  );
                },
              ),
            ),

            // Footer Interaction Area (Moved back into main Column to ensure it stays above keyboard correctly in all scenarios)
            _buildMentionSuggestions(),
            if (_selectedMedia != null || _selectedGifUrl != null)
              Container(
                height: 100,
                padding: const EdgeInsets.all(8),
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _selectedGifUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _selectedGifUrl!,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            )
                          : (_isSelectedVideo
                              ? Container(
                                  height: 80,
                                  width: 80,
                                  color: Colors.black87,
                                  child: const Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                  ),
                                )
                              : Image.file(
                                  File(_selectedMedia!.path),
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                )),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedMedia = null;
                          _isSelectedVideo = false;
                          _selectedGifUrl = null;
                        }),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (_isUploading)
                      const Positioned.fill(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            Material(
              elevation: 12,
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.15,
                          ),
                          border: Border(
                            top: BorderSide(
                              color: theme.dividerColor,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to ${_replyTo!.authorName}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _replyTo = null),
                              child: const Icon(Icons.close, size: 14),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          top: BorderSide(color: theme.dividerColor, width: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Typing Area (Top)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _commentController,
                                    focusNode: _commentFocusNode,
                                    minLines: 1,
                                    maxLines: 5,
                                    style: const TextStyle(fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: 'Add a comment...',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor:
                                          theme.colorScheme.surfaceContainerHighest,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: _isSending ? null : _sendComment,
                                  icon: _isSending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          Icons.send,
                                          color: theme.colorScheme.primary,
                                          size: 24,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          // Media Toolbar (Bottom)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: _showMediaSourceSelector,
                                  tooltip: 'Add media',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.gif_box_outlined, size: 20),
                                  onPressed: _showGifPicker,
                                  tooltip: 'Search GIFs',
                                ),
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Text(
                                    '${_commentController.text.length}/280',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: _commentController.text.length > 280
                                          ? Colors.red
                                          : theme.hintColor,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GifPickerSheet extends StatefulWidget {
  final Function(String) onGifSelected;
  const _GifPickerSheet({required this.onGifSelected});

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _gifs = [];
  bool _isLoading = false;
  String? _error;
  final String _apiKey = 'dc6zaTOxFJmzC';

  @override
  void initState() {
    super.initState();
    _fetchTrendingGifs();
  }

  Future<void> _fetchTrendingGifs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        "https://api.giphy.com/v1/gifs/trending?api_key=$_apiKey&limit=20&rating=g",
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final List results = data['data'];
        if (mounted) {
          setState(() {
            _gifs = results
                .map((g) => g['images']['fixed_height_small']['url'] as String)
                .toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load GIFs');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchGifs(String query) async {
    if (query.isEmpty) {
      _fetchTrendingGifs();
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        "https://api.giphy.com/v1/gifs/search?api_key=$_apiKey&q=${Uri.encodeComponent(query)}&limit=20&rating=g",
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        final List results = data['data'];
        if (mounted) {
          setState(() {
            _gifs = results
                .map((g) => g['images']['fixed_height_small']['url'] as String)
                .toList();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to search GIFs');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search GIPHY...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: _searchGifs,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('Error: $_error'))
                  : GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: _gifs.length,
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () {
                        widget.onGifSelected(_gifs[index]);
                        Navigator.pop(context);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _gifs[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Powered by GIPHY',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final CommentModel comment;
  final String currentUserId;
  final Function(CommentModel) onReply;
  final CommentService commentService;
  final bool isExpanded;
  final Function(bool) onToggleExpand;

  const _CommentItem({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
    required this.commentService,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  void _showActionMenu(BuildContext context, CommentModel comment) {
    final isAuthor = currentUserId == comment.authorId;
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
                title: const Text('Edit Comment'),
                onTap: () {
                  Navigator.pop(context);
                  _triggerEdit(context, comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Comment',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Comment'),
                      content: const Text(
                        'Are you sure? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await commentService.deleteComment(
                      commentId: comment.commentId,
                      postId: comment.postId,
                    );
                  }
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: comment.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _triggerEdit(BuildContext context, CommentModel comment) {
    final state = context.findAncestorStateOfType<_CommentsBottomSheetState>();
    if (state != null) state._editComment(context, comment);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLiked = comment.likes.contains(currentUserId);

    return GestureDetector(
      onLongPress: () => _showActionMenu(context, comment),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: comment.authorImageUrl != null
                      ? CachedNetworkImageProvider(comment.authorImageUrl!)
                      : null,
                  child: comment.authorImageUrl == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.authorName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            TimeUtils.formatShorthand(comment.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment.content, style: theme.textTheme.bodyMedium),
                      if (comment.imageUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: EdgeInsets.zero,
                                  child: InteractiveViewer(
                                    child: CachedNetworkImage(
                                      imageUrl: comment.imageUrl!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: comment.imageUrl!,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => onReply(comment),
                            child: Text(
                              'Reply',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (isLiked) {
                                commentService.unlikeComment(
                                  commentId: comment.commentId,
                                  userId: currentUserId,
                                );
                              } else {
                                commentService.likeComment(
                                  commentId: comment.commentId,
                                  userId: currentUserId,
                                );
                              }
                            },
                            child: Row(
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 14,
                                  color: isLiked
                                      ? Colors.red
                                      : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${comment.likes.length}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
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
            StreamBuilder<List<CommentModel>>(
              stream: commentService.getReplies(comment.commentId),
              builder: (context, snapshot) {
                final replies = snapshot.data ?? [];
                if (replies.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(left: 48.0, top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => onToggleExpand(!isExpanded),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            isExpanded
                                ? 'Hide replies'
                                : 'View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (isExpanded)
                        ...replies.map(
                          (reply) => _ReplyItem(
                            reply: reply,
                            currentUserId: currentUserId,
                            commentService: commentService,
                            onReply: onReply,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyItem extends StatelessWidget {
  final CommentModel reply;
  final String currentUserId;
  final CommentService commentService;
  final Function(CommentModel) onReply;
  const _ReplyItem({
    required this.reply,
    required this.currentUserId,
    required this.commentService,
    required this.onReply,
  });

  void _editComment(BuildContext context, CommentModel comment) async {
    final controller = TextEditingController(text: comment.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Reply'),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Edit your reply...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newContent != null &&
        newContent.isNotEmpty &&
        newContent != comment.content) {
      await commentService.updateComment(
        commentId: comment.commentId,
        content: newContent,
        authorId: currentUserId,
      );
    }
  }

  void _showActionMenu(BuildContext context, CommentModel comment) {
    final isAuthor = currentUserId == comment.authorId;
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
                title: const Text('Edit Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _editComment(context, comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Reply',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Reply'),
                      content: const Text(
                        'Are you sure? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await commentService.deleteComment(
                      commentId: comment.commentId,
                      postId: comment.postId,
                    );
                  }
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: comment.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
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
    final theme = Theme.of(context);
    final isLiked = reply.likes.contains(currentUserId);
    return GestureDetector(
      onLongPress: () => _showActionMenu(context, reply),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundImage: reply.authorImageUrl != null
                  ? CachedNetworkImageProvider(reply.authorImageUrl!)
                  : null,
              child: reply.authorImageUrl == null
                  ? const Icon(Icons.person, size: 12)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          reply.authorName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        TimeUtils.formatShorthand(reply.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (reply.replyToName != null)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '@${reply.replyToName} ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: reply.content,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  else
                    Text(reply.content, style: theme.textTheme.bodySmall),
                  if (reply.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: EdgeInsets.zero,
                              child: InteractiveViewer(
                                child: CachedNetworkImage(
                                  imageUrl: reply.imageUrl!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: reply.imageUrl!,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => onReply(reply),
                        child: Text(
                          'Reply',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (isLiked) {
                            commentService.unlikeComment(
                              commentId: reply.commentId,
                              userId: currentUserId,
                            );
                          } else {
                            commentService.likeComment(
                              commentId: reply.commentId,
                              userId: currentUserId,
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 12,
                              color: isLiked ? Colors.red : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${reply.likes.length}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 10,
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
}
