import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/analytics_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[AnalyticsService] $message');
    }
  }

  // Track a view event
  Future<void> trackView(String postId, String authorId) async {
    try {
      final analyticsId = '$postId:analytics';
      final analyticsRef = _firestore
          .collection('post_analytics')
          .doc(analyticsId);

      // Get existing analytics or create new
      final doc = await analyticsRef.get();

      if (doc.exists) {
        await analyticsRef.update({
          'viewCount': FieldValue.increment(1),
          'updatedAt': DateTime.now(),
        });
      } else {
        final now = DateTime.now();
        await analyticsRef.set({
          'analyticsId': analyticsId,
          'postId': postId,
          'authorId': authorId,
          'viewCount': 1,
          'likeCount': 0,
          'commentCount': 0,
          'shareCount': 0,
          'repostCount': 0,
          'likedByUsers': [],
          'sharedByUsers': [],
          'repostedByUsers': [],
          'createdAt': now,
          'updatedAt': now,
          'engagementRate': 0.0,
        });
      }

      _debugLog('View tracked for post: $postId');
    } catch (e) {
      _debugLog('Error tracking view: $e');
    }
  }

  // Track a like event
  Future<void> trackLike(String postId, String authorId, String userId) async {
    try {
      final analyticsId = '$postId:analytics';
      final analyticsRef = _firestore
          .collection('post_analytics')
          .doc(analyticsId);

      await analyticsRef.set({
        'likeCount': FieldValue.increment(1),
        'likedByUsers': FieldValue.arrayUnion([userId]),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));

      _debugLog('Like tracked for post: $postId');
    } catch (e) {
      _debugLog('Error tracking like: $e');
    }
  }

  // Track an unlike event
  Future<void> trackUnlike(String postId, String userId) async {
    try {
      final analyticsId = '$postId:analytics';
      await _firestore.collection('post_analytics').doc(analyticsId).update({
        'likeCount': FieldValue.increment(-1),
        'likedByUsers': FieldValue.arrayRemove([userId]),
        'updatedAt': DateTime.now(),
      });

      _debugLog('Unlike tracked for post: $postId');
    } catch (e) {
      _debugLog('Error tracking unlike: $e');
    }
  }

  // Track a comment event
  Future<void> trackComment(String postId) async {
    try {
      final analyticsId = '$postId:analytics';
      await _firestore.collection('post_analytics').doc(analyticsId).set({
        'commentCount': FieldValue.increment(1),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));

      _debugLog('Comment tracked for post: $postId');
    } catch (e) {
      _debugLog('Error tracking comment: $e');
    }
  }

  // Track a share event
  Future<void> trackShare(String postId, String authorId, String userId) async {
    try {
      final analyticsId = '$postId:analytics';
      await _firestore.collection('post_analytics').doc(analyticsId).set({
        'shareCount': FieldValue.increment(1),
        'sharedByUsers': FieldValue.arrayUnion([userId]),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));

      _debugLog('Share tracked for post: $postId');
    } catch (e) {
      _debugLog('Error tracking share: $e');
    }
  }

  // Track a repost event
  Future<void> trackRepost(
    String postId,
    String authorId,
    String userId,
  ) async {
    try {
      final analyticsId = '$postId:analytics';
      await _firestore.collection('post_analytics').doc(analyticsId).set({
        'repostCount': FieldValue.increment(1),
        'repostedByUsers': FieldValue.arrayUnion([userId]),
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));

      _debugLog('Repost tracked for post: $postId');
    } catch (e) {
      _debugLog('Error tracking repost: $e');
    }
  }

  // Get analytics for a single post
  Future<AnalyticsModel?> getPostAnalytics(String postId) async {
    try {
      final analyticsId = '$postId:analytics';
      final doc = await _firestore
          .collection('post_analytics')
          .doc(analyticsId)
          .get();

      if (doc.exists) {
        return AnalyticsModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      _debugLog('Error getting post analytics: $e');
      return null;
    }
  }

  // Get analytics for all posts by author (stream for real-time)
  Stream<List<AnalyticsModel>> getAuthorAnalyticsStream(
    String authorId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('post_analytics')
        .where('authorId', isEqualTo: authorId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AnalyticsModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get top performing posts
  Stream<List<AnalyticsModel>> getTopPostsStream(
    String authorId, {
    String sortBy = 'engagementRate',
    int limit = 10,
  }) {
    return _firestore
        .collection('post_analytics')
        .where('authorId', isEqualTo: authorId)
        .orderBy(sortBy, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AnalyticsModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get analytics summary for author
  Future<Map<String, dynamic>> getAuthorSummary(String authorId) async {
    try {
      final snapshot = await _firestore
          .collection('post_analytics')
          .where('authorId', isEqualTo: authorId)
          .get();

      int totalViews = 0;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;
      int totalReposts = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalViews += (data['viewCount'] as int?) ?? 0;
        totalLikes += (data['likeCount'] as int?) ?? 0;
        totalComments += (data['commentCount'] as int?) ?? 0;
        totalShares += (data['shareCount'] as int?) ?? 0;
        totalReposts += (data['repostCount'] as int?) ?? 0;
      }

      final avgEngagementRate = totalViews > 0
          ? (totalLikes / totalViews)
          : 0.0;

      return {
        'totalPosts': snapshot.docs.length,
        'totalViews': totalViews,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'totalReposts': totalReposts,
        'totalEngagements':
            totalLikes + totalComments + totalShares + totalReposts,
        'avgEngagementRate': avgEngagementRate,
        'avgViewsPerPost': snapshot.docs.isNotEmpty
            ? totalViews ~/ snapshot.docs.length
            : 0,
      };
    } catch (e) {
      _debugLog('Error getting author summary: $e');
      return {
        'totalPosts': 0,
        'totalViews': 0,
        'totalLikes': 0,
        'totalComments': 0,
        'totalShares': 0,
        'totalReposts': 0,
        'totalEngagements': 0,
        'avgEngagementRate': 0.0,
        'avgViewsPerPost': 0,
      };
    }
  }

  // Get time-series data for a specific metric (for charts)
  Future<List<Map<String, dynamic>>> getTimeSeriesData(
    String authorId, {
    String metric = 'likeCount',
    int daysBack = 30,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));

      final snapshot = await _firestore
          .collection('post_analytics')
          .where('authorId', isEqualTo: authorId)
          .where('createdAt', isGreaterThan: cutoffDate)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'date': (data['createdAt'] as Timestamp).toDate(),
          'value': data[metric] ?? 0,
          'postId': data['postId'],
        };
      }).toList();
    } catch (e) {
      _debugLog('Error getting time series data: $e');
      return [];
    }
  }

  // Batch analyze posts (when user views analytics dashboard)
  Future<void> batchAnalyzeUserPosts(String authorId) async {
    try {
      final snapshot = await _firestore
          .collection('post_analytics')
          .where('authorId', isEqualTo: authorId)
          .get();

      _debugLog(
        'Analyzing ${snapshot.docs.length} posts for author: $authorId',
      );
    } catch (e) {
      _debugLog('Error batch analyzing posts: $e');
    }
  }
}
