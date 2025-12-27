import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';
import 'notification_service.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new comment
  Future<CommentModel> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String? authorImageUrl,
    required String content,
    required String postAuthorId,
  }) async {
    try {
      final commentId = _firestore.collection('comments').doc().id;
      final now = DateTime.now();

      final comment = CommentModel(
        commentId: commentId,
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        content: content,
        createdAt: now,
        updatedAt: now,
      );

      // Save comment to Firestore
      await _firestore
          .collection('comments')
          .doc(commentId)
          .set(comment.toJson());

      // Update post's comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      // Create comment notification if not commenting own post
      if (authorId != postAuthorId) {
        final notificationService = NotificationService();
        await notificationService.createNotification(
          userId: postAuthorId,
          triggeredBy: authorId,
          triggeredByName: authorName,
          triggeredByImageUrl: authorImageUrl,
          type: 'comment',
          postId: postId,
          commentId: commentId,
          content: '$authorName commented on your post',
        );
      }

      return comment;
    } catch (e) {
      rethrow;
    }
  }

  // Get comments for a post
  Stream<List<CommentModel>> getCommentsByPost(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get single comment
  Future<CommentModel?> getComment(String commentId) async {
    try {
      final doc = await _firestore.collection('comments').doc(commentId).get();
      if (doc.exists) {
        return CommentModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update comment
  Future<void> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      await _firestore.collection('comments').doc(commentId).update({
        'content': content,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Delete comment
  Future<void> deleteComment({
    required String commentId,
    required String postId,
  }) async {
    try {
      // Delete comment document
      await _firestore.collection('comments').doc(commentId).delete();

      // Decrement post's comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Like a comment
  Future<void> likeComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('comments').doc(commentId).update({
        'likes': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Unlike a comment
  Future<void> unlikeComment({
    required String commentId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('comments').doc(commentId).update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get recent comments across all posts
  Future<List<CommentModel>> getRecentComments({int limit = 20}) async {
    try {
      final query = await _firestore
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => CommentModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
