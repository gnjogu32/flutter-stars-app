import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../models/post_model.dart';
import 'notification_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // Create a new post
  Future<void> createPost({
    required String authorId,
    required String authorName,
    String? authorUsername,
    required String? authorImageUrl,
    required String content,
    required List<XFile> imageFiles,
    required Map<String, Uint8List> imageBytes, // Pre-loaded bytes
    required String? talent,
    XFile? videoFile,
    FilePickerResult? audioFileResult,
  }) async {
    try {
      // Validate input
      if (content.isEmpty && imageFiles.isEmpty) {
        throw Exception('Post must have content or images');
      }

      // Upload images to Firebase Storage
      final imageUrls = <String>[];
      String? audioUrl;
      String? videoUrl;
      String postType = 'text';

      // Upload images
      for (final image in imageFiles) {
        final storageRef = FirebaseStorage.instance.ref();
        final imageRef = storageRef.child(
          'posts/images/${DateTime.now().millisecondsSinceEpoch}_${image.name}',
        );
        final uploadTask = imageRef.putData(imageBytes[image.path]!);
        final snapshot = await uploadTask.whenComplete(() {});
        final url = await snapshot.ref.getDownloadURL();
        imageUrls.add(url);
      }
      if (imageUrls.isNotEmpty) {
        postType = 'image';
      }

      // Upload audio if present
      if (audioFileResult != null &&
          audioFileResult.files.single.path != null) {
        final audioFile = File(audioFileResult.files.single.path!);
        final storageRef = FirebaseStorage.instance.ref();
        final audioRef = storageRef.child(
          'posts/audios/${DateTime.now().millisecondsSinceEpoch}_${audioFileResult.files.single.name}',
        );
        final uploadTask = audioRef.putFile(audioFile);
        final snapshot = await uploadTask.whenComplete(() {});
        audioUrl = await snapshot.ref.getDownloadURL();
        postType = 'audio';
      }

      // Upload video if present
      if (videoFile != null) {
        final storageRef = FirebaseStorage.instance.ref();
        final videoRef = storageRef.child(
          'posts/videos/${DateTime.now().millisecondsSinceEpoch}_${videoFile.name}',
        );
        final uploadTask = videoRef.putFile(File(videoFile.path));
        final snapshot = await uploadTask.whenComplete(() {});
        videoUrl = await snapshot.ref.getDownloadURL();
        postType = 'video';
      }

      // Verify authentication and refresh token
      final currentUser = _auth.currentUser;
      _debugLog('DEBUG: Current user: ${currentUser?.uid}');
      _debugLog('DEBUG: Current user email: ${currentUser?.email}');
      _debugLog('DEBUG: Author ID to upload: $authorId');
      _debugLog('DEBUG: IDs match: ${currentUser?.uid == authorId}');

      if (currentUser == null) {
        throw Exception('User not authenticated. Please sign in again.');
      }

      if (currentUser.uid != authorId) {
        throw Exception(
          'Authentication mismatch. Please sign out and sign in again.',
        );
      }

      // Refresh ID token to ensure latest permissions
      try {
        await currentUser.getIdToken(true); // Force refresh
        _debugLog('DEBUG: Token refreshed successfully');
      } catch (e) {
        _debugLog('DEBUG: Token refresh failed: $e');
      }

      // Generate postId for the upload path (will be used in Firestore too)
      final postId = _firestore.collection('posts').doc().id;

      // Extract hashtags
      final hashtags = <String>[];
      final hashtagRegex = RegExp(r'#(\w+)');
      final matches = hashtagRegex.allMatches(content);
      for (final match in matches) {
        final tag = match.group(1)?.toLowerCase();
        if (tag != null && !hashtags.contains(tag)) {
          hashtags.add(tag);
        }
      }

      // Create post document (postId already generated above)
      final now = DateTime.now();

      final post = PostModel(
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorUsername: authorUsername,
        authorImageUrl: authorImageUrl,
        content: content,
        imageUrls: imageUrls,
        audioUrl: audioUrl,
        videoUrl: videoUrl,
        talent: talent,
        postType: postType,
        hashtags: hashtags,
        createdAt: now,
        updatedAt: now,
      );

      // Save post to Firestore
      try {
        await _firestore.collection('posts').doc(postId).set(post.toJson());

        // Notify followers when author mentions @followers in post content.
        if (_notificationService.containsFollowersMention(content)) {
          await _notificationService.notifyFollowersMention(
            authorId: authorId,
            authorName: authorName,
            authorImageUrl: authorImageUrl,
            content: content,
            postId: postId,
          );
        }

        // Notify directly-mentioned users in the post content (e.g., @johndoe).
        await _notificationService.notifyUserMentions(
          authorId: authorId,
          authorName: authorName,
          authorImageUrl: authorImageUrl,
          content: content,
          postId: postId,
          type: 'mention_user',
        );
      } catch (e) {
        throw Exception('Failed to save post to database: $e');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Repost existing content to current user's feed
  Future<String> repostPost({
    required PostModel originalPost,
    required String reposterId,
    required String reposterName,
    String? reposterUsername,
    required String? reposterImageUrl,
    String? repostCaption,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != reposterId) {
        throw Exception('User not authenticated. Please sign in again.');
      }

      final postId = _firestore.collection('posts').doc().id;
      final now = DateTime.now();
      final ownerId = (originalPost.originalAuthorId ?? originalPost.authorId)
          .trim();
      final ownerName =
          (originalPost.originalAuthorName ?? originalPost.authorName).trim();
      final ownerUsername =
          originalPost.originalAuthorUsername ?? originalPost.authorUsername;
      final ownerImageUrl =
          originalPost.originalAuthorImageUrl ?? originalPost.authorImageUrl;

      final repost = PostModel(
        postId: postId,
        authorId: reposterId,
        authorName: reposterName,
        authorUsername: reposterUsername,
        authorImageUrl: reposterImageUrl,
        originalPostId: originalPost.postId,
        originalAuthorId: ownerId,
        originalAuthorName: ownerName,
        originalAuthorUsername: ownerUsername,
        originalAuthorImageUrl: ownerImageUrl,
        content: originalPost.content,
        repostCaption: repostCaption,
        imageUrls: List<String>.from(originalPost.imageUrls),
        audioUrl: originalPost.audioUrl,
        videoUrl: originalPost.videoUrl,
        talent: originalPost.talent,
        repostCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      final originalPostRef = _firestore
          .collection('posts')
          .doc(originalPost.postId);
      final repostRef = _firestore.collection('posts').doc(postId);

      await _firestore.runTransaction((transaction) async {
        final originalSnapshot = await transaction.get(originalPostRef);
        if (!originalSnapshot.exists) {
          throw Exception('Original post no longer exists.');
        }

        transaction.set(repostRef, repost.toJson());
        transaction.update(originalPostRef, {
          'repostCount': FieldValue.increment(1),
        });
      });

      // Handle mentions in repost caption
      if (repostCaption != null && repostCaption.isNotEmpty) {
        if (_notificationService.containsFollowersMention(repostCaption)) {
          await _notificationService.notifyFollowersMention(
            authorId: reposterId,
            authorName: reposterName,
            authorImageUrl: reposterImageUrl,
            content: repostCaption,
            postId: postId,
          );
        }

        await _notificationService.notifyUserMentions(
          authorId: reposterId,
          authorName: reposterName,
          authorImageUrl: reposterImageUrl,
          content: repostCaption,
          postId: postId,
          type: 'mention_user',
        );
      }
      return postId;
    } catch (e) {
      rethrow;
    }
  }

  // Delete a post
  Future<void> deletePost(PostModel post) async {
    try {
      // Storage deletion removed

      // Delete post document
      await _firestore.collection('posts').doc(post.postId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Update post
  Future<void> updatePost({
    required String postId,
    required String content,
    String? talent,
    String? repostCaption,
  }) async {
    try {
      // Extract hashtags from content
      final hashtags = <String>[];
      final hashtagRegex = RegExp(r'#(\w+)');
      final matches = hashtagRegex.allMatches(content);
      for (final match in matches) {
        final tag = match.group(1)?.toLowerCase();
        if (tag != null && !hashtags.contains(tag)) {
          hashtags.add(tag);
        }
      }

      final updateData = {
        'content': content,
        'talent': talent,
        'hashtags': hashtags,
        'updatedAt': DateTime.now(),
      };

      // Only update repostCaption if provided (for reposts)
      if (repostCaption != null) {
        updateData['repostCaption'] = repostCaption;
      }

      await _firestore.collection('posts').doc(postId).update(updateData);
    } catch (e) {
      rethrow;
    }
  }

  // Like a post
  Future<void> likePost(String postId, String userId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Unlike a post
  Future<void> unlikePost(String postId, String userId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Undo a repost
  Future<void> undoRepost({
    required String originalPostId,
    required String reposterId,
  }) async {
    try {
      // Find the repost document
      final repostQuery = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: reposterId)
          .where('originalPostId', isEqualTo: originalPostId)
          .limit(1)
          .get();

      if (repostQuery.docs.isEmpty) return;

      final repostDoc = repostQuery.docs.first;
      final originalPostRef = _firestore
          .collection('posts')
          .doc(originalPostId);

      await _firestore.runTransaction((transaction) async {
        final originalSnapshot = await transaction.get(originalPostRef);

        transaction.delete(repostDoc.reference);

        if (originalSnapshot.exists) {
          transaction.update(originalPostRef, {
            'repostCount': FieldValue.increment(-1),
          });
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  // Check if user has reposted a post
  Future<bool> hasUserReposted(String postId, String userId) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .where('originalPostId', isEqualTo: postId)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get post by ID
  Future<PostModel?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return PostModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get posts by author
  Future<List<PostModel>> getPostsByAuthor(String authorId) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: authorId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => PostModel.fromJson(doc.data())).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get posts by talent category
  Future<List<PostModel>> getPostsByTalent(String talent) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('talent', isEqualTo: talent)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => PostModel.fromJson(doc.data())).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get all posts (with pagination)
  Stream<List<PostModel>> getAllPostsStream({int limit = 50}) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PostModel.fromJson(doc.data()))
              .toList(),
        );
  }

  // Get muted posts
  Future<List<PostModel>> getMutedPosts(List<String> mutedIds) async {
    try {
      if (mutedIds.isEmpty) return [];

      final List<PostModel> muted = [];
      // Firestore 'in' query supports max 10-30 IDs usually.
      // If there are many, we might need to fetch individually or in chunks.
      for (String id in mutedIds) {
        final p = await getPost(id);
        if (p != null) muted.add(p);
      }
      return muted;
    } catch (e) {
      rethrow;
    }
  }

  // Get liked posts
  Future<List<PostModel>> getLikedPosts(String userId) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('likes', arrayContains: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => PostModel.fromJson(doc.data())).toList();
    } catch (e) {
      rethrow;
    }
  }
}
