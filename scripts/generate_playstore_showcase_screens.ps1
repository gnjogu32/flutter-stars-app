param(
    [string]$InputDir = 'play_store_materials/graphics/screenshots/final_1080x1920',
    [string]$OutputDir = 'play_store_materials/graphics/screenshots/showcase_1080x1920'
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Draw-RoundedRect {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Brush]$Brush,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [int]$R
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    try {
        $d = $R * 2
        $path.AddArc($X, $Y, $d, $d, 180, 90)
        $path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
        $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
        $path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        $Graphics.FillPath($Brush, $path)
    } finally {
        $path.Dispose()
    }
}

function Draw-RoundedRectBorder {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Pen]$Pen,
        [int]$X,
        [int]$Y,
        [int]$W,
        [int]$H,
        [int]$R
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    try {
        $d = $R * 2
        $path.AddArc($X, $Y, $d, $d, 180, 90)
        $path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
        $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
        $path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        $Graphics.DrawPath($Pen, $path)
    } finally {
        $path.Dispose()
    }
}

function New-ShowcaseImage {
    param(
        [string]$InFile,
        [string]$OutFile,
        [string]$Title,
        [string]$Subtitle
    )

    $canvasW = 1080
    $canvasH = 1920
    $phoneW = 860
    $phoneH = 1570
    $phoneX = [int](($canvasW - $phoneW) / 2)
    $phoneY = 250

    $bmp = New-Object System.Drawing.Bitmap($canvasW, $canvasH)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $src = $null
    $titleFont = $null
    $subFont = $null
    $detailFont = $null
    $topCaptionFont = $null
    $topSubFont = $null

    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

        $gradRect = New-Object System.Drawing.Rectangle(0, 0, $canvasW, $canvasH)
        $bgGrad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $gradRect,
            [System.Drawing.Color]::FromArgb(255, 11, 19, 44),
            [System.Drawing.Color]::FromArgb(255, 30, 64, 148),
            20
        )
        $g.FillRectangle($bgGrad, $gradRect)
        $bgGrad.Dispose()

        $bubbleA = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(36, 255, 255, 255))
        $bubbleB = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 132, 201, 255))
        $g.FillEllipse($bubbleA, -160, 1220, 520, 520)
        $g.FillEllipse($bubbleB, 760, -180, 420, 420)
        $bubbleA.Dispose()
        $bubbleB.Dispose()

        # Phone shadow
        $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 0, 0, 0))
        Draw-RoundedRect -Graphics $g -Brush $shadowBrush -X ($phoneX + 14) -Y ($phoneY + 20) -W $phoneW -H $phoneH -R 78
        $shadowBrush.Dispose()

        # Phone body
        $phoneBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 22, 22, 26))
        Draw-RoundedRect -Graphics $g -Brush $phoneBrush -X $phoneX -Y $phoneY -W $phoneW -H $phoneH -R 78
        $phoneBrush.Dispose()

        $strokePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 62, 62, 70), 3)
        Draw-RoundedRectBorder -Graphics $g -Pen $strokePen -X $phoneX -Y $phoneY -W $phoneW -H $phoneH -R 78
        $strokePen.Dispose()

        # Screen area in phone body
        $screenMargin = 34
        $screenX = $phoneX + $screenMargin
        $screenY = $phoneY + 52
        $screenW = $phoneW - ($screenMargin * 2)
        $screenH = $phoneH - 92

        $screenBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
        Draw-RoundedRect -Graphics $g -Brush $screenBrush -X $screenX -Y $screenY -W $screenW -H $screenH -R 42
        $screenBrush.Dispose()

        $src = [System.Drawing.Image]::FromFile($InFile)
        $inset = 6
        $drawX = $screenX + $inset
        $drawY = $screenY + $inset
        $drawW = $screenW - ($inset * 2)
        $drawH = $screenH - ($inset * 2)
        $g.DrawImage($src, $drawX, $drawY, $drawW, $drawH)

        # Camera notch
        $notchW = 170
        $notchH = 28
        $notchX = [int]($canvasW / 2 - $notchW / 2)
        $notchY = $phoneY + 28
        $notchBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 15, 15, 18))
        Draw-RoundedRect -Graphics $g -Brush $notchBrush -X $notchX -Y $notchY -W $notchW -H $notchH -R 13
        $notchBrush.Dispose()

        # Caption block (background)
        $titleFont = New-Object System.Drawing.Font('Segoe UI', 62, [System.Drawing.FontStyle]::Bold)
        $subFont = New-Object System.Drawing.Font('Segoe UI', 28, [System.Drawing.FontStyle]::Regular)
        $detailFont = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Regular)

        $titleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(238, 223, 234, 255))

        $g.DrawString($Title, $titleFont, $titleBrush, 82, 62)
        $g.DrawString($Subtitle, $subFont, $subBrush, 86, 146)
        $g.DrawString('Starpage', $detailFont, $subBrush, 88, 191)

        $titleBrush.Dispose()
        $subBrush.Dispose()

        # Strong top caption banner for Play Store standout style.
        $captionX = 58
        $captionY = 28
        $captionW = $canvasW - 116
        $captionH = 176
        $captionBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 8, 12, 24))
        Draw-RoundedRect -Graphics $g -Brush $captionBg -X $captionX -Y $captionY -W $captionW -H $captionH -R 38
        $captionBg.Dispose()

        $captionBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 122, 185, 255), 3)
        Draw-RoundedRectBorder -Graphics $g -Pen $captionBorder -X $captionX -Y $captionY -W $captionW -H $captionH -R 38
        $captionBorder.Dispose()

        $topCaptionFont = New-Object System.Drawing.Font('Segoe UI', 44, [System.Drawing.FontStyle]::Bold)
        $topSubFont = New-Object System.Drawing.Font('Segoe UI', 23, [System.Drawing.FontStyle]::Bold)
        $topTitleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
        $topSubBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 218, 235, 255))

        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $sf.Trimming = [System.Drawing.StringTrimming]::EllipsisWord

        $titleRect = New-Object System.Drawing.RectangleF(($captionX + 28), ($captionY + 20), ($captionW - 56), 82)
        $subRect = New-Object System.Drawing.RectangleF(($captionX + 30), ($captionY + 102), ($captionW - 60), 56)

        $g.DrawString($Title.ToUpperInvariant(), $topCaptionFont, $topTitleBrush, $titleRect, $sf)
        $g.DrawString($Subtitle, $topSubFont, $topSubBrush, $subRect, $sf)

        $topTitleBrush.Dispose()
        $topSubBrush.Dispose()
        $sf.Dispose()

        $bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        if ($topSubFont) { $topSubFont.Dispose() }
        if ($topCaptionFont) { $topCaptionFont.Dispose() }
        if ($detailFont) { $detailFont.Dispose() }
        if ($subFont) { $subFont.Dispose() }
        if ($titleFont) { $titleFont.Dispose() }
        if ($src) { $src.Dispose() }
        if ($g) { $g.Dispose() }
        if ($bmp) { $bmp.Dispose() }
    }
}

