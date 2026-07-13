import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starpage/models/post_model.dart';
import 'package:starpage/models/user_model.dart';
import 'package:starpage/widgets/comments_bottom_sheet.dart';
import 'package:starpage/services/user_service.dart';
import 'package:starpage/services/post_service.dart';
import 'package:starpage/services/notification_service.dart';
import 'package:starpage/services/share_service.dart';
import 'package:starpage/utils/auth_guard.dart';
import 'package:starpage/utils/mention_utils.dart';
import 'package:starpage/screens/profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:starpage/widgets/expandable_text.dart';
import 'package:starpage/widgets/video_player_widget.dart';
import 'package:starpage/widgets/audio_player_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailsSheet extends StatefulWidget {
  final PostModel post;
  final ScrollController? scrollController;
  final String currentUserId;

  const PostDetailsSheet({
    super.key,
    required this.post,
    this.scrollController,
    required this.currentUserId,
  });

  @override
  State<PostDetailsSheet> createState() => _PostDetailsSheetState();
}

class _PostDetailsSheetState extends State<PostDetailsSheet> {
  late bool _isLiked;
  late int _likeCount;
  bool _isLikeUpdating = false;
  bool _isReposting = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedBy(widget.currentUserId);
    _likeCount = widget.post.likeCount;
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    if (widget.currentUserId.isEmpty) return;
    try {
      final userService = UserService();
      final savedIds = await userService.getSavedPostIds(widget.currentUserId);
      if (mounted) {
        setState(() {
          _isSaved = savedIds.contains(widget.post.postId);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSave() async {
    if (widget.currentUserId.isEmpty) {
      await AuthGuard.show(context);
      return;
    }

    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);

    try {
      final userService = UserService();
      if (wasSaved) {
        await userService.unsavePost(widget.currentUserId, widget.post.postId);
      } else {
        await userService.savePost(widget.currentUserId, widget.post.postId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaved = wasSaved);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikeUpdating) return;
    if (!await AuthGuard.check(context, widget.currentUserId)) return;

    final wasLiked = _isLiked;
    setState(() {
      _isLikeUpdating = true;
      _isLiked = !wasLiked;
      _likeCount = wasLiked ? (_likeCount - 1) : _likeCount + 1;
    });

    try {
      if (wasLiked) {
        await PostService().unlikePost(
          widget.post.postId,
          widget.currentUserId,
        );
      } else {
        await PostService().likePost(widget.post.postId, widget.currentUserId);
        if (widget.currentUserId != widget.post.authorId) {
          final currentUser = await UserService().getUser(widget.currentUserId);
          if (currentUser != null) {
            await NotificationService().createNotification(
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = wasLiked ? (_likeCount + 1) : (_likeCount - 1);
        });
      }
    } finally {
      if (mounted) setState(() => _isLikeUpdating = false);
    }
  }

  void _openComments() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => CommentsBottomSheet(
          postId: widget.post.postId,
          postAuthorId: widget.post.authorId,
          currentUserId: widget.currentUserId,
          postContent: widget.post.content,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _repostToFeed({String caption = ''}) async {
    if (_isReposting) return;
    setState(() => _isReposting = true);
    try {
      final userService = UserService();
      final postService = PostService();
      final currentUser = await userService.getUser(widget.currentUserId);
      if (currentUser == null) throw Exception('Profile not found');

      // Check if already reposted
      final alreadyReposted = await postService.hasUserReposted(
        widget.post.postId,
        widget.currentUserId,
      );

      if (alreadyReposted) {
        await postService.undoRepost(
          originalPostId: widget.post.postId,
          reposterId: widget.currentUserId,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Repost removed ✓')));
        }
      } else {
        final repostId = await postService.repostPost(
          originalPost: widget.post,
          reposterId: widget.currentUserId,
          reposterName: currentUser.displayName,
          reposterUsername: currentUser.username,
          reposterImageUrl: currentUser.profileImageUrl,
          repostCaption: caption,
        );

        if (widget.currentUserId != widget.post.authorId) {
          try {
            await NotificationService().createNotification(
              userId: widget.post.authorId,
              triggeredBy: widget.currentUserId,
              triggeredByName: currentUser.displayName,
              triggeredByImageUrl: currentUser.profileImageUrl,
              type: 'repost_post',
              postId: repostId,
              content: '${currentUser.displayName} reposted your content',
            );
          } catch (e) {
            debugPrint('Repost notification skipped: $e');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reposted ✓')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isReposting = false);
    }
  }

  Future<void> _confirmRepost() async {
    if (_isReposting) return;
    final textController = TextEditingController();
    final focusNode = FocusNode();
    final hasFocus = ValueNotifier(false);
    var showEmojiPanel = false;

    focusNode.addListener(() {
      hasFocus.value = focusNode.hasFocus;
    });

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        bool listenerAdded = false;
        // Mention state
        List<UserModel> mentionableUsers = [];
        List<UserModel> filteredMentionUsers = [];
        String? activeMentionQuery;
        bool isLoadingMentionUsers = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> ensureMentionableUsersLoaded() async {
              if (mentionableUsers.isNotEmpty || isLoadingMentionUsers) return;
              isLoadingMentionUsers = true;
              try {
                final users = await UserService().getAllUsers();
                mentionableUsers = users;
              } finally {
                isLoadingMentionUsers = false;
              }
            }

            void handleMentionInputChanged() async {
              final query = MentionUtils.activeMentionQuery(
                textController.text,
                textController.selection,
              );

              if (query == null) {
                if (activeMentionQuery != null ||
                    filteredMentionUsers.isNotEmpty) {
                  setDialogState(() {
                    activeMentionQuery = null;
                    filteredMentionUsers = const [];
                  });
                }
                return;
              }

              await ensureMentionableUsersLoaded();
              final normalizedQuery = query.toLowerCase();
              final currentUserId = widget.currentUserId;
              final matchingUsers = mentionableUsers
                  .where((user) {
                    if (user.uid == currentUserId) return false;
                    final handle =
                        user.username ??
                        MentionUtils.normalizeDisplayNameToHandle(
                          user.displayName,
                        );
                    return normalizedQuery.isEmpty ||
                        handle.startsWith(normalizedQuery) ||
                        user.displayName.toLowerCase().contains(
                          normalizedQuery,
                        );
                  })
                  .take(5)
                  .toList();

              setDialogState(() {
                activeMentionQuery = query;
                filteredMentionUsers = matchingUsers;
              });
            }

            if (!listenerAdded) {
              textController.addListener(handleMentionInputChanged);
              listenerAdded = true;
            }

            void insertMentionHandle(String handle) {
              final nextValue = MentionUtils.insertMention(
                text: textController.text,
                selection: textController.selection,
                handle: handle,
              );
              textController.value = nextValue;
              setDialogState(() {
                activeMentionQuery = null;
                filteredMentionUsers = const [];
              });
            }

            Widget buildMentionSuggestions() {
              if (activeMentionQuery == null) return const SizedBox.shrink();
              final theme = Theme.of(context);
              final showFollowers = 'followers'.startsWith(
                activeMentionQuery!.toLowerCase(),
              );
              if (!showFollowers && filteredMentionUsers.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showFollowers)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.campaign_outlined),
                        title: const Text('@followers'),
                        onTap: () => insertMentionHandle('followers'),
                      ),
                    ...filteredMentionUsers.map((user) {
                      final handle =
                          user.username ??
                          MentionUtils.normalizeDisplayNameToHandle(
                            user.displayName,
                          );
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundImage: user.profileImageUrl != null
                              ? CachedNetworkImageProvider(
                                  user.profileImageUrl!,
                                )
                              : null,
                          child: user.profileImageUrl == null
                              ? const Icon(Icons.person, size: 14)
                              : null,
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          '@$handle',
                          style: const TextStyle(fontSize: 10),
                        ),
                        onTap: () => insertMentionHandle(handle),
                      );
                    }),
                  ],
                ),
              );
            }

            final List<String> quickEmojis = [
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

            return AlertDialog(
              title: const Text('Repost'),
              content: ValueListenableBuilder<bool>(
                valueListenable: hasFocus,
                builder: (context, value, child) {
                  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                  final composerBottomInset = showEmojiPanel
                      ? 0.0
                      : keyboardInset;
                  return AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: composerBottomInset),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add an optional caption to your repost:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
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
                                      context,
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
                                  controller: textController,
                                  focusNode: focusNode,
                                  onTap: () {
                                    if (showEmojiPanel) {
                                      setDialogState(
                                        () => showEmojiPanel = false,
                                      );
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Write something...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                  maxLines: 3,
                                  maxLength: 280,
                                ),
                              ),
                            ],
                          ),
                          buildMentionSuggestions(),
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
                                    itemCount: quickEmojis.length,
                                    itemBuilder: (context, index) {
                                      final emoji = quickEmojis[index];
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          final currentText =
                                              textController.text;
                                          final currentSelection =
                                              textController.selection;
                                          final start =
                                              currentSelection.start >= 0
                                              ? currentSelection.start
                                              : currentText.length;
                                          final end = currentSelection.end >= 0
                                              ? currentSelection.end
                                              : currentText.length;
                                          final newText = currentText
                                              .replaceRange(start, end, emoji);
                                          textController
                                              .value = TextEditingValue(
                                            text: newText,
                                            selection: TextSelection.collapsed(
                                              offset: start + emoji.length,
                                            ),
                                          );
                                        },
                                        child: Center(
                                          child: Text(
                                            emoji,
                                            style: const TextStyle(
                                              fontSize: 24,
                                            ),
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
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, textController.text),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  child: const Text('Repost'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      await _repostToFeed(caption: result.trim());
    }
    hasFocus.dispose();
    focusNode.dispose();
    textController.dispose();
  }

  void _showShareOptions() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            Text(
              'Share Post',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(context);
                ShareService.copyToClipboard(widget.post);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard ✓')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.pop(context);
                ShareService.sharePost(widget.post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repost'),
              onTap: () {
                Navigator.pop(context);
                _confirmRepost();
              },
            ),
            if ((widget.post.originalAuthorId ?? widget.post.authorId) ==
                    widget.currentUserId &&
                widget.post.videoUrl != null)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Download Video'),
                onTap: () {
                  Navigator.pop(context);
                  // Use PostWidget's download if possible, or just call Gal directly if needed.
                  // For now, consistent UI is enough.
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ownerName = widget.post.originalAuthorName ?? widget.post.authorName;
    final ownerImageUrl =
        widget.post.originalAuthorImageUrl ?? widget.post.authorImageUrl;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.post.repostCaption != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Original post by $ownerName',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ExpandableText(
                          widget.post.content,
                          style: theme.textTheme.bodySmall,
                          trimLines: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your caption:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpandableText(
                    widget.post.repostCaption!,
                    style: theme.textTheme.bodyMedium,
                    trimLines: 5,
                  ),
                ] else ...[
                  ExpandableText(
                    widget.post.content,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
                    trimLines: 10,
                  ),
                ],
                const SizedBox(height: 16),

                // Media: Images
                if (widget.post.imageUrls.isNotEmpty) ...[
                  ...widget.post.imageUrls.map(
                    (url) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Media: Audio
                if (widget.post.audioUrl != null &&
                    widget.post.audioUrl!.isNotEmpty) ...[
                  AudioPlayerWidget(audioUrl: widget.post.audioUrl!),
                  const SizedBox(height: 16),
                ],

                // Media: Video
                if (widget.post.videoUrl != null &&
                    widget.post.videoUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: VideoPlayerWidget(
                      videoUrl: widget.post.videoUrl!,
                      autoPlay: true,
                      looping: true,
                      post: widget.post,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // Interaction TabBar (Consistent with Feed)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.post.postId)
                .snapshots(),
            builder: (context, snapshot) {
              int likeCount = _likeCount;
              int commentCount = widget.post.commentCount;
              int repostCount = widget.post.repostCount;
              bool isLiked = _isLiked;

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final List likes = data['likes'] as List? ?? [];
                likeCount = likes.length;
                commentCount = data['commentCount'] ?? 0;
                repostCount = data['repostCount'] ?? 0;
                isLiked = likes.contains(widget.currentUserId);

                if (!_isLikeUpdating) {
                  _isLiked = isLiked;
                  _likeCount = likeCount;
                }
              }

              return DefaultTabController(
                length: 5,
                child: TabBar(
                  onTap: (index) {
                    if (index == 0) _toggleLike();
                    if (index == 1) _openComments();
                    if (index == 2) _confirmRepost();
                    if (index == 3) _toggleSave();
                    if (index == 4) _showShareOptions();
                  },
                  indicatorColor: Colors.transparent,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  dividerColor: Colors.transparent,
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: theme.textTheme.labelSmall,
                  tabs: [
                    Tab(
                      height: 48,
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : null,
                        size: 20,
                      ),
                      child: Text(
                        '$likeCount',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Tab(
                      height: 48,
                      icon: const Icon(Icons.comment_outlined, size: 20),
                      child: Text(
                        '$commentCount',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Tab(
                      height: 48,
                      icon: const Icon(Icons.repeat, size: 20),
                      child: Text(
                        '$repostCount',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Tab(
                      height: 48,
                      icon: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        size: 20,
                      ),
                      child: const Text('Save', style: TextStyle(fontSize: 10)),
                    ),
                    const Tab(
                      height: 48,
                      icon: Icon(Icons.share_outlined, size: 20),
                      child: Text('Share', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              );
            },
          ),

          // Author section at the very bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(userId: widget.post.authorId),
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundImage: ownerImageUrl != null
                        ? CachedNetworkImageProvider(ownerImageUrl)
                        : null,
                    child: ownerImageUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ownerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (widget.post.talent != null)
                        Text(
                          widget.post.talent!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
