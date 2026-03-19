#!/usr/bin/env pwsh
<#
.SYNOPSIS
Repairs missing Red Hat Java Gradle init script caches used by VS Code.

.DESCRIPTION
Some VS Code Java/Gradle diagnostics reference an older Red Hat Java extension
cache version path that no longer has the expected init.gradle files.

This script finds the newest valid cache under:
  %APPDATA%\Code\User\globalStorage\redhat.java
and copies the Gradle init script bundle into any version folder missing it.

.EXAMPLE
.\scripts\fix-redhat-java-gradle-init.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

$base = Join-Path $env:APPDATA 'Code\User\globalStorage\redhat.java'
if (-not (Test-Path $base)) {
    throw "Red Hat Java storage folder not found: $base"
}

$versionDirs = Get-ChildItem -Path $base -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name }

if (-not $versionDirs) {
    throw "No Red Hat Java version folders found under: $base"
}

$sourceVersionDir = $null
$sourceGradleDir = $null

for ($i = $versionDirs.Count - 1; $i -ge 0; $i--) {
    $candidate = $versionDirs[$i].FullName
    $candidateInit = Get-ChildItem -Path $candidate -Recurse -Filter init.gradle -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\\.cp\\gradle\\init\\init\.gradle$' } |
        Select-Object -First 1

    if ($candidateInit) {
        $sourceVersionDir = $candidate
        $sourceGradleDir = Split-Path (Split-Path $candidateInit.FullName -Parent) -Parent
        break
    }
}

if (-not $sourceGradleDir) {
    throw 'Could not locate a valid source Gradle init cache in any redhat.java version folder.'
}

$relativeGradlePath = $sourceGradleDir.Substring($sourceVersionDir.Length).TrimStart('\\')
Write-Info "Using source version: $(Split-Path $sourceVersionDir -Leaf)"
Write-Info "Source Gradle cache: $sourceGradleDir"

$fixed = @()
$unchanged = @()

foreach ($versionDir in $versionDirs) {
    $targetGradleDir = Join-Path $versionDir.FullName $relativeGradlePath
    $targetInit = Join-Path $targetGradleDir 'init\init.gradle'

    if (Test-Path $targetInit) {
        $unchanged += $versionDir.Name
        continue
    }

    New-Item -ItemType Directory -Path $targetGradleDir -Force | Out-Null
    Copy-Item -Path (Join-Path $sourceGradleDir '*') -Destination $targetGradleDir -Recurse -Force

    if (Test-Path $targetInit) {
        $fixed += $versionDir.Name
        Write-Ok "Repaired missing init.gradle for redhat.java $($versionDir.Name)"
    }
    else {
        Write-WarnMsg "Copy completed but target init.gradle still missing for $($versionDir.Name)"
    }
}

if ($fixed.Count -eq 0) {
    Write-Ok 'No repairs needed. All version folders already contain init.gradle.'
}
else {
    Write-Ok "Repaired versions: $($fixed -join ', ')"
}

if ($unchanged.Count -gt 0) {
    Write-Info "Already healthy versions: $($unchanged -join ', ')"
}

Write-Info 'Done. If VS Code still shows stale diagnostics, run: Java: Clean Java Language Server Workspace.'
