import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorUsername;
  final String? authorImageUrl;
  final String content;
  final String? imageUrl;
  final String? videoUrl;
  final List<String> likes;
  final String parentId;
  final String? replyToName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isEdited;
  final DateTime? editedAt;

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorUsername,
    this.authorImageUrl,
    required this.content,
    this.imageUrl,
    this.videoUrl,
    this.likes = const [],
    this.parentId = '',
    this.replyToName,
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
    this.editedAt,
  });

  // Convert CommentModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'commentId': commentId,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorUsername': authorUsername,
      'authorImageUrl': authorImageUrl,
      'content': content,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'likes': likes,
      'parentId': parentId,
      'replyToName': replyToName,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isEdited': isEdited,
      'editedAt': editedAt,
    };
  }

  // Create CommentModel from Firestore document
  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      commentId: json['commentId'] ?? '',
      postId: json['postId'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? '',
      authorUsername: json['authorUsername'],
      authorImageUrl: json['authorImageUrl'],
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'],
      videoUrl: json['videoUrl'],
      likes: List<String>.from(json['likes'] ?? []),
      parentId: json['parentId'] ?? '',
      replyToName: json['replyToName'],
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
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] is Timestamp
          ? (json['editedAt'] as Timestamp).toDate()
          : json['editedAt'] != null
          ? DateTime.parse(json['editedAt'])
          : null,
    );
  }

  // Create a copy with updated fields
  CommentModel copyWith({
    String? commentId,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorUsername,
    String? authorImageUrl,
    String? content,
    String? imageUrl,
    String? videoUrl,
    List<String>? likes,
    String? parentId,
    String? replyToName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isEdited,
    DateTime? editedAt,
  }) {
    return CommentModel(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorUsername: authorUsername ?? this.authorUsername,
      authorImageUrl: authorImageUrl ?? this.authorImageUrl,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      likes: likes ?? this.likes,
      parentId: parentId ?? this.parentId,
      replyToName: replyToName ?? this.replyToName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  // Get like count
  int get likeCount => likes.length;

  // Check if liked by user
  bool isLikedBy(String userId) => likes.contains(userId);
}
