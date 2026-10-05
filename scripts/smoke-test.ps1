param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [ValidateSet('Baseline', 'Vanilla', 'Crysis', 'CrysisRepeated', 'All')]
    [string]$Mode = 'All',
    [string]$LogDirectory = 'docs\validacao\logs\smoke',
    [ValidateRange(10, 120)][int]$TimeoutSeconds = 30,
    [switch]$Timed
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Get-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}

function ConvertTo-ProcessArgument([string]$Value) {
    if ($Value.Contains('"')) { throw 'Argumento de processo com aspas nao suportado.' }
    if ($Value -match '\s') { return '"' + $Value + '"' }
    return $Value
}

# Source format: Doom 1.9 header, one player, MAP01, medium skill, no monsters.
# Each of the 175 commands contains forwardmove/sidemove/angleturn/buttons.
# This exercises simulation with movement, turning, attack, use and pause.
# It supplies tic commands directly; it does not test keyboard/mouse input.
function New-SmokeDemo([string]$Path) {
    $demoBytes = New-Object 'System.Collections.Generic.List[byte]'
    [byte[]]$header = @(109, 2, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0)
    $demoBytes.AddRange($header)
    for ($tic = 0; $tic -lt 175; $tic++) {
        [byte]$forward = 0
        [byte]$turn = 0
        [byte]$buttons = 0
        if ($tic -ge 10 -and $tic -lt 45) { $forward = 25 }
        if ($tic -ge 45 -and $tic -lt 65) { $turn = 4 }
        if ($tic -ge 65 -and $tic -lt 115) { $buttons = 1 }
        if ($tic -eq 120) { $buttons = 2 }
        if ($tic -eq 135 -or $tic -eq 140) { $buttons = 129 }
        $demoBytes.Add($forward)
        $demoBytes.Add(0)
        $demoBytes.Add($turn)
        $demoBytes.Add($buttons)
    }
    $demoBytes.Add(128) # DEMOMARKER, followed by normal singledemo shutdown.
    [IO.File]::WriteAllBytes($Path, $demoBytes.ToArray())
}

