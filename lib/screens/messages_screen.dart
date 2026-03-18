import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/conversation_model.dart';
import '../services/chat_service.dart';
import '../utils/animation_utils.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  final Set<String> _deletingConversationIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToChat(ConversationModel conversation) {
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
          otherUserName: conversation.otherUserName ?? 'User',
          otherUserImageUrl: conversation.otherUserImageUrl,
        ),
      ),
    );
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
        title: const Text('Messages'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey.shade100,
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

                return ListView.builder(
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
    final isDeleting = _deletingConversationIds.contains(
      conversation.conversationId,
    );

    return AnimationUtils.scaleButtonAnimation(
      onTap: isDeleting ? () {} : () => _navigateToChat(conversation),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundImage: conversation.otherUserImageUrl != null
                      ? NetworkImage(conversation.otherUserImageUrl!)
                      : null,
                  child: conversation.otherUserImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                // User info and last message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.otherUserName ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
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
                          timeago.format(conversation.lastMessageTime),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        PopupMenuButton<String>(
                          icon: isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.more_vert, size: 18),
                          onSelected: (value) {
                            if (value == 'delete') {
                              _confirmAndDeleteConversation(conversation);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete chat',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (conversation.unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
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
