param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runDir = Join-Path $projectRoot 'build\run'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$configPath = Join-Path $runDir 'default.cfg'
$extraConfigPath = Join-Path $runDir 'crispy-doom.cfg'
if (!(Test-Path -LiteralPath $configPath)) {
    [IO.File]::WriteAllText($configPath, '', [Text.Encoding]::ASCII)
}
if (!(Test-Path -LiteralPath $extraConfigPath)) {
    [IO.File]::WriteAllText($extraConfigPath, "fullscreen 0`nwindow_width 960`nwindow_height 600`n", [Text.Encoding]::ASCII)
}
Write-Host 'Configuracao de execucao local: build/run.'
