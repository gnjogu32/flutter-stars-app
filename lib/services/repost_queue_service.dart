import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/repost_queue_model.dart';
import '../models/post_model.dart';
import 'post_service.dart';

class RepostQueueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostService _postService = PostService();

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[RepostQueueService] $message');
    }
  }

  // Add repost to queue (immediate or scheduled)
  Future<RepostQueueModel> queueRepost({
    required String userId,
    required String postId,
    required String originalAuthorId,
    required String userName,
    required String? userImageUrl,
    required PostModel post,
    String? caption,
    DateTime? scheduleTime,
  }) async {
    try {
      // Default to immediate if no schedule time
      scheduleTime ??= DateTime.now();
      final isScheduled = scheduleTime.isAfter(
        DateTime.now().add(Duration(seconds: 1)),
      );

      final queueId = _firestore.collection('repost_queue').doc().id;
      final now = DateTime.now();

      final queueItem = RepostQueueModel(
        queueId: queueId,
        userId: userId,
        postId: postId,
        originalAuthorId: originalAuthorId,
        repostCaption: caption,
        scheduleTime: scheduleTime,
        isScheduled: isScheduled,
        createdAt: now,
        status: 'pending',
      );

      await _firestore
          .collection('repost_queue')
          .doc(queueId)
          .set(queueItem.toJson());

      _debugLog('Queued repost: $queueId (scheduled: $isScheduled)');

      // If immediate, process now
      if (!isScheduled) {
        _processQueueItem(queueItem, post, userName, userImageUrl);
      }

      return queueItem;
    } catch (e) {
      _debugLog('Failed to queue repost: $e');
      rethrow;
    }
  }

  // Get pending reposts for user
  Stream<List<RepostQueueModel>> getPendingRepostsStream(String userId) {
    return _firestore
        .collection('repost_queue')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduleTime', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RepostQueueModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get all reposts (pending, sent, failed) for user
  Stream<List<RepostQueueModel>> getUserRepostHistoryStream(
    String userId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('repost_queue')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RepostQueueModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Process a queued repost (execute the actual repost)
  Future<void> _processQueueItem(
    RepostQueueModel item,
    PostModel post,
    String userName,
    String? userImageUrl,
  ) async {
    try {
      // Repost the post
      await _postService.repostPost(
        originalPost: post,
        reposterId: item.userId,
        reposterName: userName,
        reposterImageUrl: userImageUrl,
        repostCaption: item.repostCaption,
      );

      // Mark as sent
      await _firestore.collection('repost_queue').doc(item.queueId).update({
        'status': 'sent',
      });

      _debugLog('Repost processed: ${item.queueId}');
    } catch (e) {
      _debugLog('Error processing repost: $e');
      // Mark as failed
      await _firestore.collection('repost_queue').doc(item.queueId).update({
        'status': 'failed',
        'errorMessage': e.toString(),
      });
    }
  }

  // Cancel a queued repost
  Future<void> cancelRepost(String queueId) async {
    try {
      await _firestore.collection('repost_queue').doc(queueId).delete();
      _debugLog('Cancelled repost: $queueId');
    } catch (e) {
      _debugLog('Failed to cancel repost: $e');
      rethrow;
    }
  }

  // Manually process all due scheduled reposts (can be called from background job/scheduled task)
  Future<void> processScheduledReposts(String userId) async {
    try {
      final now = DateTime.now();

      // Get all pending reposts for this user that are due
      final querySnapshot = await _firestore
          .collection('repost_queue')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .where('scheduleTime', isLessThanOrEqualTo: now)
          .get();

      _debugLog('Found ${querySnapshot.docs.length} reposts to process');

      for (final doc in querySnapshot.docs) {
        final queueItem = RepostQueueModel.fromJson(doc.data());

        // Fetch the original post
        final postDoc = await _firestore
            .collection('posts')
            .doc(queueItem.postId)
            .get();

        if (postDoc.exists) {
          final post = PostModel.fromJson(
            postDoc.data() as Map<String, dynamic>,
          );

          // Get user data for display
          final userDoc = await _firestore
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userName = userData['displayName'] ?? 'Someone';
            final userImageUrl = userData['profileImageUrl'];

            await _processQueueItem(queueItem, post, userName, userImageUrl);
          }
        }
      }
    } catch (e) {
      _debugLog('Error processing scheduled reposts: $e');
    }
  }

  // Delete completed repost history (older than X days)
  Future<void> cleanupOldReposts(String userId, {int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

      await _firestore
          .collection('repost_queue')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'sent')
          .where('createdAt', isLessThan: cutoffDate)
          .get()
          .then((snapshot) {
            for (final doc in snapshot.docs) {
              doc.reference.delete();
            }
          });

      _debugLog('Cleaned up reposts older than $daysOld days');
    } catch (e) {
      _debugLog('Error cleaning up reposts: $e');
    }
  }

  // Get stats for user's repost queue
  Future<Map<String, int>> getRepostStats(String userId) async {
    try {
      final pending = await _firestore
          .collection('repost_queue')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final sent = await _firestore
          .collection('repost_queue')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'sent')
          .count()
          .get();

      final failed = await _firestore
          .collection('repost_queue')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'failed')
          .count()
          .get();

      return {
        'pending': pending.count ?? 0,
        'sent': sent.count ?? 0,
        'failed': failed.count ?? 0,
      };
    } catch (e) {
      _debugLog('Error getting repost stats: $e');
      return {'pending': 0, 'sent': 0, 'failed': 0};
    }
  }
}
