# Direct Messaging Feature - Starpage

## Overview

The Direct Messaging system enables real-time peer-to-peer communication between Starpage users. Messages are delivered instantly via Firebase Firestore with read receipts and conversation management.

## Architecture

### Data Models

#### MessageModel
Located in `lib/models/message_model.dart`

```dart
class MessageModel {
  final String messageId;              // Unique message identifier
  final String conversationId;         // Parent conversation
  final String senderId;               // User who sent message
  final String senderName;             // Sender's display name
  final String? senderImageUrl;        // Sender's profile image
  final String content;                // Message text
  final DateTime sentAt;               // Timestamp of send
  final bool isRead;                   // Read status
  final DateTime? readAt;              // When message was read (optional)
}
```

#### ConversationModel
Located in `lib/models/conversation_model.dart`

```dart
class ConversationModel {
  final String conversationId;         // Unique conversation ID (sorted user IDs)
  final List<String> participantIds;   // Two user IDs involved
  final String lastMessage;            // Preview of last message
  final String lastSenderId;           // Who sent the last message
  final DateTime lastMessageTime;      // Timestamp of last message
  final int unreadCount;               // Number of unread messages for current user
  final String? otherUserName;         // Display name of other participant
  final String? otherUserImageUrl;     // Profile image of other participant
}
```

### Firestore Structure

```
conversations/
├── {conversationId}/
│   ├── conversationId: string
│   ├── participantIds: string[]      # [userId1, userId2]
│   ├── lastMessage: string
│   ├── lastSenderId: string
│   ├── lastMessageTime: timestamp
│   ├── otherUserName: string
│   ├── otherUserImageUrl: string
│   ├── createdAt: timestamp
│   └── messages/
│       └── {messageId}/
│           ├── messageId: string
│           ├── conversationId: string
│           ├── senderId: string
│           ├── senderName: string
│           ├── senderImageUrl: string (optional)
│           ├── content: string
│           ├── sentAt: timestamp
│           ├── isRead: boolean
│           └── readAt: timestamp (optional)
```

### Service Layer

#### ChatService
Located in `lib/services/chat_service.dart`

**Key Methods:**

1. **sendMessage()**
   ```dart
   Future<void> sendMessage({
     required String senderId,
     required String senderName,
     required String? senderImageUrl,
     required String recipientId,
     required String recipientName,
     required String? recipientImageUrl,
     required String content,
   })
   ```
   - Creates message document in Firestore
   - Updates conversation metadata
   - Triggers notification for recipient

2. **getMessagesStream()**
   ```dart
   Stream<List<MessageModel>> getMessagesStream(String conversationId)
   ```
   - Returns real-time stream of messages
   - Orders by `sentAt` descending (newest first)
   - Limits to last 50 messages for performance

3. **getConversationsStream()**
   ```dart
   Stream<List<ConversationModel>> getConversationsStream(String userId)
   ```
   - Returns all conversations for a user
   - Orders by `lastMessageTime` descending

4. **markMessageAsRead()**
   ```dart
   Future<void> markMessageAsRead(String conversationId, String messageId)
   ```
   - Sets `isRead` flag on individual message

5. **markAllMessagesAsRead()**
   ```dart
   Future<void> markAllMessagesAsRead(String conversationId, String userId)
   ```
   - Marks all unread messages from other user as read
   - Called when ChatScreen is opened

6. **deleteMessage()**
   ```dart
   Future<void> deleteMessage(String conversationId, String messageId)
   ```
   - Removes message document from Firestore

7. **searchConversations()**
   ```dart
   Future<List<ConversationModel>> searchConversations(String userId, String query)
   ```
   - Filters conversations by other user's name

8. **startConversation()**
   ```dart
   Future<String> startConversation({
     required String currentUserId,
     required String targetUserId,
     required String targetUserName,
     required String? targetUserImageUrl,
   })
   ```
   - Creates conversation document if not exists
   - Returns conversation ID

### UI Components

#### MessagesScreen
Located in `lib/screens/messages_screen.dart`

**Features:**
- Lists all active conversations
- Search conversations by user name
- Shows last message preview
- Displays unread message count with badge
- Timestamps using `timeago` package
- Staggered animations for list items
- Tap to open conversation

**Layout:**
```
┌─────────────────────────────────┐
│ Messages                        │
├─────────────────────────────────┤
│ [Search box]                    │
├─────────────────────────────────┤
│ [User 1] Last message...    2h  │
│ [Avatar]                   [2]  │
├─────────────────────────────────┤
│ [User 2] Last message...   15m  │
│ [Avatar]                   [0]  │
├─────────────────────────────────┤
│ [User 3] Last message...    1d  │
│ [Avatar]                   [5]  │
└─────────────────────────────────┘
```

#### ChatScreen
Located in `lib/screens/chat_screen.dart`

**Features:**
- Real-time message display
- Left/right aligned message bubbles
- Timestamps for each message
- Read receipt indicators (checkmarks)
- Message input field with send button
- Auto-scroll to latest messages
- Loading state while sending
- Empty state message

**Message Bubbles:**
- **Current User**: Blue background, right-aligned
- **Other User**: Gray background, left-aligned
- Shows sender name and timestamp
- Read indicator with checkmark icon

**Input Area:**
- Text field with multi-line support
- Send button with loading spinner
- Input validation (no empty messages)

### Navigation Integration

#### MainApp
Updated `lib/screens/main_app.dart` to include Messages tab

