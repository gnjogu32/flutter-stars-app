import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class TrendingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get trending posts based on likes and engagement (24 hours)
  Future<List<PostModel>> getTrendingPosts({int limit = 10}) async {
    try {
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

      final query = await _firestore
          .collection('posts')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: twentyFourHoursAgo,
            isLessThanOrEqualTo: now,
          )
          .orderBy('createdAt', descending: true)
          .limit(100) // Get more to sort by engagement
          .get();

      // Convert to PostModel and sort by engagement score
      final posts = query.docs
          .map((doc) => PostModel.fromJson(doc.data()))
          .toList();

      // Sort by engagement score (likes + comments weighted)
      posts.sort((a, b) {
        final scoreA = (a.likes.length * 2) + a.commentCount;
        final scoreB = (b.likes.length * 2) + b.commentCount;
        return scoreB.compareTo(scoreA);
      });

      return posts.take(limit).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get trending posts by category/talent
  Future<List<PostModel>> getTrendingPostsByTalent({
    required String talent,
    int limit = 10,
  }) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final query = await _firestore
          .collection('posts')
          .where('talent', isEqualTo: talent)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: sevenDaysAgo,
            isLessThanOrEqualTo: now,
          )
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final posts = query.docs
          .map((doc) => PostModel.fromJson(doc.data()))
          .toList();

      // Sort by engagement score
      posts.sort((a, b) {
        final scoreA = (a.likes.length * 2) + a.commentCount;
        final scoreB = (b.likes.length * 2) + b.commentCount;
        return scoreB.compareTo(scoreA);
      });

      return posts.take(limit).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Stream of trending posts for real-time updates
  Stream<List<PostModel>> getTrendingPostsStream({int limit = 10}) {
    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

    return _firestore
        .collection('posts')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: twentyFourHoursAgo,
          isLessThanOrEqualTo: now,
        )
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map((doc) => PostModel.fromJson(doc.data()))
              .toList();

          // Sort by engagement score
          posts.sort((a, b) {
            final scoreA = (a.likes.length * 2) + a.commentCount;
            final scoreB = (b.likes.length * 2) + b.commentCount;
            return scoreB.compareTo(scoreA);
          });

          return posts.take(limit).toList();
        });
  }

  // Get top posts by likes
  Future<List<PostModel>> getTopPostsByLikes({int limit = 10}) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final query = await _firestore
          .collection('posts')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: thirtyDaysAgo,
            isLessThanOrEqualTo: now,
          )
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      final posts = query.docs
          .map((doc) => PostModel.fromJson(doc.data()))
          .toList();

      // Sort by likes count
      posts.sort((a, b) => b.likes.length.compareTo(a.likes.length));

      return posts.take(limit).toList();
    } catch (e) {
      rethrow;
    }
  }
}
