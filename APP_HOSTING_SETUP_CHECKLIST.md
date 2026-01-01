# App Hosting Setup Checklist

## Pre-Deployment Steps

### 1. Firebase Console Setup
- [ ] Go to [Firebase Console](https://console.firebase.google.com/)
- [ ] Select `starpage-ed409` project
- [ ] Enable **App Hosting** API
- [ ] Create App Hosting backend named `flutter-stars-web`
- [ ] Set region to `us-central1`

### 2. GitHub Setup
- [ ] Ensure Flutter code is pushed to GitHub repo
- [ ] Repository is public or Firebase has access
- [ ] Default branch is set (main/develop)

### 3. GitHub Secrets Configuration
Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```
FIREBASE_SERVICE_ACCOUNT = [Firebase Service Account JSON]
WIF_PROVIDER = [Workload Identity Provider]
WIF_SERVICE_ACCOUNT = [Service Account Email]
FIREBASE_PROJECT_ID = starpage-ed409
```

#### To get Workload Identity Provider:
```bash
gcloud iam workload-identity-pools create "github" \
  --project="starpage-ed409" \
  --location="global" \
  --display-name="GitHub"

gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="starpage-ed409" \
  --location="global" \
  --workload-identity-pool="github" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

### 4. Local Build Testing
Run these commands to verify your web build works:

```powershell
# Clean and get dependencies
flutter clean
flutter pub get

# Build for web
flutter build web --release

# Test locally
cd build/web
python -m http.server 8000
# or use: npx http-server
```

Then visit `http://localhost:8000` to verify.

### 5. Environment Configuration (Optional)

If your app needs environment-specific variables, add to App Hosting settings:

```
FIREBASE_CONFIG=production
FLUTTER_ENV=web
API_BASE_URL=https://api.starpage.com
```

### 6. Custom Domain Setup (Optional)

1. In Firebase App Hosting dashboard
2. Go to **Custom domains**
3. Add your custom domain
4. Follow DNS verification
5. Update domain DNS records:
   ```
   CNAME: your-app.web.app
   TXT: (Firebase verification code)
   ```

## Deployment

### Automatic Deployment (Recommended)
```
Push to main → Automatically deploys to production
Push to develop → Preview deployment
Create PR → Preview channel created
```

### Manual Deployment
```powershell
firebase deploy --project starpage-ed409 --only apphosting
```

## Post-Deployment Verification

- [ ] Visit `https://flutter-stars-web--starpage-ed409.web.app`
- [ ] Check that all pages load correctly
- [ ] Test authentication flow
- [ ] Check Firebase connectivity
- [ ] Test image uploads/loading
- [ ] Verify responsive design on mobile
- [ ] Check console for JavaScript errors
- [ ] Monitor performance in Firebase Console

## Monitoring

### View Logs
```bash
firebase functions:log --project starpage-ed409
gcloud logging read "resource.type=cloud_run_revision" --limit 50 --project starpage-ed409
```

### Check Metrics
1. Firebase Console → **App Hosting** → **Deployments**
2. View build logs and deployment history
3. Go to **Monitoring** → **Uptime** to set uptime checks

## Troubleshooting

### If build fails:
1. Check GitHub Actions logs
2. Run `flutter build web --release --web-verbose` locally
3. Verify all dependencies in `pubspec.yaml`
4. Check `pubspec.lock` is committed

### If app doesn't load:
1. Check browser console (F12)
2. Verify Firebase config in web build
3. Check network requests in DevTools
4. Try `flutter clean` and rebuild

### If deployment takes too long:
- Reduce build size: `--tree-shake-icons`
- Cache dependencies in GitHub Actions
- Consider splitting large bundles

## Success Indicators

✅ GitHub Actions workflow completes successfully  
✅ App loads at `https://flutter-stars-web--starpage-ed409.web.app`  
✅ No errors in browser console  
✅ Firebase operations work (auth, database, etc.)  
✅ Responsive on mobile devices  
✅ Performance metrics show in Firebase Console  

## Next Steps After Deployment

1. Set up monitoring alerts
2. Configure error reporting
3. Set up analytics
4. Monitor costs in Google Cloud Console
5. Plan feature rollouts with traffic policies

## Useful Commands

```bash
# Check deployment status
firebase deploy --project starpage-ed409 --only apphosting --dry-run

# View app hosting logs
gcloud run logs read flutter-stars-web --region us-central1

# List all deployed backends
firebase apphosting:backends:list --project starpage-ed409

# Promote version to production
firebase apphosting:backends:promote --project starpage-ed409 --backend=flutter-stars-web

# Set environment variables
firebase apphosting:backends:env:set --project starpage-ed409 --backend=flutter-stars-web KEY=value
```

## Support Resources

- [App Hosting Docs](https://firebase.google.com/docs/app-hosting)
- [Cloud Run Docs](https://cloud.google.com/run/docs)
- [GitHub Actions Troubleshooting](https://docs.github.com/en/actions/learn-github-actions)
- [Flutter Web Documentation](https://flutter.dev/docs/deployment/web)

## Status

**Last Updated**: December 31, 2025  
**Project**: starpage-ed409  
**Status**: Ready for deployment ✅
