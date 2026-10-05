$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$androidDir = Join-Path $projectRoot "android"

function Resolve-JavaHome {
    $candidates = @(
        $env:JAVA_HOME,
        "C:\Program Files\Java\jdk-17",
        "C:\Program Files\Java\jdk-21",
        "C:\Program Files\Eclipse Adoptium\jdk-17",
        "C:\Program Files\Microsoft\jdk-17",
        "C:\Program Files\Amazon Corretto\jdk17"
    ) | Where-Object { $_ }

    foreach ($candidate in $candidates) {
        $javaExe = Join-Path $candidate "bin\java.exe"
        if (Test-Path $javaExe) {
            return $candidate.TrimEnd("\")
        }
    }

    $installed = Get-ChildItem "C:\Program Files\Java" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    foreach ($path in $installed) {
        $javaExe = Join-Path $path "bin\java.exe"
        if (Test-Path $javaExe) {
            return $path.TrimEnd("\")
        }
    }

    return $null
}

$javaHome = Resolve-JavaHome
if (-not $javaHome) {
    throw "JDK 17 was not found. Install JDK 17 or set JAVA_HOME before running this script."
}

$env:JAVA_HOME = $javaHome
$env:Path = "$javaHome\bin;$env:Path"

Write-Host "Using JAVA_HOME=$env:JAVA_HOME"
Write-Host "Running Android release bundle build..."

Push-Location $androidDir
try {
    & ".\gradlew.bat" :app:bundleRelease
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
