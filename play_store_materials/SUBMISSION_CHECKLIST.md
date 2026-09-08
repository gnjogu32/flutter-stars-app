# Play Store Submission Checklist - Starpage

## 📋 Pre-Submission Checklist

### ✅ Phase 1: Account Setup
- [ ] Google Play Developer Account created ($25 one-time fee)
- [ ] Payment method added to account
- [ ] Developer profile completed
- [ ] Business/Individual information verified

### ✅ Phase 2: Text Content (COMPLETED)
- [x] Short description (80 characters)
- [x] Full description (4000 characters)
- [x] Release notes prepared (v1.1.9)
- [x] Privacy policy URL ready: https://starpage.me/privacy
- [x] Data deletion URL ready: https://starpage.me/delete-account
- [x] Support email configured: support@starpage.me

### ✅ Phase 3: Graphics Materials
- [x] App icon ready (assets/icon.png)
- [ ] Feature graphic (1024x500 PNG/JPG) - *Recommendation: Use stadium cover photo*
- [x] Screenshots captured (from CPH2719)
- [ ] Graphics framed and polished
- [ ] Files organized in play_store_materials/graphics/

### ✅ Phase 4: App Build
- [x] Release build optimized: `flutter build apk --release`
- [x] APK signed with production keystore: `starpage-keystore-new.jks`
- [x] APK tested on device: Verified on CPH2719
- [x] 100% Analysis Pass: `flutter analyze` returns no issues
- [x] All automated tests passed

### ✅ Phase 5: App Information
- [x] App name: "Starpage"
- [x] Package Name: `com.starpage.app`
- [ ] Category: Social / Entertainment
- [ ] Content rating questionnaire completed
- [ ] Target audience defined (13+)
- [ ] Supported countries/regions selected

### ✅ Phase 6: Store Listing
- [ ] All text content uploaded
- [ ] All graphics uploaded
- [ ] Preview reviewed
- [ ] App details verified

### ✅ Phase 7: Technical Requirements
- [x] Min SDK: API 24 (Android 7.0)
- [x] Target SDK: API 36 (Android 16 Support)
- [x] 64-bit support enabled
- [x] App permissions audited
- [x] Privacy policy compliant & Live at starpage.me
- [x] Digital Asset Links: https://starpage.me/.well-known/assetlinks.json

---

## 📱 Current Status

**Project**: Starpage Social Media Platform
**Version**: 1.1.9
**Build Number**: 15
**Package**: com.starpage.app
**Domain**: starpage.me

**Completed**:
- ✅ Text content updated (Visibility features + Custom Domain)
- ✅ Privacy & Deletion URLs verified live
- ✅ CI/CD Workflows synchronized and fixed
- ✅ Critical features (Reels, Discover, Chat) verified stable
- ✅ Zero-issue code analysis

**In Progress**:
- ⏳ Graphic polish (Framing captured screenshots)

**Pending**:
- ⏳ Play Store upload and submission

---

## 🎯 Final Verification Actions

### Done Today:
1. Updated release notes for v1.1.9+15.
2. Verified starpage.me DNS propagation.
3. Aligned all CI/CD paths with production keystore.
4. Generated assetlinks.json template.

### Next Steps for Submission:
1. Framing the captured screenshots with device borders.
2. Replace placeholder SHA-256 in `assetlinks.json` once obtained from Play Console.
3. Submit for Google Review.

**Total to launch**: Ready for upload. 🎉
