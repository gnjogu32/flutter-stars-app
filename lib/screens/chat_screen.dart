import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/media_service.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/animation_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/video_player_widget.dart';
import 'profile_screen.dart';

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
  final MediaService _mediaService = MediaService();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late UserModel? _currentUser;
  bool _isSending = false;
  bool _isUserTyping = false;
  bool _showEmojiPanel = false;
  Timer? _typingTimer;
  bool _isMediaUploading = false;

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

  void _showChatMediaPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.35,
        minChildSize: 0.2,
        maxChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Send Media',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.photo_library, color: Colors.blue),
                      ),
                      title: const Text('Gallery'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickChatMedia(ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child:
                            const Icon(Icons.camera_alt, color: Colors.green),
                      ),
                      title: const Text('Camera'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickChatMedia(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.videocam, color: Colors.red),
                      ),
                      title: const Text('Video'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickChatVideo();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickChatMedia(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (file == null) return;

      setState(() => _isMediaUploading = true);

      final String? imageUrl = await _mediaService.uploadChatMedia(
        widget.conversationId,
        file,
      );

      if (imageUrl != null) {
        await _sendMediaMessage(imageUrl: imageUrl);
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMediaUploading = false);
    }
  }

  Future<void> _pickChatVideo() async {
    try {
      final XFile? file = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (file == null) return;

      setState(() => _isMediaUploading = true);

      final String? videoUrl = await _mediaService.uploadChatVideo(
        widget.conversationId,
        file,
      );

      if (videoUrl != null) {
        await _sendMediaMessage(videoUrl: videoUrl);
      } else {
        throw Exception('Failed to upload video');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMediaUploading = false);
    }
  }

  Future<void> _sendMediaMessage({String? imageUrl, String? videoUrl}) async {
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
        content: '',
        imageUrl: imageUrl,
        videoUrl: videoUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send media: $e')));
      }
    }
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

    // Responsive sizing
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isTablet = screenWidth > 600;
    final isLandscape = screenHeight < screenWidth;
    final emojiPanelHeight = isLandscape ? 160.0 : 240.0;
    final messageBubbleMaxWidth = isTablet
        ? screenWidth * 0.5
        : screenWidth * 0.75;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProfileScreen(userId: widget.otherUserId),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: widget.otherUserImageUrl != null
                    ? CachedNetworkImageProvider(widget.otherUserImageUrl!)
                    : null,
                child: widget.otherUserImageUrl == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.otherUserName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
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
                      child: _buildMessageBubble(
                        displayMessages[index],
                        messageBubbleMaxWidth,
                      ),
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

              if (!isTyping && !_isMediaUploading) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (_isMediaUploading) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sending media...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ] else if (isTyping) ...[
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
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji panel above typing area (if visible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: _showEmojiPanel ? emojiPanelHeight : 0,
              child: _showEmojiPanel
                  ? Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: GridView.builder(
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isTablet ? 12 : 8,
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
            // Divider between emoji panel and typing area
            if (_showEmojiPanel) Divider(height: 1, color: theme.dividerColor),
            // Typing area always visible at bottom
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: composerBottomInset),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 600 : double.infinity,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _showChatMediaPicker,
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Send media',
                        ),
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
                              fillColor:
                                  theme.colorScheme.surfaceContainerHighest,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, double maxWidth) {
    final isCurrentUser = message.senderId == _auth.currentUser?.uid;
    final theme = Theme.of(context);
    final alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isCurrentUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isCurrentUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final bool hasMedia = message.imageUrl != null || message.videoUrl != null;

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
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (hasMedia)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildChatMedia(message),
                    ),
                  ),
                if (message.content.isNotEmpty)
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
                        TimeUtils.formatShorthand(message.sentAt),
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
                          Flexible(
                            child: Text(
                              'Read ${TimeUtils.formatShorthand(message.readAt!)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    color: Colors.blue.withValues(alpha: 0.7),
                                  ),
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildChatMedia(MessageModel message) {
    if (message.imageUrl != null) {
      return GestureDetector(
        onTap: () {
          // Open fullscreen image viewer (reuse from PostWidget or create common)
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
                body: InteractiveViewer(
                  child: Center(
                    child: CachedNetworkImage(imageUrl: message.imageUrl!),
                  ),
                ),
              ),
            ),
          );
        },
        child: CachedNetworkImage(
          imageUrl: message.imageUrl!,
          placeholder: (context, url) => Container(
            height: 200,
            width: double.infinity,
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.broken_image),
        ),
      );
    } else if (message.videoUrl != null) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 300),
        child: VideoPlayerWidget(
          videoUrl: message.videoUrl!,
          autoPlay: false,
          looping: true,
          muted: false,
          currentUserId: _auth.currentUser?.uid ?? '',
        ),
      );
    }
    return const SizedBox.shrink();
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
