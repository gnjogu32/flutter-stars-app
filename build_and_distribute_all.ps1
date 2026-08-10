# PowerShell script to build, copy, upload APK, and notify testers in one step

# Step 1: Build APK
Write-Host "Building APK..."

flutter build apk --release
$possiblePaths = @(
    "build/app/outputs/flutter-apk/app-release.apk",
    "android/app/build/outputs/flutter-apk/app-release.apk",
    "android/app/build/outputs/apk/release/app-release.apk"
)
$apkPath = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $apkPath = $path
        break
    }
}
if ($LASTEXITCODE -ne 0) {
    if (-not $apkPath) {
        Write-Error "Flutter build failed and APK not found. Aborting."
        exit 1
    } else {
        Write-Warning "Flutter build reported failure, but APK was found at $apkPath. Continuing..."
    }
}

# Step 2: Copy APK to known location
Write-Host "Copying APK..."
powershell -ExecutionPolicy Bypass -File copy_release_apk.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "APK copy failed. Aborting."
    exit 1
}

# Step 3: Upload to Firebase and notify testers
Write-Host "Uploading to Firebase and notifying testers..."
powershell -ExecutionPolicy Bypass -File upload_and_notify_firebase.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Firebase upload failed."
    exit 1
}

Write-Host "All steps completed successfully."
