# Starpage Android Deployment Guide

## Overview
Your Starpage app is now configured for Android deployment with production-ready settings.

## What's Been Configured

### ✅ Package Name
- **Old:** `com.example.flutter_stars_app`
- **New:** `org.starpage.app`
- Unique identifier for your app on Google Play

### ✅ App Name
- Display name changed to "Starpage" (visible to users)

### ✅ Permissions Added
The following permissions have been configured for the app functionality:
- `INTERNET` - Firebase communication
- `ACCESS_NETWORK_STATE` - Network status check
- `CAMERA` - User photo/video capture
- `READ_MEDIA_IMAGES` - Access user photos (Android 13+)
- `READ_MEDIA_VIDEO` - Access user videos (Android 13+)
- `READ_EXTERNAL_STORAGE` - Fallback for older Android versions
- `WRITE_EXTERNAL_STORAGE` - Media storage access

### ✅ Signing Configuration
- Release build signing config created
- ProGuard code obfuscation enabled
- Resource shrinking enabled for smaller APK size

### ✅ Build Optimization
- MinifyEnabled: Reduces APK size
- ShrinkResources: Removes unused resources
- ProGuard: Obfuscates code for security

---

## Next Steps: Generate Release Keystore

### Step 1: Generate Keystore File
Open PowerShell and run:

```powershell
keytool -genkey -v -keystore starpage-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage
```

You'll be prompted to enter:
- Keystore password (save this!)
- Key password (can be same as keystore)
- First name, last name, org, etc.

### Step 2: Store Keystore Securely
Move the generated `starpage-keystore.jks` to: `android/`
```
flutter_stars_app/
├── android/
│   └── starpage-keystore.jks  ← Place keystore here
├── android/app/
└── ...
```

### Step 3: Configure Signing in build.gradle.kts

Uncomment and update this section in `android/app/build.gradle.kts`:

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

### Step 4: Set Environment Variables

**Option A: PowerShell (Temporary)**
```powershell
$env:KEYSTORE_PASSWORD = "your_keystore_password"
$env:KEY_PASSWORD = "your_key_password"
```

**Option B: Create global environment variables**
1. Open System Properties → Environment Variables
2. Add `KEYSTORE_PASSWORD` and `KEY_PASSWORD`
3. Restart PowerShell

---

## Build Release APK

### Option 1: Build APK (for manual distribution)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-release.apk`

### Option 2: Build App Bundle (for Google Play)
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

---

## Upload to Google Play

### Prerequisites
1. Google Play Developer Account ($25 one-time fee)
2. App signing certificate (already configured)
3. Google Play Console access

### Steps
1. Go to [Google Play Console](https://play.google.com/console)
2. Create a new app
3. Fill in app details:
   - App name: Starpage
   - Default language: English
   - App category: Social
4. Upload App Bundle (`app-release.aab`)
5. Add screenshots, description, and icon
6. Review content rating
7. Set pricing (free or paid)
8. Submit for review

---

## Important Security Notes

⚠️ **CRITICAL: Protect Your Keystore**
- **Never** commit `starpage-keystore.jks` to git
- **Never** share your keystore password
- **Backup** your keystore securely
- **Loss** of keystore means you cannot update your app

### .gitignore Update
Your .gitignore should include:
```
# Keystore
*.jks
*.keystore
android/*.jks
android/*.keystore
```

---

## Version Updates

Current configuration:
- Version Code: Managed by Flutter (from pubspec.yaml)
- Version Name: Managed by Flutter (from pubspec.yaml)

To update versions, modify `pubspec.yaml`:
```yaml
version: 1.0.0+1
# Format: version_number+build_number
```

---

## Testing Before Deployment

### Test Release Build Locally
```bash
# Run on physical device
flutter run --release

# Or test the APK
flutter install build/app/outputs/flutter-release.apk
```

### Checklist
- [ ] All features work in release mode
- [ ] No debug logging visible
- [ ] Firebase is configured for production
- [ ] App icon appears correctly
- [ ] App name displays as "Starpage"
- [ ] All permissions work correctly
- [ ] No crashes on different devices

---

## Troubleshooting

### Issue: "Signing config not found"
**Solution:** Make sure keystore file path is correct and file exists

### Issue: "Keystore password incorrect"
**Solution:** Check environment variables are set correctly

### Issue: "App crashes on release build"
**Solution:** Check ProGuard rules - you may need to add more keep rules

### Issue: Large APK size
**Solution:** Ensure minifyEnabled and shrinkResources are true

---

## Support Files Generated

1. `android/app/build.gradle.kts` - Updated with signing and optimization
2. `android/app/src/main/AndroidManifest.xml` - Updated permissions and app name
3. `android/app/proguard-rules.pro` - Code obfuscation rules

---

## Next: iOS Deployment
When ready, similar steps for iOS deployment:
1. Update bundle ID
2. Configure signing certificates
3. Build and upload to App Store

Would you like help with iOS deployment next?
