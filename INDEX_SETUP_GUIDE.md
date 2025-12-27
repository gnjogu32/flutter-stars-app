# Firestore Index Setup Guide

## Quick Start

This guide will help you create all necessary Firestore indexes for the Starpage app.

## Option 1: Firebase Console (Manual) - Recommended for Beginners

### Step 1: Open Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **starpage-ed409**
3. Click on **Firestore Database** in the left sidebar

### Step 2: Navigate to Indexes
1. In the Firestore Database panel, click on the **Indexes** tab
2. You should see two sub-tabs: "Cloud Firestore indexes" and "Datastore indexes"
3. Make sure you're on **Cloud Firestore indexes**

### Step 3: Create Indexes Manually

#### Index 1: Users - Search by Display Name
1. Click **Create Index**
2. **Collection ID:** `users`
3. **Fields:**
   - Field: `displayName` | Order: `Ascending`
4. Click **Create**

#### Index 2: Posts - Filter by Talent
1. Click **Create Index**
2. **Collection ID:** `posts`
3. **Fields:**
   - Field: `talent` | Order: `Ascending`
   - Field: `createdAt` | Order: `Descending`
4. Click **Create**

#### Index 3: Posts - Filter by Author
1. Click **Create Index**
2. **Collection ID:** `posts`
3. **Fields:**
   - Field: `authorId` | Order: `Ascending`
   - Field: `createdAt` | Order: `Descending`
4. Click **Create**

#### Index 4: Notifications - Unread
1. Click **Create Index**
2. **Collection ID:** `notifications` → Document ID: `{userId}` → Subcollection: `userNotifications`
3. **Fields:**
   - Field: `isRead` | Order: `Ascending`
4. Click **Create**

#### Index 5: Notifications - Ordered
1. Click **Create Index**
2. **Collection ID:** `notifications` → Document ID: `{userId}` → Subcollection: `userNotifications`
3. **Fields:**
   - Field: `createdAt` | Order: `Descending`
4. Click **Create**

---

## Option 2: Firebase CLI (Automated)

### Step 1: Install Firebase CLI
```bash
npm install -g firebase-tools
```

### Step 2: Authenticate
```bash
firebase login
```

### Step 3: Deploy Indexes
Navigate to your Flutter project root directory and run:

```bash
firebase deploy --only firestore:indexes
```

The CLI will read from `firestore.indexes.json` and create all indexes automatically.

---

## Option 3: Let Firebase Auto-Create Indexes

Firebase will automatically detect compound queries and suggest index creation:

1. Run your Flutter app: `flutter run -d edge`
2. Test features that use compound queries:
   - Search for users
   - Filter posts by talent
   - View notifications
3. Check Firebase Console → Firestore Database → Indexes
4. Click any **"Create index"** suggestions that appear
5. Firebase will automatically create and manage them

---

## Verify Index Creation

### In Firebase Console:
1. Go to **Firestore Database** → **Indexes** tab
2. Look for indexes with status **Enabled** (green checkmark)
3. All 5 indexes should appear within a few minutes

### In Terminal (if using CLI):
```bash
firebase firestore:indexes
```

This shows all indexes and their status.

---

## Index Status Timeline

| Stage | Duration | What's Happening |
|-------|----------|------------------|
| Creating | 1-5 minutes | Firestore is building the index |
| Enabled | N/A | Index is ready to use |
| Error | N/A | Check Firebase Console for details |

---

## Troubleshooting

### Indexes not appearing?
- Wait 5-10 minutes, indexes take time to create
- Refresh the Firebase Console
- Check that you're in the correct project

### "Index creation failed" error?
- Verify your Firestore rules allow reads/writes
- Check that fields exist in your documents
- Clear browser cache and try again

### Queries still slow?
- Ensure all 5 indexes are **Enabled** (not Creating)
- Check that your queries match the indexed fields
- Firestore may need 24 hours to optimize

---

## Index Verification

### Test that indexes are working:
1. Open your app in Edge browser
2. Go to **Discover** tab → search for users
3. Open **Profile** → view posts by talent
4. Check **Notifications** tab
5. All should load quickly

If queries are fast, indexes are working! 🎉

---

## Cost Impact

**Good news:** Firestore indexes DO NOT increase your costs.
- Creating indexes: **Free**
- Maintaining indexes: **Free**
- Read/write operations: Standard pricing (same with or without indexes)

Indexes only affect performance, not pricing.

---

## Best Practices

✅ **Do:**
- Create indexes for frequently used queries
- Use compound indexes for complex filters
- Monitor Firebase Console for suggested indexes
- Test query performance after creating indexes

❌ **Don't:**
- Create duplicate indexes
- Index every field
- Forget to create indexes for compound queries
- Ignore Firebase's index suggestions

---

## Need Help?

- Firebase Docs: https://firebase.google.com/docs/firestore/query-data/indexing
- Firebase Console: https://console.firebase.google.com
- Project: starpage-ed409

