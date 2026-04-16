import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final RegExp _followersMentionPattern = RegExp(
    r'(^|\s)@followers\b',
    caseSensitive: false,
  );

  static final RegExp _userMentionPattern = RegExp(
    r'(^|\s)@([A-Za-z0-9._-]{2,32})\b',
    caseSensitive: false,
  );

  // Create a new notification
  Future<void> createNotification({
    required String userId,
    required String triggeredBy,
    required String triggeredByName,
    String? triggeredByImageUrl,
    required String type,
    String? postId,
    String? commentId,
    required String content,
  }) async {
    try {
      final notificationId = _firestore.collection('notifications').doc().id;
      final now = DateTime.now();

      final notification = NotificationModel(
        notificationId: notificationId,
        userId: userId,
        triggeredBy: triggeredBy,
        triggeredByName: triggeredByName,
        triggeredByImageUrl: triggeredByImageUrl,
        type: type,
        postId: postId,
        commentId: commentId,
        content: content,
        isRead: false,
        createdAt: now,
      );

      await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .doc(notificationId)
          .set(notification.toJson());
    } catch (e) {
      rethrow;
    }
  }

  bool containsFollowersMention(String text) {
    return _followersMentionPattern.hasMatch(text);
  }

  Set<String> extractMentionHandles(String text) {
    final matches = _userMentionPattern.allMatches(text);
    final handles = <String>{};

    for (final match in matches) {
      final raw = (match.group(2) ?? '').trim().toLowerCase();
      if (raw.isEmpty) continue;
      if (raw == 'followers') continue;
      handles.add(raw);
    }

    return handles;
  }

  String _normalizeDisplayNameToHandle(String displayName) {
    return displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');
  }

  Future<int> notifyUserMentions({
    required String authorId,
    required String authorName,
    String? authorImageUrl,
    required String content,
    String? postId,
    String? commentId,
    String type = 'mention_user',
    Set<String> excludeUserIds = const <String>{},
  }) async {
    try {
      final mentionedHandles = extractMentionHandles(content);
      if (mentionedHandles.isEmpty) return 0;

      final usersSnap = await _firestore.collection('users').get();
      if (usersSnap.docs.isEmpty) return 0;

      final handleToUserId = <String, String>{};

      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final userId = (data['uid'] as String?)?.trim().isNotEmpty == true
            ? (data['uid'] as String).trim()
            : doc.id;

        final displayName = (data['displayName'] as String?) ?? '';
        final normalizedHandle = _normalizeDisplayNameToHandle(displayName);
        if (normalizedHandle.isEmpty) continue;

        handleToUserId.putIfAbsent(normalizedHandle, () => userId);
      }

      final recipients = <String>{};
      for (final handle in mentionedHandles) {
        final userId = handleToUserId[handle];
        if (userId == null) continue;
        recipients.add(userId);
      }

      recipients.remove(authorId);
      recipients.removeAll(excludeUserIds);

      if (recipients.isEmpty) return 0;

      final preview = _buildContentPreview(content);
      final message = preview.isEmpty
          ? '$authorName mentioned you'
          : '$authorName mentioned you: "$preview"';

      var sentCount = 0;
      for (final recipientId in recipients) {
        await createNotification(
          userId: recipientId,
          triggeredBy: authorId,
          triggeredByName: authorName,
          triggeredByImageUrl: authorImageUrl,
          type: type,
          postId: postId,
          commentId: commentId,
          content: message,
        );
        sentCount += 1;
      }

      return sentCount;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveFcmToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearFcmToken(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<int> notifyFollowersMention({
    required String authorId,
    required String authorName,
    String? authorImageUrl,
    required String content,
    String? postId,
    String? commentId,
    String type = 'mention_followers',
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(authorId).get();
      if (!userDoc.exists) return 0;

      final userData = userDoc.data();
      final followerIds = List<String>.from(
        userData?['followers'] ?? const [],
      ).where((id) => id.trim().isNotEmpty && id != authorId).toSet().toList();

      if (followerIds.isEmpty) return 0;

      final preview = _buildContentPreview(content);
      final message = preview.isEmpty
          ? '$authorName mentioned @followers'
          : '$authorName mentioned @followers: "$preview"';

      final now = DateTime.now();
      var sentCount = 0;

      for (final recipientId in followerIds) {
        final notificationId = _firestore.collection('notifications').doc().id;
        final notification = NotificationModel(
          notificationId: notificationId,
          userId: recipientId,
          triggeredBy: authorId,
          triggeredByName: authorName,
          triggeredByImageUrl: authorImageUrl,
          type: type,
          postId: postId,
          commentId: commentId,
          content: message,
          isRead: false,
          createdAt: now,
        );

        await _firestore
            .collection('notifications')
            .doc(recipientId)
            .collection('userNotifications')
            .doc(notificationId)
            .set(notification.toJson());
        sentCount += 1;
      }

      return sentCount;
    } catch (e) {
      rethrow;
    }
  }

  String _buildContentPreview(String content) {
    final normalized = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';
    if (normalized.length <= 120) return normalized;
    return '${normalized.substring(0, 117)}...';
  }

  // Get notifications for a user
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .doc(userId)
        .collection('userNotifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get unread notification count
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .doc(userId)
        .collection('userNotifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      rethrow;
    }
  }

  // Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  // Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Check if notification already exists (to avoid duplicates)
  Future<bool> notificationExists({
    required String userId,
    required String triggeredBy,
    required String type,
    String? postId,
    String? commentId,
  }) async {
    try {
      Query query = _firestore
          .collection('notifications')
          .doc(userId)
          .collection('userNotifications')
          .where('triggeredBy', isEqualTo: triggeredBy)
          .where('type', isEqualTo: type);

      if (postId != null) {
        query = query.where('postId', isEqualTo: postId);
      }
      if (commentId != null) {
        query = query.where('commentId', isEqualTo: commentId);
      }

      final snapshot = await query.get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
