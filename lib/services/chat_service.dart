import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import 'notification_service.dart';
import 'user_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get or create conversation ID from two user IDs
  String _getConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Send a message
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String? senderImageUrl,
    required String recipientId,
    required String recipientName,
    required String? recipientImageUrl,
    required String content,
  }) async {
    try {
      final conversationId = _getConversationId(senderId, recipientId);
      final messageId = _firestore.collection('messages').doc().id;
      final now = DateTime.now();

      final message = MessageModel(
        messageId: messageId,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderImageUrl: senderImageUrl,
        content: content,
        sentAt: now,
      );

      // Save message
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set(message.toJson());

      // Update conversation metadata for both users
      await _firestore.collection('conversations').doc(conversationId).set({
        'conversationId': conversationId,
        'participantIds': [senderId, recipientId],
        'lastMessage': content,
        'lastSenderId': senderId,
        'lastMessageTime': now,
        'updatedAt': now,
      });

      // Create message notification for recipient
      final notificationService = NotificationService();
      await notificationService.createNotification(
        userId: recipientId,
        triggeredBy: senderId,
        triggeredByName: senderName,
        triggeredByImageUrl: senderImageUrl,
        type: 'direct_message',
        content: '$senderName sent you a message',
      );
    } catch (e) {
      rethrow;
    }
  }

  // Get messages for a conversation
  Stream<List<MessageModel>> getMessagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get conversations for a user
  Stream<List<ConversationModel>> getConversationsStream(String userId) {
    return _firestore
        .collectionGroup('conversations')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ConversationModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Mark message as read
  Future<void> markMessageAsRead(
    String conversationId,
    String messageId,
  ) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'isRead': true, 'readAt': DateTime.now()});
    } catch (e) {
      rethrow;
    }
  }

  // Mark all messages as read
  Future<void> markAllMessagesAsRead(
    String conversationId,
    String userId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({'isRead': true, 'readAt': DateTime.now()});
      }
    } catch (e) {
      rethrow;
    }
  }

  // Delete a message
  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  // Search conversations
  Future<List<ConversationModel>> searchConversations(
    String userId,
    String query,
  ) async {
    try {
      if (query.isEmpty) {
        return [];
      }

      final querySnapshot = await _firestore
          .collectionGroup('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      final results = querySnapshot.docs
          .map((doc) => ConversationModel.fromJson(doc.data()))
          .where(
            (conv) => (conv.otherUserName ?? '').toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();

      return results;
    } catch (e) {
      rethrow;
    }
  }

  // Get unread message count
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      int totalUnread = 0;
      final querySnapshot = await _firestore
          .collectionGroup('conversations')
          .where('participantIds', arrayContains: userId)
          .get();

      for (var doc in querySnapshot.docs) {
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(doc.id)
            .collection('messages')
            .where('senderId', isNotEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();

        totalUnread += messagesSnapshot.docs.length;
      }

      return totalUnread;
    } catch (e) {
      return 0;
    }
  }

  // Start a conversation with a user
  Future<String> startConversation({
    required String currentUserId,
    required String targetUserId,
    required String targetUserName,
    required String? targetUserImageUrl,
  }) async {
    try {
      final userService = UserService();
      final currentUser = await userService.getUser(currentUserId);

      if (currentUser == null) {
        throw Exception('Current user not found');
      }

      final conversationId = _getConversationId(currentUserId, targetUserId);

      // Create conversation document if it doesn't exist
      await _firestore.collection('conversations').doc(conversationId).set({
        'conversationId': conversationId,
        'participantIds': [currentUserId, targetUserId],
        'lastMessage': '',
        'lastSenderId': '',
        'lastMessageTime': DateTime.now(),
        'otherUserName': targetUserName,
        'otherUserImageUrl': targetUserImageUrl,
        'createdAt': DateTime.now(),
      }, SetOptions(merge: true));

      return conversationId;
    } catch (e) {
      rethrow;
    }
  }
}
