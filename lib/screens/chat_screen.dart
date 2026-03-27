import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
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
  final FocusNode _messageFocusNode = FocusNode();
  late UserModel? _currentUser;
  bool _isSending = false;
  bool _isUserTyping = false;
  bool _showEmojiPanel = false;
  Timer? _typingTimer;

  static const List<String> _quickEmojis = [
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

  @override
  void initState() {
    super.initState();
    // Defer expensive operations to background to prevent UI blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead(); // Fire-and-forget, don't block UI
      _loadCurrentUser(); // Load user data asynchronously in background
    });

    _messageController.addListener(_onTextChanged);
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final user = await _userService.getUser(userId);
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading current user: $e');
    }
  }

  void _onTextChanged() {
    final isTyping = _messageController.text.isNotEmpty;

    if (isTyping && !_isUserTyping) {
      // User started typing
      setState(() => _isUserTyping = true);
      _chatService.setTypingStatus(
        conversationId: widget.conversationId,
        userId: _auth.currentUser?.uid ?? '',
        isTyping: true,
      );
    } else if (!isTyping && _isUserTyping) {
      // User stopped typing
      setState(() => _isUserTyping = false);
      _chatService.setTypingStatus(
        conversationId: widget.conversationId,
        userId: _auth.currentUser?.uid ?? '',
        isTyping: false,
      );
    }

    // Reset timer for stopping typing after delay
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(milliseconds: 1500), () {
        if (_messageController.text.isNotEmpty == false && _isUserTyping) {
          setState(() => _isUserTyping = false);
          _chatService.setTypingStatus(
            conversationId: widget.conversationId,
            userId: _auth.currentUser?.uid ?? '',
            isTyping: false,
          );
        }
      });
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

  void _toggleEmojiPanel() {
    setState(() => _showEmojiPanel = !_showEmojiPanel);

    if (_showEmojiPanel) {
      _messageFocusNode.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } else {
      FocusScope.of(context).requestFocus(_messageFocusNode);
    }
  }

  void _hideEmojiPanelOnInputTap() {
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
    }
  }

  void _insertEmoji(String emoji) {
    final currentText = _messageController.text;
    final currentSelection = _messageController.selection;

    final start = currentSelection.start >= 0
        ? currentSelection.start
        : currentText.length;
    final end = currentSelection.end >= 0
        ? currentSelection.end
        : currentText.length;

    final newText = currentText.replaceRange(start, end, emoji);

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    // Clear typing status when leaving chat
    _chatService.setTypingStatus(
      conversationId: widget.conversationId,
      userId: _auth.currentUser?.uid ?? '',
      isTyping: false,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final composerBottomInset = _showEmojiPanel ? 0.0 : keyboardInset;
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          // Typing indicator
          StreamBuilder<bool>(
            stream: _chatService.getTypingStatusStream(
              widget.conversationId,
              widget.otherUserId,
            ),
            builder: (context, snapshot) {
              final isTyping = snapshot.data ?? false;

              if (!isTyping) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(
                      '${widget.otherUserName} is typing',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Animated typing dots
                    SizedBox(
                      width: 20,
                      height: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(3, (index) {
                          return AnimatedOpacity(
                            opacity:
                                ((DateTime.now().millisecond ~/ 200) + index) %
                                        3 ==
                                    0
                                ? 0.3
                                : 1,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: composerBottomInset),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _toggleEmojiPanel,
                      icon: Icon(
                        _showEmojiPanel
                            ? Icons.keyboard_outlined
                            : Icons.emoji_emotions_outlined,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        focusNode: _messageFocusNode,
                        controller: _messageController,
                        onTap: _hideEmojiPanelOnInputTap,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: theme.colorScheme.surfaceContainerHighest,
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: _showEmojiPanel ? 240 : 0,
                  child: _showEmojiPanel
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8,
                                    childAspectRatio: 1.2,
                                  ),
                              itemCount: _quickEmojis.length,
                              itemBuilder: (context, index) {
                                final emoji = _quickEmojis[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _insertEmoji(emoji),
                                  child: Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isCurrentUser = message.senderId == _auth.currentUser?.uid;
    final theme = Theme.of(context);
    final alignment = isCurrentUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bgColor = isCurrentUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isCurrentUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(color: textColor),
                ),
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
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.isRead ? Colors.blue : Colors.grey,
                      ),
                      if (message.isRead && message.readAt != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          'Read ${timeago.format(message.readAt!)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 10,
                                color: Colors.blue.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(MessageModel message) {
    final isCurrentUser = message.senderId == _auth.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy message'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(this.context);
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: message.content));
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            if (isCurrentUser)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMessage(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text(
          'Delete this message? This action cannot be undone.',
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

    try {
      await _chatService.deleteMessage(
        widget.conversationId,
        message.messageId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
    }
  }
}
