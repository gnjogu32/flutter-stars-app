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

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Not authenticated'));
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
    return AnimationUtils.scaleButtonAnimation(
      onTap: () => _navigateToChat(conversation),
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
                    Text(
                      timeago.format(conversation.lastMessageTime),
                      style: Theme.of(context).textTheme.labelSmall,
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
