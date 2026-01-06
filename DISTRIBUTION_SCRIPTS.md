# Distribution Scripts Quick Reference

## Available Scripts

### 1. `distribute.ps1` (Windows PowerShell)
Manually distribute an APK to Firebase App Distribution

**Usage:**
```powershell
.\scripts\distribute.ps1 `
  -AppId "1:123456789:android:abc123" `
  -Testers "tester1@example.com,tester2@example.com" `
  -ReleaseNotes "Bug fixes and improvements" `
  -ApkPath "build/app/outputs/flutter-apk/app-release.apk"
```

**Requirements:**
- Firebase CLI installed: `npm install -g firebase-tools`
- Authenticated: `firebase login`
- APK file exists

---

### 2. `distribute.sh` (Bash/Linux/macOS)
Same as `distribute.ps1` but for Unix-like systems

**Usage:**
```bash
chmod +x scripts/distribute.sh
./scripts/distribute.sh "1:123:android:abc" "tester@example.com" "Release notes"
```

**Positional Arguments:**
1. App ID (required)
2. Testers (required)
3. Release Notes (optional, default: "New build distribution")
4. APK Path (optional, default: build/app/outputs/flutter-apk/app-release.apk)

---

### 3. `build-and-distribute.ps1` (Windows - Comprehensive)
Build APK, run tests, and distribute in one command

**Usage:**
```powershell
.\scripts\build-and-distribute.ps1 `
  -AppId "1:123456789:android:abc123" `
  -Testers "tester@example.com" `
  -ReleaseNotes "v1.0.0 Release" `
  -SkipTests `
  -SkipAnalyze
```

**Options:**
- `-AppId` - Firebase App ID (required)
- `-Testers` - Comma-separated tester emails (required)
- `-ReleaseNotes` - Release notes (optional)
- `-SkipTests` - Skip running tests
- `-SkipAnalyze` - Skip code analysis
- `-ApkPath` - Custom APK path

**Process:**
1. Code analysis (`flutter analyze`)
2. Unit tests (`flutter test`)
3. Build release APK (`flutter build apk --release`)
4. Distribute to Firebase
5. Display timing and summary

---

### 4. `bump-version.ps1` (Version Management)
Update version, create git tag, and trigger automated release

**Usage:**
```powershell
.\scripts\bump-version.ps1 `
  -Version "1.0.0" `
  -Message "Initial production release"
```

**What it does:**
1. Validates semantic version (X.Y.Z)
2. Checks git working directory is clean
3. Updates `pubspec.yaml` with new version
4. Increments build number
5. Creates git commit
6. Creates annotated git tag
7. Pushes to origin

**After running:**
- GitHub Actions automatically triggers
- Builds release APK
- Distributes to Firebase
- Notifies testers

---

## Common Workflows

### Manual Build & Test
```powershell
flutter build apk --release
flutter test
```

### Quick Distribution (no build)
```powershell
.\scripts\distribute.ps1 `
  -AppId "YOUR_APP_ID" `
  -Testers "testers@example.com" `
  -ReleaseNotes "Bug fixes"
```

### Full Pipeline (Build + Test + Distribute)
```powershell
.\scripts\build-and-distribute.ps1 `
  -AppId "YOUR_APP_ID" `
  -Testers "testers@example.com"
```

### Release New Version (Automated via GitHub Actions)
```powershell
.\scripts\bump-version.ps1 -Version "1.0.1" -Message "Bug fix release"
# This triggers GitHub Actions automatically!
```

---

## Prerequisites

### Firebase CLI
```powershell
npm install -g firebase-tools
firebase login
```

### Flutter
- Already installed in your environment
- Version 3.38.5+ recommended

### Git
- Already configured
- Working directory should be clean before version bumps

---

## Environment Variables (Optional)

Set these to avoid typing them repeatedly:

**PowerShell Profile** (`$PROFILE`):
```powershell
$env:FIREBASE_APP_ID = "1:123456789:android:abc123"
$env:FIREBASE_TESTERS = "tester1@example.com,tester2@example.com"
```

Then use:
```powershell
.\scripts\distribute.ps1 -AppId $env:FIREBASE_APP_ID -Testers $env:FIREBASE_TESTERS
```

---

## Troubleshooting

### "Firebase CLI not found"
```powershell
npm install -g firebase-tools
```

### "Not authenticated with Firebase"
```powershell
firebase login
```

### "APK not found"
Build first:
```powershell
flutter build apk --release
```

### "Working directory has uncommitted changes"
Commit or stash changes:
```powershell
git add -A
git commit -m "Your message"
```

### "Invalid version format"
Use semantic versioning: `1.0.0`, `1.0.1`, etc. (not `1.0` or `1.0.0-alpha`)

---

## Tips

1. **Test locally first**: Run `flutter analyze` and `flutter test` before distributing
2. **Use semantic versioning**: Helps track features, fixes, and breaking changes
3. **Write good release notes**: Include what changed and why
4. **Check Firebase Console**: Monitor tester feedback and distribution status
5. **Keep testers updated**: Add/remove testers as needed
6. **Archive old builds**: Firebase keeps recent builds; clean up old ones regularly

---

## Quick Links

- Firebase Console: https://console.firebase.google.com
- GitHub Actions: https://github.com/YOUR_REPO/actions
- Firebase App Distribution Docs: https://firebase.google.com/docs/app-distribution
- Firebase CLI Docs: https://firebase.google.com/docs/cli
