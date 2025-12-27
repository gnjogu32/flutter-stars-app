# Android Testing & Deployment: Quick Start Guide

## What's Been Created For You

I've created a complete Android testing and deployment system for your Starpage app. Here's what you now have:

### 📚 Documentation Files

1. **[ANDROID_TESTING_DEPLOYMENT.md](ANDROID_TESTING_DEPLOYMENT.md)** - Complete guide covering:
   - Unit, widget, and integration testing setup
   - Pre-deployment testing checklist
   - Release keystore configuration
   - Build automation
   - Google Play Store publishing
   - Troubleshooting guide

2. **[KEYSTORE_SETUP_GUIDE.md](KEYSTORE_SETUP_GUIDE.md)** - Step-by-step guide for:
   - Generating release keystore
   - Setting permanent environment variables
   - Securing your keystore
   - Troubleshooting signing issues
   - Certificate export for Firebase

3. **[TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)** - Comprehensive checklist for:
   - 15 phases of testing
   - Device compatibility matrix
   - Feature-by-feature validation
   - Security verification
   - Performance testing
   - Network condition testing

### 🛠️ Automation Scripts

Located in `scripts/` folder:

```powershell
# Build release APK (for direct distribution)
.\scripts\build-apk.ps1 -VersionName "1.0.0" -VersionCode 1

# Build App Bundle (required for Google Play)
.\scripts\build-appbundle.ps1 -VersionName "1.0.0" -VersionCode 1

# Run all tests with optional coverage
.\scripts\run-tests.ps1
.\scripts\run-tests.ps1 -CoverageReport $true

# Interactive deployment checklist
.\scripts\deployment-checklist.ps1
```

---

## 🚀 Getting Started (5 Steps)

### Step 1: Generate Release Keystore

```powershell
# Open PowerShell in your project root
cd c:\Users\user\Documents\flutter_application_stars\flutter_stars_app

# Generate keystore - SAVE THE PASSWORDS!
keytool -genkey -v -keystore android/starpage-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage
```

You'll be prompted for passwords. Write them down and keep them safe!

### Step 2: Configure Signing

Set environment variables (permanent):
1. Press `Win + R`
2. Type `sysdm.cpl`
3. Click "Environment Variables"
4. Add these user variables:
   - `KEYSTORE_PASSWORD` = your_keystore_password
   - `KEY_PASSWORD` = your_key_password
5. Restart PowerShell

Or temporarily in PowerShell:
```powershell
$env:KEYSTORE_PASSWORD = "your_password"
$env:KEY_PASSWORD = "your_password"
```

### Step 3: Update build.gradle.kts

File: `android/app/build.gradle.kts`

Uncomment the release signing config:
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

### Step 4: Run Tests

```powershell
# Run all tests
flutter test

# Or use the automated script
.\scripts\run-tests.ps1
```

### Step 5: Build & Test Release APK

```powershell
# Build release APK
.\scripts\build-apk.ps1 -VersionName "1.0.0" -VersionCode 1

# Install on connected device
adb install build/app/outputs/flutter-release.apk

# Test thoroughly using TESTING_CHECKLIST.md
```

---

## 📋 Testing Workflow

### Local Testing
```powershell
# 1. Run unit tests
flutter test

# 2. Build debug version
flutter run --debug

# 3. Test on device (manual testing)

# 4. Build release version
flutter build apk --release

# 5. Test release on device
adb install build/app/outputs/flutter-release.apk
flutter run --release
```

### Pre-Deployment Checklist
Use the interactive checklist:
```powershell
.\scripts\deployment-checklist.ps1
```

Or manually go through [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md):
- Phase 1: Local Build & Setup
- Phase 2: Unit & Widget Tests
- Phase 3: Device Testing
- Phase 4-15: Feature testing, performance, security, etc.

---

## 🎯 Build for Production

### For Direct Distribution (APK)
```powershell
# Set environment variables
$env:KEYSTORE_PASSWORD = "your_password"
$env:KEY_PASSWORD = "your_password"

# Build
.\scripts\build-apk.ps1 -VersionName "1.0.1" -VersionCode 2

# Output: build/app/outputs/flutter-release.apk
```

