# PowerShell script to copy the latest APK to a standard location
$apkSrc1 = "android/app/build/outputs/flutter-apk/app-release.apk"
$apkSrc2 = "android/app/build/outputs/apk/release/app-release.apk"
$apkDst = "build/app-release-latest.apk"

if (Test-Path $apkSrc1) {
    Copy-Item $apkSrc1 $apkDst -Force
    Write-Host "Copied $apkSrc1 to $apkDst"
} elseif (Test-Path $apkSrc2) {
    Copy-Item $apkSrc2 $apkDst -Force
    Write-Host "Copied $apkSrc2 to $apkDst"
} else {
    Write-Host "No APK found to copy."
    exit 1
}
