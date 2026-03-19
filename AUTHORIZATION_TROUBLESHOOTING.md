# User Not Authorized - Troubleshooting Guide

## ✅ What Was Fixed

### Firestore Rules Update
Fixed authorization issue in conversations/messaging rules:

**Before** (Incorrect):
```javascript
match /conversations/{conversationId} {
  allow read: if request.auth.uid in resource.data.participants;  // ❌ Wrong field name
}
```

**After** (Correct):
```javascript
match /conversations/{conversationId} {
  allow read: if request.auth.uid in resource.data.participantIds;  // ✅ Correct field
}
```

**Status**: ✅ **Rules deployed successfully**

---

## 🔐 Authorization Error Causes & Solutions

### Error 1: "User Not Authorized" on Messages/Messaging

**Cause**: User not authenticated or rules deny access  
**Solution**:
- ✅ Make sure you're logged in (check Profile tab)
- ✅ Log out and log back in to refresh auth token
- ✅ Check internet connection is active
- ✅ Rules just deployed - restart app to clear cache

```bash
# Restart app to reload rules
adb shell pm clear starpage.com
adb shell am start -n starpage.com/.MainActivity
```

### Error 2: "Permission Denied" in Firestore Operations

**Cause**: User lacks permission for specific operation  
**Solution Check**:

| Feature | Rule | Fix |
|---------|------|-----|
| **View Profile** | Public read | No login needed |
| **Create Post** | Needs authentication | Must be logged in |
| **Comment** | Needs authentication | Must be logged in |
| **Message** | Must be conversation participant | Start conversation first |
| **Edit Post** | Must be author | You must own the post |

### Error 3: "Access Denied" on Cloud Storage

**Cause**: Storage upload/download permission denied  
**Solution**:
- ✅ Check Cloud Storage rules are deployed:
```bash
firebase deploy --only storage:rules
```
- ✅ Verify file path matches rules pattern:
  - Profile: `profile_images/{userId}.jpg`
  - Posts: `posts/{userId}/{postId}/*`
- ✅ Check user authentication token is valid

### Error 4: "Operation Not Permitted" on Database

**Cause**: Firestore rules prevent operation  
**Solution**:
```bash
# Verify rules are correct
firebase firestore:indexes

# Redeploy rules
firebase deploy --only firestore:rules
```

---

## 🔧 Current Authorization Rules (Now Fixed)

### Users Collection
```javascript
match /users/{userId} {
  allow read: if true;  // Anyone can view profiles
  allow write: if request.auth != null && request.auth.uid == userId;  // Only owner can edit
}
```

### Posts Collection
```javascript
match /posts/{postId} {
  allow read: if true;  // Anyone can read posts
  allow create: if request.auth != null;  // Any authenticated user
  allow update: if request.auth != null && resource.data.authorId == request.auth.uid;  // Author only
  allow delete: if request.auth != null && resource.data.authorId == request.auth.uid;  // Author only
}
```

### Comments Collection
```javascript
match /comments/{commentId} {
  allow read: if true;  // Anyone can read
  allow create: if request.auth != null;  // Any authenticated user
  allow update: if request.auth != null && resource.data.authorId == request.auth.uid;  // Author only
  allow delete: if request.auth != null && resource.data.authorId == request.auth.uid;  // Author only
}
```

### Conversations Collection ✅ FIXED
```javascript
match /conversations/{conversationId} {
  allow read: if request.auth != null && 
                 (request.auth.uid in resource.data.participantIds);  // ✅ Conversation participants only
  allow create: if request.auth != null;  // Any authenticated user
  allow update: if request.auth != null && 
                   (request.auth.uid in resource.data.participantIds);  // Participants only
}
```

### Messages Collection (Sub-collection)
```javascript
match /messages/{messageId} {
  allow read: if request.auth != null && 
                 (request.auth.uid in get(...).data.participantIds);  // Participants only
  allow create: if request.auth != null && 
                   request.auth.uid == request.resource.data.senderId;  // Sender must be auth user
}
```

---

## ✅ Verification Checklist

Before troubleshooting, verify:

- [ ] **Firebase Console Access**
  - Go to: https://console.firebase.google.com
  - Select project: `starpage-ed409`
  - Can you see Firestore Database?

- [ ] **Authentication Status**
  - Profile tab shows your name (logged in)
  - Can view other users' profiles
  - Can load home feed

- [ ] **Database Rules**
  - Check: Firestore → Rules
  - Status: Should show "✅ Compiled and deployed"
  - Last deploy: Today (Jan 26, 2026)

- [ ] **Storage Rules**
  - Check: Firebase → Storage → Rules
  - Status: Should show "✅ Compiled and deployed"
  - Allows profile image uploads

- [ ] **Network Connection**
  - Try loading home feed (posts should load)
  - Try uploading profile picture
  - Try creating a post (if logged in)

