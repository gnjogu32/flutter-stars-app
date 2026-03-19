# Firebase App Distribution + CI/CD - Command Reference Card

## Quick Commands

### Release a Version (Most Common)

```powershell
# Create version tag and trigger automated release
git tag -a v1.0.0 -m "Release notes here"
git push origin v1.0.0

# That's it! In ~8 minutes:
# - APK builds automatically
# - Tests run automatically
# - Firebase receives APK
# - Testers get email
```

---

## Git Commands

### Create and Push Version Tags

```powershell
# Simple tag (automated)
git tag -a v1.0.0 -m "v1.0.0 release"
git push origin v1.0.0

# With detailed release notes
git tag -a v1.0.0 -m "v1.0.0 - Release Notes

FEATURES:
- Feature A
- Feature B

FIXES:
- Fixed crash on startup
- Improved performance"

git push origin v1.0.0
```

### List and View Tags

```powershell
# List all tags
git tag

# View specific tag
git show v1.0.0

# List with annotations
git tag -l -n

# Delete tag (if mistake)
git tag -d v1.0.0
git push origin :v1.0.0
```

### Standard Git Workflow

```powershell
# Make changes
git add .
git commit -m "Feature: Add new functionality"
git push origin main

# Create release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

---

## Firebase CLI Commands

### Installation & Setup

```powershell
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# List projects
firebase projects:list

# Select project
firebase use starpage-ed409
```

### Manual Distribution (If Needed)

```powershell
# Build APK first
flutter build apk --release

# Distribute to single tester
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk `
  --app="1:123456789:android:abc123" `
  --testers="tester@example.com" `
  --release-notes="v1.0.0 release"

# Distribute to group
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk `
  --app="1:123456789:android:abc123" `
  --groups="Alpha Testers" `
  --release-notes="v1.0.0 release"
```

---

## GitHub Secrets Management

### Add Secrets

```powershell
# Go to: GitHub → Settings → Secrets and variables → Actions

# Secret 1: FIREBASE_APP_ID
# Value: 1:123456789:android:abc123...

# Secret 2: FIREBASE_SERVICE_ACCOUNT
# Value: Entire JSON contents from Firebase

# Secret 3: FIREBASE_TESTERS
# Value: tester1@gmail.com,tester2@gmail.com

# Secret 4: FIREBASE_GROUPS
# Value: Alpha Testers,Beta Testers
```

### Update Secrets

```powershell
# Go to: GitHub → Settings → Secrets and variables → Actions
# Click secret name
# Click "Update secret"
# Enter new value
# Save

# Example: Add new tester
# FIREBASE_TESTERS: tester1@gmail.com,tester2@gmail.com,tester3@gmail.com
```

---

## Flutter Commands

### Build APK Locally

```powershell
# Debug APK
flutter build apk --debug

# Release APK (what gets distributed)
flutter build apk --release

# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

### Testing

```powershell
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run with coverage
flutter test --coverage

# Code analysis
flutter analyze
```

### Install and Run

```powershell
# List connected devices
adb devices

# Install APK on device
adb install build/app/outputs/flutter-apk/app-release.apk

# Run app
flutter run --release
```

---

## GitHub Actions Commands

### Manual Trigger Workflow

```
GitHub → Actions → Build and Distribute → Run workflow
```

### View Workflow Logs

```
GitHub → Actions → [Workflow name] → [Workflow run] → [Job name]
```

### Download Artifacts

```
GitHub → Actions → [Workflow run] → Artifacts section
```

---

## Firebase Console URLs

### Navigation

```
Main Dashboard
https://console.firebase.google.com

Your Project (starpage-ed409)
https://console.firebase.google.com/project/starpage-ed409

App Distribution
https://console.firebase.google.com/project/starpage-ed409/appdistribution

Testers & Groups
https://console.firebase.google.com/project/starpage-ed409/appdistribution/groups

Releases
https://console.firebase.google.com/project/starpage-ed409/appdistribution/releases

Analytics & Crash Reports
https://console.firebase.google.com/project/starpage-ed409/analytics
```

### Common Tasks in Firebase Console

```powershell
# View all releases
App Distribution → Releases

# Manage testers
App Distribution → Testers & Groups

# Create tester group
Testers & Groups → Create group

# Add tester to group
Click group → Add testers → Enter email

# View crash reports
Analytics → Crash Reports

# View download stats
Releases → Click release → View details
```

---

## Troubleshooting Commands

### Verify Firebase CLI

```powershell
firebase --version
firebase projects:list
```

