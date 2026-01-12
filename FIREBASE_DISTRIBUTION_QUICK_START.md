# Firebase App Distribution - Step-by-Step Action Guide

## Quick Start (15 minutes)

This is a **practical action guide**. Follow these steps in order to get Firebase App Distribution working with CI/CD.

---

## STEP 1: Get Firebase App ID (5 minutes)

### Go to Firebase Console

1. Open: https://console.firebase.google.com
2. Click your project: **starpage-ed409**
3. In the left menu, scroll down to **App Distribution**
4. Click **App Distribution**

### Find Your App ID

1. Click **Testers & Groups** (top of page)
2. You'll see Android app listed
3. Find the **App ID** section (looks like: `1:123456789:android:abc123abc123`)
4. **Copy the full App ID**

### If you don't see App Distribution:
1. Click the menu icon (☰)
2. Look for "All products" or "More products"
3. Search for "App Distribution"
4. Click **Enable**

---

## STEP 2: Create Your First Tester Group (3 minutes)

### Go to Testers & Groups

1. Firebase Console → **App Distribution** → **Testers & Groups**
2. Click **Create group** (blue button)

### Create Groups

Enter these group names (click **Create** after each):

**Group 1:**
- Name: `Alpha Testers`
- Click **Create**

**Group 2:**
- Name: `Beta Testers`
- Click **Create**

---

## STEP 3: Add Testers (3 minutes)

### Add to Alpha Testers Group

1. Click **Alpha Testers** (in the group list)
2. Click **Add testers**
3. Enter tester emails (comma-separated):
   ```
   your.tester1@gmail.com
   your.tester2@gmail.com
   ```
4. Click **Add**

**Result**: Testers will receive invitation emails within minutes.

---

## STEP 4: Generate Service Account Key (2 minutes)

### Go to Service Accounts

1. Firebase Console → **Project Settings** (gear icon, top-left)
2. Click **Service Accounts** tab
3. Click **Generate New Private Key**
4. Confirm by clicking **Generate Key**

**Your browser downloads a JSON file automatically.**

### Save the File

- ✅ Keep the downloaded JSON file safe
- ❌ **Do NOT commit to GitHub**
- ✅ You'll copy its contents to GitHub Secrets next

---

## STEP 5: Add GitHub Secrets (5 minutes)

### Open Your GitHub Repository

1. Go to: https://github.com/YOUR_USERNAME/YOUR_REPO
2. Click **Settings** tab (top-right)
3. Left menu → **Secrets and variables** → **Actions**

### Add Secret 1: FIREBASE_APP_ID

1. Click **New repository secret**
2. **Name**: `FIREBASE_APP_ID`
3. **Value**: Paste the App ID from Step 1
   ```
   1:123456789:android:abc123abc123
   ```
4. Click **Add secret**

### Add Secret 2: FIREBASE_SERVICE_ACCOUNT

1. Click **New repository secret** again
2. **Name**: `FIREBASE_SERVICE_ACCOUNT`
3. **Value**: Open the JSON file from Step 4 and paste the ENTIRE contents
   ```json
   {
     "type": "service_account",
     "project_id": "starpage-ed409",
     ...
   }
   ```
4. Click **Add secret**

### Add Secret 3: FIREBASE_TESTERS

1. Click **New repository secret** again
2. **Name**: `FIREBASE_TESTERS`
3. **Value**: Your tester emails (comma-separated)
   ```
   your.tester1@gmail.com,your.tester2@gmail.com
   ```
4. Click **Add secret**

### Add Secret 4: FIREBASE_GROUPS (Optional)

1. Click **New repository secret** again
2. **Name**: `FIREBASE_GROUPS`
3. **Value**: Your tester group names (comma-separated)
   ```
   Alpha Testers,Beta Testers
   ```
4. Click **Add secret**

### Verify All Secrets Added

Go back to **Settings** → **Secrets and variables** → **Actions**

You should see:
- ✅ FIREBASE_APP_ID
- ✅ FIREBASE_SERVICE_ACCOUNT
- ✅ FIREBASE_TESTERS
- ✅ FIREBASE_GROUPS

---

## STEP 6: Test the CI/CD Pipeline (2 minutes)

### Test with a Version Tag

