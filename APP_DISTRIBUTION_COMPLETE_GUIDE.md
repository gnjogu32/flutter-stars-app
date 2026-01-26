# Starpage App Distribution - Complete Setup Guide

## 📋 Overview

Your app has **3 distribution channels** fully configured:

| Channel | Purpose | Audience | Frequency |
|---------|---------|----------|-----------|
| **Firebase App Distribution** | Beta testing & QA | Internal testers + beta users | On-demand + tags |
| **Google Play Store** | Production release | General public | Manual releases |
| **Firebase Hosting** | Web version | Web users | CI/CD automated |

---

## 🚀 QUICK START (5 MINUTES)

### To Distribute Your Next Release:

```bash
# 1. Update version in pubspec.yaml
version: 1.0.1+2  # Increment build number

# 2. Commit and tag
git add pubspec.yaml
git commit -m "Release v1.0.1"
git tag v1.0.1 -m "Version 1.0.1"

# 3. Push everything
git push origin main --tags

# ✅ That's it! GitHub Actions will:
#    - Build release APK automatically
#    - Distribute to Firebase App Distribution
#    - Notify your testers
```

---

## 📦 DISTRIBUTION CHANNEL 1: Firebase App Distribution

### Status: ✅ FULLY CONFIGURED

**What it does:**
- Distributes APK builds to testers
- Beta testing before Play Store release
- Tester feedback & crash reporting
- No app store review required

### Setup Checklist

- [x] Firebase App Distribution enabled
- [x] GitHub Actions workflow configured (`.github/workflows/build-and-distribute.yml`)
- [x] Service Account created
- [x] GitHub Secrets configured
- [x] Tester groups ready

### Current Configuration

**GitHub Workflow**: `build-and-distribute.yml`
- **Triggers on**: Tag push (v*), main branch push, manual dispatch
- **Builds**: Debug APK (every push), Release APK (tags only)
- **Distributes**: To Firebase App Distribution when tagged
- **Notifies**: Registered testers via email

**Required GitHub Secrets:**
```
FIREBASE_APP_ID           → 1:246255479274:android:341fbd17995cbd2e862a93
FIREBASE_SERVICE_ACCOUNT  → [Your service account JSON]
FIREBASE_GROUPS           → Alpha Testers,Beta Testers
```

### How to Distribute to Testers

#### Method 1: Automatic (On Version Tag) ⭐ RECOMMENDED
```bash
# Create and push a version tag
git tag v1.0.1 -m "Release version 1.0.1"
git push origin v1.0.1

# ✅ GitHub Actions will automatically:
#    1. Build release APK
#    2. Upload to Firebase App Distribution
#    3. Notify all testers in configured groups
#    4. Testers receive email invite with download link
```

#### Method 2: Manual (Via Firebase Console)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select **starpage-ed409** project
3. **App Distribution** → **Releases**
4. Click **Upload APK**
5. Select your built APK from `build/app/outputs/flutter-apk/app-release.apk`
6. Add release notes
7. Select tester groups
8. Click **Distribute**

#### Method 3: Manual (Via Firebase CLI)
```powershell
# Build release APK
flutter build apk --release

# Upload to Firebase App Distribution
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk `
  --app 1:246255479274:android:341fbd17995cbd2e862a93 `
  --groups "Alpha Testers,Beta Testers" `
  --release-notes "Version 1.0.1: Bug fixes and improvements"
