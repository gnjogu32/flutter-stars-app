# PowerShell script to copy the release APK to a known location for distribution
$possiblePaths = @(
    "build/app/outputs/flutter-apk/app-release.apk",
    "android/app/build/outputs/flutter-apk/app-release.apk",
    "android/app/build/outputs/apk/release/app-release.apk"
)

$apkSource = $null
foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $apkSource = $path
        break
    }
}

$apkDestDir = "build/latest-apk"
$apkDest = "$apkDestDir/app-release.apk"

if (-not $apkSource) {
    Write-Error "APK not found in any expected location. Build may have failed."
    exit 1
}

if (!(Test-Path $apkDestDir)) {
    New-Item -ItemType Directory -Path $apkDestDir | Out-Null
}

Copy-Item $apkSource $apkDest -Force
Write-Host "Copied APK from $apkSource to $apkDest"
