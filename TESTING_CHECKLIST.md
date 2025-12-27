# Pre-Deployment Testing Checklist

## Quick Start

Use the interactive checklist script:
```powershell
.\scripts\deployment-checklist.ps1
```

Or follow this manual checklist.

---

## ✓ PHASE 1: Local Build & Setup

### Prerequisites
- [ ] Flutter SDK installed and updated
- [ ] Android SDK installed (API 21+)
- [ ] Device connected via USB or Android emulator running
- [ ] Keystore generated and placed at `android/starpage-keystore.jks`
- [ ] Environment variables `KEYSTORE_PASSWORD` and `KEY_PASSWORD` set

### Build Verification
```powershell
# Test debug build
flutter run --debug

# Test release build
flutter build apk --release

# Verify APK was created
Test-Path build/app/outputs/flutter-release.apk
```

- [ ] Debug build completes without errors
- [ ] Release build completes without errors
- [ ] APK file created at expected location

---

## ✓ PHASE 2: Unit & Widget Tests

### Run Tests
```powershell
# Run all tests
.\scripts\run-tests.ps1

# Run with coverage
.\scripts\run-tests.ps1 -CoverageReport $true
```

### Test Requirements
- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] Test coverage above 70%
- [ ] No test warnings or errors

### Test Scope
Test coverage should include:
- [ ] UserModel validation
- [ ] PostModel serialization/deserialization
- [ ] Firebase service methods
- [ ] UI widget interactions
- [ ] Navigation flows
- [ ] State management logic

---

## ✓ PHASE 3: Device Testing

### Device Setup
```powershell
# List available devices
adb devices

# Launch emulator (if needed)
flutter emulators --launch Pixel_3_API_30

# Install release APK
adb install build/app/outputs/flutter-release.apk
```

### Test on Multiple Devices
- [ ] Test on at least 2 physical Android devices
- [ ] Test on Android emulator (API 21+)
- [ ] Test on emulator with API 30+
- [ ] Test on phone screen size (5-6 inches)
- [ ] Test on tablet screen size (7+ inches)

### Device Compatibility Matrix

| Characteristic | Test Devices |
|---|---|
| Android Version | 8.0, 10, 12, 13, 14 |
| Screen Size | Phone (5-6"), Tablet (10") |
| RAM | 2GB, 4GB, 8GB |
| Storage | Full device, Low storage |
| CPU | ARM32, ARM64 |

---

## ✓ PHASE 4: Authentication Testing

### Sign Up Flow
```
1. Launch app
2. Tap "Sign Up"
3. Enter email: test@example.com
4. Enter password: TestPassword123!
5. Confirm password: TestPassword123!
6. Tap "Create Account"
```

- [ ] Form validates email format
- [ ] Form validates password requirements
- [ ] Firebase creates user account
- [ ] User logged in after signup
- [ ] App navigates to home screen
- [ ] User data saved in Firestore

### Login Flow
```
1. Logout current user
2. Tap "Log In"
3. Enter registered email
4. Enter correct password
5. Tap "Log In"
```

- [ ] Login succeeds with correct credentials
- [ ] Error shown with wrong password
- [ ] Firebase session created
- [ ] App navigates to home screen
- [ ] User profile loads correctly

### Password Reset Flow
```
1. On login screen, tap "Forgot Password"
2. Enter registered email
3. Tap "Send Reset Link"
4. Check email for reset link
5. Click link and set new password
6. Login with new password
```

- [ ] Reset email sent successfully
- [ ] Reset link works correctly
- [ ] Password updated in Firebase
- [ ] Can login with new password
- [ ] Old password no longer works

### Session Persistence
```
1. Login with valid credentials
2. Close app completely
3. Reopen app
```

- [ ] User remains logged in
- [ ] No additional login required
- [ ] User data loads correctly
- [ ] Firebase token refreshed if needed

### Logout
```
1. Tap user profile
2. Tap "Logout"
```

- [ ] Firebase session cleared
- [ ] User returned to login screen
- [ ] No cached user data visible
- [ ] App ready for new user login

