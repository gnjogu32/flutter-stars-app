import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/profile_screen.dart';
import '../models/user_model.dart';

class AuthorProfileAvatar extends StatelessWidget {
  const AuthorProfileAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 20,
              child: Icon(Icons.person, size: 22),
            ),
          );
        }

        final userData = UserModel.fromFirestoreDoc(snapshot.data!);

        return Semantics(
          button: true,
          label: 'Your profile avatar (${userData.displayName})',
          hint: 'Double tap to open your profile screen',
          child: Tooltip(
            message: 'View profile (${userData.displayName})',
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: userData.uid),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: userData.profileImageUrl != null
                      ? CachedNetworkImageProvider(userData.profileImageUrl!)
                      : null,
                  child: userData.profileImageUrl == null
                      ? const Icon(Icons.person, size: 22)
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
