import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? username;
  final String? profileImageUrl;
  final String? bio;
  final String?
  talent; // Category of talent (e.g., Art, Music, Writing, Dance, etc.)
  final List<String> followers;
  final List<String> following;
  final List<String> savedPosts;
  final List<String> blockedUsers;
  final List<String> mutedAuthors;
  final List<String> mutedPosts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.username,
    this.profileImageUrl,
    this.bio,
    this.talent,
    this.followers = const [],
    this.following = const [],
    this.savedPosts = const [],
    this.blockedUsers = const [],
    this.mutedAuthors = const [],
    this.mutedPosts = const [],
    required this.createdAt,
    required this.updatedAt,
    this.fcmToken,
  });

  // Convert UserModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'talent': talent,
      'followers': followers,
      'following': following,
      'savedPosts': savedPosts,
      'blockedUsers': blockedUsers,
      'mutedAuthors': mutedAuthors,
      'mutedPosts': mutedPosts,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'fcmToken': fcmToken,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      username: json['username'],
      profileImageUrl: json['profileImageUrl'],
      bio: json['bio'],
      talent: json['talent'],
      followers: List<String>.from(json['followers'] ?? []),
      following: List<String>.from(json['following'] ?? []),
      savedPosts: List<String>.from(json['savedPosts'] ?? []),
      blockedUsers: List<String>.from(json['blockedUsers'] ?? []),
      mutedAuthors: List<String>.from(json['mutedAuthors'] ?? []),
      mutedPosts: List<String>.from(json['mutedPosts'] ?? []),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['updatedAt'] ?? DateTime.now().toIso8601String(),
            ),
      fcmToken: json['fcmToken'],
    );
  }

  // Create UserModel from Firestore document with doc.id fallback for uid
  factory UserModel.fromFirestoreDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final String docUid = doc.id;

    return UserModel(
      uid: (data['uid'] as String?)?.isNotEmpty == true
          ? data['uid'] as String
          : docUid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      username: data['username'],
      profileImageUrl: data['profileImageUrl'],
      bio: data['bio'],
      talent: data['talent'],
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      savedPosts: List<String>.from(data['savedPosts'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      mutedAuthors: List<String>.from(data['mutedAuthors'] ?? []),
      mutedPosts: List<String>.from(data['mutedPosts'] ?? []),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              data['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(
              data['updatedAt'] ?? DateTime.now().toIso8601String(),
            ),
      fcmToken: data['fcmToken'],
    );
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? username,
    String? profileImageUrl,
    String? bio,
    String? talent,
    List<String>? followers,
    List<String>? following,
    List<String>? savedPosts,
    List<String>? blockedUsers,
    List<String>? mutedAuthors,
    List<String>? mutedPosts,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      talent: talent ?? this.talent,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      savedPosts: savedPosts ?? this.savedPosts,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      mutedAuthors: mutedAuthors ?? this.mutedAuthors,
      mutedPosts: mutedPosts ?? this.mutedPosts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  // Get follower count
  int get followerCount => followers.length;

  // Get following count
  int get followingCount => following.length;
}