$exePath = Get-ProjectPath $Executable
$logRoot = Get-ProjectPath $LogDirectory
$iwadPath = Join-Path $projectRoot 'content\iwad\freedoom2.wad'
if (!(Test-Path -LiteralPath $exePath)) { throw "Executavel ausente: $exePath. Execute scripts/setup-build.ps1 -Build." }
if (!(Test-Path -LiteralPath $iwadPath)) { throw 'IWAD ausente. Execute scripts/setup-iwad.ps1.' }
$iwadHash = (Get-FileHash -LiteralPath $iwadPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($iwadHash -ne 'a8772e088847032510d97ba2312406a6998f21cbab44d4ff10696faa9c0ecd4b') {
    throw 'O IWAD de teste nao corresponde ao Freedoom Phase 2 v0.13.0 fixado.'
}

New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$demoPath = Join-Path $logRoot 'fase0-smoke.lmp'
New-SmokeDemo $demoPath
$cases = switch ($Mode) {
    'Baseline' { @('baseline') }
    'Vanilla' { @('vanilla') }
    'Crysis' { @('crysis') }
    'CrysisRepeated' { @('crysis-repeated') }
    'All' { @('vanilla', 'crysis', 'crysis-repeated') }
}

$environmentNames = @('SDL_VIDEODRIVER', 'SDL_AUDIODRIVER', 'SDL_RENDER_DRIVER')
$previousEnvironment = @{}
foreach ($environmentName in $environmentNames) {
    $previousEnvironment[$environmentName] = [Environment]::GetEnvironmentVariable($environmentName, 'Process')
}
$results = @()
try {
    # SDL dummy avoids desktop focus and hardware audio. Hidden process plus
    # -nogui also suppresses console windows and fatal-error message boxes.
    $env:SDL_VIDEODRIVER = 'dummy'
    $env:SDL_AUDIODRIVER = 'dummy'
    $env:SDL_RENDER_DRIVER = 'software'
    foreach ($caseName in $cases) {
        $caseDir = Join-Path $logRoot $caseName
        New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
        $configPath = Join-Path $caseDir 'default.cfg'
        $extraConfigPath = Join-Path $caseDir 'crispy-doom.cfg'
        [IO.File]::WriteAllText($configPath, '', [Text.Encoding]::ASCII)
        [IO.File]::WriteAllText($extraConfigPath, "fullscreen 0`nforce_software_renderer 1`nwindow_width 640`nwindow_height 400`nsmooth_pixel_scaling 0`n", [Text.Encoding]::ASCII)
        $stdoutPath = Join-Path $caseDir 'stdout.log'
        $stderrPath = Join-Path $caseDir 'stderr.log'
        $demoOption = '-playdemo'
        if ($Timed) { $demoOption = '-timedemo' }
        $arguments = @('-iwad', $iwadPath, '-config', $configPath, '-extraconfig', $extraConfigPath,
            '-savedir', $caseDir, '-nosound', '-nogui', '-window', $demoOption, $demoPath)
        if ($caseName -in @('crysis', 'crysis-repeated')) { $arguments += '-crysis' }
        if ($caseName -eq 'crysis-repeated') { $arguments += '-crysis' }
        if ($Timed) { $arguments += '-nodraw' }
        $commandArguments = ($arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' '
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath $exePath -ArgumentList $commandArguments -WorkingDirectory $projectRoot `
            -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (!$completed) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $process.WaitForExit()
        }
        $timer.Stop()
        $process.Refresh()
        $output = [IO.File]::ReadAllText($stdoutPath) + [IO.File]::ReadAllText($stderrPath)
        $activationCount = [regex]::Matches($output, '\[CRYSIS\] mode enabled').Count
        $expectedActivation = 0
        if ($caseName -in @('crysis', 'crysis-repeated')) { $expectedActivation = 1 }
        $timingMatch = [regex]::Match($output, 'timed (\d+) gametics in (\d+) realtics')
        $expectedExit = $process.ExitCode -eq 0
        # Upstream G_CheckDemoStatus deliberately calls I_Error at timedemo end,
        # so a nonzero exit with the exact timing result is expected in -Timed.
        if ($Timed) { $expectedExit = $timingMatch.Success -and $process.ExitCode -ne 0 }
        $passed = $completed -and $expectedExit -and $output.Contains('Playing demo ') -and
            ($activationCount -eq $expectedActivation)
        $result = [ordered]@{
            case = $caseName
            passed = $passed
            completed = $completed
            timed_out = !$completed
            exit_code = $process.ExitCode
            elapsed_seconds = [Math]::Round($timer.Elapsed.TotalSeconds, 3)
            activation_count = $activationCount
            expected_activation_count = $expectedActivation
            timed_gametics = $(if ($timingMatch.Success) { [int]$timingMatch.Groups[1].Value } else { $null })
            executable = $exePath
            arguments = $arguments
            stdout = $stdoutPath
            stderr = $stderrPath
        }
        $results += [pscustomobject]$result
        Write-Host ($caseName + ': ' + $(if ($passed) { 'PASS' } else { 'FAIL' }) + ' (exit ' + $process.ExitCode + ')')
        $process.Dispose()
    }
}
finally {
    foreach ($environmentName in $environmentNames) {
        [Environment]::SetEnvironmentVariable($environmentName, $previousEnvironment[$environmentName], 'Process')
    }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    method = $(if ($Timed) { 'headless-timedemo' } else { 'headless-finite-playdemo' })
    executable_sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
    iwad_sha256 = $iwadHash
    demo_sha256 = (Get-FileHash -LiteralPath $demoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    demo_commands = 175
    limitations = @('Comandos de tic simulados; entrada teclado/mouse nao verificada.',
        'SDL dummy e -nosound: imagem e audio perceptiveis nao verificados.',
        'Menu, nova partida e restart interativos nao verificados.',
        'Demos continuam permitidas apenas nesta Fase 0; atualizar teste antes da Fase 1.')
    results = $results
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
