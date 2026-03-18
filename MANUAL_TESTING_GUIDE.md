# Manual Testing Guide - Starpage App

**Status**: App is running at http://localhost:56497  
**Date**: February 14, 2026  
**Tests Passed**: 3/3 unit tests ✅

---

## 🎯 Testing Overview

This guide helps you manually test all features before Play Store submission.

### Quick Status
- ✅ Unit tests: 3/3 passed
- ⏳ Manual testing: In progress
- ⏳ Device testing: Pending
- ⏳ Performance testing: Pending

---

## 📋 Feature Testing Checklist

### 1. Authentication Testing 🔐

#### Sign Up Flow
- [ ] Navigate to sign-up screen
- [ ] Try creating account with:
  - [ ] Valid email and password (6+ characters)
  - [ ] Invalid email format → Should show error
  - [ ] Weak password (< 6 chars) → Should show error
  - [ ] Empty fields → Should show validation error
- [ ] Verify account creation success
- [ ] Check if redirected to profile setup or home

#### Login Flow
- [ ] Go to login screen
- [ ] Test login with:
  - [ ] Correct credentials → Should succeed
  - [ ] Wrong password → Should show error
  - [ ] Non-existent email → Should show error
  - [ ] Empty fields → Should show validation
- [ ] Verify successful login redirects to home

#### Password Reset
- [ ] Click "Forgot Password"
- [ ] Enter registered email
- [ ] Check for confirmation message
- [ ] Check email inbox for reset link (if configured)

#### Session Management
- [ ] Login successfully
- [ ] Close browser/tab
- [ ] Reopen app → Should stay logged in
- [ ] Logout → Should redirect to login

---

### 2. Profile Testing 👤

#### View Profile
- [ ] Navigate to your profile
- [ ] Verify profile displays:
  - [ ] Display name
  - [ ] Username/email
  - [ ] Bio/description
  - [ ] Profile picture (if uploaded)
  - [ ] Follower count
  - [ ] Following count
  - [ ] Posts count

#### Edit Profile
- [ ] Click Edit Profile button
- [ ] Test updating:
  - [ ] Display name → Save → Verify change
  - [ ] Bio/description → Save → Verify change
  - [ ] Talent category → Save → Verify change
  - [ ] Profile picture:
    - [ ] Upload new image
    - [ ] Verify image appears
    - [ ] Check image quality
    - [ ] Try large file (> 5MB) → Should handle/compress

#### View Other Profiles
- [ ] Find another user (via search or posts)
- [ ] Click on their profile
- [ ] Verify you can see:
  - [ ] Their display name
  - [ ] Their bio
  - [ ] Their posts
  - [ ] Follow/Unfollow button
- [ ] Test Follow → Should increment follower count
- [ ] Test Unfollow → Should decrement follower count

---

### 3. Posts Testing 📝

#### Create Post
- [ ] Click "Create Post" or "+" button
- [ ] Test creating post with:
  - [ ] Text only
  - [ ] Text + single image
  - [ ] Text + multiple images (if supported)
  - [ ] Very long text (test scrolling)
  - [ ] Emoji in text
- [ ] Verify post appears in feed immediately
- [ ] Check post shows correct:
  - [ ] Author name
  - [ ] Author profile picture
  - [ ] Timestamp
  - [ ] Content

#### View Posts
- [ ] Scroll through home feed
- [ ] Verify posts load smoothly
- [ ] Check infinite scroll works (loads more posts)
- [ ] Test pull-to-refresh
- [ ] Click on a post → Opens detailed view
- [ ] Verify images load correctly
- [ ] Test image zoom/expand (if available)

#### Interact with Posts
- [ ] Like a post
  - [ ] Heart/like icon changes color
  - [ ] Like count increases
  - [ ] Post owner gets notification (check later)
- [ ] Unlike a post
  - [ ] Icon returns to default
  - [ ] Like count decreases
- [ ] Comment on a post
  - [ ] Type comment
  - [ ] Submit
  - [ ] Verify comment appears
  - [ ] Verify comment count increases
  - [ ] Post owner gets notification (check later)
- [ ] View all comments
  - [ ] Click "View comments"
  - [ ] Scroll through comments
  - [ ] Test commenting from detail view

#### Delete Post
- [ ] Find your own post
- [ ] Click delete/menu button
- [ ] Confirm deletion
- [ ] Verify post removed from feed
- [ ] Verify post removed from profile

