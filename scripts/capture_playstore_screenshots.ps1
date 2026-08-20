param(
    [string]$DeviceId,
    [switch]$UseCurrentScreenOnly
)

$ErrorActionPreference = 'Stop'

function Get-AdbPath {
    $roots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        "$env:LOCALAPPDATA\Android\Sdk",
        "$env:USERPROFILE\AppData\Local\Android\Sdk"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $roots) {
        $candidate = Join-Path $root 'platform-tools\adb.exe'
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw 'adb.exe not found. Install Android SDK platform-tools or set ANDROID_SDK_ROOT.'
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Capture-DeviceScreenshot {
    param(
        [string]$Adb,
        [string]$Serial,
        [string]$OutFile
    )

    $remotePath = '/sdcard/starpage_playstore_capture.png'
    & $Adb -s $Serial shell screencap -p $remotePath | Out-Null
    & $Adb -s $Serial pull $remotePath $OutFile | Out-Null
    & $Adb -s $Serial shell rm $remotePath | Out-Null
    if (-not (Test-Path -LiteralPath $OutFile)) {
        throw "Failed to capture screenshot to $OutFile"
    }
}

function Resize-ForPlayStore {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [int]$TargetWidth = 1080,
        [int]$TargetHeight = 1920
    )

    Add-Type -AssemblyName System.Drawing
    $image = $null
    $canvas = $null
    $graphics = $null
    try {
        $image = [System.Drawing.Image]::FromFile($InputFile)
        $scale = [Math]::Max($TargetWidth / $image.Width, $TargetHeight / $image.Height)
        $scaledWidth = [int][Math]::Ceiling($image.Width * $scale)
        $scaledHeight = [int][Math]::Ceiling($image.Height * $scale)
        $offsetX = [int](($TargetWidth - $scaledWidth) / 2)
        $offsetY = [int](($TargetHeight - $scaledHeight) / 2)

        $canvas = New-Object System.Drawing.Bitmap($TargetWidth, $TargetHeight)
        $graphics = [System.Drawing.Graphics]::FromImage($canvas)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.Clear([System.Drawing.Color]::Black)
        $graphics.DrawImage($image, $offsetX, $offsetY, $scaledWidth, $scaledHeight)

        $canvas.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        if ($graphics) { $graphics.Dispose() }
        if ($canvas) { $canvas.Dispose() }
        if ($image) { $image.Dispose() }
    }
}

$projectRoot = (Get-Location).Path
$adb = Get-AdbPath

$devicesRaw = & $adb devices
$deviceLines = $devicesRaw | Where-Object { $_ -match "\tdevice$" }
if (-not $deviceLines) {
    throw 'No Android device detected by adb. Connect device and enable USB debugging.'
}

$availableSerials = @()
foreach ($line in $deviceLines) {
    $parts = $line -split "\t"
    if ($parts[0]) { $availableSerials += $parts[0] }
}

if (-not $DeviceId) {
    if ($availableSerials.Count -gt 1) {
        throw "Multiple devices connected. Re-run with -DeviceId. Found: $($availableSerials -join ', ')"
    }
    $DeviceId = $availableSerials[0]
}

if ($availableSerials -notcontains $DeviceId) {
    throw "Device '$DeviceId' not found. Connected: $($availableSerials -join ', ')"
}

$baseDir = Join-Path $projectRoot 'play_store_materials\graphics\screenshots'
$rawDir = Join-Path $baseDir 'raw'
$finalDir = Join-Path $baseDir 'final_1080x1920'
Ensure-Directory -Path $baseDir
Ensure-Directory -Path $rawDir
Ensure-Directory -Path $finalDir

$captureList = @(
    '01_home_feed',
    '02_create_post',
    '03_user_profile',
    '04_post_detail',
    '05_direct_messages',
    '06_notifications',
    '07_search',
    '08_edit_profile'
)

if ($UseCurrentScreenOnly) {
    $captureList = @('manual_capture')
}

Write-Host "Using adb: $adb"
Write-Host "Using device: $DeviceId"
Write-Host ""

foreach ($name in $captureList) {
    if (-not $UseCurrentScreenOnly) {
        Write-Host "Open this screen on your phone now: $name"
        Write-Host "Press Enter to capture..."
        [void][System.Console]::ReadLine()
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $rawFile = Join-Path $rawDir ($name + '_' + $timestamp + '.png')
    $finalFile = Join-Path $finalDir ($name + '.png')

    Capture-DeviceScreenshot -Adb $adb -Serial $DeviceId -OutFile $rawFile
    Resize-ForPlayStore -InputFile $rawFile -OutputFile $finalFile

    Write-Host "Captured: $finalFile"
}

Write-Host ""
Write-Host 'Done. Play Store-ready screenshots are in:'
Write-Host $finalDir