# Google Cloud Build Setup Guide

## Overview
This guide sets up Google Cloud Build to automatically build and test your Flutter Stars App.

## Prerequisites

1. **Google Cloud Project** with billing enabled
2. **Cloud Build API** enabled
3. **Cloud Storage** for build artifacts
4. **GitHub/GitLab** repository connected to Cloud Build

## Quick Setup

### Step 1: Enable Required APIs

```powershell
# Authenticate with Google Cloud
gcloud auth login

# Set your project ID
$env:PROJECT_ID = "your-project-id"
gcloud config set project $env:PROJECT_ID

# Enable Cloud Build API
gcloud services enable cloudbuild.googleapis.com

# Enable Cloud Storage
gcloud services enable storage.googleapis.com

# Enable Cloud Run (optional, for deployment)
gcloud services enable run.googleapis.com
```

### Step 2: Create Cloud Build Trigger

1. Go to [Cloud Build Console](https://console.cloud.google.com/cloud-build/triggers)
2. Click **Create Trigger**
3. Configure:
   - **Source**: GitHub/GitLab (connect your repository)
   - **Branch**: `main` (or your default branch)
   - **Build Configuration**: Cloud Build configuration file
   - **Location**: `cloudbuild.yaml`
4. Click **Create**

### Step 3: Set Up Secret Manager for Keystore Passwords

```powershell
# Create secrets for keystore passwords
echo "your_keystore_password" | gcloud secrets create KEYSTORE_PASSWORD --data-file=-
echo "your_key_password" | gcloud secrets create KEY_PASSWORD --data-file=-

# Grant Cloud Build service account access
$BUILD_ACCOUNT = "$(gcloud projects describe $env:PROJECT_ID --format='value(projectNumber)')@cloudbuild.gserviceaccount.com"
gcloud secrets add-iam-policy-binding KEYSTORE_PASSWORD --member="serviceAccount:$BUILD_ACCOUNT" --role="roles/secretmanager.secretAccessor"
gcloud secrets add-iam-policy-binding KEY_PASSWORD --member="serviceAccount:$BUILD_ACCOUNT" --role="roles/secretmanager.secretAccessor"
```

### Step 4: Update cloudbuild.yaml with Secrets

Modify your `cloudbuild.yaml` to reference secrets:

```yaml
steps:
  - name: 'gcr.io/cloud-builders/gke-deploy'
    secretEnv: ['KEYSTORE_PASSWORD', 'KEY_PASSWORD']
    # ... rest of build steps

availableSecrets:
  secretManager:
  - versionName: projects/$PROJECT_ID/secrets/KEYSTORE_PASSWORD/versions/latest
    env: 'KEYSTORE_PASSWORD'
  - versionName: projects/$PROJECT_ID/secrets/KEY_PASSWORD/versions/latest
    env: 'KEY_PASSWORD'
```

### Step 5: Create Cloud Storage Bucket for Artifacts

```powershell
# Create bucket for build artifacts
$BUCKET_NAME = "$env:PROJECT_ID-flutter-artifacts"
gsutil mb gs://$BUCKET_NAME

# Set permissions
$BUILD_ACCOUNT = "$(gcloud projects describe $env:PROJECT_ID --format='value(projectNumber)')@cloudbuild.gserviceaccount.com"
gsutil iam ch serviceAccount:$BUILD_ACCOUNT:roles/storage.objectCreator gs://$BUCKET_NAME
```

## File Structure

```
cloudbuild.yaml          # Main build configuration (recommended)
cloudbuild-simple.yaml   # Alternative simpler config
Dockerfile.build         # Docker-based build (optional)
```

## Usage

### Manual Build Trigger

```powershell
# Trigger a build manually
gcloud builds submit --config=cloudbuild.yaml
```

### View Build Logs

```powershell
# List recent builds
gcloud builds list --limit 10

# View specific build logs
gcloud builds log BUILD_ID
```

### Download Artifacts

```powershell
# Download APK from Cloud Storage
gsutil cp gs://$BUCKET_NAME/flutter-builds/*/flutter-app-release.apk ./
```

## Troubleshooting

### Build Fails with "Buildpack Detection"
- **Cause**: Using generic buildpacks for Flutter
- **Solution**: Use `cloudbuild.yaml` with explicit Flutter build steps (provided)

### "Flutter not found"
- **Cause**: Flutter SDK not installed in build environment
- **Solution**: Ensure Step 1 (install-flutter) runs before build steps

### Keystore Password Errors
- **Cause**: Secrets not properly configured
- **Solution**: 
  1. Verify secrets exist: `gcloud secrets list`
  2. Verify Cloud Build service account has access
  3. Use `gcloud secrets versions list SECRET_NAME` to check versions

### Build Timeout
- **Cause**: Flutter compilation takes >1 hour
- **Solution**: Increase `timeout` in cloudbuild.yaml (currently 3600s)

## Which Config to Use?

| Config | Use When |
|--------|----------|
| `cloudbuild.yaml` | You want a Docker-based build with caching |
| `cloudbuild-simple.yaml` | You want faster setup without Docker |

**Recommendation**: Start with `cloudbuild-simple.yaml`, rename to `cloudbuild.yaml` when ready.

## Next Steps

1. ✅ Update `cloudbuild.yaml` with your project ID
2. ✅ Set up Secret Manager with keystore passwords
3. ✅ Create Cloud Build trigger in Google Cloud Console
4. ✅ Test by pushing to your repository or running `gcloud builds submit`
5. ✅ Monitor builds in [Cloud Build Console](https://console.cloud.google.com/cloud-build/builds)

## Deployment Options

### Option 1: Firebase Hosting (Web)
```yaml
# Add to cloudbuild.yaml after APK build
- name: 'gcr.io/firebase-tools/firebase-tools'
  args: ['deploy', '--only=hosting']
```

### Option 2: Google Play Store
Manual upload of AAB to Play Console (not automated yet)

### Option 3: Cloud Run (Preview)
App will be available at: `https://flutter-stars-app-[PROJECT_ID].run.app`

## Security Considerations

✅ Keystore passwords stored in Secret Manager  
✅ Secrets only accessed during build  
✅ Artifacts stored in private Cloud Storage bucket  
✅ Build logs in Cloud Logging  
✅ Service account with minimal required permissions
