# Firebase App Hosting Integration Guide

## Overview
Firebase App Hosting is a fully managed platform for deploying and scaling web apps with a focus on performance and ease of use. It's built on Cloud Run and provides automatic scaling, built-in CI/CD, and global CDN.

**Project**: starpage-ed409  
**Region**: us-central1 (default)

## Prerequisites
- ✅ Flutter web app configured
- ✅ Firebase project created (`starpage-ed409`)
- ✅ Firebase CLI installed
- ✅ GitHub repository with your Flutter code
- Node.js 18+ installed

## Step 1: Enable App Hosting API

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select **starpage-ed409** project
3. Navigate to **App Hosting** from the left sidebar
4. Click **Create an app**
5. Select **GitHub** as your source repository
6. Authorize Firebase to access your GitHub account
7. Select your repository (flutter_stars_app)
8. Select branch: **main** (production) or **develop** (staging)

## Step 2: Configure Build Settings

### Option A: Automatic Build Configuration (Recommended)

Firebase will auto-detect your Flutter web app:

1. Source directory: `/` (root)
2. Build command: `flutter build web --release`
3. Output directory: `build/web`

### Option B: Custom `firebase.json` Configuration

Update your [firebase.json](firebase.json) to include App Hosting config:

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "cleanUrls": true,
    "trailingSlashBehavior": "REMOVE"
  },
  "apphosting": {
    "servingConfig": {
      "app": "flutter-stars-web"
    }
  }
}
```

## Step 3: Create GitHub Workflow File

Create `.github/workflows/app-hosting-deploy.yml`:

```yaml
name: Deploy to Firebase App Hosting

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          cache: true
      
      - name: Get dependencies
        run: flutter pub get
      
      - name: Build Flutter web
        run: flutter build web --release
      
      - name: Deploy to Firebase App Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          projectId: starpage-ed409
          channelId: ${{ github.event_name == 'pull_request' && 'pr-${{ github.event.number }}' || 'live' }}
```

## Step 4: Create Dockerfile (Optional - For Custom Runtime)

If you need additional dependencies or custom build steps, create `Dockerfile`:

```dockerfile
# Build stage
FROM node:18-alpine AS builder

# Install Flutter SDK
RUN apk add --no-cache git curl bash
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:$PATH"
RUN flutter config --enable-web
RUN flutter pub global activate webdev

WORKDIR /app
COPY . .

RUN flutter pub get
RUN flutter build web --release

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/build/web /app

EXPOSE 8080
CMD ["npx", "http-server", ".", "-p", "8080", "-c-1"]
```

## Step 5: Set Environment Variables (If Needed)

If your app requires environment variables:

1. Go to Firebase App Hosting settings
2. Click **Environment variables**
3. Add your variables:
   - `FIREBASE_PROJECT_ID=starpage-ed409`
   - `FIREBASE_API_KEY=<your-api-key>`
   - `FLUTTER_ENV=production`

## Step 6: Configure Custom Domain

### Using Firebase Domain
1. App Hosting automatically provides: `starpage-ed409.web.app`

### Using Custom Domain
1. In Firebase App Hosting settings, click **Custom domains**
2. Click **Add custom domain**
3. Enter your domain (e.g., `starpage.com`)
4. Follow DNS verification steps
5. Update your domain's DNS records

## Step 7: Deployment

### Automatic Deployment (GitHub Integration)
- Push to `main` branch → Automatic production deployment
- Push to `develop` branch → Staging/preview deployment
- Create PR → Preview channel created

### Manual Deployment
```powershell
# Install Firebase CLI (if not already done)
npm install -g firebase-tools

# Login
firebase login

# Deploy
firebase deploy --project starpage-ed409 --only apphosting
```

## Step 8: Verify Deployment

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select **starpage-ed409**
3. Click **App Hosting** from left menu
4. Check deployment status (should show "Live" or "Success")
5. Visit your app at: `https://starpage-ed409.web.app`

## Monitoring & Debugging

### View Logs
```powershell
firebase functions:log --project starpage-ed409
```

### Check Build Logs
1. App Hosting dashboard → Select your app
2. Click **Deployments** tab
3. Click a deployment to see build logs

### Performance Monitoring
1. In Firebase Console, go to **Performance**
2. View real-time web app performance metrics

### Error Tracking
1. In Firebase Console, go to **Crashlytics** (if enabled)
2. View client-side errors from your deployed app

## Build Optimization Tips

### 1. Reduce Build Time
```yaml
# In flutter pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  # Minimize dependencies
```

### 2. Optimize Output Size
```bash
flutter build web --release --tree-shake-icons
```

### 3. Cache Dependencies in GitHub Actions
```yaml
- name: Cache Flutter
  uses: actions/cache@v3
  with:
    path: ~/.pub-cache
    key: ${{ runner.os }}-flutter-${{ hashFiles('**/pubspec.lock') }}
```

## Troubleshooting

### Issue: "Build failed" error
**Solution**: 
- Check GitHub Actions logs for detailed error
- Run `flutter build web --release` locally to test
- Verify all dependencies are in `pubspec.yaml`

### Issue: App displays blank page
**Solution**:
- Check browser console for JavaScript errors
- Verify `web/index.html` is properly configured
- Check Flutter web build: `flutter build web --release --web-verbose`

### Issue: Custom domain not resolving
**Solution**:
- Wait 24-48 hours for DNS propagation
- Verify DNS records in your domain provider
- Check Firebase custom domain settings

### Issue: Large bundle size
**Solution**:
- Use `--tree-shake-icons` flag
- Enable gzip compression in `firebase.json`
- Code-split large features

## Comparison: App Hosting vs Firebase Hosting

| Feature | App Hosting | Firebase Hosting |
|---------|------------|-----------------|
| Auto-scaling | ✅ Yes | Limited |
| CI/CD Integration | ✅ Native | Manual setup |
| Containerization | ✅ Yes (Cloud Run) | Static files |
| Custom runtime | ✅ Dockerfile support | No |
| Backend integration | ✅ Cloud Run + Functions | Functions only |
| Global CDN | ✅ Yes | Yes |
| Cost | Pay per request | Pay per GB |

## Cost Estimation

**Monthly cost for typical Flutter web app**:
- Requests: 1M/month → ~$0.40
- Network egress: 100GB/month → ~$0.12
- Storage: 1GB → Free tier covers

**Use Firebase Hosting if**: Static-only deployment  
**Use App Hosting if**: Custom backend, scaling needs, Dockerfile required

## Next Steps

1. ✅ Enable App Hosting API in Firebase Console
2. ✅ Set up GitHub Actions workflow
3. ✅ Configure environment variables
4. ✅ Set custom domain (optional)
5. ✅ Deploy and monitor

## Useful Links

- [Firebase App Hosting Docs](https://firebase.google.com/docs/app-hosting)
- [Cloud Run Docs](https://cloud.google.com/run/docs)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Flutter Web Deployment](https://flutter.dev/docs/deployment/web)

## Support

For issues or questions:
- Check [Firebase documentation](https://firebase.google.com/docs)
- Review [Cloud Run troubleshooting](https://cloud.google.com/run/docs/troubleshooting)
- Check GitHub Actions logs for deployment errors
