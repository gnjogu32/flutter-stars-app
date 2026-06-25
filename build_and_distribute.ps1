# --- Permanent Flutter APK Build & Firebase App Distribution Workflow ---
#
# Prerequisites:
# - Flutter, Dart, Node.js, npm, and Firebase CLI installed
# - npm global bin directory in PATH (see below)
# - Update $APP_ID and $TESTER_GROUP as needed

$ErrorActionPreference = "Stop"

$APP_ID = "1:246255479274:android:177b790682bb5b59862a93"  # <-- Update as needed
$TESTER_GROUP = "alpha,beta"  # <-- Update as needed
$APK_PATH = "build/app/outputs/flutter-apk/app-release.apk"
$RELEASE_NOTES = "Release 1.1.2 (6)"

$KEY_PROPS_PATH = "android/key.properties"
if (Test-Path $KEY_PROPS_PATH) {
	$rawProps = Get-Content $KEY_PROPS_PATH | Where-Object {
		$_ -and -not $_.TrimStart().StartsWith("#") -and -not $_.TrimStart().StartsWith("!")
	}
	$props = ConvertFrom-StringData ($rawProps -join "`n")

	if ($props["storeFile"]) { $env:STORE_FILE = $props["storeFile"] }
	if ($props["storePassword"]) { $env:STORE_PASSWORD = $props["storePassword"] }
	if ($props["keyAlias"]) { $env:KEY_ALIAS = $props["keyAlias"] }
	if ($props["keyPassword"]) { $env:KEY_PASSWORD = $props["keyPassword"] }
}

# Ensure npm global bin is in PATH for firebase-tools
$env:Path += ";C:\Users\user\AppData\Roaming\npm"

Write-Host "--- Flutter Clean ---"
flutter clean
Write-Host "--- Flutter Pub Get ---"
flutter pub get
Write-Host "--- Flutter Build APK (Release) ---"
flutter build apk --release

if (!(Test-Path $APK_PATH)) {
	throw "Build artifact not found: $APK_PATH"
}

Write-Host "--- Firebase App Distribution ---"
firebase appdistribution:distribute $APK_PATH --app $APP_ID --groups $TESTER_GROUP --release-notes $RELEASE_NOTES
