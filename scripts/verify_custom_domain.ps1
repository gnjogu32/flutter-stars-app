param(
    [string]$CustomDomain = "starpage.me",
    [string]$FirebaseHost = "starpage-ed409.web.app"
)

$ErrorActionPreference = "Stop"

function Test-Url {
    param([string]$Url)

    $result = [ordered]@{
        url = $Url
        status = "ERR"
        finalUrl = ""
        title = ""
        server = ""
        ok = $false
    }

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 10 -TimeoutSec 20
        $result.status = [string][int]$response.StatusCode
        $result.finalUrl = $response.BaseResponse.ResponseUri.AbsoluteUri
        $serverHeader = $response.Headers["Server"]
        if ($serverHeader -is [array]) {
            $result.server = [string]($serverHeader | Select-Object -First 1)
        } else {
            $result.server = [string]$serverHeader
        }

        $content = [string]$response.Content
        if ($content -match "(?is)<title>(.*?)</title>") {
            $result.title = $matches[1].Trim()
        } else {
            $snippet = $content -replace "\s+", " "
            $result.title = $snippet.Substring(0, [Math]::Min(80, $snippet.Length))
        }

        $result.ok = ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
    } catch {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $result.status = [string]$statusCode
            $result.finalUrl = $Url
            $result.ok = $false
        } else {
            $result.status = "ERR"
            $result.finalUrl = $Url
            $result.ok = $false
        }
    }

    [pscustomobject]$result
}

Write-Host "=== Firebase Hosting Cutover Verification ===" -ForegroundColor Cyan
Write-Host "Custom domain : $CustomDomain"
Write-Host "Firebase host : $FirebaseHost"
Write-Host ""

$urls = @(
    "https://$CustomDomain",
    "https://$CustomDomain/privacy",
    "https://$CustomDomain/privacy.html",
    "https://$FirebaseHost",
    "https://$FirebaseHost/privacy",
    "https://$FirebaseHost/privacy.html"
)

$urlResults = foreach ($u in $urls) { Test-Url -Url $u }
$urlResults | Format-Table url, status, finalUrl, server, title -AutoSize

Write-Host ""
Write-Host "=== DNS Records ($CustomDomain) ===" -ForegroundColor Cyan

$a = @()
$aaaa = @()
$cname = @()

try { $a = Resolve-DnsName -Name $CustomDomain -Type A -ErrorAction Stop } catch {}
try { $aaaa = Resolve-DnsName -Name $CustomDomain -Type AAAA -ErrorAction Stop } catch {}
try {
    $cname = Resolve-DnsName -Name $CustomDomain -Type CNAME -ErrorAction Stop |
        Where-Object { $_.Type -eq "CNAME" }
} catch {}

if ($a.Count -gt 0) {
    Write-Host "A records:"
    $a | Select-Object Name, Type, IPAddress | Format-Table -AutoSize
} else {
    Write-Host "A records: none"
}

if ($aaaa.Count -gt 0) {
    Write-Host "AAAA records:"
    $aaaa | Select-Object Name, Type, IPAddress | Format-Table -AutoSize
} else {
    Write-Host "AAAA records: none"
}

if ($cname.Count -gt 0) {
    Write-Host "CNAME records:"
    $cname | Select-Object Name, Type, NameHost | Format-Table -AutoSize
} else {
    Write-Host "CNAME records: none"
}

Write-Host ""
$customPrivacy = $urlResults | Where-Object { $_.url -eq "https://$CustomDomain/privacy" } | Select-Object -First 1
$firebasePrivacy = $urlResults | Where-Object { $_.url -eq "https://$FirebaseHost/privacy" } | Select-Object -First 1

if ($customPrivacy.status -eq "200" -and $firebasePrivacy.status -eq "200") {
    Write-Host "Result: PASS - Custom domain appears aligned with Firebase content." -ForegroundColor Green
} else {
    Write-Host "Result: CHECK - Custom domain is not fully aligned yet." -ForegroundColor Yellow
    Write-Host "Expected: both /privacy endpoints should return HTTP 200."
}
