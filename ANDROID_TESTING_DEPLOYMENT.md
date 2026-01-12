# Android Testing & Deployment Complete Guide

## Part 1: Testing Setup

### Unit Tests
Unit tests verify Dart logic without UI or Android dependencies.

#### Create unit test file: `test/services/user_service_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/services/user_service.dart';

void main() {
  group('UserService', () {
    test('validateEmail returns true for valid email', () {
      // Example: implement validation logic test
      expect(true, true);
    });

    test('validatePassword enforces minimum length', () {
      // Test password validation
      expect(true, true);
    });
  });
}
```

#### Create mock service: `test/mocks/firebase_auth_mock.dart`
```dart
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
```

#### Run unit tests
```powershell
flutter test
```

### Widget Tests
Widget tests verify UI components without deploying to a device.

#### Update: `test/widget_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starpage/main.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // Verify app rendered without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('HomePage displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      
      // Add specific widget tests for your pages
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
```

#### Run widget tests
```powershell
flutter test test/widget_test.dart
```

### Integration Tests (Android-specific)
Integration tests run on a real device/emulator and verify full app flow.

#### Create: `test_driver/integration_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:starpage/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Tests', () {
    testWidgets('User can launch app and navigate', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify app launched
      expect(find.byType(MaterialApp), findsOneWidget);

      // Navigate and test key flows
      // Add your navigation and interaction tests here
    });

    testWidgets('Firebase integration works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test Firebase connection
      // Verify auth state, firestore queries, etc.
    });

    testWidgets('Permissions are requested correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify permission request dialogs appear when needed
      // Test camera, photo picker flows
    });
  });
}
```

#### Run integration tests on Android
```powershell
# On connected device
flutter test integration_test/integration_test.dart

# Or with specific device
flutter test integration_test/integration_test.dart --target=integration_test/integration_test.dart
```

#### Add to pubspec.yaml (dev_dependencies)
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  mockito: ^6.1.0
```

### Run All Tests
```powershell
# Run all tests with coverage
flutter test --coverage

# Generate coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
```

---

## Part 2: Pre-Deployment Testing Checklist

### Local Release Build Testing

#### Step 1: Clean Build
```powershell
flutter clean
flutter pub get
```

#### Step 2: Test on Debug Build First
```powershell
flutter run --debug
```
- ✓ App launches without crashes
- ✓ All features responsive
- ✓ Firebase connected
- ✓ All permissions work

#### Step 3: Build and Test Release APK
```powershell
flutter build apk --release
```

#### Step 4: Install Release APK on Device
```powershell
# Find your device
adb devices

# Install APK
adb install build/app/outputs/flutter-release.apk

# Or let Flutter handle it
flutter install build/app/outputs/flutter-release.apk
```

#### Step 5: Test Release Build
```powershell
flutter run --release
```

### Comprehensive Testing Checklist

Create: `TESTING_CHECKLIST.md`

```markdown
## Pre-Release Testing Checklist

### Authentication
- [ ] Sign up with email
- [ ] Login with existing account
- [ ] Password reset flow works
- [ ] Auto-login persists after app restart
- [ ] Logout clears all data

### UI & Performance
- [ ] All screens load without crashes
- [ ] No debug console logs visible
- [ ] UI responsive on different screen sizes
- [ ] Animations smooth
- [ ] No ANR (Application Not Responding) errors
- [ ] App size reasonable

### Firebase Integration
- [ ] Firestore queries work
- [ ] Cloud Storage uploads/downloads work
- [ ] Firebase Auth mutations succeed
- [ ] Offline mode degrades gracefully
- [ ] Real-time updates work

### Permissions (Android)
- [ ] Camera permission request works
- [ ] Photo gallery access works
- [ ] Storage permission handling correct
- [ ] Denied permissions handled gracefully
- [ ] Re-request after denial works

### Device Compatibility
- [ ] Test on Android 8.0+ (minSdk requirement)
- [ ] Test on at least 2 physical devices
- [ ] Test on Android emulator (different API levels)
- [ ] Test with different screen sizes
- [ ] Test with different languages/locales

### Network Conditions
- [ ] Test on 4G/LTE
- [ ] Test on WiFi
- [ ] Test with poor network (throttling)
- [ ] Test offline behavior
- [ ] Network error handling works

### Data & Security
- [ ] No sensitive data in logs
- [ ] Firebase rules enforce security
- [ ] Keystore properly configured
- [ ] No hardcoded API keys visible
- [ ] ProGuard obfuscation works

### Edge Cases
- [ ] Very long text fields handled
- [ ] Large image uploads work
- [ ] Force stop and restart works
- [ ] Multi-language support works
- [ ] First-time user experience is smooth
```

