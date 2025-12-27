import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? profileImageUrl;
  final String? bio;
  final String?
  talent; // Category of talent (e.g., Art, Music, Writing, Dance, etc.)
  final List<String> followers;
  final List<String> following;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
    this.bio,
    this.talent,
    this.followers = const [],
    this.following = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert UserModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'talent': talent,
      'followers': followers,
      'following': following,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      bio: json['bio'],
      talent: json['talent'],
      followers: List<String>.from(json['followers'] ?? []),
      following: List<String>.from(json['following'] ?? []),
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
    );
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? profileImageUrl,
    String? bio,
    String? talent,
    List<String>? followers,
    List<String>? following,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      talent: talent ?? this.talent,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get follower count
  int get followerCount => followers.length;

  // Get following count
  int get followingCount => following.length;
}
