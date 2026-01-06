#!/bin/pwsh
<#
.SYNOPSIS
    Build and distribute Flutter app in one command
.DESCRIPTION
    Builds release APK and distributes to Firebase App Distribution
.PARAMETER AppId
    Firebase App ID (required)
.PARAMETER Testers
    Comma-separated tester emails (required)
.PARAMETER ReleaseNotes
    Release notes for distribution
.PARAMETER SkipTests
    Skip running tests before build
.PARAMETER SkipAnalyze
    Skip code analysis before build
.EXAMPLE
    .\build-and-distribute.ps1 -AppId "1:123:android:abc" -Testers "test@example.com" -ReleaseNotes "v1.0.0"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AppId,
    
    [Parameter(Mandatory=$true)]
    [string]$Testers,
    
    [string]$ReleaseNotes = "Release build",
    
    [switch]$SkipTests,
    
    [switch]$SkipAnalyze,
    
    [string]$ApkPath = "build/app/outputs/flutter-apk/app-release.apk"
)

$ErrorActionPreference = "Stop"
$startTime = Get-Date

function Write-Status {
    param([string]$Message, [string]$Color = "Green")
    Write-Host ">>> $Message" -ForegroundColor $Color
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "!!! $Message" -ForegroundColor Red
    exit 1
}

function Write-Duration {
    param([DateTime]$Start)
    $duration = (Get-Date) - $Start
    Write-Host "    Duration: $([math]::Round($duration.TotalMinutes, 2)) minutes"
}

try {
    Write-Status "Build and Distribute Pipeline" "Cyan"
    Write-Status "===============================" "Cyan"
    Write-Host ""
    
    # Step 1: Code Analysis
    if (-not $SkipAnalyze) {
        Write-Status "Step 1: Running code analysis..."
        flutter analyze
        Write-Duration $startTime
        Write-Host ""
    }
    
    # Step 2: Tests
    if (-not $SkipTests) {
        Write-Status "Step 2: Running tests..."
        flutter test
        Write-Duration $startTime
        Write-Host ""
    }
    
    # Step 3: Build
    $buildStart = Get-Date
    Write-Status "Step 3: Building release APK..." "Yellow"
    flutter build apk --release
    
    if (-not (Test-Path $ApkPath)) {
        Write-Error-Custom "APK build failed - file not found"
    }
    
    $apkSize = (Get-Item $ApkPath).Length / 1MB
    Write-Status "APK built successfully: $([math]::Round($apkSize, 2)) MB"
    Write-Duration $buildStart
    Write-Host ""
    
    # Step 4: Distribution
    $distStart = Get-Date
    Write-Status "Step 4: Distributing to Firebase..." "Yellow"
    
    # Check Firebase CLI
    firebase --version 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Firebase CLI not found. Install with: npm install -g firebase-tools"
    }
    
    # Verify authentication
    firebase projects:list 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Not authenticated with Firebase. Run: firebase login"
    }
    
    Write-Status "Starting Firebase distribution..."
    Write-Host "  App ID: $AppId"
    Write-Host "  Testers: $Testers"
    Write-Host "  Release Notes: $ReleaseNotes"
    
    firebase appdistribution:distribute $ApkPath `
        --app="$AppId" `
        --release-notes="$ReleaseNotes" `
        --testers="$Testers"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Firebase distribution failed"
    }
    
    Write-Status "Distribution successful!" "Green"
    Write-Duration $distStart
    Write-Host ""
    
    # Summary
    $totalDuration = (Get-Date) - $startTime
    Write-Status "Pipeline completed successfully!" "Green"
    Write-Host "Total time: $([math]::Round($totalDuration.TotalMinutes, 2)) minutes"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Testers will receive invitation emails"
    Write-Host "  2. Check Firebase Console for distribution status"
    Write-Host "  3. Monitor tester feedback"
    
}
catch {
    Write-Error-Custom "Pipeline failed: $_"
}
