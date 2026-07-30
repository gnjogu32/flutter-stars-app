import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../utils/mention_utils.dart';
import 'keyboard_prompt_banner.dart';

class RepostDialog extends StatefulWidget {
  final PostModel post;
  final String currentUserId;

  const RepostDialog({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  static Future<String?> show(BuildContext context, {required PostModel post, required String currentUserId}) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RepostDialog(post: post, currentUserId: currentUserId),
    );
  }

  @override
  State<RepostDialog> createState() => _RepostDialogState();
}

class _RepostDialogState extends State<RepostDialog> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final UserService _userService = UserService();

  List<UserModel> _mentionableUsers = [];
  List<UserModel> _filteredMentionUsers = [];
  String? _activeMentionQuery;
  bool _isLoadingMentionUsers = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleMentionInputChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _ensureMentionableUsersLoaded() async {
    if (_mentionableUsers.isNotEmpty || _isLoadingMentionUsers) return;
    _isLoadingMentionUsers = true;
    try {
      final users = await _userService.getAllUsers();
      if (mounted) {
        setState(() {
          _mentionableUsers = users;
        });
      }
    } finally {
      _isLoadingMentionUsers = false;
    }
  }

  void _handleMentionInputChanged() async {
    final query = MentionUtils.activeMentionQuery(
      _textController.text,
      _textController.selection,
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
    _textController.value = MentionUtils.insertMention(
      text: _textController.text,
      selection: _textController.selection,
      handle: handle,
    );
    setState(() {
      _activeMentionQuery = null;
      _filteredMentionUsers = const [];
    });
    _focusNode.requestFocus();
  }

  Widget _buildMentionSuggestions() {
    if (_activeMentionQuery == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final showFollowers = 'followers'.startsWith(
      _activeMentionQuery!.toLowerCase(),
    );
    if (!showFollowers && _filteredMentionUsers.isEmpty) {
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
              onTap: () => _insertMentionHandle('followers'),
            ),
          ..._filteredMentionUsers.map((user) {
            final handle =
                user.username ??
                MentionUtils.normalizeDisplayNameToHandle(user.displayName);
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundImage: user.profileImageUrl != null
                    ? CachedNetworkImageProvider(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person, size: 14)
                    : null,
              ),
              title: Text(
                user.displayName,
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Text('@$handle', style: const TextStyle(fontSize: 10)),
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
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Repost',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const KeyboardPromptBanner(
                        visible: true,
                        text: 'Add a repost caption before sharing.',
                        icon: Icons.repeat_outlined,
                      ),
                    ],
                  ),
                ),
                Material(
                  elevation: 12,
                  color: theme.colorScheme.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMentionSuggestions(),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: theme.dividerColor,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                autofocus: true,
                                minLines: 1,
                                maxLines: 5,
                                style: const TextStyle(fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Write something...',
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
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(
                                context,
                                _textController.text.trim(),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                minimumSize: const Size(0, 40),
                              ),
                              child: const Text(
                                'Repost',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
