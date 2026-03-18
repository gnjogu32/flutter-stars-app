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
    String parentId = '',
    String? replyToName,
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
        parentId: parentId,
        replyToName: replyToName,
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

  // Get comments for a post with pagination
  Stream<List<CommentModel>> getCommentsByPost(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .where('parentId', isEqualTo: '')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get replies for a comment with limit (client-side sorting)
  Stream<List<CommentModel>> getReplies(String parentCommentId) {
    return _firestore
        .collection('comments')
        .where('parentId', isEqualTo: parentCommentId)
        .limit(30)
        .snapshots()
        .map((snapshot) {
          final replies = snapshot.docs
              .map((doc) => CommentModel.fromJson(doc.data()))
              .toList();
          replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return replies;
        });
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

  // Update comment (author only)
  Future<void> updateComment({
    required String commentId,
    required String content,
    required String authorId,
  }) async {
    try {
      final doc = await _firestore.collection('comments').doc(commentId).get();
      if (!doc.exists) {
        throw Exception('Comment not found');
      }

      final currentAuthorId = doc.data()?['authorId'];
      if (currentAuthorId != authorId) {
        throw Exception('Only comment author can edit');
      }

      await _firestore.collection('comments').doc(commentId).update({
        'content': content,
        'updatedAt': DateTime.now(),
        'isEdited': true,
        'editedAt': DateTime.now(),
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
      // Delete all replies first, then the comment itself
      final repliesSnap = await _firestore
          .collection('comments')
          .where('parentId', isEqualTo: commentId)
          .get();
      final batch = _firestore.batch();
      for (final doc in repliesSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('comments').doc(commentId));
      await batch.commit();

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
