# Firebase App Distribution Complete Setup Guide

## Overview
Firebase App Distribution allows you to distribute test builds to testers and monitor their feedback. This guide covers:
- Setting up Firebase App Distribution
- Managing testers and tester groups
- Configuring GitHub Actions for automated distribution
- Distributing builds manually or automatically

---

## Part 1: Firebase Console Setup

### Step 1: Enable Firebase App Distribution

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **starpage-ed409**
3. From the left menu, select **App Distribution**
   - If you don't see it, click "View all products" and enable it
4. Click **Get Started**

### Step 2: Create Tester Groups

1. In App Distribution, click **Testers & Groups**
2. Click **Create group**
3. Enter group name (e.g., "Alpha Testers", "Beta Testers", "VIP Testers")
4. Click **Create**

**Recommended Groups:**
```
├── Alpha Testers
│   └─ Early access, frequent updates, provide detailed feedback
├── Beta Testers
│   └─ Stable releases, weekly updates
└── QA Team
    └─ Internal testing, all builds
```

### Step 3: Add Testers to Groups

1. Click **Testers & Groups**
2. Click a group name to edit
3. Click **Add testers**
4. Enter email addresses (comma-separated):
   ```
   tester1@example.com
   tester2@example.com
   tester3@example.com
   ```
5. Click **Add**
6. Testers will receive invitation emails

### Step 4: Get Your Firebase App ID

1. Go to **Project Settings** (gear icon, top-left)
2. Click **Your Apps** section
3. Find your Android app
4. Copy the **App ID** (format: `1:123456789:android:abc123...`)
5. Save this - you'll need it for GitHub Actions

### Step 5: Create Service Account for Automated Distribution

1. Go to **Project Settings** → **Service Accounts** tab
2. Click **Generate New Private Key**
3. Click **Generate Key** to confirm
4. A JSON file will download automatically
5. **Important**: Keep this file secure - don't commit it to GitHub
6. You'll add its contents to GitHub Secrets

---

## Part 2: GitHub Actions Secrets Setup

### Add Required Secrets to GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

#### Secret 1: FIREBASE_APP_ID

```
Name: FIREBASE_APP_ID
Value: 1:123456789:android:abc123...
```
(Copy from Firebase Console)

#### Secret 2: FIREBASE_SERVICE_ACCOUNT

```
Name: FIREBASE_SERVICE_ACCOUNT
Value: [Paste entire JSON contents from downloaded key file]
```

Example JSON content:
```json
{
  "type": "service_account",
  "project_id": "starpage-ed409",
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxx@starpage-ed409.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
}
```

#### Secret 3: FIREBASE_TESTERS

```
Name: FIREBASE_TESTERS
Value: tester1@example.com,tester2@example.com,tester3@example.com
```

#### Secret 4: FIREBASE_GROUPS

```
Name: FIREBASE_GROUPS
Value: Alpha Testers,Beta Testers
```
(Optional - comma-separated tester group names)

### Verify Secrets Added

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. You should see 4 secrets listed:
   - ✅ FIREBASE_APP_ID
   - ✅ FIREBASE_SERVICE_ACCOUNT
   - ✅ FIREBASE_TESTERS
   - ✅ FIREBASE_GROUPS

---

## Part 3: GitHub Actions Workflow

### Automatic Workflow Triggers

Your CI/CD pipeline is already configured in `.github/workflows/build-and-distribute.yml`:

#### Trigger 1: Push to Main
- **Event**: Push to `main` branch
- **Action**: Build APK, run tests, run analysis
- **Result**: Debug APK available for download

#### Trigger 2: Create Version Tag
- **Event**: Create git tag starting with `v` (e.g., `v1.0.0`)
- **Action**: Build release APK, distribute to Firebase
- **Result**: Testers receive invitation email

#### Trigger 3: Manual Trigger
- **Event**: Manually run workflow from GitHub
- **Action**: Build and optionally distribute
- **Result**: Customizable per run

### Workflow Process

```
┌─────────────────────────────────────────┐
│ 1. Event Triggered (Push/Tag/Manual)    │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ 2. Setup Environment                    │
│    ├─ Java 17                           │
│    ├─ Flutter 3.38.5                    │
│    └─ Dependencies                      │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ 3. Run Tests & Analysis                 │
│    ├─ flutter analyze                   │
│    └─ flutter test                      │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ 4. Build APK                            │
│    ├─ Debug (always)                    │
│    └─ Release (on tag only)             │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ 5. Upload Artifacts                     │
│    └─ Store APK for 30 days             │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ 6. Distribute to Firebase (Tag Only)    │
│    ├─ Download release APK              │
│    ├─ Send to Firebase                  │
│    └─ Notify testers via email          │
└────────────┬────────────────────────────┘
             ↓
┌─────────────────────────────────────────┐
│ ✅ Complete - Testers notified          │
└─────────────────────────────────────────┘
```

---

## Part 4: Using the Workflow

### Method 1: Create Version Tag (Recommended for Releases)

```powershell
# Create a version tag
git tag -a v1.0.0 -m "Version 1.0.0 - Initial release"

# Push tag to GitHub (triggers workflow)
git push origin v1.0.0
```

**This will:**
1. Trigger the workflow automatically
2. Build release APK
3. Distribute to Firebase App Distribution
4. Email testers with download link
5. Create GitHub Release

### Method 2: Manual Workflow Trigger

1. Go to GitHub repository
2. Click **Actions** tab
3. Select **Build and Distribute** workflow
4. Click **Run workflow**
5. Choose branch and options
6. Click **Run workflow**

