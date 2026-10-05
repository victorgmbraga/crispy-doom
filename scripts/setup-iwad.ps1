param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$contentDir = Join-Path $projectRoot 'content\iwad'
$iwadPath = Join-Path $contentDir 'freedoom2.wad'
$expectedIwadHash = 'a8772e088847032510d97ba2312406a6998f21cbab44d4ff10696faa9c0ecd4b'
$expectedArchiveHash = '3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59'
$downloadUrl = 'https://github.com/freedoom/freedoom/releases/download/v0.13.0/freedoom-0.13.0.zip'

if ((Test-Path -LiteralPath $iwadPath) -and
    ((Get-FileHash -LiteralPath $iwadPath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expectedIwadHash)) {
    Write-Host 'Freedoom Phase 2 v0.13.0: IWAD verificado.'
    exit 0
}

New-Item -ItemType Directory -Force -Path $contentDir | Out-Null
$stagingDir = Join-Path $projectRoot ('.tools\freedoom-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null
try {
    $archivePath = Join-Path $stagingDir 'freedoom-0.13.0.zip'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
    $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($archiveHash -ne $expectedArchiveHash) { throw 'Hash SHA256 do ZIP Freedoom diferente do valor fixado.' }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingDir
    $releaseDir = Join-Path $stagingDir 'freedoom-0.13.0'
    $downloadedIwad = Join-Path $releaseDir 'freedoom2.wad'
    $iwadHash = (Get-FileHash -LiteralPath $downloadedIwad -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($iwadHash -ne $expectedIwadHash) { throw 'Hash SHA256 do IWAD Freedoom diferente do manifesto oficial.' }
    Copy-Item -LiteralPath $downloadedIwad -Destination $iwadPath
    Copy-Item -LiteralPath (Join-Path $releaseDir 'COPYING.txt') -Destination (Join-Path $contentDir 'COPYING-FREEDOOM.txt')
    Copy-Item -LiteralPath (Join-Path $releaseDir 'CREDITS.txt') -Destination (Join-Path $contentDir 'CREDITS-FREEDOOM.txt')
    Copy-Item -LiteralPath (Join-Path $releaseDir 'CREDITS-MUSIC.txt') -Destination (Join-Path $contentDir 'CREDITS-MUSIC-FREEDOOM.txt')
    Write-Host 'Freedoom Phase 2 v0.13.0: baixado e verificado.'
}
finally {
    $resolvedStaging = [IO.Path]::GetFullPath($stagingDir)
    $allowedPrefix = [IO.Path]::GetFullPath((Join-Path $projectRoot '.tools')) + [IO.Path]::DirectorySeparatorChar
    if ($resolvedStaging.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}
