import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation_model.dart';
import '../services/chat_service.dart';
import '../utils/animation_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/keyboard_prompt_banner.dart';
import '../widgets/author_profile_avatar.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  final Set<String> _deletingConversationIds = <String>{};

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleFocusChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToChat(ConversationModel conversation, {UserModel? otherUser}) {
    // Extract other user ID from conversation
    final currentUserId = _auth.currentUser?.uid ?? '';
    final otherUserId = conversation.participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.conversationId,
          otherUserId: otherUserId,
          otherUserName:
              otherUser?.displayName ?? conversation.otherUserName ?? 'User',
          otherUserImageUrl:
              otherUser?.profileImageUrl ?? conversation.otherUserImageUrl,
        ),
      ),
    );
  }

  bool _canDeleteConversation(ConversationModel conversation) {
    // Both participants can delete the chat for themselves,
    // but in our current ChatService.deleteConversation it deletes the document.
    // For now, let's allow anyone in the chat to delete the document.
    return conversation.participantIds.contains(_auth.currentUser?.uid);
  }

  Future<void> _confirmAndDeleteConversation(
    ConversationModel conversation,
  ) async {
    if (_deletingConversationIds.contains(conversation.conversationId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat'),
        content: Text(
          'Delete your conversation with ${conversation.otherUserName ?? 'this user'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deletingConversationIds.add(conversation.conversationId);
    });

    try {
      await _chatService.deleteConversation(conversation.conversationId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _deletingConversationIds.remove(conversation.conversationId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    final showKeyboardPrompt = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          centerTitle: true,
          elevation: 0,
        ),
        body: _LoginPromptBody(
          icon: Icons.mail_outline_rounded,
          message: 'Log in to send and receive messages.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AuthorProfileAvatar(),
        title: const Text('Messages'),
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBar: showKeyboardPrompt
          ? SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  MediaQuery.viewInsetsOf(context).bottom + 12,
                ),
                child: const KeyboardPromptBanner(
                  visible: true,
                  text: 'Search for a conversation.',
                  icon: Icons.search,
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : Colors.grey.shade100,
                filled: true,
              ),
              onChanged: (value) {
                setState(() => _isSearching = value.isNotEmpty);
              },
            ),
          ),
          // Conversations list
          Expanded(
            child: StreamBuilder<List<ConversationModel>>(
              stream: _chatService.getConversationsStream(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var conversations = snapshot.data ?? [];

                // Filter conversations if searching
                if (_isSearching && _searchController.text.isNotEmpty) {
                  conversations = conversations
                      .where(
                        (c) => (c.otherUserName ?? '').toLowerCase().contains(
                          _searchController.text.toLowerCase(),
                        ),
                      )
                      .toList();
                }

                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mail_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation with someone\nto send them a direct message',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 400));
                    if (mounted) setState(() {});
                  },
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      return AnimationUtils.slideUpAnimation(
                        duration: const Duration(milliseconds: 400),
                        delayMilliseconds: index * 50,
                        child: _buildConversationItem(
                          context,
                          conversations[index],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(
    BuildContext context,
    ConversationModel conversation,
  ) {
    return _ConversationItem(
      key: ValueKey(conversation.conversationId),
      conversation: conversation,
      isDeleting: _deletingConversationIds.contains(
        conversation.conversationId,
      ),
      onTap: (otherUser) => _navigateToChat(conversation, otherUser: otherUser),
      onDelete: () => _confirmAndDeleteConversation(conversation),
      canDelete: _canDeleteConversation(conversation),
    );
  }
}

class _ConversationItem extends StatefulWidget {
  final ConversationModel conversation;
  final bool isDeleting;
  final Function(UserModel?) onTap;
  final VoidCallback onDelete;
  final bool canDelete;

  const _ConversationItem({
    super.key,
    required this.conversation,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
    required this.canDelete,
  });

  @override
  State<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<_ConversationItem>
    with AutomaticKeepAliveClientMixin {
  final UserService _userService = UserService();
  UserModel? _otherUser;
  bool _isLoadingOtherUser = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadOtherUser();
  }

  Future<void> _loadOtherUser() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final otherUserId = widget.conversation.participantIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    if (otherUserId.isNotEmpty) {
      final user = await _userService.getUser(otherUserId);
      if (mounted) {
        setState(() {
          _otherUser = user;
          _isLoadingOtherUser = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingOtherUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName =
        _otherUser?.displayName ?? widget.conversation.otherUserName ?? 'User';
    final imageUrl =
        _otherUser?.profileImageUrl ?? widget.conversation.otherUserImageUrl;
    final hasUnread = widget.conversation.unreadCount > 0;

    return AnimationUtils.scaleButtonAnimation(
      onTap: widget.isDeleting ? () {} : () => widget.onTap(_otherUser),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Card(
          elevation: hasUnread ? 2 : 0,
          shadowColor: hasUnread
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: hasUnread
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade200),
              width: hasUnread ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: () {
                    if (_otherUser != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfileScreen(userId: _otherUser!.uid),
                        ),
                      );
                    }
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: imageUrl != null
                            ? CachedNetworkImageProvider(imageUrl)
                            : null,
                        child: imageUrl == null
                            ? const Icon(Icons.person, size: 30)
                            : null,
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.cardColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      if (_isLoadingOtherUser)
                        const Positioned.fill(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white24,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // User info and last message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: hasUnread
                              ? FontWeight.w900
                              : FontWeight.bold,
                          color: hasUnread
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasUnread
                            ? 'Sent you a new message'
                            : (widget.conversation.lastMessage.isEmpty
                                  ? 'Start a conversation'
                                  : widget.conversation.lastMessage),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: hasUnread
                              ? theme.colorScheme.primary.withValues(alpha: 0.8)
                              : theme.hintColor,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Time and unread indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TimeUtils.formatShorthand(
                            widget.conversation.lastMessageTime,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: hasUnread
                                ? theme.colorScheme.primary
                                : theme.hintColor,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          splashRadius: 24,
                          icon: widget.isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.more_vert, size: 22),
                          onSelected: (value) {
                            if (value == 'delete') {
                              widget.onDelete();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              enabled: widget.canDelete,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: widget.canDelete
                                        ? Colors.red
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete chat',
                                    style: TextStyle(
                                      color: widget.canDelete
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (widget.conversation.unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${widget.conversation.unreadCount}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable login prompt shown in place of screens that need authentication.
class _LoginPromptBody extends StatelessWidget {
  final IconData icon;
  final String message;
  const _LoginPromptBody({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: cs.primaryContainer,
              child: Icon(icon, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center, style: tt.bodyLarge),
            const SizedBox(height: 28),
            SizedBox(
              width: 200,
              child: FilledButton(
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/login'),
                child: const Text('Log In'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: OutlinedButton(
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/signup'),
                child: const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