Open PowerShell in your project folder:

```powershell
# Create a test version tag
git tag -a v0.0.1 -m "Test release"

# Push the tag to GitHub
git push origin v0.0.1
```

### Monitor the Workflow

1. Go to your GitHub repository
2. Click **Actions** tab
3. You should see **Build and Distribute** running
4. Watch the progress in real-time

**The workflow will:**
- ✅ Build release APK
- ✅ Run tests
- ✅ Distribute to Firebase
- ✅ Email testers

---

## STEP 7: Verify Everything Works (3 minutes)

### Check Firebase Console

1. Go to Firebase Console → **App Distribution**
2. Click **Releases**
3. You should see your release listed:
   - Release version: **v0.0.1**
   - Date and time
   - Download status

### Check Tester Emails

1. Testers should receive emails with:
   - Subject: "Starpage (Android) is now available for testing"
   - Download link
   - Release notes

2. Testers can click the link and install on Android devices

### Check GitHub Actions

1. Go to GitHub → **Actions**
2. Click the **Build and Distribute** workflow
3. You should see green checkmarks ✅ for all steps:
   - ✅ Build
   - ✅ Run tests
   - ✅ Firebase distribute
   - ✅ Notify

---

## You're Done! 🎉

Your Firebase App Distribution is now **fully configured** and **integrated with CI/CD**.

### What Happens Now?

Whenever you want to release a new version to testers:

```powershell
# Create a version tag
git tag -a v1.0.0 -m "Version 1.0.0 release"

# Push it
git push origin v1.0.0
```

That's it! GitHub Actions will:
1. Build the APK
2. Run all tests
3. Distribute to Firebase
4. Email testers automatically

---

## Common Tasks

### How to Add More Testers

1. Firebase Console → **App Distribution** → **Testers & Groups**
2. Click your group name
3. Click **Add testers**
4. Enter email addresses
5. Click **Add**

Testers will receive email invitations.

### How to Update Testers in CI/CD

1. GitHub → **Settings** → **Secrets and variables** → **Actions**
2. Click **FIREBASE_TESTERS**
3. Click **Update secret**
4. Update the email list
5. Click **Update secret**

### How to Release a Test Version

```powershell
# Build and test locally first
flutter build apk --release
flutter test

# If all good, release to testers
git tag -a v1.0.0-beta -m "Beta release"
git push origin v1.0.0-beta

# Testers get notified automatically!
```

### How to Skip Distribution (Just Build)

Push to `main` branch (without a version tag):

```powershell
git add .
git commit -m "Your changes"
git push origin main
```

This builds APK but **doesn't** distribute to testers. APK available in GitHub Actions artifacts.

---

## Troubleshooting

### Workflow Fails? Check These:

1. **Go to GitHub Actions**
   - Click the failed workflow
   - Scroll down to see the error
   - Error messages usually show what's wrong

2. **Common Issues:**

   | Error | Fix |
   |-------|-----|
   | "FIREBASE_APP_ID not found" | Check secret name spelling (exactly `FIREBASE_APP_ID`) |
   | "Service account invalid" | Regenerate key in Firebase Console, paste full JSON |
   | "APK not found" | Ensure APK builds successfully locally first |
   | "Testers not in group" | Add testers to group in Firebase Console first |

3. **Validate Locally First**
   ```powershell
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

   If this fails, the workflow will also fail.

---

## Next Steps

### Understand the CI/CD Flow

Read: [CI_CD_SETUP.md](CI_CD_SETUP.md)

### Learn Advanced Features

Read: [FIREBASE_APP_DISTRIBUTION_SETUP.md](FIREBASE_APP_DISTRIBUTION_SETUP.md)

### Manual Distribution (if needed)

```powershell
# Distribute without GitHub Actions
.\scripts\distribute.ps1 `
  -AppId "YOUR_APP_ID" `
  -Testers "tester@example.com" `
  -ReleaseNotes "v1.0.0 Release"
```

---

## Support

- **Firebase Docs**: https://firebase.google.com/docs/app-distribution
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Workflow File**: [.github/workflows/build-and-distribute.yml](.github/workflows/build-and-distribute.yml)

---

**Congratulations!** Your app is now ready for distributed testing. 🚀

