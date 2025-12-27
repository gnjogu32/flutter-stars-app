# Firebase Hosting CI/CD Setup Guide

## Overview
This guide explains how to set up automated CI/CD deployment to Firebase Hosting using GitHub Actions.

## Prerequisites
- [x] GitHub repository created and code pushed
- [x] Firebase project configured (`starpage-ed409`)
- [x] Flutter web build working locally

## Setup Steps

### 1. Generate Firebase Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **starpage-ed409**
3. Navigate to: **Project Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. Save the JSON file (keep it secure!)

### 2. Add GitHub Secrets

Add the following secrets to your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

1. **FIREBASE_SERVICE_ACCOUNT**
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: Paste the entire contents of the Firebase service account JSON file

2. **GITHUB_TOKEN** (automatically available)
   - Already provided by GitHub Actions

### 3. Configure Firebase Hosting

Update your `firebase.json` file:

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
    ]
  }
}
```

### 4. Workflow Configuration

The workflow file (`.github/workflows/firebase-hosting-deploy.yml`) includes:

- **Triggers**: Runs on push to `main` and `develop` branches, and on pull requests
- **Build**: Compiles Flutter web with optimizations
- **Deploy**: Automatically deploys to Firebase Hosting on main branch pushes

### 5. Firebase CLI Setup (Local Testing)

Test the deployment locally:

```powershell
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Test deployment
firebase deploy --project starpage-ed409
```

## Workflow Behavior

### On Push to `main` Branch
1. Builds Flutter web release
2. Runs tests (if configured)
3. Deploys to Firebase Hosting (live channel)

### On Push to `develop` Branch
1. Builds Flutter web release
2. Runs tests
3. No automatic deployment (preview only)

### On Pull Requests
1. Builds Flutter web release
2. Runs tests
3. Creates a preview channel (optional)

## Monitoring Deployments

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select **Hosting** from the left menu
3. View deployment history and logs
4. Check GitHub Actions tab for build logs

## Troubleshooting

### Deployment Fails: "Service Account Not Found"
- Ensure `FIREBASE_SERVICE_ACCOUNT` secret is added correctly
- Verify the JSON content is not truncated

### Build Fails: "Flutter command not found"
- Check Flutter version in workflow (currently `3.10.4`)
- Ensure `pubspec.yaml` has correct dependencies

### Build Takes Too Long
- GitHub Actions provides 10 GB storage
- Flutter web builds are cached automatically
- First build may take 5-10 minutes

### Deployment Shows Old Version
- Clear browser cache (Ctrl+Shift+Delete)
- Check Firebase Hosting deployment logs
- Verify correct project ID: `starpage-ed409`

## Next Steps

1. **Add Environment Variables** (if needed):
   - Add `FLUTTER_WEB_USE_SKIA=true` for better rendering
   - Add API endpoints for different environments

2. **Add Preview Channels**:
   - Deploy to preview channels on pull requests
   - Share previews with team before merging

3. **Add Custom Domain**:
   - Go to Hosting settings
   - Add your custom domain
   - Follow DNS configuration

4. **Enable Performance Monitoring**:
   - Add Firebase Performance Monitoring SDK
   - Track real user performance metrics

## Security Best Practices

✅ **Do:**
- Keep service account key secure
- Rotate keys periodically
- Use branch protection rules
- Enable required status checks

❌ **Don't:**
- Commit service account key to repository
- Share secrets in logs
- Use production credentials for testing
- Disable security checks

## Deployment URL

Your deployed app will be available at:
- **Production**: `https://starpage-ed409.web.app`
- **Preview**: `https://starpage-ed409--preview-<id>.web.app`

## Support Resources

- [Firebase Hosting Documentation](https://firebase.google.com/docs/hosting)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