---

## ✓ PHASE 5: UI & Navigation Testing

### App Launch
```
1. Fresh install or clear app data
2. Launch app
```

- [ ] App launches within 3 seconds
- [ ] No splash screen crashes
- [ ] App name displays as "Starpage"
- [ ] App icon displays correctly
- [ ] Intro/onboarding screens show (if applicable)
- [ ] No console errors visible

### Navigation
```
1. Navigate through all screens
2. Use back button throughout
3. Test all navigation methods
```

- [ ] All screens accessible
- [ ] Navigation responsive
- [ ] Back button works correctly
- [ ] No navigation loops
- [ ] State preserved during navigation
- [ ] Deep links work (if implemented)

### Screen-Specific Tests

#### Home/Discover Screen
- [ ] Feed loads correctly
- [ ] Posts display with images/videos
- [ ] Like button works
- [ ] Comment button opens comment modal
- [ ] Share button functions
- [ ] Infinite scroll loads more posts
- [ ] Pull-to-refresh works

#### Create Post Screen
- [ ] Camera button opens camera
- [ ] Gallery button opens photo picker
- [ ] Image/video preview displays
- [ ] Text input works
- [ ] Submit button creates post
- [ ] Success message shows
- [ ] New post appears in feed

#### Chat Screen
- [ ] Conversation list loads
- [ ] Message sending works
- [ ] Messages display in correct order
- [ ] Real-time updates work
- [ ] Typing indicator shows
- [ ] Message notifications work

#### User Profile
- [ ] User info displays
- [ ] Profile image shows
- [ ] Edit button works
- [ ] Follow/unfollow works
- [ ] User posts display
- [ ] Statistics update

---

## ✓ PHASE 6: Performance Testing

### App Responsiveness
- [ ] All button taps respond within 100ms
- [ ] Text input feels responsive
- [ ] Scrolling is smooth (60 FPS)
- [ ] Animations are smooth
- [ ] No lag when typing

### Memory Usage
```powershell
# Monitor memory via logcat
adb logcat | Select-String "starpage"
```

- [ ] App starts with <100MB RAM
- [ ] Memory usage stable over time
- [ ] No memory leaks on navigation
- [ ] No OOM errors

### Battery Impact
- [ ] No excessive battery drain
- [ ] No background processes spinning
- [ ] Location services not running unnecessarily
- [ ] Camera/sensors disabled when not needed

### Network Performance
Test on various connections:
- [ ] WiFi (fast): Content loads immediately
- [ ] 4G/LTE: Content loads within 2-3 seconds
- [ ] Poor network: Graceful degradation
- [ ] Offline: Appropriate error messages

---

## ✓ PHASE 7: Permissions Testing

### Camera Permission
```
1. Go to Create Post
2. Tap Camera button
3. When prompted, tap "Allow"
```

- [ ] Permission dialog appears
- [ ] Camera opens after approval
- [ ] Photos/videos captured correctly
- [ ] Permission persists after grant

### Gallery/Photos Permission
```
1. Go to Create Post
2. Tap Gallery button
3. When prompted, tap "Allow"
```

- [ ] Permission dialog appears
- [ ] Gallery/file picker opens
- [ ] Photos/videos selected correctly
- [ ] Multiple selection works

### Storage Permission
- [ ] Files can be saved to device storage
- [ ] Files can be read from storage
- [ ] Works on Android 6.0+ (runtime permissions)
- [ ] Works on Android 5.0 (manifest permissions)

### Denying Permissions
```
1. Try to access feature requiring permission
2. When prompted, tap "Deny"
```

- [ ] App doesn't crash
- [ ] Appropriate error message shown
- [ ] User can try again
- [ ] Permission can be granted later in Settings

### Re-requesting Permissions
```
1. Deny a permission
2. Try same feature again
3. See "Don't ask again" option
4. Tap permission request
```

- [ ] Re-request dialog appears
- [ ] "Don't ask again" option visible
- [ ] Users can grant from app settings
- [ ] App settings link works

