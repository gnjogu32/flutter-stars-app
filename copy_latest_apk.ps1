# PowerShell script to automate APK handling for Flutter builds
# 1. Finds the latest APK in standard output locations
# 2. Copies it to a central location (e.g., ./build/latest-apk/)
# 3. Optionally triggers Firebase App Distribution upload

$apkDirs = @(
    "android/app/build/outputs/apk/release",
    "android/app/build/outputs/flutter-apk"
)

$latestApk = $null
$latestTime = 0
foreach ($dir in $apkDirs) {
    if (Test-Path $dir) {
        $apks = Get-ChildItem -Path $dir -Filter *.apk -Recurse | Sort-Object LastWriteTime -Descending
        if ($apks.Count -gt 0 -and $apks[0].LastWriteTime.Ticks -gt $latestTime) {
            $latestApk = $apks[0]
            $latestTime = $apks[0].LastWriteTime.Ticks
        }
    }
}

if ($latestApk -ne $null) {
    $destDir = "build/latest-apk"
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
    $destPath = Join-Path $destDir $latestApk.Name
    Copy-Item $latestApk.FullName $destPath -Force
    Write-Host "Copied latest APK to $destPath"
    # Optional: Uncomment to upload to Firebase App Distribution
    # firebase appdistribution:distribute $destPath --app 1:246255479274:android:177b790682bb5b59862a93 --groups testers --release-notes "Automated build and distribution"
} else {
    Write-Host "No APK found in standard output locations."
}