---

## 🐛 Debugging Steps

### Step 1: Check Authentication
```bash
# Get current user
# Go to Profile tab in app
# Should show your name and email

# If not logged in:
# 1. Go to Login screen
# 2. Enter email and password
# 3. Should authenticate successfully
```

### Step 2: Check Firestore Rules
```bash
# View current rules
firebase firestore:indexes

# View rule file
cat firestore.rules

# Redeploy if needed
firebase deploy --only firestore:rules
```

### Step 3: Check Firebase Project
```bash
# Verify correct project
firebase projects:list

# Should show: starpage-ed409

# If not, set project
firebase use starpage-ed409
```

### Step 4: Monitor Real-time Logs
```bash
# Watch app logs during operation
adb logcat starpage.com:V *:S

# Look for Firestore errors like:
# - "Permission denied"
# - "PERMISSION_DENIED"
# - "Unauthorized"
```

### Step 5: Clear and Rebuild
```bash
# Clear all caches
flutter clean
adb shell pm clear starpage.com

# Rebuild
flutter build apk --release

# Reinstall
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 📊 Authorization Flow (What Happens)

```
User performs action (e.g., send message)
    ↓
[1] Check: Is user authenticated?
    request.auth != null
    ↓
[2] Check: Does user meet rule conditions?
    request.auth.uid == resource owner OR
    request.auth.uid in participants[] OR
    other rule conditions
    ↓
[3] Result: Allow or Deny
    ✅ Operation succeeds
    ❌ Operation fails with "Not Authorized"
```

---

## 🔗 Files Just Updated

- ✅ `firestore.rules` - Fixed `participantIds` field name
- ✅ Firebase deployed successfully

---

## 📞 Common Solutions

### "Not authorized to read" - Profile
```
✅ Solution: Profiles are public - check internet connection
```

### "Not authorized to create" - Post
```
✅ Solution: Log in first, then try again
```

### "Not authorized to update" - Edit Post
```
✅ Solution: Only post author can edit - check you own it
```

### "Not authorized to send" - Message
```
✅ Solution: You must be a conversation participant
✅ Action: Create new conversation first, then message
```

### "Not authorized" - Any operation
```
✅ Solution 1: Log out and log back in
✅ Solution 2: Restart app (force close + reopen)
✅ Solution 3: Clear app cache: adb shell pm clear starpage.com
✅ Solution 4: Check Rules are deployed: firebase deploy --only firestore:rules
```

---

## 🚀 Testing Authorization

### Test 1: Read Public Data (No Auth Needed)
```
1. Open app (don't log in)
2. Try viewing home feed
→ Should show public posts (if any exist)
→ ✅ Pass: Public read works
```

### Test 2: Create Data (Auth Needed)
```
1. Try to create post WITHOUT logging in
→ Should show "Not authenticated" error
→ ✅ Pass: Auth check works

2. Log in with valid account
3. Try to create post again
→ Should succeed
→ ✅ Pass: Authenticated create works
```

### Test 3: Modify Own Data
```
1. Log in as User A
2. Create a post
3. Click edit
4. Modify post
→ Should succeed
→ ✅ Pass: Owner modification works
```

### Test 4: Block Unauthorized Modify
```
1. Log in as User A
2. Create a post
3. Switch to User B account
4. Try to edit User A's post
→ Should fail with "Not authorized"
→ ✅ Pass: Authorization blocking works
```

---

## 📋 Summary of Authorization Rules

| Action | Public | Authenticated | Owner Only |
|--------|--------|---------------|-----------|
| View Profile | ✅ | ✅ | ✅ |
| View Post | ✅ | ✅ | ✅ |
| View Comments | ✅ | ✅ | ✅ |
| Create Post | ❌ | ✅ | ✅ |
| Create Comment | ❌ | ✅ | ✅ |
| Edit Post | ❌ | ❌ | ✅ |
| Delete Post | ❌ | ❌ | ✅ |
| Send Message | ❌ | ✅ (if participant) | ✅ |
| Read Message | ❌ | ✅ (if participant) | ✅ |

---

**Last Updated**: January 26, 2026  
**Status**: ✅ Authorization rules deployed and verified  
**Firebase Project**: starpage-ed409

---

## ✅ You Should Now Be Able To:

- ✅ View public posts and comments (no login needed)
- ✅ Create account and log in
- ✅ Create posts (while logged in)
- ✅ Comment on posts (while logged in)
- ✅ Send messages to other users
- ✅ Edit/delete your own posts
- ✅ Follow other users

If you still see "Not Authorized" errors:
1. Check you're logged in (Profile tab)
2. Restart app (force close and reopen)
3. Clear cache: `adb shell pm clear starpage.com`
4. Check rules deployed: `firebase deploy --only firestore:rules`

