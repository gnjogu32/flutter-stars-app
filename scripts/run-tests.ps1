#!/usr/bin/env pwsh
<#
.SYNOPSIS
Run all tests for Starpage application.

.DESCRIPTION
This script runs unit tests, widget tests, and generates coverage reports.

.PARAMETER CoverageReport
If true, generates HTML coverage report

.EXAMPLE
.\run-tests.ps1
.\run-tests.ps1 -CoverageReport $true
#>

param(
    [Parameter(Mandatory=$false)]
    [boolean]$CoverageReport = $false
)

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

Write-Header "Running Starpage Tests"

Write-Step "Checking dependencies..."
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter not found"
    exit 1
}
Write-Success "Flutter found"

Write-Step "Getting dependencies..."
flutter pub get

if ($CoverageReport) {
    Write-Header "Running Tests with Coverage"
    Write-Step "Running tests with coverage analysis..."
    
    flutter test --coverage
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Tests passed!"
        
        # Try to generate HTML report if lcov is available
        if (Get-Command genhtml -ErrorAction SilentlyContinue) {
            Write-Step "Generating HTML coverage report..."
            genhtml coverage/lcov.info -o coverage/html
            Write-Success "Coverage report: coverage/html/index.html"
        }
        else {
            Write-Host "lcov not installed. Install with: choco install lcov" -ForegroundColor Yellow
            Write-Host "Raw coverage data available at: coverage/lcov.info" -ForegroundColor Cyan
        }
    }
    else {
        Write-Error "Tests failed!"
        exit 1
    }
}
else {
    Write-Header "Running Tests"
    Write-Step "Running all tests..."
    
    flutter test
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "All tests passed!"
    }
    else {
        Write-Error "Some tests failed!"
        exit 1
    }
}

Write-Header "Test Run Complete"
Write-Host "✓ Ready for deployment!" -ForegroundColor Green
