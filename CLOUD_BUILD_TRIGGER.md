# Cloud Build Trigger - Manual Setup Guide

Since `gcloud` CLI installation is proving complex, here's how to trigger your build using the **Google Cloud Console**:

## Option 1: Trigger Via Google Cloud Console (Recommended)

1. **Open Cloud Build Triggers:**
   - Go to: https://console.cloud.google.com/cloud-build/triggers

2. **Find Your Trigger:**
   - Look for your Flutter Stars App repository
   - If not listed, click "Create Trigger" and select your GitHub repo

3. **Manual Build Trigger:**
   - Click on your trigger name
   - Click "Run" or "Trigger Workflow"
   - Select branch: `main`
   - Click "Create"

4. **View Build:**
   - Watch the build progress in the Build Details page
   - Logs appear in real-time

## Option 2: Install gcloud via Windows Package Manager

```powershell
# If you have Windows Package Manager (winget)
winget install Google.CloudSDK

# Then authenticate
gcloud auth login

# Set project
gcloud config set project YOUR-PROJECT-ID

# Submit build
cd "c:\Users\user\Documents\flutter_application_stars\flutter_stars_app"
gcloud builds submit --config=cloudbuild.yaml
```

## Option 3: Use REST API with PowerShell

```powershell
# Authenticate with Google Cloud
gcloud auth login

# Get credentials
$token = gcloud auth print-access-token
$projectId = gcloud config get-value project

# Create build request
$buildRequest = @{
    source = @{
        repoSource = @{
            repoName = "flutter-stars-app"
            branchName = "main"
        }
    }
    steps = @(
        @{
            name = "gcr.io/cloud-builders/gke-deploy"
            entrypoint = "bash"
            args = @("-c", "flutter --version")
        }
    )
} | ConvertTo-Json

# Submit build
$uri = "https://cloudbuild.googleapis.com/v1/projects/$projectId/builds"
Invoke-WebRequest -Uri $uri `
    -Method POST `
    -Headers @{"Authorization" = "Bearer $token"} `
    -Body $buildRequest `
    -ContentType "application/json"
```

## What the Build Will Do

Once triggered, Cloud Build will:

1. ✅ Detect `cloudbuild.yaml` in your repo
2. ✅ Install Flutter SDK
3. ✅ Run `flutter pub get`
4. ✅ Build APK: `flutter build apk --release`
5. ✅ Build App Bundle: `flutter build appbundle --release`
6. ✅ Store artifacts in Cloud Storage
7. ✅ Display build logs in console

## Monitor Your Build

**Cloud Build Console:**
https://console.cloud.google.com/cloud-build/builds

**View Logs:**
- Click on the Build ID
- See real-time output and errors
- Download artifacts when complete

## Expected Build Time

First build: **8-15 minutes** (downloads Flutter SDK)
Subsequent builds: **3-5 minutes** (uses cached layers)

## Troubleshooting

**Build Fails?**
- Check the build logs for specific errors
- Verify `cloudbuild.yaml` syntax
- Ensure keystore credentials are set
- Check Cloud Build service account permissions

**No Trigger Found?**
- Create a new trigger in Cloud Build console
- Connect your GitHub repository
- Point to `cloudbuild.yaml`

## Next Steps

1. Go to: https://console.cloud.google.com/cloud-build/triggers
2. Find or create your trigger
3. Click "Run" to trigger a build
4. Monitor progress in real-time
