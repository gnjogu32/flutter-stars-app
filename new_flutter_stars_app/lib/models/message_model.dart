import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String content;
  final bool isRead;
  final DateTime sentAt;
  final DateTime? readAt;

  MessageModel({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    required this.content,
    this.isRead = false,
    required this.sentAt,
    this.readAt,
  });

  // Convert MessageModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'content': content,
      'isRead': isRead,
      'sentAt': sentAt,
      'readAt': readAt,
    };
  }

  // Create MessageModel from Firestore document
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      messageId: json['messageId'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      senderImageUrl: json['senderImageUrl'],
      content: json['content'] ?? '',
      isRead: json['isRead'] ?? false,
      sentAt: json['sentAt'] is Timestamp
          ? (json['sentAt'] as Timestamp).toDate()
          : DateTime.parse(json['sentAt'] ?? DateTime.now().toIso8601String()),
      readAt: json['readAt'] is Timestamp
          ? (json['readAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Copy with updated fields
  MessageModel copyWith({
    String? messageId,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderImageUrl,
    String? content,
    bool? isRead,
    DateTime? sentAt,
    DateTime? readAt,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderImageUrl: senderImageUrl ?? this.senderImageUrl,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
