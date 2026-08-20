param(
    [string]$AppName = 'STARPAGE',
    [string]$Tagline = 'Where Creativity Meets Community'
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Resize-And-SavePng {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$Width,
        [int]$Height
    )

    $src = $null
    $bmp = $null
    $g = $null
    try {
        $src = [System.Drawing.Image]::FromFile($SourcePath)
        $bmp = New-Object System.Drawing.Bitmap($Width, $Height)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($src, 0, 0, $Width, $Height)
        $bmp.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        if ($g) { $g.Dispose() }
        if ($bmp) { $bmp.Dispose() }
        if ($src) { $src.Dispose() }
    }
}

function New-FeatureGraphic {
    param(
        [string]$IconPath,
        [string]$DestinationPath,
        [string]$Title,
        [string]$Subtitle
    )

    $width = 1024
    $height = 500
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)

    $icon = $null
    $iconBack = $null
    $titleFont = $null
    $subtitleFont = $null
    $detailFont = $null
    $titleBrush = $null
    $subBrush = $null

    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

        $rect = New-Object System.Drawing.Rectangle(0, 0, $width, $height)
        $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect,
            [System.Drawing.Color]::FromArgb(255, 15, 22, 45),
            [System.Drawing.Color]::FromArgb(255, 28, 58, 125),
            25
        )
        $g.FillRectangle($grad, $rect)
        $grad.Dispose()

        # Decorative glow circles.
        $circleBrush1 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 255, 255, 255))
        $circleBrush2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 112, 189, 255))
        $g.FillEllipse($circleBrush1, 700, -80, 420, 420)
        $g.FillEllipse($circleBrush2, -120, 280, 420, 420)
        $circleBrush1.Dispose()
        $circleBrush2.Dispose()

        # Icon panel.
        $iconBack = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
        $g.FillEllipse($iconBack, 70, 110, 280, 280)

        $icon = [System.Drawing.Image]::FromFile($IconPath)
        $g.DrawImage($icon, 95, 135, 230, 230)

        $titleFont = New-Object System.Drawing.Font('Segoe UI', 68, [System.Drawing.FontStyle]::Bold)
        $subtitleFont = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Regular)
        $detailFont = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Regular)
        $titleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 225, 236, 255))

        $g.DrawString($Title, $titleFont, $titleBrush, 390, 130)
        $g.DrawString($Subtitle, $subtitleFont, $subBrush, 392, 235)
        $g.DrawString('Create  •  Connect  •  Discover', $detailFont, $subBrush, 394, 285)

        $bmp.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        if ($subBrush) { $subBrush.Dispose() }
        if ($titleBrush) { $titleBrush.Dispose() }
        if ($detailFont) { $detailFont.Dispose() }
        if ($subtitleFont) { $subtitleFont.Dispose() }
        if ($titleFont) { $titleFont.Dispose() }
        if ($iconBack) { $iconBack.Dispose() }
        if ($icon) { $icon.Dispose() }
        if ($g) { $g.Dispose() }
        if ($bmp) { $bmp.Dispose() }
    }
}

$projectRoot = (Get-Location).Path
$graphicsDir = Join-Path $projectRoot 'play_store_materials\graphics'
Ensure-Directory -Path $graphicsDir

$sourceIcon = Join-Path $projectRoot 'assets\icon.png'
if (-not (Test-Path -LiteralPath $sourceIcon)) {
    throw "Source icon not found: $sourceIcon"
}

$appIconOut = Join-Path $graphicsDir 'app_icon_512.png'
$featureOut = Join-Path $graphicsDir 'feature_graphic_1024x500.png'

Resize-And-SavePng -SourcePath $sourceIcon -DestinationPath $appIconOut -Width 512 -Height 512
New-FeatureGraphic -IconPath $sourceIcon -DestinationPath $featureOut -Title $AppName -Subtitle $Tagline

Write-Host 'Generated Play Store graphics:'
Write-Host $appIconOut
Write-Host $featureOut