**Bottom Navigation Items:**
1. Home
2. Discover
3. **Messages** (NEW)
4. Notifications
5. Profile

### Profile Integration

#### Profile Message Button
Updated `lib/screens/profile_screen.dart`

**New Feature:**
- "Message" button appears on other users' profiles
- Located below Follow/Following button
- Opens ChatScreen with that user's conversation
- Uses outlined button style for differentiation

**Button Logic:**
```dart
void _navigateToChat(UserModel user) {
  final currentUserId = _auth.currentUser?.uid;
  final conversationId = _generateConversationId(currentUserId, user.uid);
  
  Navigator.push(ChatScreen(
    conversationId: conversationId,
    otherUserId: user.uid,
    otherUserName: user.displayName,
    otherUserImageUrl: user.profileImageUrl,
  ));
}
```

## Usage Flow

### Starting a Conversation

1. **From Profile Page:**
   - Navigate to another user's profile
   - Click "Message" button
   - Opens ChatScreen with that user

2. **From Messages Tab:**
   - Click Messages in bottom navigation
   - Tap existing conversation OR
   - Search for user and start new conversation

### Sending a Message

1. Open conversation from Messages screen
2. Type message in input field
3. Press send button
4. Message appears immediately on screen
5. Delivered to recipient in real-time
6. Notification sent to recipient

### Viewing Messages

1. Messages display in real-time as they arrive
2. Older messages load when scrolling up
3. Newest messages appear at bottom
4. Auto-scroll to latest message
5. Read status shows with checkmark

### Message Status

- **Sent**: Message appears in conversation
- **Delivered**: Visible to recipient in real-time
- **Read**: Checkmark indicator when recipient opens chat

## Notifications

When a message is sent, a notification is created in the recipient's notification feed:

```dart
await notificationService.createNotification(
  userId: recipientId,
  triggeredBy: senderId,
  triggeredByName: senderName,
  triggeredByImageUrl: senderImageUrl,
  type: 'direct_message',
  content: '$senderName sent you a message',
);
```

**Notification Type:** `direct_message`

## Key Features

✅ **Real-time Messaging**
- Messages delivered instantly via Firestore streams
- Live conversation updates

✅ **Conversation Management**
- Automatic conversation creation/retrieval
- Sorted by most recent activity
- Unread message tracking

✅ **User Experience**
- Clean message bubbles (left/right aligned)
- Timestamps on all messages
- Read receipts with checkmarks
- Auto-scroll to latest messages

✅ **Search & Filter**
- Search conversations by user name
- Quick access to past conversations

✅ **Notifications**
- Notifications sent on new messages
- Unread message badges

✅ **Animations**
- Staggered list animations
- Slide-up transitions
- Smooth button interactions

## Performance Considerations

1. **Message Limit:** Query limited to last 50 messages per conversation
   - Prevents loading too much history on first load
   - Users can scroll up to load older messages (future enhancement)

2. **Firestore Queries:**
   - Conversation list uses `collectionGroup` with user ID filter
   - Messages ordered by timestamp with limit

3. **Real-time Streams:**
   - Streams automatically close when widgets are disposed
   - Provider pattern manages stream subscriptions

## Future Enhancements

- [ ] Message pagination (load older messages on scroll)
- [ ] Image sharing in messages
- [ ] Typing indicators ("User is typing...")
- [ ] Message editing and deletion
- [ ] Message reactions/emojis
- [ ] Message search within conversations
- [ ] Pin important messages
- [ ] Group conversations
- [ ] Voice/video call integration
- [ ] Message encryption

## Testing

### Manual Testing Steps

1. **Create Conversation:**
   - Login as User A
   - Navigate to User B's profile
   - Click "Message" button
   - Verify ChatScreen opens

2. **Send Message:**
   - Type message in input field
   - Click send button
   - Verify message appears in conversation

3. **Real-time Delivery:**
   - Have two instances open (or two users)
   - Send message from User A
   - Verify appears immediately in User B's instance

4. **Conversation List:**
   - Navigate to Messages tab
   - Verify conversations listed by most recent
   - Verify unread badges show

5. **Search:**
   - Type user name in search box
   - Verify list filters by name

## Firestore Indexes

No special indexes required for basic messaging functionality. However, for production with high message volume, consider adding indexes for:

```
Collection: conversations/{conversationId}/messages
- sentAt (Descending)
- isRead (Ascending)
```

## Error Handling

- **Invalid User**: Checks for null current user before navigation
- **Failed Send**: SnackBar error message shown to user
- **Load Error**: Error message displayed in streams
- **Network Issues**: Handled by Firebase error handling

## Security Considerations

- Messages only visible to conversation participants (via participantIds check)
- Users can only modify their own messages
- Read receipts only for messages from other user
- Notification only created for recipient

## Code References

**Key Files:**
- [MessageModel](lib/models/message_model.dart)
- [ConversationModel](lib/models/conversation_model.dart)
- [ChatService](lib/services/chat_service.dart)
- [MessagesScreen](lib/screens/messages_screen.dart)
- [ChatScreen](lib/screens/chat_screen.dart)
- [ProfileScreen](lib/screens/profile_screen.dart) - Message button
- [MainApp](lib/screens/main_app.dart) - Navigation

## Summary

The Direct Messaging feature provides a complete real-time chat system for Starpage users. Built on Firestore, it offers instant message delivery, conversation management, and seamless UI integration. The architecture is scalable and provides a foundation for future enhancements like image sharing, typing indicators, and group conversations.
