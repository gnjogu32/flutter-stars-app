"""
Firestore Query Indexes for Starpage App

This document lists all the database queries that require Firestore indexes
for optimal performance. Follow the instructions below to set up these indexes
in your Firebase Console.

IMPORTANT: Firestore will automatically suggest creating indexes when you run
compound queries. However, you can pre-create them using this guide.

═══════════════════════════════════════════════════════════════════════════════

1. USERS COLLECTION - Search by Display Name
───────────────────────────────────────────────────────────────────────────────
Location: lib/services/user_service.dart - searchUsers()
Query: 
  where('displayName', isGreaterThanOrEqualTo: query)
  where('displayName', isLessThan: query + 'z')
  orderBy('displayName')

Index Needed:
  Collection: users
  Fields: displayName (Ascending), displayName (Ascending)

═══════════════════════════════════════════════════════════════════════════════

2. POSTS COLLECTION - Filter by Talent Category
───────────────────────────────────────────────────────────────────────────────
Location: lib/services/post_service.dart - getPostsByTalent()
Query:
  where('talent', isEqualTo: talent)
  orderBy('createdAt', descending: true)

Index Needed:
  Collection: posts
  Fields: talent (Ascending), createdAt (Descending)

═══════════════════════════════════════════════════════════════════════════════

3. POSTS COLLECTION - Filter by Author
───────────────────────────────────────────────────────────────────────────────
Location: lib/services/post_service.dart - getPostsByAuthor()
Query:
  where('authorId', isEqualTo: authorId)
  orderBy('createdAt', descending: true)

Index Needed:
  Collection: posts
  Fields: authorId (Ascending), createdAt (Descending)

═══════════════════════════════════════════════════════════════════════════════

4. NOTIFICATIONS COLLECTION - Unread Notifications
───────────────────────────────────────────────────────────────────────────────
Location: lib/services/notification_service.dart - getUnreadCountStream()
Query:
  Collection: notifications/{userId}/userNotifications
  where('isRead', isEqualTo: false)

Index Needed:
  Collection: notifications/{userId}/userNotifications
  Fields: isRead (Ascending)

═══════════════════════════════════════════════════════════════════════════════

5. NOTIFICATIONS COLLECTION - Ordered Notifications
───────────────────────────────────────────────────────────────────────────────
Location: lib/services/notification_service.dart - getNotificationsStream()
Query:
  Collection: notifications/{userId}/userNotifications
  orderBy('createdAt', descending: true)

Index Needed:
  Collection: notifications/{userId}/userNotifications
  Fields: createdAt (Descending)

═══════════════════════════════════════════════════════════════════════════════

6. NOTIFICATIONS COLLECTION - All Notifications (with read filter)
───────────────────────────────────────────────────────────────────────────────
Location: lib/services/notification_service.dart - markAllAsRead()
Query:
  Collection: notifications/{userId}/userNotifications
  where('isRead', isEqualTo: false)

Note: This index overlaps with #4

═══════════════════════════════════════════════════════════════════════════════
═══════════════════════════════════════════════════════════════════════════════

HOW TO CREATE INDEXES IN FIREBASE CONSOLE:

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project (starpage-ed409)
3. Navigate to: Firestore Database → Indexes
4. Click "Create Index"
5. Fill in the required fields:
   - Collection ID: (from the list above)
   - Fields: (add fields in the order specified)
   - Query scope: Collection (or Collection group if sub-collection)
   - Status: Enabled

═══════════════════════════════════════════════════════════════════════════════

AUTOMATED INDEX CREATION:

Firebase Cloud Firestore can automatically suggest and create indexes when you
run compound queries in development. The easiest way is to:

1. Run the app with these queries active
2. Check the Firebase Console
3. Firebase will show "Create index" suggestions
4. Click the suggestion to auto-create the index

═══════════════════════════════════════════════════════════════════════════════

PERFORMANCE IMPACT:

These indexes will:
✓ Speed up search queries (users, posts by talent)
✓ Optimize notification filtering
✓ Reduce read operations
✓ Enable sorting with filters
✓ Improve app responsiveness

Without indexes, Firestore will still work but may return results slower or
show warnings in the console.

═══════════════════════════════════════════════════════════════════════════════
"""
