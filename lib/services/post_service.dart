import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';
import 'notification_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
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
    required String? authorImageUrl,
    required String content,
    required List<XFile> imageFiles,
    required Map<String, Uint8List> imageBytes, // Pre-loaded bytes
    required String? talent,
    XFile? audioFile,
    Uint8List? audioBytes,
    XFile? videoFile,
    Uint8List? videoBytes,
  }) async {
    try {
      // Validate input
      if (content.isEmpty &&
          imageFiles.isEmpty &&
          audioFile == null &&
          videoFile == null) {
        throw Exception('Post must have content, images, audio, or video');
      }

      // Upload images to Firebase Storage
      List<String> imageUrls = [];
      String? audioUrl;
      String? videoUrl;

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

      _debugLog('DEBUG: Storage bucket: ${_storage.bucket}');

      // Generate postId for the upload path (will be used in Firestore too)
      final postId = _firestore.collection('posts').doc().id;

      // Upload audio if provided
      if (audioFile != null && audioBytes != null) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${audioFile.name}';
          final uploadPath = 'posts/$authorId/$postId/audio/$fileName';
          final ref = _storage.ref().child(uploadPath);

          _debugLog('DEBUG: Uploading audio to: $uploadPath');

          final metadata = SettableMetadata(
            contentType: audioFile.mimeType ?? 'audio/mpeg',
            customMetadata: {'uploadedBy': authorId},
          );

          await ref.putData(audioBytes, metadata);
          audioUrl = await ref.getDownloadURL();
          _debugLog('DEBUG: Audio upload successful: $audioUrl');
        } catch (e) {
          _debugLog('DEBUG: Audio upload failed: $e');
          throw Exception('Failed to upload audio: $e');
        }
      }

      // Upload video if provided
      if (videoFile != null && videoBytes != null) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${videoFile.name}';
          final uploadPath = 'posts/$authorId/$postId/video/$fileName';
          final ref = _storage.ref().child(uploadPath);

          _debugLog('DEBUG: Uploading video to: $uploadPath');

          final metadata = SettableMetadata(
            contentType: videoFile.mimeType ?? 'video/mp4',
            customMetadata: {'uploadedBy': authorId},
          );

          await ref.putData(videoBytes, metadata);
          videoUrl = await ref.getDownloadURL();
          _debugLog('DEBUG: Video upload successful: $videoUrl');
        } catch (e) {
          _debugLog('DEBUG: Video upload failed: $e');
          throw Exception('Failed to upload video: $e');
        }
      }

      for (int i = 0; i < imageFiles.length; i++) {
        String? uploadPath; // Declare outside try block for error logging
        try {
          final imageFile = imageFiles[i];
          // Match storage rule pattern: posts/{userId}/{postId}/{filename}
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${i}_${imageFile.name}';
          uploadPath = 'posts/$authorId/$postId/$fileName';
          final ref = _storage.ref().child(uploadPath);

          // Debug logging
          _debugLog('DEBUG: Uploading to path: $uploadPath');
          _debugLog('DEBUG: Author ID: $authorId');
          _debugLog('DEBUG: XFile path: ${imageFile.path}');
          _debugLog('DEBUG: XFile name: ${imageFile.name}');

          // Use pre-loaded bytes to avoid cache file deletion
          final fileBytes = imageBytes[imageFile.path];
          if (fileBytes == null) {
            throw Exception('Image bytes not found for ${imageFile.path}');
          }
          _debugLog('DEBUG: Using pre-loaded ${fileBytes.length} bytes');

          // Add metadata for the upload
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'uploadedBy': authorId},
          );

          await ref.putData(fileBytes, metadata);

          final url = await ref.getDownloadURL();
          imageUrls.add(url);
          _debugLog('DEBUG: Upload successful: $url');
        } catch (e) {
          _debugLog('DEBUG: Upload failed - Error: $e');
          _debugLog('DEBUG: Error type: ${e.runtimeType}');
          _debugLog('DEBUG: Author ID was: $authorId');
          _debugLog('DEBUG: Upload path was: $uploadPath');
          throw Exception('Failed to upload image ${i + 1}: $e');
        }
      }

      // Create post document (postId already generated above)
      final now = DateTime.now();

      final post = PostModel(
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        content: content,
        imageUrls: imageUrls,
        audioUrl: audioUrl,
        videoUrl: videoUrl,
        talent: talent,
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
      } catch (e) {
        throw Exception('Failed to save post to database: $e');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Repost existing content to current user's feed
  Future<void> repostPost({
    required PostModel originalPost,
    required String reposterId,
    required String reposterName,
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
      final ownerImageUrl =
          originalPost.originalAuthorImageUrl ?? originalPost.authorImageUrl;

      final repost = PostModel(
        postId: postId,
        authorId: reposterId,
        authorName: reposterName,
        authorImageUrl: reposterImageUrl,
        originalAuthorId: ownerId,
        originalAuthorName: ownerName,
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
    } catch (e) {
      rethrow;
    }
  }

  // Delete a post
  Future<void> deletePost(PostModel post) async {
    try {
      // Delete images from storage
      for (String imageUrl in post.imageUrls) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          // Continue if image deletion fails
        }
      }

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
      final updateData = {
        'content': content,
        'talent': talent,
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
}
