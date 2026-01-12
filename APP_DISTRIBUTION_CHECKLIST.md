# App Distribution Setup Checklist

## Overview
This checklist ensures Firebase App Distribution is fully configured for automated APK distribution to testers.

---

## ✅ What's Already Configured

### GitHub Actions Workflow
- ✅ Build and Distribute workflow exists: `.github/workflows/build-and-distribute.yml`
- ✅ Builds debug APK on every push
- ✅ Builds release APK on version tags (`v*`)
- ✅ Distributes to Firebase App Distribution when tagged
- ✅ Uses Firebase Distribution GitHub Action

---

## 🔧 Setup Checklist

### STEP 1: Firebase Console Setup (10 min)

- [ ] Go to [Firebase Console](https://console.firebase.google.com)
- [ ] Select project: **starpage-ed409**
- [ ] Enable **App Distribution** (left menu)
- [ ] Note your **Android App ID** (format: `1:246255479274:android:341fbd17995cbd2e862a93`)

#### Create Tester Groups
- [ ] Go to **App Distribution** → **Testers & Groups**
- [ ] Create group: **Alpha Testers** (early access)
- [ ] Create group: **Beta Testers** (stable releases)
- [ ] Create group: **QA Team** (internal testing, optional)

#### Add Testers
- [ ] Click each group and add tester email addresses
- [ ] Testers will receive invitation emails
- [ ] Testers must accept invitation to receive builds

---

### STEP 2: Generate Service Account Key (5 min)

- [ ] Go to **Project Settings** (⚙️ icon) → **Service Accounts** tab
- [ ] Click **Generate New Private Key**
- [ ] Confirm: Click **Generate Key**
- [ ] Save the downloaded JSON file securely
- [ ] ⚠️ **Do NOT commit this file to GitHub**

---

### STEP 3: Add GitHub Repository Secrets (5 min)

Go to: `https://github.com/YOUR_USERNAME/YOUR_REPO/settings/secrets/actions`

#### Secret 1: FIREBASE_APP_ID
```
Name:  FIREBASE_APP_ID
Value: 1:246255479274:android:341fbd17995cbd2e862a93
       (from Firebase Console → Your Apps → Android App)
```

#### Secret 2: FIREBASE_SERVICE_ACCOUNT
```
Name:  FIREBASE_SERVICE_ACCOUNT
Value: [Paste entire JSON from downloaded service account key]
       Example:
       {
         "type": "service_account",
         "project_id": "starpage-ed409",
         "private_key_id": "...",
         ...
       }
```

#### Secret 3: FIREBASE_GROUPS (Optional)
```
Name:  FIREBASE_GROUPS
Value: Alpha Testers,Beta Testers
       (Comma-separated group names)
```

#### Secret 4: FIREBASE_TESTERS (Optional)
```
Name:  FIREBASE_TESTERS
Value: tester1@gmail.com,tester2@gmail.com
       (Comma-separated email addresses)
```

---

### STEP 4: Test the Distribution Workflow (5 min)

#### Option A: Push a Version Tag
```bash
# Create a version tag
git tag v1.0.0 -m "First release"

# Push the tag
git push origin v1.0.0
```

This will:
1. ✅ Build release APK
2. ✅ Trigger Firebase App Distribution
3. ✅ Testers receive invitations + download link

#### Option B: Trigger Manually
1. Go to GitHub Repository
2. Click **Actions** tab
3. Click **Build and Distribute** workflow
4. Click **Run workflow** dropdown
5. Click **Run workflow**

---

## 📊 Distribution Workflow Steps

When you push a tag like `v1.0.0`:

```
1. Checkout Code
   ↓
2. Setup Java 17
   ↓
3. Setup Flutter 3.38.5
   ↓
4. Get Dependencies (flutter pub get)
   ↓
5. Run Code Analysis (flutter analyze)
   ↓
6. Run Tests (flutter test)
   ↓
7. Build Debug APK
   ↓
8. Build Release APK (tagged releases only)
   ↓
9. Upload APK to GitHub Artifacts
   ↓
10. Download APK
    ↓
11. Distribute via Firebase App Distribution
    ↓
12. Testers Receive:
    • Invitation email (first time)
    • Download link
    • Release notes (commit message)
```

---

## 🎯 How Testers Receive Builds

### For New Testers
1. **Invitation Email**: Testers get invited to Firebase App Distribution
2. **Accept Invitation**: Testers click link and join the program
3. **Receive Build**: Once accepted, they get access to the app

### For Existing Testers
1. **Build Ready**: When you distribute a new build
2. **Notification Email**: Testers get email with download link
3. **Download**: Click link → Install on device

---

## 📱 How Testers Install the App

### Via Firebase App Distribution Link
1. Receive email: "Your app is ready!"
2. Click download link in email
3. Firebase App Distribution shows app
4. Click **Install** button
5. Download APK (if not auto-installing)
6. Open APK on device to install

### Via Google Play (Optional)
- Can also upload to Play Store internal testing
- Testers install via Play Store app

---

## 🚀 How to Distribute Builds

### Method 1: Version Tags (Recommended)
```bash
# Create new version
git tag v1.0.1 -m "Bug fixes and performance improvements"

# Push to GitHub
git push origin v1.0.1

# GitHub Actions automatically:
# - Builds release APK
# - Distributes to Firebase App Distribution
```

### Method 2: Manual Trigger
1. GitHub Repository → **Actions**
2. Select **Build and Distribute** workflow
3. Click **Run workflow**
4. Builds and distributes immediately

### Method 3: Push to Release Branch
Current setup distributes on version tags. You can modify workflow to also:
- Distribute on every push to `main` (debug APK)
- Distribute on pull request approval (pre-release)

---

## 🔍 Monitor Distributions

### In Firebase Console
1. Go to **App Distribution** → **Releases**
2. See list of all distributed builds
3. View:
   - Build timestamp
   - Testers who installed
   - Release notes
   - Status (available, installed, etc.)

### View Tester Feedback
1. **App Distribution** → **Releases**
2. Click a release
3. See tester comments and ratings
4. View crash reports and feedback

---

## ⚠️ Common Issues & Solutions

### Issue: "Secret not found"
**Solution:**
1. Go to GitHub Settings → Secrets
2. Verify all required secrets are added:
   - FIREBASE_APP_ID
   - FIREBASE_SERVICE_ACCOUNT
3. Check spelling (case-sensitive)

### Issue: "Invalid service account"
**Solution:**
1. Download fresh service account key
2. Paste entire JSON (including `{}`)
3. Ensure no line breaks or formatting issues

### Issue: "Testers not receiving builds"
**Solution:**
1. Check testers accepted Firebase invitation
2. Go to **Testers & Groups** in Firebase Console
3. Verify tester email is listed
4. Resend invitations if needed

### Issue: "APK signature invalid"
**Solution:**
1. Ensure you're using release APK for distribution
2. Check keystore configuration
3. Verify signing key in GitHub Secrets

---

## 📋 Summary: 4 Simple Steps

1. **Firebase Setup** (10 min)
   - Enable App Distribution
   - Create tester groups
   - Add testers

2. **Generate Service Account** (5 min)
   - Project Settings → Service Accounts
   - Download JSON key

3. **Add GitHub Secrets** (5 min)
   - FIREBASE_APP_ID
   - FIREBASE_SERVICE_ACCOUNT
   - FIREBASE_GROUPS (optional)
   - FIREBASE_TESTERS (optional)

4. **Distribute Builds** (1 min per release)
   - Push version tag: `git push origin v1.0.0`
   - Or manually trigger workflow
   - Testers receive build automatically

---

## ✅ After Setup

- [x] Firebase App Distribution enabled
- [x] GitHub Actions workflow configured
- [ ] Secrets added to GitHub
- [ ] Tester groups created
- [ ] Testers invited
- [ ] Ready to distribute!

---

## Next Steps

1. Complete the checklist above
2. Test with `git tag v1.0.0 && git push origin v1.0.0`
3. Watch GitHub Actions build
4. Check Firebase App Distribution for new release
5. Testers will receive notifications

---

## Reference Links

- [Firebase App Distribution Docs](https://firebase.google.com/docs/app-distribution)
- [Firebase Distribution GitHub Action](https://github.com/wzieba/Firebase-Distribution-Github-Action)
- [Your GitHub Secrets Settings](https://github.com/YOUR_USERNAME/flutter_stars_app/settings/secrets/actions)
- [Firebase Console - App Distribution](https://console.firebase.google.com/u/0/project/starpage-ed409/appdistribution)

---

## Version Release Command

When ready to distribute:

```bash
# Set version
VERSION="1.0.1"

# Create tag with release notes
git tag $VERSION -m "Release $VERSION: Bug fixes and improvements"

# Push tag
git push origin $VERSION

# GitHub Actions automatically builds and distributes!
```

Monitor progress:
1. GitHub Actions → Build and Distribute workflow
2. Firebase Console → App Distribution → Releases
