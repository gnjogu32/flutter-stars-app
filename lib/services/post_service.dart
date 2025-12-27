import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Create a new post
  Future<void> createPost({
    required String authorId,
    required String authorName,
    required String? authorImageUrl,
    required String content,
    required List<File> imageFiles,
    required String? talent,
  }) async {
    try {
      // Upload images to Firebase Storage
      List<String> imageUrls = [];
      for (File imageFile in imageFiles) {
        final fileName =
            'posts/$authorId/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
        final ref = _storage.ref().child(fileName);
        await ref.putFile(imageFile);
        final url = await ref.getDownloadURL();
        imageUrls.add(url);
      }

      // Create post document
      final postId = _firestore.collection('posts').doc().id;
      final now = DateTime.now();

      final post = PostModel(
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        content: content,
        imageUrls: imageUrls,
        talent: talent,
        createdAt: now,
        updatedAt: now,
      );

      // Save post to Firestore
      await _firestore.collection('posts').doc(postId).set(post.toJson());
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
  }) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'content': content,
        'talent': talent,
        'updatedAt': DateTime.now(),
      });
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
