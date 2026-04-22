import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
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
  // Firebase Storage removed

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

  // Upload profile image from pre-loaded bytes (removed)
  Future<String?> uploadProfileImageFromBytes(
    String userId,
    dynamic imageFile,
    dynamic imageBytes,
  ) async {
    // Stub: feature removed
    return null;
  }

  // Upload profile image to Firebase Storage (removed)
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    // Stub: feature removed
    return null;
  }

  // Delete old profile image from Firebase Storage (removed)
  Future<void> deleteOldProfileImage(String userId) async {
    // Stub: feature removed
  }

  // Update user profile with image URL
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? profileImageUrl,
    String? talent,
    bool clearProfileImage = false,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (displayName != null) updateData['displayName'] = displayName;
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
}