### Method 3: Simple Push to Main

```powershell
# Commit and push code
git add .
git commit -m "Feature: Add new functionality"
git push origin main
```

**This will:**
1. Run tests and analysis
2. Build debug APK
3. Store APK as artifact (30 days)
4. No email to testers

---

## Part 5: Local Manual Distribution

### If GitHub Actions is unavailable or you need immediate distribution:

#### Using PowerShell Script

1. Build the APK:
```powershell
flutter build apk --release
```

2. Distribute:
```powershell
.\scripts\distribute.ps1 `
  -AppId "YOUR_FIREBASE_APP_ID" `
  -Testers "tester1@example.com,tester2@example.com" `
  -ReleaseNotes "v1.0.0 - Bug fixes and improvements"
```

#### Using Firebase CLI Directly

```powershell
# Install Firebase CLI (one-time)
npm install -g firebase-tools

# Login to Firebase
firebase login

# Distribute APK
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk `
  --app="1:123456789:android:abc123" `
  --release-notes="v1.0.0 Release" `
  --testers="tester1@example.com,tester2@example.com"
```

---

## Part 6: Managing Testers

### Add New Tester

1. Firebase Console → **App Distribution** → **Testers & Groups**
2. Click group name to edit
3. Click **Add testers**
4. Enter email address
5. Click **Add**
6. Tester receives invitation email

### Remove Tester

1. Click group to edit
2. Find tester in the list
3. Click **Remove**

### Update Testers List in GitHub

When you add/remove testers, update GitHub Secret:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **FIREBASE_TESTERS**
3. Update the email list
4. Click **Update secret**

New secret value:
```
tester1@example.com,tester2@example.com,tester3@example.com
```

---

## Part 7: Monitoring Distribution

### Firebase Console

1. Go to **App Distribution**
2. Click **Releases**
3. View:
   - Release date and time
   - Who downloaded it
   - Tester feedback
   - Crash reports

### GitHub Actions

1. Go to **Actions** tab
2. Click workflow run
3. View:
   - Build status
   - Test results
   - Error logs
   - Artifact downloads

### Tester Feedback

Testers receive emails with:
- Download link
- Release notes
- Option to provide feedback
- Crash reports automatically included

---

## Part 8: Troubleshooting

### Issue: "Firebase CLI not found"
```powershell
npm install -g firebase-tools
firebase login
```

### Issue: "Service account not valid"
- Regenerate service account key in Firebase Console
- Update `FIREBASE_SERVICE_ACCOUNT` GitHub secret with new JSON
- Ensure JSON is pasted as-is (not formatted)

### Issue: "Testers not receiving emails"
1. Check email addresses are correct
2. Verify testers accepted invitation
3. Go to Firebase Console → **Testers & Groups**
4. Check tester status

### Issue: "Workflow fails at distribution step"
1. Check `FIREBASE_APP_ID` is correct format
2. Verify service account has correct permissions
3. Check `FIREBASE_TESTERS` has valid emails
4. View GitHub Actions logs for specific error

### Issue: "APK not signed properly"
- Ensure `KEYSTORE_PASSWORD` and `KEY_PASSWORD` environment variables are set
- Check keystore file exists at `android/starpage-keystore.jks`
- Verify signing config in `android/app/build.gradle.kts`

---

## Quick Reference

### Firebase App Distribution Commands

```powershell
# Build and distribute (local)
.\scripts\distribute.ps1 -AppId "YOUR_APP_ID" -Testers "tester@example.com"

# Build, test, and distribute (local)
.\scripts\build-and-distribute.ps1 -AppId "YOUR_APP_ID" -Testers "tester@example.com"

# Using Firebase CLI directly
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk `
  --app="YOUR_APP_ID" `
  --testers="tester@example.com"
```

### Git/GitHub Commands

```powershell
# Create version tag and trigger CI/CD
git tag -a v1.0.0 -m "Version 1.0.0"
git push origin v1.0.0

# View GitHub Actions status
# Navigate to: GitHub → Repository → Actions tab
```

### Useful Links

- **Firebase Console**: https://console.firebase.google.com
- **GitHub Repository**: https://github.com/YOUR_USERNAME/YOUR_REPO
- **Firebase App Distribution Docs**: https://firebase.google.com/docs/app-distribution
- **GitHub Actions Docs**: https://docs.github.com/en/actions

---

## Checklist - Complete Setup

- [ ] **Firebase Console**
  - [ ] Created tester groups (Alpha, Beta, QA)
  - [ ] Added testers to groups
  - [ ] Copied Firebase App ID
  - [ ] Generated Service Account key

- [ ] **GitHub Secrets**
  - [ ] Added `FIREBASE_APP_ID`
  - [ ] Added `FIREBASE_SERVICE_ACCOUNT` (JSON)
  - [ ] Added `FIREBASE_TESTERS`
  - [ ] Added `FIREBASE_GROUPS`

- [ ] **Workflow Configuration**
  - [ ] Verified `.github/workflows/build-and-distribute.yml` exists
  - [ ] Tested manual workflow trigger
  - [ ] Created test version tag

- [ ] **Testing**
  - [ ] Run workflow with test tag (v0.0.1)
  - [ ] Verify testers received email
  - [ ] Check Firebase Console for release
  - [ ] Verify tester can download APK

---

**Setup Time**: ~30 minutes
**Automated Releases**: Every tag push automatically distributes to testers
**Support**: See troubleshooting section or Firebase documentation

