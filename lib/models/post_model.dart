import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String? originalAuthorId;
  final String? originalAuthorName;
  final String? originalAuthorImageUrl;
  final String content;
  final String? repostCaption;
  final List<String> imageUrls;
  final String? audioUrl; // Optional audio file URL
  final String? videoUrl; // Optional video file URL
  final String? talent; // Category of the post (Art, Music, Writing, etc.)
  final String postType; // 'text', 'image', 'video', 'audio'
  final List<String> likes;
  final int commentCount;
  final int repostCount;
  final int videoViewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  PostModel({
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    this.originalAuthorId,
    this.originalAuthorName,
    this.originalAuthorImageUrl,
    required this.content,
    this.repostCaption,
    this.imageUrls = const [],
    this.audioUrl,
    this.videoUrl,
    this.talent,
    this.postType = 'text',
    this.likes = const [],
    this.commentCount = 0,
    this.repostCount = 0,
    this.videoViewCount = 0,
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
      'originalAuthorId': originalAuthorId,
      'originalAuthorName': originalAuthorName,
      'originalAuthorImageUrl': originalAuthorImageUrl,
      'content': content,
      'repostCaption': repostCaption,
      'imageUrls': imageUrls,
      'audioUrl': audioUrl,
      'videoUrl': videoUrl,
      'talent': talent,
      'postType': postType,
      'likes': likes,
      'commentCount': commentCount,
      'repostCount': repostCount,
      'videoViewCount': videoViewCount,
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
      originalAuthorId: json['originalAuthorId'],
      originalAuthorName: json['originalAuthorName'],
      originalAuthorImageUrl: json['originalAuthorImageUrl'],
      content: json['content'] ?? '',
      repostCaption: json['repostCaption'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      audioUrl: json['audioUrl'],
      videoUrl: json['videoUrl'],
      talent: json['talent'],
      postType:
          json['postType'] ?? (json['videoUrl'] != null ? 'video' : 'text'),
      likes: List<String>.from(json['likes'] ?? []),
      commentCount: json['commentCount'] ?? 0,
      repostCount: json['repostCount'] ?? 0,
      videoViewCount: json['videoViewCount'] ?? 0,
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

  // Create PostModel from Firestore document with doc.id fallback
  factory PostModel.fromFirestoreDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final String docId = doc.id;

    return PostModel(
      postId: (data['postId'] as String?)?.isNotEmpty == true
          ? data['postId'] as String
          : docId,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorImageUrl: data['authorImageUrl'],
      originalAuthorId: data['originalAuthorId'],
      originalAuthorName: data['originalAuthorName'],
      originalAuthorImageUrl: data['originalAuthorImageUrl'],
      content: data['content'] ?? '',
      repostCaption: data['repostCaption'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      audioUrl: data['audioUrl'],
      videoUrl: data['videoUrl'],
      talent: data['talent'],
      postType: data['postType'] ??
          (data['videoUrl'] != null ? 'video' : 'text'),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      repostCount: data['repostCount'] ?? 0,
      videoViewCount: data['videoViewCount'] ?? 0,
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
    );
  }

  // Create a copy with updated fields
  PostModel copyWith({
    String? postId,
    String? authorId,
    String? authorName,
    String? authorImageUrl,
    String? originalAuthorId,
    String? originalAuthorName,
    String? originalAuthorImageUrl,
    String? content,
    List<String>? imageUrls,
    String? audioUrl,
    String? videoUrl,
    String? talent,
    List<String>? likes,
    int? commentCount,
    int? repostCount,
    int? videoViewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorImageUrl: authorImageUrl ?? this.authorImageUrl,
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      originalAuthorName: originalAuthorName ?? this.originalAuthorName,
      originalAuthorImageUrl:
          originalAuthorImageUrl ?? this.originalAuthorImageUrl,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      audioUrl: audioUrl ?? this.audioUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      talent: talent ?? this.talent,
      likes: likes ?? this.likes,
      commentCount: commentCount ?? this.commentCount,
      repostCount: repostCount ?? this.repostCount,
      videoViewCount: videoViewCount ?? this.videoViewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get like count
  int get likeCount => likes.length;

  // Check if post is liked by a specific user
  bool isLikedBy(String userId) => likes.contains(userId);

  // Helper for empty placeholder
  factory PostModel.empty() {
    return PostModel(
      postId: '',
      authorId: '',
      authorName: 'Unknown',
      content: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