$captionMap = @{
    '01_home_feed.png' = @('Discover Trending Content', 'Fresh posts from creators worldwide')
    '02_create_post.png' = @('Share Your Creativity', 'Post photos, videos, and your ideas')
    '03_user_profile.png' = @('Showcase Your Profile', 'Build your creator identity')
    '04_post_detail.png' = @('Engage with Community', 'Like, comment, and connect in real time')
    '05_direct_messages.png' = @('Chat Directly', 'Private conversations made simple')
    '06_notifications.png' = @('Stay Instantly Updated', 'Never miss likes, comments, and follows')
    '07_search.png' = @('Find New Creators', 'Search and discover talent fast')
    '08_edit_profile.png' = @('Customize Your Presence', 'Fine-tune your profile and bio')
}

$inDirAbs = Join-Path (Get-Location).Path $InputDir
$outDirAbs = Join-Path (Get-Location).Path $OutputDir

if (-not (Test-Path -LiteralPath $inDirAbs)) {
    throw "Input directory not found: $inDirAbs"
}

Ensure-Directory -Path $outDirAbs

$files = Get-ChildItem -LiteralPath $inDirAbs -Filter '*.png' -File | Sort-Object Name
if (-not $files) {
    throw 'No PNG screenshots found in input directory.'
}

foreach ($f in $files) {
    if (-not $captionMap.ContainsKey($f.Name)) {
        continue
    }
    $title = $captionMap[$f.Name][0]
    $subtitle = $captionMap[$f.Name][1]
    $outPath = Join-Path $outDirAbs $f.Name
    New-ShowcaseImage -InFile $f.FullName -OutFile $outPath -Title $title -Subtitle $subtitle
    Write-Host "Generated: $outPath"
}

Write-Host ''
Write-Host 'Done. Showcase screenshots are in:'
Write-Host $outDirAbs