```

### Tester Groups (Already Configured)

**In Firebase Console** → **App Distribution** → **Testers & Groups**:

| Group | Purpose | Email Example |
|-------|---------|---|
| Alpha Testers | Early access, frequent updates | internal@starpage.app |
| Beta Testers | Stable releases | beta@starpage.app |
| QA Team | Internal testing | qa@starpage.app |

**To add testers:**
1. Firebase Console → **Testers & Groups**
2. Select group
3. Click **Add testers**
4. Enter email addresses (comma-separated)
5. Testers receive invite email

---

## 🎮 DISTRIBUTION CHANNEL 2: Google Play Store

### Status: ✅ FULLY CONFIGURED (Ready to Deploy)

**What it does:**
- Distributes app to millions of Android users
- Manages app reviews, ratings, versions
- Tracks installs, crashes, ratings
- Official app store presence

### Prerequisites Checklist

- [x] Google Play Developer Account ($25 fee, already paid)
- [x] Release APK built and signed ✅
- [x] Keystore configured (`android/key.properties`)
- [x] App ID: `org.starpage.app`
- [x] GitHub Actions workflow ready (`.github/workflows/android-deploy-playstore.yml`)

### Current Configuration

**GitHub Workflow**: `android-deploy-playstore.yml`
- **Triggers on**: Manual dispatch (workflow_dispatch) + pubspec.yaml changes on main
- **Builds**: App Bundle (AAB) for Play Store
- **Deploys to**: Google Play internal/alpha/beta/production tracks
- **Requires secrets**: `PLAY_STORE_SERVICE_ACCOUNT`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`

### Google Play Console Setup

#### Step 1: Create App Listing (Already Done)
✅ App created in Google Play Console
- App name: **Starpage**
- Package name: **org.starpage.app**
- App type: **Free**