---

### 4. Social Features Testing 🤝

#### Follow System
- [ ] Follow a user → Check they appear in "Following" list
- [ ] Unfollow a user → Check they're removed from list
- [ ] View "Followers" list
- [ ] View "Following" list
- [ ] Test following multiple users
- [ ] Verify followed users' posts appear in feed

#### Search & Discovery
- [ ] Open search
- [ ] Search for users by:
  - [ ] Username
  - [ ] Display name
  - [ ] Partial name
- [ ] Search for posts by:
  - [ ] Keyword
  - [ ] Hashtag (if supported)
- [ ] Test empty search results
- [ ] Test special characters in search

#### Feed Algorithm
- [ ] Verify home feed shows:
  - [ ] Posts from followed users
  - [ ] Recent posts first (chronological)
  - [ ] OR trending posts (if algorithm-based)
- [ ] Check "Explore" or "Trending" section (if exists)

---

### 5. Messaging Testing 💬

#### Direct Messages
- [ ] Navigate to messages/inbox
- [ ] Start new conversation:
  - [ ] Search for user
  - [ ] Send first message
  - [ ] Verify message appears in chat
- [ ] Reply to existing conversation
- [ ] Test sending:
  - [ ] Short messages
  - [ ] Long messages (test scrolling)
  - [ ] Emoji
  - [ ] Multiple messages quickly
- [ ] Verify real-time updates:
  - [ ] Send message
  - [ ] Check it appears without refresh
- [ ] Check conversation list:
  - [ ] Shows recent conversations
  - [ ] Shows last message preview
  - [ ] Shows unread badge (if applicable)

#### Message Notifications
- [ ] Send a message to another user
- [ ] Check if recipient gets notification
- [ ] Click notification → Opens conversation

---

### 6. Notifications Testing 🔔

#### Notification Types
- [ ] Like notification:
  - [ ] Get a like on your post
  - [ ] Check notification appears
  - [ ] Click notification → Opens post
- [ ] Comment notification:
  - [ ] Get a comment on your post
  - [ ] Check notification appears
  - [ ] Click notification → Opens post with comments
- [ ] Follow notification:
  - [ ] Get a new follower
  - [ ] Check notification appears
  - [ ] Click notification → Opens follower's profile
- [ ] Message notification:
  - [ ] Receive a new message
  - [ ] Check notification appears
  - [ ] Click notification → Opens chat

#### Notification Settings
- [ ] Navigate to settings/notifications
- [ ] Toggle notification preferences
- [ ] Test enabling/disabling different types

---

### 7. UI/UX Testing 🎨

#### Navigation
- [ ] Test all bottom navigation tabs:
  - [ ] Home/Feed
  - [ ] Search/Explore
  - [ ] Create Post
  - [ ] Notifications
  - [ ] Profile
- [ ] Test back button navigation
- [ ] Test deep linking (if configured)

#### Responsive Design
- [ ] Resize browser window
- [ ] Test at different widths:
  - [ ] Mobile (320px - 480px)
  - [ ] Tablet (768px - 1024px)
  - [ ] Desktop (1200px+)
- [ ] Verify layout adapts properly
- [ ] Check text remains readable
- [ ] Verify buttons are clickable

#### Loading States
- [ ] Check loading indicators appear for:
  - [ ] Initial app load
  - [ ] Fetching posts
  - [ ] Loading profile
  - [ ] Uploading images
- [ ] Verify spinners/skeletons look good

#### Error Handling
- [ ] Disconnect internet
- [ ] Try loading content → Should show error
- [ ] Try posting → Should show error
- [ ] Reconnect → Should recover gracefully
- [ ] Test offline mode (if supported)

#### Animations
- [ ] Like button animation
- [ ] Page transitions
- [ ] Modal/dialog animations
- [ ] Pull-to-refresh animation
- [ ] Loading animations

---

### 8. Performance Testing ⚡

#### Load Times
- [ ] Measure app initial load time (< 3 seconds ideal)
- [ ] Check feed loads quickly
- [ ] Verify images load progressively
- [ ] Test with slow 3G network (Chrome DevTools)

#### Smooth Scrolling
- [ ] Scroll through long feed
- [ ] Verify no lag or stuttering
- [ ] Check 60fps maintained

#### Memory Usage
- [ ] Open Chrome DevTools → Performance
- [ ] Record while using app
- [ ] Check memory doesn't increase excessively
- [ ] Test for memory leaks

