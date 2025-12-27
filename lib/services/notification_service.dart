import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
