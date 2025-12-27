#!/usr/bin/env pwsh
<#
.SYNOPSIS
Complete pre-deployment checklist for Starpage Android app.

.DESCRIPTION
This script guides you through all pre-deployment checks and requirements.
#>

$ErrorActionPreference = "Continue"

$checklist = @{
    "Authentication" = @(
        @{ Task = "Sign up with email"; Checked = $false }
        @{ Task = "Login with existing account"; Checked = $false }
        @{ Task = "Password reset flow"; Checked = $false }
        @{ Task = "Auto-login persists"; Checked = $false }
        @{ Task = "Logout clears data"; Checked = $false }
    )
    "UI & Performance" = @(
        @{ Task = "All screens load without crashes"; Checked = $false }
        @{ Task = "No debug logs visible"; Checked = $false }
        @{ Task = "Responsive on different sizes"; Checked = $false }
        @{ Task = "Smooth animations"; Checked = $false }
        @{ Task = "No ANR errors"; Checked = $false }
        @{ Task = "App size reasonable"; Checked = $false }
    )
    "Firebase Integration" = @(
        @{ Task = "Firestore queries work"; Checked = $false }
        @{ Task = "Cloud Storage uploads"; Checked = $false }
        @{ Task = "Firebase Auth mutations"; Checked = $false }
        @{ Task = "Offline mode works"; Checked = $false }
        @{ Task = "Real-time updates work"; Checked = $false }
    )
    "Permissions (Android)" = @(
        @{ Task = "Camera permission request"; Checked = $false }
        @{ Task = "Photo gallery access"; Checked = $false }
        @{ Task = "Storage permission handling"; Checked = $false }
        @{ Task = "Denied permissions handled"; Checked = $false }
        @{ Task = "Permission re-request works"; Checked = $false }
    )
    "Device Compatibility" = @(
        @{ Task = "Test on Android 8.0+"; Checked = $false }
        @{ Task = "Test on 2+ physical devices"; Checked = $false }
        @{ Task = "Test on Android emulator"; Checked = $false }
        @{ Task = "Different screen sizes"; Checked = $false }
        @{ Task = "Different languages/locales"; Checked = $false }
    )
    "Network Conditions" = @(
        @{ Task = "Test on 4G/LTE"; Checked = $false }
        @{ Task = "Test on WiFi"; Checked = $false }
        @{ Task = "Test with poor network"; Checked = $false }
        @{ Task = "Offline behavior works"; Checked = $false }
        @{ Task = "Network error handling"; Checked = $false }
    )
    "Data & Security" = @(
        @{ Task = "No sensitive data in logs"; Checked = $false }
        @{ Task = "Firebase rules secure"; Checked = $false }
        @{ Task = "Keystore configured"; Checked = $false }
        @{ Task = "No hardcoded API keys"; Checked = $false }
        @{ Task = "ProGuard obfuscation works"; Checked = $false }
    )
    "Build & Release" = @(
        @{ Task = "Release build completes"; Checked = $false }
        @{ Task = "APK signed correctly"; Checked = $false }
        @{ Task = "App Bundle created"; Checked = $false }
        @{ Task = "Keystore backed up"; Checked = $false }
        @{ Task = "Version bumped correctly"; Checked = $false }
    )
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
}

function Show-Checklist {
    Write-Header "STARPAGE PRE-DEPLOYMENT CHECKLIST"
    
    $totalItems = 0
    $completedItems = 0
    
    foreach ($category in $checklist.Keys) {
        Write-Host "`n$category" -ForegroundColor Yellow
        Write-Host ("-" * 50) -ForegroundColor Gray
        
        $items = $checklist[$category]
        foreach ($item in $items) {
            $totalItems++
            $checkbox = if ($item.Checked) { "✓" } else { "☐" }
            $color = if ($item.Checked) { "Green" } else { "White" }
            Write-Host "  $checkbox $($item.Task)" -ForegroundColor $color
            if ($item.Checked) { $completedItems++ }
        }
    }
    
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    Write-Host "Progress: $completedItems / $totalItems items completed" -ForegroundColor Cyan
    $percentComplete = [math]::Round(($completedItems / $totalItems) * 100)
    Write-Host "Completion: $percentComplete%" -ForegroundColor Cyan
    Write-Host "=" * 70 -ForegroundColor Cyan
    
    return @{ Total = $totalItems; Completed = $completedItems }
}

function Show-Menu {
    Write-Host "`nOptions:" -ForegroundColor Cyan
    Write-Host "1. Mark category complete" -ForegroundColor Green
    Write-Host "2. Mark individual item" -ForegroundColor Green
    Write-Host "3. View detailed instructions" -ForegroundColor Green
    Write-Host "4. Generate report" -ForegroundColor Green
    Write-Host "5. Exit" -ForegroundColor Green
    Write-Host "Choice (1-5): " -ForegroundColor Cyan -NoNewline
}

function Mark-Category-Complete {
    Write-Host "`nCategories:" -ForegroundColor Yellow
    $categories = @($checklist.Keys)
    for ($i = 0; $i -lt $categories.Count; $i++) {
        Write-Host "$($i+1). $($categories[$i])" -ForegroundColor Cyan
    }
    
    [int]$choice = Read-Host "Select category (1-$($categories.Count))"
    if ($choice -gt 0 -and $choice -le $categories.Count) {
        $selectedCategory = $categories[$choice - 1]
        foreach ($item in $checklist[$selectedCategory]) {
            $item.Checked = $true
        }
        Write-Host "✓ $selectedCategory marked complete!" -ForegroundColor Green
    }
}