---

## ✓ PHASE 8: Firebase Integration

### Authentication
- [ ] User creation in Firebase Auth
- [ ] Email verification (if enabled)
- [ ] Password reset works
- [ ] Session token refreshes
- [ ] Logout clears session

### Firestore
- [ ] Posts collection creates documents
- [ ] User profiles save correctly
- [ ] Conversations collection works
- [ ] Messages save with timestamps
- [ ] Real-time listeners work
- [ ] Offline mode degrades gracefully

### Cloud Storage
- [ ] Image uploads to Cloud Storage
- [ ] Download URLs generated
- [ ] Thumbnail generation works
- [ ] Large file uploads work
- [ ] Upload progress shows
- [ ] Delete removes files

### Real-time Updates
```
1. Open message thread on two devices
2. Send message from one device
3. Check other device receives it
```

- [ ] Messages appear in real-time
- [ ] Like counts update live
- [ ] Comment counts update live
- [ ] Online status updates

---

## ✓ PHASE 9: Data & Security

### Sensitive Data
```powershell
# Check logs for sensitive data
adb logcat | Select-String "password|email|token|key"
```

- [ ] No passwords in logs
- [ ] No API keys in logs
- [ ] No user tokens in logs
- [ ] No Firebase URLs exposed
- [ ] ProGuard obfuscation works

### Firebase Security Rules
- [ ] Users can only modify their own data
- [ ] Private messages are private
- [ ] Profile updates authenticated
- [ ] Storage files require authentication
- [ ] Security rules tested

### App Size
```powershell
# Check APK size
(Get-Item build/app/outputs/flutter-release.apk).Length / 1MB
```

- [ ] APK size under 100MB
- [ ] Minification enabled (ProGuard)
- [ ] Resource shrinking enabled
- [ ] Unused dependencies removed

---

## ✓ PHASE 10: Network Conditions

### Good Network (WiFi)
- [ ] All features work smoothly
- [ ] Content loads quickly
- [ ] Large uploads succeed
- [ ] Real-time features responsive

### Poor Network (Throttled)
Use Android DevTools to throttle network:
```powershell
# Via logcat monitor
adb shell setprop net.change 1
```

- [ ] App doesn't crash
- [ ] Loading indicators show
- [ ] Timeout handling works
- [ ] Errors displayed appropriately
- [ ] Retry functionality works

### Network Loss
```
1. Disable WiFi/Mobile data
2. Try using app features
3. Re-enable network
```

- [ ] App shows "offline" indicator
- [ ] Features gracefully disabled
- [ ] Sync works when reconnected
- [ ] No data loss
- [ ] No app crashes

### Slow Network
- [ ] Loading spinners appear
- [ ] Timeout set appropriately (5-10s)
- [ ] Users can cancel slow operations
- [ ] Error handling for failed requests

---

## ✓ PHASE 11: Edge Cases & Error Handling

### Text Input
- [ ] Very long text fields handled
- [ ] Special characters supported
- [ ] Emoji support works
- [ ] Copy/paste works
- [ ] Text selection works

### Image/Video Handling
- [ ] Large images (10MB+) handled
- [ ] Multiple images selectable
- [ ] Video preview works
- [ ] Memory doesn't leak with many images
- [ ] Corrupted files handled gracefully

### Account Edge Cases
```
1. Try signup with existing email
2. Try login with non-existent account
3. Try password reset with unregistered email
```

- [ ] Appropriate error messages
- [ ] No app crashes
- [ ] User can recover

### Force Stop & Restart
```
1. Open app
2. Go to Settings → Apps → Starpage
3. Tap "Force Stop"
4. Reopen app
```

- [ ] App restarts cleanly
- [ ] User still logged in
- [ ] No corrupted data
- [ ] Cache cleared appropriately

### Low Storage
```
1. Fill device storage to 90%
2. Try creating/uploading content
```

- [ ] Appropriate error message
- [ ] App doesn't crash
- [ ] Graceful degradation

