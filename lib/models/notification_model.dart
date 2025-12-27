import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String userId; // Recipient of the notification
  final String triggeredBy; // Who triggered the notification
  final String triggeredByName; // Name of who triggered it
  final String? triggeredByImageUrl; // Profile image of who triggered it
  final String type; // 'follow', 'like_post', 'comment', 'like_comment'
  final String? postId; // Related post ID (for likes/comments)
  final String? commentId; // Related comment ID (for comment likes)
  final String content; // Notification message
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.triggeredBy,
    required this.triggeredByName,
    this.triggeredByImageUrl,
    required this.type,
    this.postId,
    this.commentId,
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });

  // Convert NotificationModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'triggeredBy': triggeredBy,
      'triggeredByName': triggeredByName,
      'triggeredByImageUrl': triggeredByImageUrl,
      'type': type,
      'postId': postId,
      'commentId': commentId,
      'content': content,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }

  // Create NotificationModel from Firestore document
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notificationId: json['notificationId'] ?? '',
      userId: json['userId'] ?? '',
      triggeredBy: json['triggeredBy'] ?? '',
      triggeredByName: json['triggeredByName'] ?? '',
      triggeredByImageUrl: json['triggeredByImageUrl'],
      type: json['type'] ?? '',
      postId: json['postId'],
      commentId: json['commentId'],
      content: json['content'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
    );
  }

  // Create a copy with updated fields
  NotificationModel copyWith({
    String? notificationId,
    String? userId,
    String? triggeredBy,
    String? triggeredByName,
    String? triggeredByImageUrl,
    String? type,
    String? postId,
    String? commentId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      triggeredBy: triggeredBy ?? this.triggeredBy,
      triggeredByName: triggeredByName ?? this.triggeredByName,
      triggeredByImageUrl: triggeredByImageUrl ?? this.triggeredByImageUrl,
      type: type ?? this.type,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
