import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String content;
  final List<String> imageUrls;
  final String? talent; // Category of the post (Art, Music, Writing, etc.)
  final List<String> likes;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PostModel({
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    required this.content,
    this.imageUrls = const [],
    this.talent,
    this.likes = const [],
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert PostModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorImageUrl': authorImageUrl,
      'content': content,
      'imageUrls': imageUrls,
      'talent': talent,
      'likes': likes,
      'commentCount': commentCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create PostModel from Firestore document
  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      postId: json['postId'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? '',
      authorImageUrl: json['authorImageUrl'],
      content: json['content'] ?? '',
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      talent: json['talent'],
      likes: List<String>.from(json['likes'] ?? []),
      commentCount: json['commentCount'] ?? 0,
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
  PostModel copyWith({
    String? postId,
    String? authorId,
    String? authorName,
    String? authorImageUrl,
    String? content,
    List<String>? imageUrls,
    String? talent,
    List<String>? likes,
    int? commentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorImageUrl: authorImageUrl ?? this.authorImageUrl,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      talent: talent ?? this.talent,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get like count
  int get likeCount => likes.length;

  // Check if post is liked by a specific user
  bool isLikedBy(String userId) => likes.contains(userId);
}
