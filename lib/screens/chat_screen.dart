import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/media_service.dart';
import '../services/encryption_service.dart';
import '../utils/time_utils.dart';
import '../utils/animation_utils.dart';
import '../screens/profile_screen.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/expandable_text.dart';

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
  final EncryptionService _encryptionService = EncryptionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  bool _isSending = false;
  bool _isUserTyping = false;
  Timer? _typingTimer;
  bool _isMediaUploading = false;
  MessageModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _initializeChat();
  }

  void _initializeChat() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _encryptionService.ensureKeysGenerated(uid);
    }
    _markRead();
  }

  void _markRead() async {
    await _chatService.markAllMessagesAsRead(
      widget.conversationId,
      _auth.currentUser?.uid ?? '',
    );
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty && !_isUserTyping) {
      _setTypingStatus(true);
    } else if (_messageController.text.isEmpty && _isUserTyping) {
      _setTypingStatus(false);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isUserTyping) {
        _setTypingStatus(false);
      }
    });
  }

  void _setTypingStatus(bool isTyping) {
    setState(() => _isUserTyping = isTyping);
    _chatService.setTypingStatus(
      conversationId: widget.conversationId,
      userId: _auth.currentUser?.uid ?? '',
      isTyping: isTyping,
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final currentUserUid = _auth.currentUser?.uid;
    if (currentUserUid == null) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      final currentUser = await _userService.getUser(currentUserUid);
      if (currentUser == null) {
        throw Exception('Your profile info was not found.');
      }

      await _chatService.sendMessage(
        senderId: currentUserUid,
        senderName: currentUser.displayName,
        senderImageUrl: currentUser.profileImageUrl,
        recipientId: widget.otherUserId,
        recipientName: widget.otherUserName,
        recipientImageUrl: widget.otherUserImageUrl,
        content: content,
        replyToId: _replyingTo?.messageId,
        replyToContent: _replyingTo?.content,
        replyToSenderName: _replyingTo?.senderName,
      );
      setState(() => _replyingTo = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessageActions(MessageModel message) {
    final isCurrentUser = message.senderId == _auth.currentUser?.uid;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = message);
                _messageFocusNode.requestFocus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(userId: message.senderId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(context);
                if (message.content.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                }
              },
            ),
            if (isCurrentUser)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(message);
                },
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
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
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

    if (confirmed == true) {
      await _chatService.deleteMessage(
        widget.conversationId,
        message.messageId,
      );
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(userId: widget.otherUserId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Conversation',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteConversation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text(
                'Block User',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmBlockUser();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBlockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${widget.otherUserName}?'),
        content: const Text(
          'They will no longer be able to message you or see your profile. This will also delete the conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUserUid = _auth.currentUser?.uid;
      if (currentUserUid != null) {
        await _userService.blockUser(currentUserUid, widget.otherUserId);
        await _chatService.deleteConversation(widget.conversationId);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _confirmDeleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure? This will delete the conversation for you.',
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

    if (confirmed == true) {
      await _chatService.deleteConversation(widget.conversationId);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showChatMediaPicker() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.gallery, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_collection_outlined),
              title: const Text('Video Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.gallery, isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.camera, isVideo: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendMedia(
    ImageSource source, {
    required bool isVideo,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? file = isVideo
          ? await picker.pickVideo(source: source)
          : await picker.pickImage(source: source, imageQuality: 70);

      if (file == null) return;

      setState(() => _isMediaUploading = true);

      final mediaService = MediaService();
      final String? downloadUrl = isVideo
          ? await mediaService.uploadChatVideo(widget.conversationId, file)
          : await mediaService.uploadChatMedia(widget.conversationId, file);

      if (downloadUrl == null) {
        throw Exception('Upload failed');
      }

      final currentUserUid = _auth.currentUser?.uid;
      if (currentUserUid == null) return;

      final currentUser = await _userService.getUser(currentUserUid);
      if (currentUser == null) throw Exception('Profile not found');

      await _chatService.sendMessage(
        senderId: currentUserUid,
        senderName: currentUser.displayName,
        senderImageUrl: currentUser.profileImageUrl,
        recipientId: widget.otherUserId,
        recipientName: widget.otherUserName,
        recipientImageUrl: widget.otherUserImageUrl,
        content: '',
        imageUrl: isVideo ? null : downloadUrl,
        videoUrl: isVideo ? downloadUrl : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send media: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMediaUploading = false);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _chatService.setTypingStatus(
      conversationId: widget.conversationId,
      userId: _auth.currentUser?.uid ?? '',
      isTyping: false,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Responsive sizing
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth > 600;
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
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(
              Icons.enhanced_encryption,
              size: 16,
              color: Colors.green,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 10, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Messages are end-to-end encrypted',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
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
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final itemKey = _messageKeys.putIfAbsent(
                      msg.messageId,
                      () => GlobalKey(),
                    );

                    return Dismissible(
                      key: Key('msg_${msg.messageId}'),
                      direction: DismissDirection.startToEnd,
                      confirmDismiss: (direction) async {
                        setState(() => _replyingTo = msg);
                        _messageFocusNode.requestFocus();
                        return false;
                      },
                      background: Container(
                        padding: const EdgeInsets.only(left: 20),
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.reply,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      child: GestureDetector(
                        onLongPress: () => _showMessageActions(msg),
                        child: Container(
                          key: itemKey,
                          color: _highlightedMessageId == msg.messageId
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : null,
                          child: _buildMessageBubble(
                            msg,
                            messageBubbleMaxWidth,
                          ),
                        ),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    if (_isMediaUploading) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sending media...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ] else if (isTyping) ...[
                      Text(
                        '${widget.otherUserName} is typing',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 20,
                        height: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(3, (index) {
                            return AnimatedOpacity(
                              opacity:
                                  ((DateTime.now().millisecond ~/ 200) +
                                              index) %
                                          3 ==
                                      0
                                  ? 0.3
                                  : 1,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
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

          // Immersive Footer Area
          Material(
            elevation: 12,
            color: theme.colorScheme.surface,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        border: Border(
                          top: BorderSide(
                            color: theme.dividerColor,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Replying to ${_replyingTo!.senderName}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _replyingTo!.content.isEmpty
                                      ? (_replyingTo!.imageUrl != null
                                            ? 'Photo'
                                            : 'Video')
                                      : _replyingTo!.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _replyingTo = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 600 : double.infinity,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: _showChatMediaPicker,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 24,
                            ),
                            tooltip: 'Send media',
                          ),
                          Expanded(
                            child: TextField(
                              focusNode: _messageFocusNode,
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 8,
                              style: const TextStyle(fontSize: 15),
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
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: AnimationUtils.scaleButtonAnimation(
                              onTap: _isSending ? () {} : _sendMessage,
                              child: IconButton(
                                icon: const Icon(Icons.send, size: 24),
                                onPressed: _isSending ? null : _sendMessage,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  final Map<String, String> _decryptedCache = {};
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      setState(() => _highlightedMessageId = messageId);
      Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message is too far up to preview'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildMessageBubble(MessageModel message, double maxWidth) {
    if (message.isEncrypted && message.content.isNotEmpty) {
      if (_decryptedCache.containsKey(message.messageId)) {
        return _renderMessageBubble(
          message.copyWith(content: _decryptedCache[message.messageId]),
          maxWidth,
        );
      }

      return FutureBuilder<String>(
        future: _decrypt(message),
        builder: (context, snapshot) {
          final decryptedContent = snapshot.data ?? '🔐 Decrypting...';
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            _decryptedCache[message.messageId] = snapshot.data!;
          }
          return _renderMessageBubble(
            message.copyWith(content: decryptedContent),
            maxWidth,
          );
        },
      );
    }
    return _renderMessageBubble(message, maxWidth);
  }

  Future<String> _decrypt(MessageModel message) async {
    final senderPublicKey = await _encryptionService.getRecipientPublicKey(
      message.senderId,
    );
    if (senderPublicKey == null) return '[Identity Error]';

    return await _encryptionService.decryptMessage(
      encryptedContent: message.content,
      nonceBase64: message.nonce!,
      senderPublicKeyBase64: senderPublicKey,
    );
  }

  Widget _renderMessageBubble(MessageModel message, double maxWidth) {
    final isCurrentUser = message.senderId == _auth.currentUser?.uid;
    final theme = Theme.of(context);
    final bgColor = isCurrentUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isCurrentUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(userId: message.senderId),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 16,
                backgroundImage: message.senderImageUrl != null
                    ? CachedNetworkImageProvider(message.senderImageUrl!)
                    : null,
                child: message.senderImageUrl == null
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: isCurrentUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (message.replyToId != null)
                    GestureDetector(
                      onTap: () => _scrollToMessage(message.replyToId!),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrentUser
                              ? Colors.white.withValues(alpha: 0.2)
                              : theme.colorScheme.surface.withValues(
                                  alpha: 0.5,
                                ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isCurrentUser
                                  ? Colors.white70
                                  : theme.colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.replyToSenderName ?? 'Message',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCurrentUser
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              message.replyToContent ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isCurrentUser
                                    ? Colors.white70
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (message.imageUrl != null)
                    GestureDetector(
                      onTap: () {
                        // Show full screen image
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: EdgeInsets.zero,
                            child: Stack(
                              children: [
                                InteractiveViewer(
                                  child: CachedNetworkImage(
                                    imageUrl: message.imageUrl!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  top: 40,
                                  right: 20,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.dividerColor,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: message.imageUrl!,
                            placeholder: (context, url) => Container(
                              width: maxWidth,
                              height: 200,
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  if (message.videoUrl != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: VideoPlayerWidget(videoUrl: message.videoUrl!),
                        ),
                      ),
                    ),
                  if (message.content.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(18).copyWith(
                          bottomRight: isCurrentUser
                              ? const Radius.circular(2)
                              : null,
                          bottomLeft: !isCurrentUser
                              ? const Radius.circular(2)
                              : null,
                        ),
                      ),
                      child: ExpandableText(
                        message.content,
                        style: TextStyle(color: textColor, fontSize: 15),
                        trimLines: 8,
                        actionStyle: TextStyle(
                          color: isCurrentUser
                              ? Colors.white70
                              : theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    TimeUtils.formatShorthand(message.sentAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(userId: message.senderId),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 12,
                backgroundImage: _auth.currentUser?.photoURL != null
                    ? CachedNetworkImageProvider(_auth.currentUser!.photoURL!)
                    : null,
                child: _auth.currentUser?.photoURL == null
                    ? const Icon(Icons.person, size: 14)
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