---

## ✓ PHASE 12: Localization (if applicable)

- [ ] All UI text translated
- [ ] Date/time formats correct
- [ ] Number formats correct
- [ ] RTL languages supported (if needed)
- [ ] Emoji display correctly

---

## ✓ PHASE 13: Release Build Specific

### Debug Artifacts
```powershell
# Verify no debug symbols
adb shell am dump-heap com.starpage.app /data/app_heap.dump
```

- [ ] No debug logs in console
- [ ] No debug UI elements visible
- [ ] No "Debug" label in app
- [ ] No development features exposed

### ProGuard Configuration
- [ ] Code obfuscated in release
- [ ] App crashes provide meaningful stack traces
- [ ] Performance optimal
- [ ] Feature parity with debug build

### Signing Verification
```powershell
# Verify APK is signed
keytool -printcert -jarfile build/app/outputs/flutter-release.apk
```

- [ ] APK properly signed
- [ ] Correct certificate used
- [ ] Signature valid

---

## ✓ PHASE 14: Version Management

### Version Bumping
- [ ] Version name updated in pubspec.yaml
- [ ] Version code incremented
- [ ] Build number matches version code
- [ ] Release notes prepared
- [ ] Changelog updated

### Current Version Information
```
Version: 1.0.0+1
Format: major.minor.patch+buildNumber
```

To bump version:
```yaml
# In pubspec.yaml
version: 1.0.1+2  # Increment both
```

---

## ✓ PHASE 15: Final Sign-Off

### Pre-Release Checklist
- [ ] All phases tested and passed
- [ ] No critical bugs found
- [ ] All features working correctly
- [ ] Performance acceptable
- [ ] Security verified
- [ ] Firebase production ready
- [ ] Privacy policy prepared
- [ ] Screenshots prepared for Play Store

### Release Readiness
- [ ] App signed and optimized
- [ ] Release notes prepared
- [ ] Play Store assets ready
- [ ] Team approval obtained
- [ ] Backup of keystore verified

### Go/No-Go Decision
- [ ] **GO:** All checks passed ✓
- [ ] **NO-GO:** Issues found (list below)

Issues found (if any):
```
[ List any issues here ]
[ These must be resolved before release ]
```

---

## Testing Environments

### Test Devices

**Primary:**
- [ ] Pixel 3 (Android 12)
- [ ] Samsung Galaxy A12 (Android 11)

**Secondary:**
- [ ] Tablet (Android 10+)
- [ ] Android emulator (API 30)

### Test Accounts

Create test accounts for:
- [ ] New user signup
- [ ] Existing user login
- [ ] Admin testing (if applicable)
- [ ] User deletion/account closure

### Test Data

Prepare test data:
- [ ] Sample posts (text, image, video)
- [ ] Sample users with profiles
- [ ] Sample conversations
- [ ] Various content types

---

## Quick Reference: Commands

```powershell
# Testing
flutter test
flutter test --coverage

# Building
.\scripts\build-apk.ps1
.\scripts\build-appbundle.ps1

# Device Management
adb devices
adb install build/app/outputs/flutter-release.apk
adb uninstall com.starpage.app

# Debugging
adb logcat | Select-String "starpage"
adb shell dumpsys meminfo com.starpage.app
```

---

## Sign-Off

- **Tester Name:** _________________
- **Date:** _________________
- **Status:** ✓ PASS / ✗ FAIL
- **Notes:** _____________________

---

## Related Documentation

- [ANDROID_TESTING_DEPLOYMENT.md](ANDROID_TESTING_DEPLOYMENT.md) - Complete testing & deployment guide
- [KEYSTORE_SETUP_GUIDE.md](KEYSTORE_SETUP_GUIDE.md) - Keystore generation & signing
- [ANDROID_DEPLOYMENT.md](ANDROID_DEPLOYMENT.md) - Android deployment overview
- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) - Project structure

---

**Last Updated:** December 2025
**Starpage Version:** 1.0.0
