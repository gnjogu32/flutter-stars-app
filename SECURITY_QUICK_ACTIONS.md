# Security & Performance Quick Actions

## 🚨 IMMEDIATE ACTIONS (DO NOW)

### 1. Delete Exposed Firebase Key
```powershell
Remove-Item "c:\Users\user\Downloads\starpage-ed409-firebase-adminsdk-fbsvc-e2c5c2a9fb.json" -Force
```

### 2. Rotate Firebase Service Account
1. Go to [Firebase Console](https://console.firebase.google.com/project/starpage-ed409/settings/serviceaccounts/adminsdk)
2. Find the key with ID: `e2c5c2a9fba77da82a772e1f9012a63ce08889fc`
3. Click "Delete" on that key
4. Click "Generate new private key"
5. Save securely, update GitHub Secrets immediately
6. Delete the downloaded file after updating secrets

### 3. Strengthen Keystore Passwords
```powershell
# Generate 32-character random passwords
$store = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})
$key = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})

# Display passwords (copy these to GitHub Secrets)
Write-Host "ANDROID_KEYSTORE_PASSWORD: $store"
Write-Host "ANDROID_KEY_PASSWORD: $key"

# Create new keystore
cd android
keytool -genkey -v -keystore starpage-keystore-new.jks -keyalg RSA -keysize 2048 -validity 10000 -alias starpage

# Update key.properties (local only)
@"
storePassword=$store
keyPassword=$key
keyAlias=starpage
storeFile=starpage-keystore-new.jks
"@ | Out-File key.properties -Encoding UTF8
```

### 4. Update GitHub Secrets
Go to: https://github.com/YOUR_USERNAME/flutter_stars_app/settings/secrets/actions

Update:
- `ANDROID_KEYSTORE_PASSWORD` → [new store password]
- `ANDROID_KEY_PASSWORD` → [new key password]
- `FIREBASE_SERVICE_ACCOUNT` → [new service account JSON]

---

## 📋 DEPLOY ENHANCED SECURITY RULES

### Firestore Rules (with validation)
```powershell
# Backup current
Copy-Item firestore.rules firestore.rules.backup

# Use enhanced version
Copy-Item firestore.rules.enhanced firestore.rules

# Deploy
firebase deploy --only firestore:rules --project starpage-ed409
```

### Storage Rules (with file limits)
```powershell
# Backup current
Copy-Item storage.rules storage.rules.backup

# Use enhanced version
Copy-Item storage.rules.enhanced storage.rules

# Deploy
firebase deploy --only storage --project starpage-ed409
```

---

## 🔍 VERIFY SECURITY

### Check Firebase API Key Restrictions
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=starpage-ed409)
2. Find each API key:
   - Android: `AIzaSyDIylfRJaAtpXSuMtoeKUzJbYEScdAGGhY`
   - Web: `AIzaSyB9w4G-9in-GzGGs9sEetXvz8h4NXtNxVU`
   - iOS: `AIzaSyCcne8lCBS7X5FXGPC8CksGdHyFnUbEsM4`

3. Restrict each key:
   - **Android Key:** Application restrictions → Android apps → Add `org.starpage.app`
   - **Web Key:** Website restrictions → Add your domains
   - **iOS Key:** iOS apps → Add bundle ID `com.example.flutterStarsApp`

### Test Security Rules
```powershell
# Install Firebase emulator
npm install -g firebase-tools

# Start emulator
firebase emulators:start --only firestore,storage

# Run tests in another terminal
flutter test test/security_rules_test.dart
```

---

## ⚡ PERFORMANCE OPTIMIZATIONS

### Update Dependencies (Test First!)
```powershell
# Update pubspec.yaml major versions
flutter pub upgrade --major-versions

# Get dependencies
flutter pub get

# Run tests
flutter test

# Build and test
flutter build apk --release
```

### Add Performance Monitoring
```powershell
# 1. Add to pubspec.yaml
# dependencies:
#   firebase_performance: ^0.10.0+9

# 2. Run
flutter pub get

# 3. Update main.dart (see SECURITY_PERFORMANCE_AUDIT.md)
```

---

## 📊 MONITORING CHECKLIST

### Daily
- [ ] Check Firebase Console for unusual activity
- [ ] Monitor authentication failures
- [ ] Review error logs

### Weekly
- [ ] Check Firestore usage and costs
- [ ] Review storage usage
- [ ] Check for security rule violations

### Monthly
- [ ] Review access logs
- [ ] Check for outdated dependencies
- [ ] Review GitHub Actions logs
- [ ] Audit user permissions

### Quarterly
- [ ] Rotate Firebase service account key
- [ ] Update keystore passwords
- [ ] Review all security rules
- [ ] Perform penetration testing
- [ ] Update dependencies

---

## 🎯 SECURITY SCORE TRACKER

| Category | Before | After | Target |
|----------|--------|-------|--------|
| Credential Management | 3/10 🔴 | TBD | 10/10 ✅ |
| Input Validation | 5/10 🟡 | TBD | 9/10 ✅ |
| File Upload Security | 6/10 🟡 | TBD | 9/10 ✅ |
| Authentication | 9/10 ✅ | 9/10 ✅ | 9/10 ✅ |
| Code Security | 8/10 ✅ | 8/10 ✅ | 9/10 ✅ |
| **Overall** | **6.5/10** 🟡 | **TBD** | **9/10** ✅ |

---

## 📞 EMERGENCY CONTACTS

### If Security Breach Suspected
1. **Immediately revoke** all Firebase service account keys
2. **Rotate** all keystore passwords
3. **Review** Firebase audit logs
4. **Check** for unauthorized data access
5. **Notify** affected users if data compromised

### Firebase Support
- [Firebase Console](https://console.firebase.google.com/project/starpage-ed409)
- [Firebase Support](https://firebase.google.com/support)
- [Report Security Issue](https://firebase.google.com/support/troubleshooter/report/features/1009840)

---

## ✅ COMPLETION CHECKLIST

Mark items as you complete them:

### Immediate (Today)
- [ ] Delete exposed Firebase service account key
- [ ] Rotate Firebase service account
- [ ] Update GitHub Secrets with new key
- [ ] Generate strong keystore passwords
- [ ] Update GitHub Secrets with new passwords

### High Priority (This Week)
- [ ] Deploy enhanced Firestore rules
- [ ] Deploy enhanced Storage rules
- [ ] Test all security rules
- [ ] Restrict Firebase API keys in Google Cloud Console
- [ ] Create new keystore with strong passwords
- [ ] Update CI/CD with new keystore

### Medium Priority (This Month)
- [ ] Update Flutter dependencies
- [ ] Add Firebase Performance Monitoring
- [ ] Implement image compression
- [ ] Test performance improvements
- [ ] Document changes in release notes

### Ongoing
- [ ] Set up security monitoring alerts
- [ ] Schedule quarterly security reviews
- [ ] Document security procedures
- [ ] Train team on security best practices

---

**Last Updated:** January 27, 2026  
**Next Review:** April 27, 2026

**For full details, see:** [SECURITY_PERFORMANCE_AUDIT.md](SECURITY_PERFORMANCE_AUDIT.md)
