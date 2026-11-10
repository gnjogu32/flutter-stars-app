import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/models/post_model.dart';
import 'package:starpage/models/comment_model.dart';

void main() {
  group('Creator Moderation & Pinned Comments Tests', () {
    test('PostModel correctly handles pinnedCommentId and allowCommentsFrom', () {
      final now = DateTime.now();
      final post = PostModel(
        postId: 'post_123',
        authorId: 'creator_1',
        authorName: 'Creative Star',
        content: 'Check out my new artwork!',
        pinnedCommentId: 'comment_999',
        allowCommentsFrom: 'followers',
        createdAt: now,
        updatedAt: now,
      );

      expect(post.pinnedCommentId, equals('comment_999'));
      expect(post.allowCommentsFrom, equals('followers'));

      final json = post.toJson();
      expect(json['pinnedCommentId'], equals('comment_999'));
      expect(json['allowCommentsFrom'], equals('followers'));

      final fromJson = PostModel.fromJson(json);
      expect(fromJson.pinnedCommentId, equals('comment_999'));
      expect(fromJson.allowCommentsFrom, equals('followers'));
    });

    test('PostModel copyWith updates creator moderation settings', () {
      final now = DateTime.now();
      final original = PostModel(
        postId: 'post_123',
        authorId: 'creator_1',
        authorName: 'Creative Star',
        content: 'Artwork post',
        createdAt: now,
        updatedAt: now,
      );

      expect(original.pinnedCommentId, isNull);
      expect(original.allowCommentsFrom, equals('everyone'));

      final updated = original.copyWith(
        pinnedCommentId: 'comment_abc',
        allowCommentsFrom: 'none',
      );

      expect(updated.pinnedCommentId, equals('comment_abc'));
      expect(updated.allowCommentsFrom, equals('none'));
    });

    test('CommentModel supports isPinned flag', () {
      final now = DateTime.now();
      final comment = CommentModel(
        commentId: 'comment_abc',
        postId: 'post_123',
        authorId: 'user_2',
        authorName: 'Fan User',
        content: 'Amazing work!',
        createdAt: now,
        updatedAt: now,
        isPinned: true,
      );

      expect(comment.isPinned, isTrue);

      final json = comment.toJson();
      expect(json['isPinned'], isTrue);

      final fromJson = CommentModel.fromJson(json);
      expect(fromJson.isPinned, isTrue);

      final unpinned = comment.copyWith(isPinned: false);
      expect(unpinned.isPinned, isFalse);
    });
  });
}
