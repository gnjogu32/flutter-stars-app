import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Get current user as stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign up with email and password
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String displayName,
    String? talent,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User user = userCredential.user!;
      await user.updateDisplayName(displayName);

      final UserModel newUser = UserModel(
        uid: user.uid,
        email: email,
        displayName: displayName,
        talent: talent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save user to Firestore
      await _firebaseFirestore
          .collection('users')
          .doc(user.uid)
          .set(newUser.toJson());

      return newUser;
    } catch (e) {
      rethrow;
    }
  }

  // Login with email and password
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      final User user = userCredential.user!;

      // Fetch user data from Firestore
      final DocumentSnapshot doc = await _firebaseFirestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return UserModel.fromJson(doc.data() as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Get user by UID
  Future<UserModel?> getUserByUid(String uid) async {
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

  // Update user profile
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

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}
