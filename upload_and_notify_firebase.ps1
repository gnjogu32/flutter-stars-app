
# PowerShell script to upload APK to Firebase App Distribution and notify testers
$apkPath = "build/latest-apk/app-release.apk"
$firebaseAppId = "1:246255479274:android:177b790682bb5b59862a93"
$testerGroups = "testers"
$releaseNotes = "Automated build and distribution"

if (!(Test-Path $apkPath)) {
	Write-Error "APK not found at $apkPath. Run the build and copy scripts first."
	exit 1
}

$firebaseArgs = @(
	"appdistribution:distribute"
	$apkPath
	"--app"
	$firebaseAppId
	"--groups"
	$testerGroups
	"--release-notes"
	$releaseNotes
)

Write-Host "Uploading APK to Firebase App Distribution..."
& firebase @firebaseArgs
Write-Host "Upload complete. Testers will be notified by Firebase."

