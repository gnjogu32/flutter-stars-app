# PowerShell script to automate Firebase App Distribution upload
# Edit the APP_ID and TESTER_GROUP variables as needed

$APP_ID = "<YOUR_FIREBASE_APP_ID>"  # TODO: Replace with your Firebase App ID
$TESTER_GROUP = "<YOUR_TESTER_GROUP>"  # TODO: Replace with your tester group or emails
$APK_PATH = "build/app/outputs/flutter-apk/app-release.apk"
$RELEASE_NOTES = "Automated build upload via script."

# Check if Firebase CLI is installed
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "Firebase CLI not found. Please install with: npm install -g firebase-tools"
    exit 1
}

# Authenticate if needed
firebase login

# Distribute APK
firebase appdistribution:distribute $APK_PATH --app $APP_ID --groups "$TESTER_GROUP" --release-notes "$RELEASE_NOTES"
