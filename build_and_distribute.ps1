# --- Permanent Flutter APK Build & Firebase App Distribution Workflow ---
#
# Prerequisites:
# - Flutter, Dart, Node.js, npm, and Firebase CLI installed
# - npm global bin directory in PATH (see below)
# - Update $APP_ID and $TESTER_GROUP as needed

$APP_ID = "1:246255479274:android:177b790682bb5b59862a93"  # <-- Update as needed
$TESTER_GROUP = "testers"  # <-- Update as needed
$APK_PATH = "build/app/outputs/flutter-apk/app-release.apk"
$RELEASE_NOTES = "Automated build upload via script."

# Ensure npm global bin is in PATH for firebase-tools
$env:Path += ";C:\Users\user\AppData\Roaming\npm"

Write-Host "--- Flutter Clean ---"
flutter clean
Write-Host "--- Flutter Pub Get ---"
flutter pub get
Write-Host "--- Flutter Build APK ---"
flutter build apk

Write-Host "--- Firebase App Distribution ---"
firebase appdistribution:distribute $APK_PATH --app $APP_ID --groups $TESTER_GROUP --release-notes $RELEASE_NOTES
