# PowerShell script to find and remove duplicate MainActivity files in the workspace
# Searches for MainActivity.kt and MainActivity.java outside the main app directory

$root = "$PSScriptRoot"
$mainAppPath = Join-Path $root 'android\app\src\main\kotlin\com\starpage\app\MainActivity.kt'

# Find all MainActivity.kt and MainActivity.java files
$allMainActivities = Get-ChildItem -Path $root -Recurse -Include MainActivity.kt,MainActivity.java -ErrorAction SilentlyContinue

foreach ($file in $allMainActivities) {
    # Only keep the main app's MainActivity.kt
    if ($file.FullName -ne $mainAppPath) {
        Write-Host "Removing duplicate: $($file.FullName)"
        Remove-Item $file.FullName -Force
    } else {
        Write-Host "Keeping main: $($file.FullName)"
    }
}

Write-Host "Duplicate MainActivity cleanup complete."
