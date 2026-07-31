import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String content;
  final String? imageUrl;
  final String? videoUrl;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool isRead;
  final bool isEncrypted;
  final String? nonce;
  final DateTime sentAt;
  final DateTime? readAt;

  MessageModel({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    required this.content,
    this.imageUrl,
    this.videoUrl,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    this.isRead = false,
    this.isEncrypted = false,
    this.nonce,
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
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'replyToId': replyToId,
      'replyToContent': replyToContent,
      'replyToSenderName': replyToSenderName,
      'isRead': isRead,
      'isEncrypted': isEncrypted,
      'nonce': nonce,
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
      imageUrl: json['imageUrl'],
      videoUrl: json['videoUrl'],
      replyToId: json['replyToId'],
      replyToContent: json['replyToContent'],
      replyToSenderName: json['replyToSenderName'],
      isRead: json['isRead'] ?? false,
      isEncrypted: json['isEncrypted'] ?? false,
      nonce: json['nonce'],
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
    String? imageUrl,
    String? videoUrl,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
    bool? isRead,
    bool? isEncrypted,
    String? nonce,
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
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      isRead: isRead ?? this.isRead,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      nonce: nonce ?? this.nonce,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
