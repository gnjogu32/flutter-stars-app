import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'push_notification_service.dart';

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

      await PushNotificationService.syncTokenForCurrentUser();

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
        await PushNotificationService.syncTokenForCurrentUser();
        return UserModel.fromFirestoreDoc(doc);
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled sign in
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user == null) return null;

      // Check if user already exists in Firestore
      final DocumentSnapshot doc = await _firebaseFirestore
          .collection('users')
          .doc(user.uid)
          .get();

      UserModel userModel;

      if (doc.exists) {
        userModel = UserModel.fromFirestoreDoc(doc);
      } else {
        // Create new user record in Firestore for first-time Google sign-in
        final String displayName =
            user.displayName ?? googleUser.displayName ?? 'Starpage User';
        userModel = UserModel(
          uid: user.uid,
          email: user.email ?? googleUser.email,
          displayName: displayName,
          profileImageUrl: user.photoURL,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firebaseFirestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toJson());
      }

      await PushNotificationService.syncTokenForCurrentUser();
      return userModel;
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Fire token cleanup in background — don't block sign-out on network calls
      PushNotificationService.clearToken().ignore();
      await GoogleSignIn().signOut().catchError((_) => null);
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
        return UserModel.fromFirestoreDoc(doc);
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
    DateTime? birthday,
    bool? birthdayPublic,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};

      if (displayName != null) updateData['displayName'] = displayName;
      if (bio != null) updateData['bio'] = bio;
      if (profileImageUrl != null) {
        updateData['profileImageUrl'] = profileImageUrl;
      }
      if (talent != null) updateData['talent'] = talent;
      if (birthday != null) updateData['birthday'] = birthday.toIso8601String();
      if (birthdayPublic != null) updateData['birthdayPublic'] = birthdayPublic;

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

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final User? user = _firebaseAuth.currentUser;
      if (user == null) return;

      final String uid = user.uid;

      // Delete user from Firestore
      await _firebaseFirestore.collection('users').doc(uid).delete();

      // Delete user from Firebase Auth
      await user.delete();
    } catch (e) {
      rethrow;
    }
  }
}