---

## Part 3: Building for Production

### Generate Release Keystore (if not done)

```powershell
# Generate keystore - SAVE THE PASSWORDS
keytool -genkey -v -keystore starpage-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage

# You'll be prompted for:
# - Keystore password (e.g., StarPage@2024)
# - Key password (can be same as keystore)
# - First Name, Last Name, Organization, etc.
```

Save keystore to: `android/starpage-keystore.jks`

### Configure Environment Variables

**Windows PowerShell**
```powershell
# Set temporarily (session only)
$env:KEYSTORE_PASSWORD = "your_keystore_password"
$env:KEY_PASSWORD = "your_key_password"

# Or set permanently:
# 1. Press Win+R, type: sysdm.cpl
# 2. Advanced → Environment Variables
# 3. Add KEYSTORE_PASSWORD and KEY_PASSWORD
# 4. Restart terminal
```

### Uncomment Release Signing in build.gradle.kts

File: `android/app/build.gradle.kts`

```kotlin
signingConfigs {
    release {
        storeFile = file("../starpage-keystore.jks")
        storePassword = System.getenv("KEYSTORE_PASSWORD")
        keyAlias = "starpage"
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}
```

### Build APK (Manual Distribution)
```powershell
flutter build apk --release
# Output: build/app/outputs/flutter-release.apk
```

### Build App Bundle (Google Play)
```powershell
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Part 4: Publishing to Google Play

### Prerequisites
1. Google Play Developer Account ($25 one-time)
2. App signing certificate (configured above)
3. Release APK or App Bundle

### Google Play Console Steps
1. Go to https://play.google.com/console
2. Create new app: "Starpage"
3. Fill app details:
   - **Default language:** English
   - **Category:** Social
   - **Contact email:** your_email@example.com
   - **Privacy policy:** your_privacy_policy_url
4. **App on Google Play**
   - All sections must be complete
5. **Create release:**
   - Upload `app-release.aab`
   - Add release notes
   - Review permissions
6. **Content rating questionnaire**
   - Answer all questions
   - Get rating (G, PG, 12+, 16+, 18+)
7. **Pricing & distribution**
   - Set as free
   - Select countries
   - Manage device configurations
8. **App content**
   - Add screenshots (5-8 per language)
   - Add icon (512x512 PNG)
   - Add feature graphic (1024x500 PNG)
   - Add description (max 4000 chars)
   - Add short description (max 80 chars)
9. **Submit for review**
   - Review takes 2-3 hours typically
   - You'll receive approval/rejection email

---

## Part 5: Build Automation Scripts

### Create: `scripts/build-release.ps1`

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$BuildType = "apk", # apk or aab
    
    [Parameter(Mandatory=$false)]
    [string]$VersionName = "1.0.0",
    
    [Parameter(Mandatory=$false)]
    [int]$VersionCode = 1
)

Write-Host "Building Starpage Release Build..." -ForegroundColor Cyan

# Check environment variables
if (-not $env:KEYSTORE_PASSWORD) {
    Write-Host "ERROR: KEYSTORE_PASSWORD not set" -ForegroundColor Red
    exit 1
}

if (-not $env:KEY_PASSWORD) {
    Write-Host "ERROR: KEY_PASSWORD not set" -ForegroundColor Red
    exit 1
}

# Clean
Write-Host "Cleaning project..." -ForegroundColor Yellow
flutter clean
flutter pub get

# Build
if ($BuildType -eq "apk") {
    Write-Host "Building APK..." -ForegroundColor Yellow
    flutter build apk --release --build-name=$VersionName --build-number=$VersionCode
    
    if ($?) {
        Write-Host "✓ APK built successfully!" -ForegroundColor Green
        Write-Host "Location: build/app/outputs/flutter-release.apk"
    }
} elseif ($BuildType -eq "aab") {
    Write-Host "Building App Bundle..." -ForegroundColor Yellow
    flutter build appbundle --release --build-name=$VersionName --build-number=$VersionCode
    
    if ($?) {
        Write-Host "✓ App Bundle built successfully!" -ForegroundColor Green
        Write-Host "Location: build/app/outputs/bundle/release/app-release.aab"
    }
}
```

