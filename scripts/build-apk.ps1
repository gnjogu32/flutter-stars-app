#!/usr/bin/env pwsh
<#
.SYNOPSIS
Build Starpage release APK with automatic signing.

.DESCRIPTION
This script builds a release APK with proper signing configuration.
Environment variables KEYSTORE_PASSWORD and KEY_PASSWORD must be set.

.PARAMETER VersionName
The version name (e.g., 1.0.0)

.PARAMETER VersionCode
The version code/build number (e.g., 1)

.EXAMPLE
.\build-apk.ps1 -VersionName "1.0.0" -VersionCode 1
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$VersionName = "1.0.0",
    
    [Parameter(Mandatory=$false)]
    [int]$VersionCode = 1
)

# Set strict error handling
$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Check-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check Flutter
    Write-Step "Checking Flutter installation..."
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Error "Flutter not found in PATH"
        exit 1
    }
    Write-Success "Flutter found"
    
    # Check Keystore
    Write-Step "Checking keystore file..."
    if (-not (Test-Path "android/starpage-keystore.jks")) {
        Write-Error "Keystore not found at android/starpage-keystore.jks"
        Write-Host "Run KEYSTORE_SETUP_GUIDE.md to generate keystore" -ForegroundColor Yellow
        exit 1
    }
    Write-Success "Keystore found"
    
    # Check Environment Variables
    Write-Step "Checking environment variables..."
    if (-not $env:KEYSTORE_PASSWORD) {
        Write-Error "KEYSTORE_PASSWORD not set"
        exit 1
    }
    Write-Success "KEYSTORE_PASSWORD set"
    
    if (-not $env:KEY_PASSWORD) {
        Write-Error "KEY_PASSWORD not set"
        exit 1
    }
    Write-Success "KEY_PASSWORD set"
}

function Clean-Project {
    Write-Header "Cleaning Project"
    
    Write-Step "Running flutter clean..."
    flutter clean
    
    Write-Step "Running flutter pub get..."
    flutter pub get
    
    Write-Success "Project cleaned and dependencies installed"
}

function Build-APK {
    Write-Header "Building Release APK"
    
    Write-Step "Building APK (Version: $VersionName, Code: $VersionCode)..."
    
    try {
        flutter build apk `
            --release `
            --build-name=$VersionName `
            --build-number=$VersionCode
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "APK build failed with exit code $LASTEXITCODE"
            exit 1
        }
        
        Write-Success "APK built successfully!"
    }
    catch {
        Write-Error "Build failed: $_"
        exit 1
    }
}

function Get-APKInfo {
    $apkPath = "build/app/outputs/flutter-release.apk"
    
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Success "APK: $apkPath"
        Write-Success "Size: $([math]::Round($apkSize, 2)) MB"
        return $apkPath
    }
    
    return $null
}

function Show-Summary {
    param([string]$APKPath)
    
    Write-Header "Build Summary"
    
    if ($APKPath) {
        Write-Success "APK created: $APKPath"
        Write-Host "`nNext steps:"
        Write-Host "1. Test on device: adb install $APKPath" -ForegroundColor Green
        Write-Host "2. Or use Flutter: flutter install $APKPath" -ForegroundColor Green
        Write-Host "3. Run tests to verify functionality" -ForegroundColor Green
        Write-Host "4. For Play Store, use: .\build-appbundle.ps1" -ForegroundColor Green
    }
    else {
        Write-Error "APK not found!"
        exit 1
    }
}

# Main execution
try {
    Check-Prerequisites
    Clean-Project
    Build-APK
    $apkPath = Get-APKInfo
    Show-Summary $apkPath
}
catch {
    Write-Error "Build script failed: $_"
    exit 1
}
