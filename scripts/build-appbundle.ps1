#!/usr/bin/env pwsh
<#
.SYNOPSIS
Build Starpage release App Bundle for Google Play Store.

.DESCRIPTION
This script builds a release App Bundle (AAB) with automatic signing.
Environment variables KEYSTORE_PASSWORD and KEY_PASSWORD must be set.
App Bundle is required for Google Play Store distribution.

.PARAMETER VersionName
The version name (e.g., 1.0.0)

.PARAMETER VersionCode
The version code/build number (e.g., 1)

.EXAMPLE
.\build-appbundle.ps1 -VersionName "1.0.0" -VersionCode 1
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

function Build-AppBundle {
    Write-Header "Building Release App Bundle"
    
    Write-Step "Building App Bundle (Version: $VersionName, Code: $VersionCode)..."
    Write-Host "This is the format required for Google Play Store distribution." -ForegroundColor Cyan
    
    try {
        flutter build appbundle `
            --release `
            --build-name=$VersionName `
            --build-number=$VersionCode
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "App Bundle build failed with exit code $LASTEXITCODE"
            exit 1
        }
        
        Write-Success "App Bundle built successfully!"
    }
    catch {
        Write-Error "Build failed: $_"
        exit 1
    }
}

function Get-BundleInfo {
    $bundlePath = "build/app/outputs/bundle/release/app-release.aab"
    
    if (Test-Path $bundlePath) {
        $bundleSize = (Get-Item $bundlePath).Length / 1MB
        Write-Success "App Bundle: $bundlePath"
        Write-Success "Size: $([math]::Round($bundleSize, 2)) MB"
        return $bundlePath
    }
    
    return $null
}

function Show-Summary {
    param([string]$BundlePath)
    
    Write-Header "Build Summary"
    
    if ($BundlePath) {
        Write-Success "App Bundle created: $BundlePath"
        Write-Host "`nNext steps for Google Play Store:"
        Write-Host "1. Go to https://play.google.com/console" -ForegroundColor Green
        Write-Host "2. Create new app or select existing app" -ForegroundColor Green
        Write-Host "3. Navigate to 'Release' → 'Production'" -ForegroundColor Green
        Write-Host "4. Click 'Create new release'" -ForegroundColor Green
        Write-Host "5. Upload: $BundlePath" -ForegroundColor Green
        Write-Host "6. Review app details and submit for review" -ForegroundColor Green
        Write-Host "`nAdditional setup needed in Google Play Console:"
        Write-Host "• Screenshots (2-8 per language)" -ForegroundColor Cyan
        Write-Host "• App icon (512x512 PNG)" -ForegroundColor Cyan
        Write-Host "• Feature graphic (1024x500 PNG)" -ForegroundColor Cyan
        Write-Host "• Description (max 4000 characters)" -ForegroundColor Cyan
        Write-Host "• Short description (max 80 characters)" -ForegroundColor Cyan
        Write-Host "• Content rating questionnaire" -ForegroundColor Cyan
        Write-Host "• Privacy policy URL" -ForegroundColor Cyan
    }
    else {
        Write-Error "App Bundle not found!"
        exit 1
    }
}

# Main execution
try {
    Check-Prerequisites
    Clean-Project
    Build-AppBundle
    $bundlePath = Get-BundleInfo
    Show-Summary $bundlePath
}
catch {
    Write-Error "Build script failed: $_"
    exit 1
}
