# CI/CD Pipeline Setup Guide

## Overview
This project includes automated CI/CD pipelines for building and distributing Flutter apps using both GitHub Actions and Google Cloud Build.

## GitHub Actions Workflow

### What It Does
- **On Push to main**: Builds APK, runs tests, runs code analysis
- **On Tag (v*)**: Builds release APK and distributes via Firebase App Distribution
- **Manual Trigger**: Via workflow_dispatch

### Setup Instructions

#### 1. Required GitHub Secrets
Add these secrets to your repository (Settings > Secrets and variables > Actions):

```
FIREBASE_APP_ID              # Found in Firebase Console
FIREBASE_SERVICE_ACCOUNT     # Service account JSON (see below)
FIREBASE_TESTERS             # Comma-separated tester emails
FIREBASE_GROUPS              # Firebase tester groups (optional)
```

#### 2. Get Firebase Service Account
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Project Settings > Service Accounts
4. Click "Generate new private key"
5. Copy the entire JSON content
6. Add as `FIREBASE_SERVICE_ACCOUNT` secret (paste the entire JSON)

#### 3. Find Firebase App ID
1. Firebase Console > Your Project
2. Project Settings > Your Apps section
3. Android app > App ID (format: `1:123456789:android:abc123...`)

#### 4. Add Tester Emails
Add tester email addresses as comma-separated list:
```
tester1@example.com,tester2@example.com,tester3@example.com
```

### Usage

**Build on Every Push:**
- Just push to main branch
- Automatically runs: code analysis, tests, debug build

**Release and Distribute:**
```bash
# Create and push a version tag
git tag -a v1.0.0 -m "Version 1.0.0 release"
git push origin v1.0.0
```

This automatically:
- Builds release APK
- Distributes to Firebase App Distribution
- Notifies testers

### Monitor Builds
1. Go to your GitHub repository
2. Click "Actions" tab
3. View workflow runs in real-time

---

## Google Cloud Build (Alternative)

### Files
- `cloudbuild.yaml` - Production build config
- `cloudbuild-simple.yaml` - Simple test build

### Setup
1. Connect GitHub repo to Cloud Build
2. Create trigger for main branch
3. Set substitution variables in trigger settings

---

## Local Testing

### Build Manually
```powershell
# Debug
flutter build apk --debug

# Release
flutter build apk --release
```

### Test Before Release
```powershell
# Run all tests
flutter test

# Run code analysis
flutter analyze

# Check build for issues
flutter build apk --release --analyze-size
```

---

## Release Process

### Step 1: Update Version
Edit `pubspec.yaml`:
```yaml
version: 1.0.0+1
```

### Step 2: Commit Changes
```bash
git add -A
git commit -m "Release v1.0.0"
```

### Step 3: Create Release Tag
```bash
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0
```

### Step 4: Verify Distribution
- GitHub Actions will automatically trigger
- Monitor progress in Actions tab
- Testers will receive invitation emails

---

## Troubleshooting

### Build Fails
1. Check GitHub Actions logs
2. Verify all secrets are set correctly
3. Run `flutter analyze` and `flutter test` locally

### Firebase Distribution Not Working
1. Verify `FIREBASE_SERVICE_ACCOUNT` secret is valid JSON
2. Check `FIREBASE_APP_ID` is correct format
3. Ensure tester emails exist in Firebase project

### APK Not Uploading
1. Verify keystore is configured correctly
2. Check signing certificate is valid
3. Review build logs for signing errors

---

## Monitoring & Status

### GitHub Actions Status Badge
Add to README.md:
```markdown
[![Build and Distribute](https://github.com/YOUR_USERNAME/flutter_stars_app/actions/workflows/build-and-distribute.yml/badge.svg)](https://github.com/YOUR_USERNAME/flutter_stars_app/actions/workflows/build-and-distribute.yml)
```

### View Builds
- GitHub Actions: https://github.com/YOUR_REPO/actions
- Cloud Build: https://console.cloud.google.com/cloud-build
- Firebase: https://console.firebase.google.com

---

## Best Practices

1. **Tag Releases**: Use semantic versioning (v1.0.0, v1.0.1, etc.)
2. **Test First**: Always run tests locally before pushing
3. **Review Logs**: Check workflow logs for any warnings
4. **Update Notes**: Commit messages become release notes
5. **Monitor Testers**: Keep tester list updated
6. **Increment Versions**: Update pubspec.yaml for each release

---

## Next Steps

1. [ ] Add GitHub secrets
2. [ ] Test workflow by pushing to main
3. [ ] Create first release tag
4. [ ] Monitor Firebase App Distribution
5. [ ] Gather tester feedback
6. [ ] Iterate and release updates
