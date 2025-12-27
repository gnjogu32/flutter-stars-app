import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String content;
  final List<String> likes;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    required this.content,
    this.likes = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert CommentModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'commentId': commentId,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorImageUrl': authorImageUrl,
      'content': content,
      'likes': likes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create CommentModel from Firestore document
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      commentId: json['commentId'] ?? '',
      postId: json['postId'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? '',
      authorImageUrl: json['authorImageUrl'],
      content: json['content'] ?? '',
      likes: List<String>.from(json['likes'] ?? []),
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
  CommentModel copyWith({
    String? commentId,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorImageUrl,
    String? content,
    List<String>? likes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommentModel(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorImageUrl: authorImageUrl ?? this.authorImageUrl,
      content: content ?? this.content,
      likes: likes ?? this.likes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get like count
  int get likeCount => likes.length;

  // Check if liked by user
  bool isLikedBy(String userId) => likes.contains(userId);
}