### Run build script
```powershell
.\scripts\build-release.ps1 -BuildType aab -VersionName "1.0.0" -VersionCode 1
```

---

## Part 6: Troubleshooting

### Issue: "Signing config not found"
```powershell
# Verify keystore exists
Test-Path android/starpage-keystore.jks

# Verify passwords are set
$env:KEYSTORE_PASSWORD
$env:KEY_PASSWORD
```

### Issue: "Keystore password incorrect"
```powershell
# Regenerate keystore if password lost
keytool -genkey -v -keystore starpage-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage
```

### Issue: "App crashes on release build"
Causes:
- ProGuard removing necessary classes
- Missing keep rules in `proguard-rules.pro`

Solution:
```
# Add to android/app/proguard-rules.pro
-keep class org.starpage.** { *; }
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }
```

### Issue: "Large APK size"
```powershell
# Enable optimizations
flutter build apk --release --target-platform=android-arm64
```

### Issue: Device not found
```powershell
# List devices
adb devices

# Restart adb
adb kill-server
adb start-server
```

---

## Part 7: Version Management

Current version: **1.0.0+1**

Format: `version_number+build_number`

To update in `pubspec.yaml`:
```yaml
version: 1.0.1+2  # Increase for updates
```

**Versioning Strategy:**
- `1.0.0` → First release
- `1.0.1` → Bug fix (patch)
- `1.1.0` → New feature (minor)
- `2.0.0` → Major changes (major)

---

## Quick Reference Commands

```powershell
# Testing
flutter test                                    # Run all tests
flutter test --coverage                        # With coverage
flutter test test/widget_test.dart             # Specific test file

# Building
flutter build apk --release                    # Build APK
flutter build appbundle --release             # Build for Play Store
flutter run --release                         # Run release build

# Device Management
adb devices                                    # List devices
adb install build/app/outputs/flutter-release.apk  # Install APK
adb uninstall org.starpage.app                # Uninstall app

# Debugging
adb logcat | Select-String "starpage"         # View app logs
adb shell getprop ro.build.version.release    # Check Android version
```

---

## Security Reminders

⚠️ **CRITICAL**
- Never commit `starpage-keystore.jks` to git
- Never share keystore password
- Backup keystore securely (USB drive, vault)
- Loss of keystore = cannot update app on Play Store
- Keep `KEYSTORE_PASSWORD` and `KEY_PASSWORD` secure

Update `.gitignore`:
```
*.jks
*.keystore
android/*.jks
android/*.keystore
```

---

## Next Steps
1. ✓ Review testing setup above
2. ✓ Create unit/widget tests for your features
3. ✓ Generate release keystore
4. ✓ Run through testing checklist
5. ✓ Build APK and test on device
6. ✓ Build App Bundle for Play Store
7. ✓ Submit to Google Play Console
