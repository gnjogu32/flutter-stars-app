import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user_model.dart';
import 'notification_service.dart';

class UserService {
  // Stub for getMentionableUsers to unblock build
  Future<List<UserModel>> getMentionableUsers() async {
    // TODO: Implement logic to return mentionable users
    return getAllUsers();
  }

  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

  // Get user by UID
  Future<UserModel?> getUser(String uid) async {
    try {
      final DocumentSnapshot doc = await _firebaseFirestore
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestoreDoc(doc);
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      final QuerySnapshot query = await _firebaseFirestore
          .collection('users')
          .get();

      return query.docs.map((doc) => UserModel.fromFirestoreDoc(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Search users by display name
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final QuerySnapshot querySnapshot = await _firebaseFirestore
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: '${query}z')
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestoreDoc(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final querySnapshot = await _firebaseFirestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get user by username
  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final querySnapshot = await _firebaseFirestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromFirestoreDoc(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get users by talent
  Future<List<UserModel>> getUsersByTalent(String talent) async {
    try {
      final QuerySnapshot query = await _firebaseFirestore
          .collection('users')
          .where('talent', isEqualTo: talent)
          .get();

      return query.docs.map((doc) => UserModel.fromFirestoreDoc(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Follow a user
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      final notificationService = NotificationService();

      // Add targetUserId to currentUser's following list
      await _firebaseFirestore.collection('users').doc(currentUserId).update({
        'following': FieldValue.arrayUnion([targetUserId]),
      });

      // Add currentUserId to targetUser's followers list
      await _firebaseFirestore.collection('users').doc(targetUserId).update({
        'followers': FieldValue.arrayUnion([currentUserId]),
      });

      // Get current user data for notification
      final currentUser = await getUser(currentUserId);
      if (currentUser != null) {
        // Create follow notification for target user
        await notificationService.createNotification(
          userId: targetUserId,
          triggeredBy: currentUserId,
          triggeredByName: currentUser.displayName,
          triggeredByImageUrl: currentUser.profileImageUrl,
          type: 'follow',
          content: '${currentUser.displayName} started following you',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Upload profile image from pre-loaded bytes
  Future<String?> uploadProfileImageFromBytes(
    String userId,
    XFile imageFile,
    Uint8List imageBytes,
  ) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child(
        'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}',
      );

      final uploadTask = imageRef.putData(imageBytes);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      rethrow;
    }
  }

  // Upload profile image to Firebase Storage
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final imageRef = storageRef.child(
        'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}_profile.jpg',
      );

      final uploadTask = imageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      rethrow;
    }
  }

  // Delete old profile image from Firebase Storage
  Future<void> deleteOldProfileImage(String userId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final folderRef = storageRef.child('profiles/$userId');

      // List all items in the folder and delete them
      final listResult = await folderRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      debugPrint('Error deleting old profile image: $e');
      // Don't rethrow, as this shouldn't block the profile update
    }
  }

  // Update user profile with image URL
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? username,
    String? bio,
    String? profileImageUrl,
    String? talent,
    bool clearProfileImage = false,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (displayName != null) updateData['displayName'] = displayName;
      if (username != null) updateData['username'] = username.toLowerCase();
      if (bio != null) updateData['bio'] = bio;
      if (clearProfileImage) {
        updateData['profileImageUrl'] = FieldValue.delete();
      } else if (profileImageUrl != null) {
        updateData['profileImageUrl'] = profileImageUrl;
      }
      if (talent != null) updateData['talent'] = talent;

      updateData['updatedAt'] = DateTime.now();

      await _firebaseFirestore.collection('users').doc(uid).update(updateData);
    } catch (e) {
      rethrow;
    }
  }

  // Unfollow a user
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      // Remove targetUserId from currentUser's following list
      await _firebaseFirestore.collection('users').doc(currentUserId).update({
        'following': FieldValue.arrayRemove([targetUserId]),
      });

      // Remove currentUserId from targetUser's followers list
      await _firebaseFirestore.collection('users').doc(targetUserId).update({
        'followers': FieldValue.arrayRemove([currentUserId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get followers of a user
  Future<List<UserModel>> getFollowers(String userId) async {
    try {
      final DocumentSnapshot userDoc = await _firebaseFirestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return [];

      final List<String> followerIds = List<String>.from(
        (userDoc.data() as Map)['followers'] ?? [],
      );

      final List<UserModel> followers = [];
      for (String followerId in followerIds) {
        final UserModel? user = await getUser(followerId);
        if (user != null) followers.add(user);
      }

      return followers;
    } catch (e) {
      rethrow;
    }
  }

  // Get following of a user
  Future<List<UserModel>> getFollowing(String userId) async {
    try {
      final DocumentSnapshot userDoc = await _firebaseFirestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return [];

      final List<String> followingIds = List<String>.from(
        (userDoc.data() as Map)['following'] ?? [],
      );

      final List<UserModel> following = [];
      for (String followingId in followingIds) {
        final UserModel? user = await getUser(followingId);
        if (user != null) following.add(user);
      }

      return following;
    } catch (e) {
      rethrow;
    }
  }

  // Save a post
  Future<void> savePost(String userId, String postId) async {
    try {
      await _firebaseFirestore.collection('users').doc(userId).update({
        'savedPosts': FieldValue.arrayUnion([postId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Unsave a post
  Future<void> unsavePost(String userId, String postId) async {
    try {
      await _firebaseFirestore.collection('users').doc(userId).update({
        'savedPosts': FieldValue.arrayRemove([postId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get saved posts of a user
  Future<List<String>> getSavedPostIds(String userId) async {
    try {
      final doc = await _firebaseFirestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['savedPosts'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
