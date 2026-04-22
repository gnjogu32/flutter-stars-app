# PowerShell script to copy the release APK to a known location for distribution
$apkSource = "android/app/build/outputs/apk/release/app-release.apk"
$apkDestDir = "build/latest-apk"
$apkDest = "$apkDestDir/app-release.apk"

if (!(Test-Path $apkSource)) {
    Write-Error "APK not found at $apkSource. Build may have failed."
    exit 1
}

if (!(Test-Path $apkDestDir)) {
    New-Item -ItemType Directory -Path $apkDestDir | Out-Null
}

Copy-Item $apkSource $apkDest -Force
Write-Host "Copied APK to $apkDest"