function Mark-Item-Complete {
    Write-Host "`nCategories:" -ForegroundColor Yellow
    $categories = @($checklist.Keys)
    for ($i = 0; $i -lt $categories.Count; $i++) {
        Write-Host "$($i+1). $($categories[$i])" -ForegroundColor Cyan
    }
    
    [int]$catChoice = Read-Host "Select category (1-$($categories.Count))"
    if ($catChoice -gt 0 -and $catChoice -le $categories.Count) {
        $selectedCategory = $categories[$catChoice - 1]
        $items = $checklist[$selectedCategory]
        
        Write-Host "`nItems in $selectedCategory`: -ForegroundColor Yellow
        for ($i = 0; $i -lt $items.Count; $i++) {
            Write-Host "$($i+1). $($items[$i].Task)" -ForegroundColor Cyan
        }
        
        [int]$itemChoice = Read-Host "Select item (1-$($items.Count))"
        if ($itemChoice -gt 0 -and $itemChoice -le $items.Count) {
            $items[$itemChoice - 1].Checked = $true
            Write-Host "✓ Item marked complete!" -ForegroundColor Green
        }
    }
}

function Show-Instructions {
    Write-Header "DETAILED PRE-DEPLOYMENT INSTRUCTIONS"
    
    Write-Host @"
STEP 1: LOCAL TESTING
━━━━━━━━━━━━━━━━━━━━━
1. Build debug APK:
   flutter build apk --debug

2. Install on device:
   adb install build/app/outputs/flutter-debug.apk

3. Test all features manually:
   - Authentication flows
   - Navigation between screens
   - Firebase operations
   - Permission requests
   - Network handling

STEP 2: RELEASE BUILD TESTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Run tests:
   .\scripts\run-tests.ps1

2. Build release APK:
   .\scripts\build-apk.ps1 -VersionName "1.0.0" -VersionCode 1

3. Install and test:
   adb install build/app/outputs/flutter-release.apk

4. Verify:
   - No debug logs
   - Performance optimal
   - All features work
   - App size acceptable

STEP 3: DEVICE TESTING
━━━━━━━━━━━━━━━━━━━━━━
Test on multiple devices:
- Different Android versions (8.0+)
- Different screen sizes
- Different manufacturers
- Various network conditions

Use Android Emulator:
   flutter emulators --launch Pixel_3_API_30

STEP 4: FIREBASE PRODUCTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Update Firebase Security Rules
2. Enable Firestore production mode
3. Configure Cloud Storage rules
4. Test with production database

STEP 5: BUILD FOR RELEASE
━━━━━━━━━━━━━━━━━━━━━━━━━
1. Verify keystore:
   Test-Path android/starpage-keystore.jks

2. Set environment variables:
   `$env:KEYSTORE_PASSWORD = "your_password"`
   `$env:KEY_PASSWORD = "your_password"`

3. Build App Bundle:
   .\scripts\build-appbundle.ps1 -VersionName "1.0.0" -VersionCode 1

4. Sign and align:
   (Handled automatically by build script)

STEP 6: PLAY STORE UPLOAD
━━━━━━━━━━━━━━━━━━━━━━━━━
1. Go to https://play.google.com/console
2. Create new app: "Starpage"
3. Fill in all required information
4. Upload App Bundle
5. Add screenshots and assets
6. Submit for review

Full details in ANDROID_DEPLOYMENT.md
"@ -ForegroundColor Cyan
}

function Generate-Report {
    $stats = Show-Checklist
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $reportFile = "DEPLOYMENT_CHECKLIST_REPORT.txt"
    
    $report = @"
STARPAGE DEPLOYMENT CHECKLIST REPORT
Generated: $timestamp

SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Completed: $($stats.Completed) / $($stats.Total)
Percentage: $(([math]::Round(($stats.Completed / $stats.Total) * 100)))%

DETAILED RESULTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"@
    
    foreach ($category in $checklist.Keys) {
        $report += "`n`n$category`n"
        $report += ("-" * 50) + "`n"
        
        foreach ($item in $checklist[$category]) {
            $status = if ($item.Checked) { "✓ DONE" } else { "☐ TODO" }
            $report += "$status - $($item.Task)`n"
        }
    }
    
    $report | Out-File $reportFile -Encoding UTF8
    Write-Host "Report saved to: $reportFile" -ForegroundColor Green
}

# Main loop
$isRunning = $true
while ($isRunning) {
    $progress = Show-Checklist
    
    if ($progress.Completed -eq $progress.Total) {
        Write-Host "`n🎉 ALL CHECKS COMPLETE! Ready for deployment!" -ForegroundColor Green
        break
    }
    
    Show-Menu
    $choice = Read-Host
    
    switch ($choice) {
        "1" { Mark-Category-Complete }
        "2" { Mark-Item-Complete }
        "3" { Show-Instructions }
        "4" { Generate-Report }
        "5" { 
            $isRunning = $false
            Write-Host "Exiting checklist..." -ForegroundColor Yellow
        }
        default { Write-Host "Invalid choice. Try again." -ForegroundColor Red }
    }
}
