import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/user_model.dart';
import 'notification_service.dart';

class UserService {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get user by UID
  Future<UserModel?> getUser(String uid) async {
    try {
      final DocumentSnapshot doc = await _firebaseFirestore
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromJson(doc.data() as Map<String, dynamic>);
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

      return query.docs
          .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
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
          .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get users by talent
  Future<List<UserModel>> getUsersByTalent(String talent) async {
    try {
      final QuerySnapshot query = await _firebaseFirestore
          .collection('users')
          .where('talent', isEqualTo: talent)
          .get();

      return query.docs
          .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
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

  // Upload profile image to Firebase Storage
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      final String fileName = 'profile_$userId.jpg';
      final Reference storageRef = _storage
          .ref()
          .child('profile_images')
          .child(fileName);

      late TaskSnapshot snapshot;

      if (kIsWeb) {
        // For web platform, read file as bytes
        final Uint8List fileBytes = await imageFile.readAsBytes();
        final UploadTask uploadTask = storageRef.putData(fileBytes);
        snapshot = await uploadTask;
      } else {
        // For native platforms (iOS, Android, etc.)
        final UploadTask uploadTask = storageRef.putFile(imageFile);
        snapshot = await uploadTask;
      }

      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Delete old profile image from Firebase Storage
  Future<void> deleteOldProfileImage(String userId) async {
    try {
      final String fileName = 'profile_$userId.jpg';
      final Reference storageRef = _storage
          .ref()
          .child('profile_images')
          .child(fileName);
      await storageRef.delete();
    } catch (e) {
      // Silently fail if image doesn't exist
      if (kDebugMode) print('Error deleting old profile image: $e');
    }
  }

  // Update user profile with image URL
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? profileImageUrl,
    String? talent,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (displayName != null) updateData['displayName'] = displayName;
      if (bio != null) updateData['bio'] = bio;
      if (profileImageUrl != null) {
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
}
