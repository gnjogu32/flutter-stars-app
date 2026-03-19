#!/bin/pwsh
<#
.SYNOPSIS
    Distribute Flutter app via Firebase App Distribution
.DESCRIPTION
    Builds and distributes APK to Firebase App Distribution with tester notifications
.PARAMETER AppId
    Firebase App ID (required)
.PARAMETER Testers
    Comma-separated tester emails (required)
.PARAMETER ReleaseNotes
    Release notes for distribution
.PARAMETER ApkPath
    Path to APK file (defaults to release APK)
.EXAMPLE
    .\distribute.ps1 -AppId "1:123456789:android:abc123" -Testers "tester@example.com" -ReleaseNotes "Bug fixes and improvements"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$AppId,
    
    [Parameter(Mandatory=$true)]
    [string]$Testers,
    
    [string]$ReleaseNotes = "New build distribution",
    
    [string]$ApkPath = "build/app/outputs/flutter-apk/app-release.apk",

    [string]$ProjectId = ""
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message, [string]$Color = "Green")
    Write-Host ">>> $Message" -ForegroundColor $Color
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "!!! $Message" -ForegroundColor Red
    exit 1
}

try {
    Write-Status "Firebase App Distribution Helper"
    Write-Status "================================" "Cyan"
    
    # Check APK exists
    if (-not (Test-Path $ApkPath)) {
        Write-Error-Custom "APK not found at: $ApkPath"
    }
    
    Write-Status "APK found: $ApkPath"
    $apkSize = (Get-Item $ApkPath).Length / 1MB
    Write-Status "APK size: $([math]::Round($apkSize, 2)) MB"
    
    # Check Firebase CLI
    $firebaseCli = firebase --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Firebase CLI not found. Install with: npm install -g firebase-tools"
    }
    
    Write-Status "Firebase CLI version: $firebaseCli"
    
    # Verify authentication (projects:list can fail for users without project-list permissions)
    Write-Status "Checking Firebase authentication..."
    firebase login:list 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Not authenticated with Firebase. Run: firebase login"
    }

    # Resolve project ID from .firebaserc when not provided.
    if ([string]::IsNullOrWhiteSpace($ProjectId) -and (Test-Path ".firebaserc")) {
        try {
            $firebaserc = Get-Content ".firebaserc" -Raw | ConvertFrom-Json
            if ($firebaserc.projects.default) {
                $ProjectId = $firebaserc.projects.default
            }
        } catch {
            # If parsing fails, continue without forcing --project.
        }
    }
    
    Write-Status "Authentication verified"
    
    # Distribution command
    Write-Status "Starting distribution..." "Yellow"
    Write-Status "App ID: $AppId"
    Write-Status "Testers: $Testers"
    Write-Status "Release Notes: $ReleaseNotes"
    Write-Status ""
    
    # Execute distribution
    $distArgs = @(
        "appdistribution:distribute",
        $ApkPath,
        "--app=$AppId",
        "--release-notes=$ReleaseNotes",
        "--testers=$Testers",
        "--non-interactive"
    )
    if (-not [string]::IsNullOrWhiteSpace($ProjectId)) {
        $distArgs += "--project=$ProjectId"
    }
    firebase @distArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Distribution successful!" "Green"
        Write-Status "Testers will receive invitation emails shortly."
        Write-Status "Check Firebase Console for distribution status."
    } else {
        Write-Error-Custom "Distribution failed. Check Firebase CLI output above."
    }
    
}
catch {
    Write-Error-Custom "Error: $_"
}
