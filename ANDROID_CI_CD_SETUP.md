# Android CI/CD Setup & Deployment Guide

## Overview
Complete CI/CD pipeline for building, testing, and deploying your Flutter Android app to Google Play Store.

## Workflows Created

### 1. **Android Build & Test** ([.github/workflows/android-build.yml](.github/workflows/android-build.yml))
- Builds release APK on every push/PR
- Builds App Bundle for Play Store deployment on main branch
- Runs tests and code analysis
- Uploads artifacts for 30 days
- Monitors APK/Bundle size

### 2. **Android Deploy to Play Store** ([.github/workflows/android-deploy-playstore.yml](.github/workflows/android-deploy-playstore.yml))
- Manual deployment to Google Play Store
- Supports multiple tracks: internal, alpha, beta, production
- Automatically triggered when pubspec.yaml version changes
- Creates GitHub releases with version info
- Requires Play Store service account credentials

### 3. **Android Emulator Tests** ([.github/workflows/android-test.yml](.github/workflows/android-test.yml))
- Runs integration tests on multiple API levels (28, 31, 33)
- Espresso unit tests
- Daily scheduled tests
- Artifact upload for debugging

---

## Setup Instructions

### Step 1: Generate Release Keystore

Open PowerShell and run:

```powershell
# Navigate to android folder
cd android

# Generate keystore (valid for 10 years)
keytool -genkey -v -keystore starpage-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage
```

**You'll be prompted for:**
- Keystore password (remember this!)
- Key password (can be same as keystore)
- Your name, organization, etc.

**Save the keystore file securely** - you'll need it later.

### Step 2: Add GitHub Secrets

Go to your GitHub repository:
**Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

1. **ANDROID_KEYSTORE_PASSWORD**
   - Your keystore password from Step 1

2. **ANDROID_KEY_PASSWORD**
   - Your key password from Step 1

3. **PLAY_STORE_SERVICE_ACCOUNT** (for Play Store deployment)
   - Contents of your Play Store service account JSON file

### Step 3: Configure Signing in build.gradle.kts

Edit [android/app/build.gradle.kts](android/app/build.gradle.kts):

```kotlin
signingConfigs {
    release {
        storeFile = file("../starpage-keystore.jks")
        storePassword = System.getenv("KEYSTORE_PASSWORD")
        keyAlias = "starpage"
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### Step 4: Set Up Google Play Store Service Account

#### A. Create Service Account in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. **APIs & Services → Service Accounts**
4. **Create Service Account**
   - Name: "Github-Play-Store"
   - Role: Basic → Editor
5. **Create Key → JSON**
6. Download the JSON file

#### B. Grant Play Store Permissions

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app (Starpage)
3. **Settings → User and permissions**
4. **Invite user**
   - Email: (from your service account JSON - `client_email` field)
   - Permissions: Admin (all permissions)

#### C. Add Service Account to GitHub

1. Copy entire JSON file contents
2. GitHub → **Settings → Secrets → New secret**
3. Name: `PLAY_STORE_SERVICE_ACCOUNT`
4. Paste JSON content

### Step 5: Create What's New Files (Optional)

For Play Store release notes:

```
whats-new/
├── en-US/
│   └── default.txt
├── es-ES/
│   └── default.txt
└── (other languages)
```

Example content:
```
🎉 New Features
- Feature 1
- Feature 2

🐛 Bug Fixes
- Fixed issue X
- Fixed issue Y