#### Step 2: Complete Store Listing
1. Go to [Google Play Console](https://play.google.com/console)
2. Select **Starpage** app
3. Click **Store listing** (left menu)

**Fill in:**
- **Short description** (80 chars):
  ```
  Creative social media for talented stars to showcase their work and connect
  ```
- **Full description** (4000 chars):
  ```
  Starpage is a social media platform where creative talents can:
  • Share their work (art, music, writing, dance, photography, etc.)
  • Discover other talented creators
  • Build their creative community
  • Collaborate with other artists
  • Showcase their talent to the world
  ```
- **Screenshots** (2-8 required):
  - Home feed
  - User profile
  - Create post
  - Notifications
  - Discovery/Trending
- **Feature graphic** (1024x500 px)
- **Icon** (512x512 px, must match app icon)
- **Category**: Social (or Art & Design)
- **Content rating**: Fill questionnaire
- **Privacy policy**: Link to your privacy policy

#### Step 3: Complete App Information
1. Click **App information** (left menu)
2. Set:
   - **App access**: Declare if authentication required
   - **Ads**: Yes/No
   - **User-generated content**: Yes (Starpage has comments, posts)
   - **Moderation policy**: Link or describe

#### Step 4: Create Service Account Key for GitHub

1. Go to **Project Settings** (⚙️) → **Service Accounts**
2. Click **Create Service Account** (if not exists)
3. Click **Generate new private key**
4. Select **JSON** format
5. Save file securely
6. Add to GitHub Secret: `PLAY_STORE_SERVICE_ACCOUNT`

#### Step 5: Deploy to Play Store

**Option A: Manual Deployment**
```powershell
# 1. Build App Bundle
flutter build appbundle --release

# 2. Upload via Play Console (Manual)
#    - Go to Google Play Console
#    - Select Starpage app
#    - Click "Create new release"
#    - Upload AAB from: build/app/outputs/bundle/release/app-release.aab
#    - Add release notes
#    - Select track (internal/alpha/beta/production)
#    - Review and submit
```

**Option B: Automatic Deployment (GitHub Actions)**
```bash
# Push to main or use workflow dispatch
git push origin main

# GitHub Actions will automatically:
# 1. Build App Bundle (AAB)
# 2. Upload to Google Play
# 3. Release to selected track

# Or trigger manually:
# - Go to GitHub Actions
# - Select "Android Deploy to Play Store" workflow
# - Click "Run workflow"
# - Select track: internal/alpha/beta/production
```

### Release Tracks Explained

| Track | Audience | Purpose | Time to Rollout |
|-------|----------|---------|-----------------|
| **internal** | Only you | Final QA on real device | Instant |
| **alpha** | Testers (opt-in) | Closed testing | 1-2 days |
| **beta** | Wider testing | Open beta testing | 3-5 days |
| **production** | Everyone | Public release | Instant |

**Recommended Flow:**
```
v1.0.0 (internal) 
  → Test on real device
  → Deploy to alpha
  → Wait for tester feedback
  → Deploy to beta
  → Stability check
  → Release to production
```

### Versioning Strategy

Every release needs version update in `pubspec.yaml`:

```yaml
# pubspec.yaml
version: 1.0.0+1
#       └─ Version code for store
#                    └─ Build number (must increment every release)

# Examples:
version: 1.0.0+1   # First release
version: 1.0.1+2   # Bug fix
version: 1.1.0+3   # Minor feature
version: 2.0.0+4   # Major version
```

---

## 🌐 DISTRIBUTION CHANNEL 3: Firebase Hosting (Web)

### Status: ✅ FULLY CONFIGURED

**What it does:**
- Hosts Flutter web version
- Custom domain support
- Automatic HTTPS/SSL
- CI/CD deployment on every push

### Current Setup

**GitHub Workflow**: `firebase-hosting-deploy.yml`
- **Triggers on**: Push to main branch, manual dispatch
- **Builds**: Flutter web version
- **Deploys to**: Firebase Hosting
- **Automatic**: Every push is live

**Custom Domain**: Ready to configure
- Current: `starpage-ed409.web.app`
- Custom domain available via Firebase Console

### Deploy Web Version

```bash
# Automatic (every push to main)
git push origin main

# Manual (via Firebase CLI)
flutter build web
firebase deploy --only hosting
```

---

## 📊 DEPLOYMENT CHECKLIST

### Before Every Release

- [ ] **Code Quality**
  - [ ] Run tests: `flutter test`
  - [ ] Run analysis: `flutter analyze`
  - [ ] No build errors: `flutter build apk --release`

- [ ] **Update Version**
  - [ ] Increment build number in `pubspec.yaml`
  - [ ] Update version code if features added
  - [ ] Example: `1.0.1+2` → `1.0.2+3`

- [ ] **Test Thoroughly**
  - [ ] Test on Android device
  - [ ] Test all main features
  - [ ] Test login/authentication
  - [ ] Test Firebase Firestore sync
  - [ ] Test profile upload
  - [ ] Test comments/notifications

- [ ] **Prepare Release Notes**
  - [ ] Write clear, user-friendly notes
  - [ ] List bug fixes
  - [ ] List new features
  - [ ] Example:
    ```
    Version 1.0.2 - Released Jan 26, 2026
    
    ✨ New Features
    • Comment system improvements
    • Better follow notifications
    
    🐛 Bug Fixes
    • Fixed profile image upload
    • Fixed notification display
    
    ⚡ Performance
    • Optimized Firestore queries
    ```

### Firebase App Distribution (Beta Testing)

```bash
# 1. Make changes
git add .
git commit -m "Add new feature"

# 2. Create version tag
git tag v1.0.2 -m "Version 1.0.2 - New features"

# 3. Push (GitHub Actions handles the rest)
git push origin main --tags

# ✅ Workflow will:
#    1. Build release APK
#    2. Upload to Firebase App Distribution
#    3. Email your testers
#    4. Create GitHub Release
```

### Google Play Store (Production)

```bash
# 1. Repeat Firebase steps above, or...

# 2. Manual upload
flutter build appbundle --release
# Upload build/app/outputs/bundle/release/app-release.aab to Google Play Console

# 3. Choose track and rollout percentage
# 4. Add release notes
# 5. Submit for review (auto-reviewed for updates)
# 6. Monitor reviews/ratings
```

### Firebase Hosting (Web)

```bash
# Automatic: Just push to main
git push origin main

# Manual
flutter build web
firebase deploy --only hosting
```

---

## 🔐 GitHub Secrets Required

### Firebase App Distribution Secrets

| Secret | Value | Where to Get |
|--------|-------|--------------|
| `FIREBASE_APP_ID` | `1:246255479274:android:341fbd17995cbd2e862a93` | Firebase Console → Your Apps |
| `FIREBASE_SERVICE_ACCOUNT` | JSON from service account key | Firebase Console → Service Accounts |
| `FIREBASE_GROUPS` | `Alpha Testers,Beta Testers` | Firebase Console → Tester Groups |

### Google Play Store Secrets

| Secret | Value | Where to Get |
|--------|-------|--------------|
| `PLAY_STORE_SERVICE_ACCOUNT` | JSON from Play Console | Google Play Console → Service Accounts |
| `ANDROID_KEYSTORE_PASSWORD` | Your keystore password | You created this during keystore setup |
| `ANDROID_KEY_PASSWORD` | Your key password | You created this during keystore setup |

### Firebase Hosting Secrets

| Secret | Value | Where to Get |
|--------|-------|--------------|
| `FIREBASE_TOKEN` | Obtained via `firebase login:ci` | Run command below |

```bash
firebase login:ci
# Browser will open, authenticate
# Copy the generated token
# Add as GitHub Secret: FIREBASE_TOKEN
```

---

## 📈 Analytics & Monitoring

### Firebase App Distribution
1. Go to **App Distribution** → **Releases**
2. View:
   - Installation status
   - Tester feedback
   - Crash reports
   - User activity

### Google Play Console
1. Go to **Dashboard**
2. Monitor:
   - Install count
   - Active users
   - Ratings & reviews
   - Crash & ANR (Application Not Responding)
   - Performance metrics

### Firebase Hosting
1. Go to **Hosting** → **Deployments**
2. View:
   - Deployment history
   - Version comparisons
   - Rollback options

---

## 🐛 Troubleshooting

### APK Build Fails
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release

# Check errors:
flutter analyze
```

### GitHub Actions Fails
1. Check workflow logs: GitHub → Actions → Failed workflow
2. Common issues:
   - Missing secrets (check spelling)
   - Java version mismatch
   - Flutter version incompatible

### Firebase Distribution Upload Fails
```bash
# Verify credentials
firebase login

# Test distribution
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:246255479274:android:341fbd17995cbd2e862a93
```

### Play Store Upload Fails
1. Check version code is unique (newer than previous)
2. Check content rating is set
3. Check release notes are provided
4. Check app signing certificate is correct
5. Verify service account has correct permissions

---

## 📞 Quick Commands Reference

```powershell
# Build commands
flutter build apk --release      # Build release APK
flutter build appbundle --release # Build for Play Store
flutter build web                # Build web version

# Firebase distribution
firebase appdistribution:distribute <path-to-apk> \
  --app <APP_ID> \
  --groups "Alpha Testers"

# Git commands
git tag v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0
git push origin main --tags

# Firebase hosting
firebase deploy --only hosting
flutter build web && firebase deploy --only hosting

# Clean everything
flutter clean
flutter pub get
```

---

## ✅ You're All Set!

Your app has professional distribution channels configured:
- ✅ Firebase App Distribution for testing
- ✅ Google Play Store for production
- ✅ Firebase Hosting for web
- ✅ GitHub Actions for automation
- ✅ CI/CD pipeline ready

**Your next steps:**
1. Add your testers to Firebase App Distribution groups
2. Create your first version tag: `git tag v1.0.0`
3. Push and watch GitHub Actions deploy automatically
4. Monitor feedback from testers
5. When ready, release to Play Store

**Questions?** Check the individual distribution docs:
- [FIREBASE_APP_DISTRIBUTION_SETUP.md](FIREBASE_APP_DISTRIBUTION_SETUP.md)
- [PLAY_STORE_DEPLOYMENT.md](PLAY_STORE_DEPLOYMENT.md)
- [FIREBASE_HOSTING_SETUP.md](FIREBASE_HOSTING_SETUP.md)

---

**Last Updated**: January 26, 2026
**App Version**: 1.0.0
**Firebase Project**: starpage-ed409
**Package Name**: org.starpage.app