### For Google Play Store (App Bundle)
```powershell
# Set environment variables
$env:KEYSTORE_PASSWORD = "your_password"
$env:KEY_PASSWORD = "your_password"

# Build
.\scripts\build-appbundle.ps1 -VersionName "1.0.1" -VersionCode 2

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Upload to Google Play
1. Go to https://play.google.com/console
2. Create new app: "Starpage"
3. Upload the `.aab` file
4. Add screenshots, description, icon
5. Submit for review

Full details: [ANDROID_TESTING_DEPLOYMENT.md](ANDROID_TESTING_DEPLOYMENT.md#part-4-publishing-to-google-play)

---

## 🔐 Security Checklist

### Keystore Security
- [ ] Keystore stored in `android/` (not committed to git)
- [ ] Passwords stored securely (not in code)
- [ ] Environment variables used for signing
- [ ] Backup of keystore created and stored safely
- [ ] `.gitignore` includes `*.jks` and `*.keystore`

### App Security
- [ ] No debug logs in release build
- [ ] No hardcoded API keys
- [ ] ProGuard obfuscation enabled
- [ ] Firebase security rules reviewed
- [ ] Sensitive data not logged

### Before Publishing
- [ ] Privacy policy URL ready
- [ ] Permissions reviewed and explained
- [ ] Firebase production database ready
- [ ] Storage rules configured
- [ ] User data handling compliant

---

## 📊 Version Management

Current version: **1.0.0+1**

Format: `version_number+build_number`

To update for new releases:
```yaml
# In pubspec.yaml
version: 1.0.1+2  # patch version, new build
version: 1.1.0+3  # minor version, new feature
version: 2.0.0+4  # major version, breaking changes
```

Update using scripts:
```powershell
.\scripts\build-appbundle.ps1 -VersionName "1.0.1" -VersionCode 2
```

---

## 🐛 Troubleshooting

### Build Fails
```powershell
# Clean and retry
flutter clean
flutter pub get
flutter build apk --release
```

### Keystore Issues
```powershell
# Check keystore exists
Test-Path android/starpage-keystore.jks

# Check environment variables
$env:KEYSTORE_PASSWORD
$env:KEY_PASSWORD

# Verify signing
keytool -list -v -keystore android/starpage-keystore.jks -alias starpage
```

### Large APK Size
- Ensure `minifyEnabled = true` in build.gradle
- Ensure `shrinkResources = true`
- Verify no unused dependencies

### App Crashes on Release Build
- Add keep rules to `android/app/proguard-rules.pro`
- Check ProGuard configuration

More troubleshooting: [ANDROID_TESTING_DEPLOYMENT.md](ANDROID_TESTING_DEPLOYMENT.md#part-6-troubleshooting)

---

## 📚 Documentation Index

| Document | Purpose |
|---|---|
| [ANDROID_TESTING_DEPLOYMENT.md](ANDROID_TESTING_DEPLOYMENT.md) | Complete testing & deployment guide |
| [KEYSTORE_SETUP_GUIDE.md](KEYSTORE_SETUP_GUIDE.md) | Keystore generation & security |
| [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md) | Pre-deployment test phases |
| [ANDROID_DEPLOYMENT.md](ANDROID_DEPLOYMENT.md) | Android deployment overview (existing) |
| [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | Project structure & features |

---

## 🎓 Common Tasks

### Run Tests
```powershell
flutter test                           # All tests
flutter test test/widget_test.dart     # Specific file
flutter test --coverage                # With coverage
```

### Build APK
```powershell
flutter build apk --release
flutter build apk --release --target-platform=android-arm64
```

### Build App Bundle
```powershell
flutter build appbundle --release
```

### Install & Run
```powershell
adb devices                                          # List devices
adb install build/app/outputs/flutter-release.apk  # Install APK
flutter run --release                              # Run release
adb uninstall com.starpage.app                      # Uninstall
```

### View Logs
```powershell
adb logcat                               # All logs
adb logcat | Select-String "starpage"   # App logs only
adb logcat | Select-String "Error"      # Errors only
```

---

## ✅ Pre-Release Checklist

Before submitting to Google Play:

```
Testing
─────────────────────────────────
☐ All unit tests pass
☐ All widget tests pass  
☐ Device testing complete (2+ devices)
☐ Performance acceptable
☐ No crashes found

Security
─────────────────────────────────
☐ No debug logs in release
☐ No hardcoded API keys
☐ Keystore properly secured
☐ Firebase rules reviewed
☐ ProGuard obfuscation works

Build
─────────────────────────────────
☐ Release APK builds successfully
☐ App Bundle builds successfully
☐ APK size acceptable (<100MB)
☐ Signing verified
☐ Version bumped

Content
─────────────────────────────────
☐ Screenshots prepared (5-8)
☐ App icon ready (512x512)
☐ Feature graphic ready (1024x500)
☐ Description written (max 4000 chars)
☐ Privacy policy URL ready
☐ Release notes prepared

Deployment
─────────────────────────────────
☐ Keystore backup created
☐ Passwords securely stored
☐ Google Play account ready
☐ Team approval obtained
☐ Go/no-go decision made
```

---

## 📞 Next Steps

1. ✓ Read [KEYSTORE_SETUP_GUIDE.md](KEYSTORE_SETUP_GUIDE.md) - Set up signing
2. ✓ Run tests: `flutter test`
3. ✓ Build APK: `.\scripts\build-apk.ps1`
4. ✓ Test on device using [TESTING_CHECKLIST.md](TESTING_CHECKLIST.md)
5. ✓ Build App Bundle: `.\scripts\build-appbundle.ps1`
6. ✓ Upload to Google Play Console
7. ✓ Monitor release and user feedback

---

## 🎉 You're Ready!

You now have everything needed to:
- ✓ Test your app thoroughly
- ✓ Build for production
- ✓ Sign releases securely
- ✓ Deploy to Google Play Store
- ✓ Maintain version history
- ✓ Troubleshoot issues

Happy deploying! 🚀

---

**Created:** December 2025  
**For:** Starpage Android Application  
**Version:** 1.0.0+1
