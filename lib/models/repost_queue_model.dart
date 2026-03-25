import 'package:cloud_firestore/cloud_firestore.dart';

class RepostQueueModel {
  final String queueId;
  final String userId;
  final String postId;
  final String originalAuthorId;
  final String? repostCaption;
  final DateTime scheduleTime; // When to post
  final bool isScheduled; // True if scheduled for future
  final DateTime createdAt;
  final String status; // 'pending', 'sent', 'failed'
  final String? errorMessage;

  RepostQueueModel({
    required this.queueId,
    required this.userId,
    required this.postId,
    required this.originalAuthorId,
    this.repostCaption,
    required this.scheduleTime,
    this.isScheduled = false,
    required this.createdAt,
    this.status = 'pending',
    this.errorMessage,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'queueId': queueId,
      'userId': userId,
      'postId': postId,
      'originalAuthorId': originalAuthorId,
      'repostCaption': repostCaption,
      'scheduleTime': scheduleTime,
      'isScheduled': isScheduled,
      'createdAt': createdAt,
      'status': status,
      'errorMessage': errorMessage,
    };
  }

  // Create from Firestore document
  factory RepostQueueModel.fromJson(Map<String, dynamic> json) {
    return RepostQueueModel(
      queueId: json['queueId'] ?? '',
      userId: json['userId'] ?? '',
      postId: json['postId'] ?? '',
      originalAuthorId: json['originalAuthorId'] ?? '',
      repostCaption: json['repostCaption'],
      scheduleTime: json['scheduleTime'] is Timestamp
          ? (json['scheduleTime'] as Timestamp).toDate()
          : DateTime.parse(json['scheduleTime'] ?? DateTime.now().toIso8601String()),
      isScheduled: json['isScheduled'] ?? false,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      status: json['status'] ?? 'pending',
      errorMessage: json['errorMessage'],
    );
  }

  // Copy with updated fields
  RepostQueueModel copyWith({
    String? queueId,
    String? userId,
    String? postId,
    String? originalAuthorId,
    String? repostCaption,
    DateTime? scheduleTime,
    bool? isScheduled,
    DateTime? createdAt,
    String? status,
    String? errorMessage,
  }) {
    return RepostQueueModel(
      queueId: queueId ?? this.queueId,
      userId: userId ?? this.userId,
      postId: postId ?? this.postId,
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      repostCaption: repostCaption ?? this.repostCaption,
      scheduleTime: scheduleTime ?? this.scheduleTime,
      isScheduled: isScheduled ?? this.isScheduled,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Check if scheduled for future
  bool get isFuture => scheduleTime.isAfter(DateTime.now());

  // Get human-readable status
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'sent':
        return 'Reposted';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
}
