#!/bin/pwsh
<#
.SYNOPSIS
    Bump version and create release tag
.DESCRIPTION
    Updates version in pubspec.yaml, creates git tag, and pushes to origin
.PARAMETER Version
    Version number (e.g., 1.0.0)
.PARAMETER Message
    Release message/notes
.EXAMPLE
    .\bump-version.ps1 -Version "1.0.0" -Message "Initial release"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [string]$Message = "Release version $Version"
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
    Write-Status "Version Bump Helper" "Cyan"
    Write-Status "===================" "Cyan"
    Write-Host ""
    
    # Validate version format
    if ($Version -notmatch '^\d+\.\d+\.\d+$') {
        Write-Error-Custom "Invalid version format. Use semantic versioning (e.g., 1.0.0)"
    }
    
    Write-Status "Version: $Version"
    Write-Status "Message: $Message"
    Write-Host ""
    
    # Check git status
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-Error-Custom "Working directory has uncommitted changes. Commit or stash them first."
    }
    
    Write-Status "Working directory clean"
    
    # Update pubspec.yaml
    Write-Status "Updating pubspec.yaml..."
    $pubspecPath = "pubspec.yaml"
    
    if (-not (Test-Path $pubspecPath)) {
        Write-Error-Custom "pubspec.yaml not found"
    }
    
    # Read current version
    $content = Get-Content $pubspecPath -Raw
    $currentVersion = $content -match 'version:\s+(\S+)' | ForEach-Object { $matches[1] }
    
    if (-not $currentVersion) {
        Write-Error-Custom "Could not find version in pubspec.yaml"
    }
    
    # Update version (increment build number)
    $buildNumber = [int]($currentVersion.Split('+')[1] -replace '[^0-9]')
    $newBuildNumber = $buildNumber + 1
    $newVersionString = "$Version+$newBuildNumber"
    
    # Replace version
    $newContent = $content -replace "version:\s+\S+", "version: $newVersionString"
    Set-Content $pubspecPath -Value $newContent -Encoding UTF8
    
    Write-Status "Updated version: $currentVersion -> $newVersionString"
    
    # Commit
    Write-Status "Creating git commit..."
    git add pubspec.yaml pubspec.lock
    git commit -m "Bump version to $newVersionString"
    
    Write-Status "Commit created"
    
    # Create tag
    Write-Status "Creating git tag..."
    $tagName = "v$Version"
    git tag -a $tagName -m "$Message"
    
    Write-Status "Tag created: $tagName"
    
    # Push
    Write-Status "Pushing to origin..." "Yellow"
    git push origin main
    git push origin $tagName
    
    Write-Status "Push completed!" "Green"
    Write-Host ""
    Write-Status "Release workflow triggered!" "Green"
    Write-Host "  Version: $newVersionString"
    Write-Host "  Tag: $tagName"
    Write-Host "  Message: $Message"
    Write-Host ""
    Write-Host "GitHub Actions will:"
    Write-Host "  1. Build release APK"
    Write-Host "  2. Distribute to Firebase"
    Write-Host "  3. Notify testers"
    Write-Host ""
    Write-Host "Monitor progress: https://github.com/YOUR_REPO/actions"
    
}
catch {
    Write-Error-Custom "Error: $_"
}