---

### 9. Security Testing 🔒

#### Authentication Security
- [ ] Verify can't access protected routes without login
- [ ] Test logging out clears session
- [ ] Check sensitive data not in URL
- [ ] Verify password is masked in forms

#### Data Privacy
- [ ] Can only edit your own profile
- [ ] Can only delete your own posts
- [ ] Can't access other users' private data
- [ ] Verify proper error messages (not exposing system info)

---

### 10. Edge Cases Testing 🔍

#### Boundary Testing
- [ ] Create post with 0 characters → Should prevent
- [ ] Create post with max characters (test limit)
- [ ] Upload very large image (> 10MB) → Should handle
- [ ] Upload invalid file type → Should show error
- [ ] Enter special characters in all text fields
- [ ] Enter very long username/email

#### Concurrent Actions
- [ ] Like/unlike rapidly (spam click)
- [ ] Send multiple messages quickly
- [ ] Create multiple posts in succession
- [ ] Follow/unfollow same user repeatedly

#### Empty States
- [ ] New account with no posts → Shows empty state
- [ ] User with no followers → Shows empty state
- [ ] No search results → Shows empty state
- [ ] No notifications → Shows empty state

---

## 🐛 Bug Tracking

### Found Issues Template

For each bug found, document:
```
**Bug #**: [Number]
**Severity**: Critical / Major / Minor / Cosmetic
**Feature**: [Which feature]
**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Result**: 
**Actual Result**: 
**Screenshot**: [If applicable]
**Device/Browser**: 
**Priority**: High / Medium / Low
```

### Critical Issues (Must Fix Before Launch)
- [ ] App crashes
- [ ] Can't login/signup
- [ ] Data loss
- [ ] Security vulnerabilities
- [ ] Payment issues (if applicable)

### Major Issues (Should Fix Before Launch)
- [ ] Features not working
- [ ] Significant UI problems
- [ ] Performance issues
- [ ] Inconsistent behavior

### Minor Issues (Can Fix After Launch)
- [ ] Minor UI glitches
- [ ] Typos
- [ ] Small UX improvements
- [ ] Non-critical bugs

---

## 📱 Device Testing (Next Phase)

### Android Devices to Test
Once you have an Android device or emulator:

1. **Install APK**:
   ```powershell
   # Build release APK
   flutter build apk --release
   
   # Install on device
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

2. **Test on Real Devices**:
   - [ ] Low-end device (< 2GB RAM)
   - [ ] Mid-range device (4GB RAM)
   - [ ] High-end device (8GB+ RAM)
   - [ ] Different Android versions (8, 10, 12, 13)

3. **Physical Device Tests**:
   - [ ] Camera (if used)
   - [ ] Notifications (when phone is locked)
   - [ ] Background app behavior
   - [ ] Battery usage
   - [ ] Data usage

---

## ✅ Testing Completion Checklist

Before submitting to Play Store:

- [ ] All automated tests pass (3/3 ✅)
- [ ] Manual testing completed
- [ ] No critical or major bugs
- [ ] Tested on at least 2 devices
- [ ] Performance is acceptable
- [ ] App works offline gracefully
- [ ] All features work as expected
- [ ] UI is polished
- [ ] Notifications work
- [ ] Deep links work (if applicable)

---

## 🔄 Current Session

**App Running**: Yes (Chrome)  
**URL**: http://localhost:56497  
**PID**: 3288

### Quick Commands
```powershell
# View app logs
# (Use GitHub Copilot to check logs)

# Stop app
# (Close browser or stop process)

# Restart app
flutter run -d chrome

# Hot reload (during development)
# Press 'r' in terminal
```

---

## 📞 Getting Help

If you encounter issues during testing:

1. **Check logs** - Ask GitHub Copilot to check app logs
2. **Hot reload** - Try hot reloading to apply fixes
3. **Restart app** - Sometimes a fresh start helps
4. **Check Firebase** - Verify Firebase connection
5. **Review docs** - Check PROJECT_OVERVIEW.md for features

---

## Next Steps After Testing

1. ✅ Complete manual testing
2. Fix any critical/major bugs found
3. Prepare Play Store materials (graphics, descriptions)
4. Build final release APK
5. Submit to Google Play Console

**Ready to test?** Open http://localhost:56497 in your browser and start going through the checklist!
