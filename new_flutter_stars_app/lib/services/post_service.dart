import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new post (STUB: No file uploads, only Firestore metadata)
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
    List<String> imageUrls = [];
    String? audioUrl;
    String? videoUrl;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated. Please sign in again.');
    }

    final postId = _firestore.collection('posts').doc().id;
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

    try {
      await _firestore.collection('posts').doc(postId).set(post.toJson());
    } catch (e) {
      throw Exception('Failed to save post to database: $e');
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
