param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$DemoPath = 'docs\validacao\logs\smoke\fase0-smoke.lmp',
    [ValidateSet('Baseline', 'All')][string]$Mode = 'All',
    [string]$LogDirectory = 'docs\validacao\logs\snapshot',
    [ValidateRange(10, 120)][int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
function Get-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}
function Quote-GdbPath([string]$Path) {
    if ($Path.Contains('"')) { throw 'Caminho com aspas nao suportado.' }
    return '"' + $Path.Replace('\', '/') + '"'
}
$exePath = Get-ProjectPath $Executable
$demoFile = Get-ProjectPath $DemoPath
$logRoot = Get-ProjectPath $LogDirectory
$debuggerPath = Join-Path $projectRoot '.tools\w64devkit\bin\gdb.exe'
$iwadPath = Join-Path $projectRoot 'content\iwad\freedoom2.wad'
foreach ($requiredPath in @($exePath, $demoFile, $debuggerPath, $iwadPath)) {
    if (!(Test-Path -LiteralPath $requiredPath)) { throw "Arquivo requerido ausente: $requiredPath" }
}
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$cases = @('vanilla', 'crysis', 'crysis-repeated')
if ($Mode -eq 'Baseline') { $cases = @('baseline') }
$results = @()
foreach ($caseName in $cases) {
    $caseDir = Join-Path $logRoot $caseName
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    $configPath = Join-Path $caseDir 'default.cfg'
    $extraConfigPath = Join-Path $caseDir 'crispy-doom.cfg'
    [IO.File]::WriteAllText($configPath, '', [Text.Encoding]::ASCII)
    [IO.File]::WriteAllText($extraConfigPath, "fullscreen 0`nforce_software_renderer 1`nwindow_width 640`nwindow_height 400`nsmooth_pixel_scaling 0`n", [Text.Encoding]::ASCII)
    $gameArguments = '-iwad ' + (Quote-GdbPath $iwadPath) + ' -config ' + (Quote-GdbPath $configPath) +
        ' -extraconfig ' + (Quote-GdbPath $extraConfigPath) + ' -savedir ' + (Quote-GdbPath $caseDir) +
        ' -nosound -nogui -window -playdemo ' + (Quote-GdbPath $demoFile)
    if ($caseName -in @('crysis', 'crysis-repeated')) { $gameArguments += ' -crysis' }
    if ($caseName -eq 'crysis-repeated') { $gameArguments += ' -crysis' }
    # GDB reads final simulation state immediately before natural demo exit.
    # No game variables or source files are modified by this trace.
    $gdbCommands = @"
set pagination off
set confirm off
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args $gameArguments
break I_Quit
commands
silent
printf "SNAPSHOT map=%d gametic=%d leveltime=%d x=%d y=%d z=%d angle=%u health=%d mobjhealth=%d bullets=%d rng=%d paused=%d\n", gamemap, gametic, leveltime, players[0].mo->x, players[0].mo->y, players[0].mo->z, players[0].mo->angle, players[0].health, players[0].mo->health, players[0].ammo[0], prndindex, paused
continue
end
run
"@
    $commandPath = Join-Path $caseDir 'trace.gdb'
    [IO.File]::WriteAllText($commandPath, $gdbCommands, [Text.Encoding]::ASCII)
    $stdoutPath = Join-Path $caseDir 'stdout.log'
    $stderrPath = Join-Path $caseDir 'stderr.log'
    $debuggerArguments = '-nx -q -batch -x ' + (Quote-GdbPath $commandPath) + ' ' + (Quote-GdbPath $exePath)
    $process = Start-Process -FilePath $debuggerPath -ArgumentList $debuggerArguments -WorkingDirectory $projectRoot `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (!$completed) {
        # Terminate this debugger and its own inferior, never other game runs.
        & taskkill.exe /PID $process.Id /T /F | Out-Null
        $process.WaitForExit()
    }
    $process.Refresh()
    $output = [IO.File]::ReadAllText($stdoutPath) + [IO.File]::ReadAllText($stderrPath)
    $snapshots = [regex]::Matches($output, '(?m)^SNAPSHOT [^\r\n]+')
    $snapshotText = $null
    if ($snapshots.Count -eq 1) { $snapshotText = $snapshots[0].Value }
    $passed = $completed -and $process.ExitCode -eq 0 -and $snapshots.Count -eq 1 -and $output.Contains('exited normally')
    $results += [pscustomobject][ordered]@{
        case = $caseName
        passed = $passed
        completed = $completed
        exit_code = $process.ExitCode
        snapshot = $snapshotText
        stdout = $stdoutPath
        stderr = $stderrPath
    }
    Write-Host ($caseName + ': ' + $(if ($passed) { 'PASS' } else { 'FAIL' }))
    if ($snapshotText) { Write-Host $snapshotText }
    $process.Dispose()
}
$identical = @($results | Select-Object -ExpandProperty snapshot -Unique).Count -eq 1
$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    method = 'gdb-read-only-final-demo-snapshot'
    executable_sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
    demo_sha256 = (Get-FileHash -LiteralPath $demoFile -Algorithm SHA256).Hash.ToLowerInvariant()
    identical_within_run = $identical
    limitations = @('Snapshot de uma demo controlada; nao substitui playtest interativo.',
        'Nao testa menu/restart/transicao de mapa nem entrada teclado/mouse.')
    results = $results
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0 -or !$identical) { exit 1 }
exit 0
