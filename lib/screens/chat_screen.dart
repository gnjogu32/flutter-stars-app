import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../utils/animation_utils.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImageUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImageUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  late UserModel? _currentUser;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _markMessagesAsRead();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final user = await _userService.getUser(userId);
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading current user: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markAllMessagesAsRead(
        widget.conversationId,
        _auth.currentUser?.uid ?? '',
      );
    } catch (e) {
      if (kDebugMode) print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || _currentUser == null) return;

      await _chatService.sendMessage(
        senderId: currentUser.uid,
        senderName: _currentUser!.displayName,
        senderImageUrl: _currentUser!.profileImageUrl,
        recipientId: widget.otherUserId,
        recipientName: widget.otherUserName,
        recipientImageUrl: widget.otherUserImageUrl,
        content: _messageController.text.trim(),
      );

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessagesStream(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Start a conversation with ${widget.otherUserName}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                // Reverse list to show newest at bottom
                final displayMessages = messages.reversed.toList();

                return ListView.builder(
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    return AnimationUtils.slideUpAnimation(
                      duration: const Duration(milliseconds: 300),
                      delayMilliseconds: 0,
                      child: _buildMessageBubble(displayMessages[index]),
                    );
                  },
                );
              },
            ),
          ),
          // Message input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: Colors.grey.shade100,
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
                AnimationUtils.scaleButtonAnimation(
                  onTap: _isSending ? () {} : _sendMessage,
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isCurrentUser = message.senderId == _auth.currentUser?.uid;
    final alignment = isCurrentUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bgColor = isCurrentUser ? Colors.blue : Colors.grey.shade300;
    final textColor = isCurrentUser ? Colors.white : Colors.black;

    return Padding(
      padding: EdgeInsets.only(
        left: isCurrentUser ? 50 : 12,
        right: isCurrentUser ? 12 : 50,
        top: 8,
        bottom: 8,
      ),
      child: Align(
        alignment: alignment,
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(message.content, style: TextStyle(color: textColor)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeago.format(message.sentAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (isCurrentUser && message.isRead)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.done_all, size: 12, color: Colors.blue),
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
