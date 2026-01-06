# Google Play Store Deployment Guide

## Prerequisites Checklist

- [ ] Google Play Developer Account ($25 one-time fee)
- [ ] Release APK built: `build/app/outputs/flutter-apk/app-release.apk` ✅
- [ ] App signing keystore configured ✅
- [ ] App ID configured: `com.starpage.app`

---

## Step 1: Create Google Play Developer Account

1. Go to **Google Play Console**: https://play.google.com/console
2. Sign in with your Google account
3. Pay the **$25 one-time registration fee**
4. Complete account setup with:
   - Developer name
   - Contact email
   - Privacy policy URL
   - Business address

**Estimated time**: 30 minutes to 1 hour (review may take a few hours)

---

## Step 2: Create New App Listing

1. In Google Play Console, click **"Create app"**
2. Enter app details:
   - **App name**: Starpage
   - **Default language**: English (US)
   - **App or game**: App
   - **Free or paid**: Free (or Paid)
3. Accept the policies and continue

---

## Step 3: Fill Out App Information

### App access
- Review app access requirements
- Select appropriate declarations

### Ads
- Declare if your app contains ads
- Provide ad placement information

### Content rating
1. Fill out the content rating questionnaire
2. Get your content rating certificate

### Target audience
- Select age groups: Mainly young adults and adults
- Content rating: Review your app's content

### User-generated content
- Select if your app contains user-generated content
- Provide moderation policies

---

## Step 4: Prepare Store Listing

### Main store listing
1. **Short description** (80 characters max):
   ```
   Discover trending content and connect with creators
   ```

2. **Full description** (4,000 characters max):
   ```
   Starpage is a social media platform where creators share content,
   connect with audiences, and discover trending posts.
   
   Features:
   - Explore trending content
   - Follow your favorite creators
   - Like and comment on posts
   - Direct messaging
   - Real-time notifications
   - Beautiful user profiles
   
   Join the Starpage community today and start sharing!
   ```

3. **Screenshots** (required):
   - Minimum 2, maximum 8 screenshots
   - Recommended: 1080x1920px (9:16 aspect ratio)
   - Show key features and app functionality

4. **Feature graphic**:
   - Size: 1024x500px
   - Recommended: Eye-catching hero image

5. **Icon**:
   - Size: 512x512px
   - PNG format
   - Your app logo

6. **Video**:
   - Optional: 15-30 second preview

---

## Step 5: Configure Release

### Internal Testing Track (Recommended first step)

1. Go to **Testing > Internal testing**
2. Create release:
   - Click **Create new release**
   - Upload your APK: `build/app/outputs/flutter-apk/app-release.apk`
   - Add release notes (what changed)
   - Review app data
   - Save and review

3. Add testers:
   - Add internal team emails
   - Share internal testing link
   - Gather feedback

### Beta Testing Track

1. Go to **Testing > Closed testing**
2. Create release (same as internal)
3. Add beta testers (up to 500)
4. Let them test for ~1-2 weeks

### Production Release

1. Go to **Release > Production**
2. Create new release:
   - Upload APK
   - Add release notes
   - Review everything
3. Submit for review (Google reviews app, typically 1-3 days)
4. If approved, app goes live!

---

## Step 6: Upload APK

### Using Google Play Console Web UI

1. Go to **Release > [Track] > Create new release**
2. Click **Upload APK**
3. Select file: `build/app/outputs/flutter-apk/app-release.apk`
4. Fill in release notes:
   ```
   Initial release
   - Explore trending content
   - Follow creators
   - Direct messaging
   - User profiles
   ```
5. Click **Review release**
6. Click **Start rollout to [Track]**

### Using Play Console API (Advanced)

```powershell
# Install play console CLI
npm install -g @react-native-community/cli-platform-android

# Upload APK using fastlane (if configured)
fastlane supply --apk build/app/outputs/flutter-apk/app-release.apk
```

---

## Step 7: Pricing & Distribution

### Pricing
- **Free app**: Select "Free" (no payment setup needed)
- **Paid app**: Configure pricing tier and payment methods

### Countries & Regions
- Select countries where app should be available
- Some regions may have content restrictions

### Device categories
- Phone/Tablet/Wear OS
- Which devices can install your app

---

## Step 8: Store Listing Details

