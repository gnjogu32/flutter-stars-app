import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class TrendingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get trending posts based on likes and engagement (24 hours)
  Future<({List<PostModel> posts, DocumentSnapshot? lastDoc})> getTrendingPosts({
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

      Query query = _firestore
          .collection('posts')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: twentyFourHoursAgo,
            isLessThanOrEqualTo: now,
          )
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.limit(limit * 2).get();

      // Convert to PostModel and sort by engagement score
      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestoreDoc(doc))
          .toList();

      // Sort by engagement score (likes + comments + views weighted)
      posts.sort((a, b) {
        final scoreA =
            (a.likes.length * 2) + a.commentCount + (a.videoViewCount / 10);
        final scoreB =
            (b.likes.length * 2) + b.commentCount + (b.videoViewCount / 10);
        return scoreB.compareTo(scoreA);
      });

      return (
        posts: posts.take(limit).toList(),
        lastDoc: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Get trending posts by category/talent
  Future<({List<PostModel> posts, DocumentSnapshot? lastDoc})>
  getTrendingPostsByTalent({required String talent, int limit = 10, DocumentSnapshot? lastDocument}) async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      Query query = _firestore
          .collection('posts')
          .where('talent', isEqualTo: talent)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: sevenDaysAgo,
            isLessThanOrEqualTo: now,
          )
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.limit(limit * 2).get();

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestoreDoc(doc))
          .toList();

      // Sort by engagement score (likes + comments + views weighted)
      posts.sort((a, b) {
        final scoreA =
            (a.likes.length * 2) + a.commentCount + (a.videoViewCount / 10);
        final scoreB =
            (b.likes.length * 2) + b.commentCount + (b.videoViewCount / 10);
        return scoreB.compareTo(scoreA);
      });

      return (
        posts: posts.take(limit).toList(),
        lastDoc: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
      );
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
              .map((doc) => PostModel.fromFirestoreDoc(doc))
              .toList();

          // Sort by engagement score (likes + comments + views weighted)
          posts.sort((a, b) {
            final scoreA =
                (a.likes.length * 2) + a.commentCount + (a.videoViewCount / 10);
            final scoreB =
                (b.likes.length * 2) + b.commentCount + (b.videoViewCount / 10);
            return scoreB.compareTo(scoreA);
          });

          return posts.take(limit).toList();
        });
  }

  // Get top posts by likes
  Future<({List<PostModel> posts, DocumentSnapshot? lastDoc})> getTopPostsByLikes({
    int limit = 10,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      Query query = _firestore
          .collection('posts')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: thirtyDaysAgo,
            isLessThanOrEqualTo: now,
          )
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.limit(limit * 2).get();

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestoreDoc(doc))
          .toList();

      // Sort by likes count
      posts.sort((a, b) => b.likes.length.compareTo(a.likes.length));

      return (
        posts: posts.take(limit).toList(),
        lastDoc: querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null,
      );
    } catch (e) {
      rethrow;
    }
  }
}