### Verify APK Builds

```powershell
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release

# Verify APK exists
Test-Path build/app/outputs/flutter-apk/app-release.apk
```

### Fix VS Code Java/Gradle Init Cache Error

```powershell
.\scripts\fix-redhat-java-gradle-init.ps1
```

Then in VS Code run:

```
Java: Clean Java Language Server Workspace
```

### Check Workflow Status

```
GitHub → Actions → See all runs
```

### View Workflow Errors

```
GitHub → Actions → [Failed workflow] → See error message
```

### Reset Failed Workflow

```powershell
# Delete and recreate tag
git tag -d v1.0.0
git push origin :v1.0.0
git tag -a v1.0.0 -m "Retry"
git push origin v1.0.0

# Or manually trigger
GitHub → Actions → Build and Distribute → Run workflow
```

---

## Release Version Examples

### Semantic Versioning

```
v1.0.0  - Major release (breaking changes)
v1.0.1  - Patch (bug fix)
v1.1.0  - Minor (new features)
v2.0.0  - Major (large update)
```

### Release Tags

```powershell
# Initial release
git tag -a v1.0.0 -m "v1.0.0 - Initial Release"

# Bug fix
git tag -a v1.0.1 -m "v1.0.1 - Bug Fix Release"

# New features
git tag -a v1.1.0 -m "v1.1.0 - New Features"

# Beta testing
git tag -a v1.1.0-beta.1 -m "v1.1.0-beta.1 - Beta Testing"

# Daily build
git tag -a v1.0.0-daily-20250110 -m "Daily Build 2025-01-10"
```

---

## Environment Variables (Optional)

### Set Credentials Locally

```powershell
# Add to PowerShell profile ($PROFILE)
$env:FIREBASE_APP_ID = "1:123456789:android:abc123"
$env:FIREBASE_TESTERS = "tester@example.com"
```

### Use in Scripts

```powershell
.\scripts\distribute.ps1 `
  -AppId $env:FIREBASE_APP_ID `
  -Testers $env:FIREBASE_TESTERS
```

---

## One-Liners

### Quick Release

```powershell
git tag -a v1.0.0 -m "Release"; git push origin v1.0.0
```

### Build and Distribute (Local)

```powershell
flutter build apk --release; .\scripts\distribute.ps1 -AppId "YOUR_APP_ID" -Testers "email@test.com"
```

### Check All Commits Since Tag

```powershell
git log v1.0.0..main --oneline
```

### Count Commits Since Tag

```powershell
(git log v1.0.0..main --oneline).Count
```

---

## Checklists

### Before Each Release

- [ ] Tests pass: `flutter test`
- [ ] Code analysis: `flutter analyze`
- [ ] Build works: `flutter build apk --release`
- [ ] Release notes prepared
- [ ] Version number updated in pubspec.yaml
- [ ] Changelog updated

### Release Day

- [ ] Create tag: `git tag -a v1.0.0 -m "message"`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] Monitor Actions: `GitHub → Actions tab`
- [ ] Check Firebase: Distribution started
- [ ] Verify Emails: Testers notified
- [ ] Done! ✅

---

## Help Commands

### Flutter Help

```powershell
flutter build --help
flutter test --help
flutter analyze --help
```

### Firebase Help

```powershell
firebase --help
firebase appdistribution:distribute --help
```

### Git Help

```powershell
git tag --help
git push --help
```

---

## Quick Links

| Resource | URL |
|----------|-----|
| Firebase Console | https://console.firebase.google.com |
| GitHub Repository | https://github.com/[YOUR_REPO] |
| Firebase Docs | https://firebase.google.com/docs/app-distribution |
| GitHub Actions Docs | https://docs.github.com/en/actions |
| Git Documentation | https://git-scm.com/doc |
| Semantic Versioning | https://semver.org/ |

---

## Desktop Reference Card

Print this for your desk:

```
RELEASE CHECKLIST
✓ Make changes
✓ Test locally
✓ Update version in pubspec.yaml
✓ Update CHANGELOG.md
✓ Push commits: git push origin main
✓ Create tag: git tag -a v1.0.0 -m "notes"
✓ Push tag: git push origin v1.0.0
✓ Wait 8 minutes
✓ Check email for notifications
✓ Done! 🎉

KEY LINKS
GitHub Actions: github.com/[repo]/actions
Firebase Console: console.firebase.google.com
Documentation: See FIREBASE_*.md files
```

---

**Bookmark this page for quick reference during releases!**