### Permissions & APIs
- Review permissions your app requests
- Ensure privacy policy covers data usage

### Privacy Policy
- Must be hosted at a URL
- Include:
  - Data collection practices
  - How user data is used
  - Analytics tools used (Firebase, etc.)
  - Third-party services

### Policies & Safety
- Read and agree to developer program policies
- Ensure your app complies with:
  - Intellectual property rights
  - Prohibited content rules
  - User privacy requirements
  - Spam and malware policies

---

## Step 9: Build Features Configuration

### Supported devices
- Minimum Android version: 7.0 (API 24) ✅
- Target Android version: 34+ ✅
- Architectures: arm64-v8a, armeabi-v7a ✅

### Required libraries
- Review required Google Play services

---

## Step 10: Submit for Review

### Pre-submission checklist
- [ ] App name and description set
- [ ] Icons and screenshots uploaded
- [ ] Privacy policy URL provided
- [ ] Content rating completed
- [ ] APK uploaded to release track
- [ ] Release notes added
- [ ] Target audience set
- [ ] Pricing and distribution configured
- [ ] Store listing completed

### Submit
1. Review all information one final time
2. Click **"Submit for review"** or **"Start rollout"**
3. Wait for Google's review (1-3 days for production)

---

## After Launch

### Monitoring
1. Go to **Analytics** for:
   - Daily active users
   - Ratings and reviews
   - Crash reports
   - Performance metrics

2. Monitor **Reviews**:
   - Respond to user feedback
   - Address bugs and requests
   - Update app regularly

### Updates
1. Build new version
2. Increment version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2
   ```
3. Build release APK
4. Upload to Play Console
5. Add release notes
6. Submit to Production

---

## Troubleshooting

### APK rejected for missing privacy policy
- Create privacy policy page
- Add HTTPS URL to Play Console
- Re-submit

### APK rejected for violating policies
- Read rejection reason carefully
- Fix issues
- Re-submit

### App crashes on Play Store
- Check Crashes in Analytics
- Review Android specific code
- Use Firebase Crashlytics for better crash reports
- Update and re-submit

### Low ratings from users
- Respond to reviews
- Fix reported issues
- Release updates regularly
- Engage with community

---

## APK Details

**Built APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Size**: 50.3 MB
- **Signing**: Configured with keystore
- **Architectures**: ARM64, ARMv7
- **Min SDK**: API 24 (Android 7.0)
- **Target SDK**: API 34

---

## Timeline

| Step | Time | Status |
|------|------|--------|
| Developer Account | 30 mins - 1 hour | Manual |
| Create App Listing | 30 mins | Manual |
| Screenshots & Store Listing | 1-2 hours | Manual |
| Content Rating | 15 mins | Automated |
| Upload APK | 5 mins | Manual |
| Google Review (Internal) | 1-3 days | Automated |
| Google Review (Production) | 1-3 days | Automated |
| **Total** | **2-5 days** | ✅ |

---

## Resources

- **Google Play Console**: https://play.google.com/console
- **App Store Policies**: https://play.google.com/about/developer-content-policy/
- **Deployment Guide**: https://developers.google.com/android/guides/releases
- **Firebase for Analytics**: https://firebase.google.com/docs/analytics
- **Privacy Policy Generator**: https://www.privacypolicygenerator.info/

---

## Quick Commands

### Build release APK
```powershell
flutter build apk --release
```

### Verify APK
```powershell
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

### View app size
```powershell
(Get-Item "build/app/outputs/flutter-apk/app-release.apk").Length / 1MB
```

---

## Version Numbering

When updating your app, update `pubspec.yaml`:

```yaml
# Format: version: major.minor.patch+buildNumber
version: 1.0.0+1    # Initial release
version: 1.0.1+2    # Bug fix
version: 1.1.0+3    # Feature release
version: 2.0.0+4    # Major release
```

---

## Next Steps

1. [ ] Create Google Play Developer account
2. [ ] Set up app listing
3. [ ] Create screenshots and store images
4. [ ] Write privacy policy
5. [ ] Fill out content rating
6. [ ] Upload APK to internal testing track
7. [ ] Test with internal team
8. [ ] Upload to production
9. [ ] Submit for review
10. [ ] Monitor analytics and reviews
