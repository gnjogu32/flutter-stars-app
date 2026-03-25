import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsModel {
  final String analyticsId;
  final String postId;
  final String authorId;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int repostCount;
  final List<String> likedByUsers;
  final List<String> sharedByUsers;
  final List<String> repostedByUsers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double engagementRate; // Calculated from likes/views

  AnalyticsModel({
    required this.analyticsId,
    required this.postId,
    required this.authorId,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.repostCount = 0,
    this.likedByUsers = const [],
    this.sharedByUsers = const [],
    this.repostedByUsers = const [],
    required this.createdAt,
    required this.updatedAt,
    this.engagementRate = 0.0,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'analyticsId': analyticsId,
      'postId': postId,
      'authorId': authorId,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'repostCount': repostCount,
      'likedByUsers': likedByUsers,
      'sharedByUsers': sharedByUsers,
      'repostedByUsers': repostedByUsers,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'engagementRate': engagementRate,
    };
  }

  // Create from Firestore document
  factory AnalyticsModel.fromJson(Map<String, dynamic> json) {
    final viewCount = json['viewCount'] as int? ?? 0;
    final likeCount = json['likeCount'] as int? ?? 0;
    final engagementRate = viewCount > 0 ? (likeCount / viewCount) : 0.0;

    return AnalyticsModel(
      analyticsId: json['analyticsId'] ?? '',
      postId: json['postId'] ?? '',
      authorId: json['authorId'] ?? '',
      viewCount: viewCount,
      likeCount: likeCount,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      repostCount: json['repostCount'] as int? ?? 0,
      likedByUsers: List<String>.from(json['likedByUsers'] ?? []),
      sharedByUsers: List<String>.from(json['sharedByUsers'] ?? []),
      repostedByUsers: List<String>.from(json['repostedByUsers'] ?? []),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      engagementRate: (json['engagementRate'] as num?)?.toDouble() ?? engagementRate,
    );
  }

  // Copy with updated fields
  AnalyticsModel copyWith({
    String? analyticsId,
    String? postId,
    String? authorId,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? repostCount,
    List<String>? likedByUsers,
    List<String>? sharedByUsers,
    List<String>? repostedByUsers,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? engagementRate,
  }) {
    return AnalyticsModel(
      analyticsId: analyticsId ?? this.analyticsId,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      repostCount: repostCount ?? this.repostCount,
      likedByUsers: likedByUsers ?? this.likedByUsers,
      sharedByUsers: sharedByUsers ?? this.sharedByUsers,
      repostedByUsers: repostedByUsers ?? this.repostedByUsers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      engagementRate: engagementRate ?? this.engagementRate,
    );
  }

  // Get total engagements
  int get totalEngagements =>
      likeCount + commentCount + shareCount + repostCount;

  // Get engagement rate as percentage
  double get engagementPercentage => engagementRate * 100;

  // Rank metrics for comparison
  String getRankEmoji(int metric, List<AnalyticsModel> allPost) {
    if (allPost.isEmpty) return '📊';
    
    final sorted = allPost.map((p) => metric).toList()..sort();
    final median = sorted[sorted.length ~/ 2] as num;
    
    if (metric > median * 1.5) return '🚀';
    if (metric > median) return '📈';
    if (metric < median * 0.5) return '📉';
    return '➡️';
  }
}
