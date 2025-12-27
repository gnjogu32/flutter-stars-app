import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String conversationId;
  final List<String> participantIds;
  final String lastMessage;
  final String lastSenderId;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? otherUserName;
  final String? otherUserImageUrl;

  ConversationModel({
    required this.conversationId,
    required this.participantIds,
    required this.lastMessage,
    required this.lastSenderId,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.otherUserName,
    this.otherUserImageUrl,
  });

  // Convert ConversationModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unreadCount,
      'otherUserName': otherUserName,
      'otherUserImageUrl': otherUserImageUrl,
    };
  }

  // Create ConversationModel from Firestore document
  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      conversationId: json['conversationId'] ?? '',
      participantIds: List<String>.from(json['participantIds'] ?? []),
      lastMessage: json['lastMessage'] ?? '',
      lastSenderId: json['lastSenderId'] ?? '',
      lastMessageTime: json['lastMessageTime'] is Timestamp
          ? (json['lastMessageTime'] as Timestamp).toDate()
          : DateTime.parse(
              json['lastMessageTime'] ?? DateTime.now().toIso8601String(),
            ),
      unreadCount: json['unreadCount'] ?? 0,
      otherUserName: json['otherUserName'],
      otherUserImageUrl: json['otherUserImageUrl'],
    );
  }

  // Copy with updated fields
  ConversationModel copyWith({
    String? conversationId,
    List<String>? participantIds,
    String? lastMessage,
    String? lastSenderId,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? otherUserName,
    String? otherUserImageUrl,
  }) {
    return ConversationModel(
      conversationId: conversationId ?? this.conversationId,
      participantIds: participantIds ?? this.participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserImageUrl: otherUserImageUrl ?? this.otherUserImageUrl,
    );
  }
}