✨ Improvements
- Better performance
```

---

## Build Artifacts

After workflows complete, find artifacts in GitHub Actions:

1. **APK** (`android-apk`)
   - Manual distribution, testing
   - Location: `build/app/outputs/flutter-release.apk`

2. **App Bundle** (`android-app-bundle`)
   - Google Play Store deployment
   - Location: `build/app/outputs/app-release.aab`
   - Smaller size, automatic APK generation per device

---

## Deployment Workflow

### Option 1: Automatic Play Store Deployment
1. Update `pubspec.yaml` version
2. Commit and push to `main` branch
3. Workflow automatically:
   - Builds app bundle
   - Deploys to Play Store (internal track)
   - Creates GitHub release

### Option 2: Manual Play Store Deployment
1. Go to GitHub **Actions → Android Deploy to Play Store**
2. Click **Run workflow**
3. Select track: internal, alpha, beta, or production
4. Workflow builds and deploys
5. Check Google Play Console for status

### Option 3: Manual APK Distribution
1. Trigger "Android Build & Test" workflow
2. Download APK from artifacts
3. Share APK directly for testing

---

## Version Management

### Update Version in pubspec.yaml
```yaml
version: 1.0.0+1
```

- First number: Major version (1.0.0)
- Second number: Minor version (1.0.0)
- Third number: Patch version (1.0.0)
- After `+`: Build number (must increment for each Play Store release)

### Update Version in build.gradle.kts (Auto-synced from pubspec.yaml)
```kotlin
android {
    defaultConfig {
        versionCode = flutter.versionCode        // Auto from pubspec
        versionName = flutter.versionName        // Auto from pubspec
    }
}
```

---

## Testing

### Run Tests Locally

```powershell
# Unit and widget tests
flutter test

# Integration tests
flutter test integration_test/

# Espresso tests (Android-specific)
cd android
./gradlew connectedAndroidTest
```

### In CI/CD

Tests run automatically on:
- Every push to `main`/`develop`
- Every pull request
- Daily scheduled tests (emulator on API 28, 31, 33)

---

## Monitoring & Debugging

### Check Build Status
1. Go to GitHub **Actions** tab
2. Select workflow
3. View build logs in real-time

### View Play Store Deployment
1. [Google Play Console](https://play.google.com/console)
2. Select Starpage app
3. **Releases** section shows:
   - Current versions per track
   - Deployment history
   - User reviews

### Debug Failures

**APK Build Failed:**
- Check Java version is 17+
- Verify signing configuration
- Check keystore password in secrets

**Play Store Upload Failed:**
- Verify service account has correct permissions
- Check app version is higher than current
- Ensure bundle is signed with correct key

**Test Failures:**
- Check Flutter dependencies are up to date
- Review test logs in GitHub Actions
- Run tests locally to reproduce

---

## Best Practices

✅ **Do:**
- Always test locally before pushing
- Use semantic versioning (1.0.0)
- Keep release notes updated
- Monitor Google Play Console reviews
- Test on multiple API levels

❌ **Don't:**
- Commit keystore files to Git
- Reuse same version code
- Deploy without testing
- Share service account keys
- Use debug builds for production

---

## Automation Rules

| Event | Action | Track |
|-------|--------|-------|
| Push to `main` | Build APK + Bundle | - |
| Version update in pubspec.yaml | Auto-deploy | internal |
| Manual workflow dispatch | Build + Deploy | Selected track |
| Pull request | Build + Test | - |
| Daily (3 AM UTC) | Emulator tests | - |

---

## Google Play Store Console Links

- [Starpage App Page](https://play.google.com/console/u/0/developers)
- [Release Management](https://play.google.com/console/u/0/developers) → Starpage → Releases
- [Test Tracks](https://play.google.com/console/u/0/developers) → Internal, Alpha, Beta
- [Analytics](https://play.google.com/console/u/0/developers) → Analytics

---

## Support & Resources

- [Flutter Android Documentation](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Signing Help](https://developer.android.com/studio/publish/app-signing)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

## Troubleshooting Checklist

- [ ] Keystore file created and secured
- [ ] GitHub secrets added (passwords, service account)
- [ ] build.gradle.kts signing config updated
- [ ] Service account has Play Store permissions
- [ ] pubspec.yaml version configured
- [ ] Tests passing locally
- [ ] Firebase configured for app signing

Done! You're ready to deploy Android releases. 🚀
