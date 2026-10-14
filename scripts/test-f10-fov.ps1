param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase10',
    [ValidateSet('All', 'Integration')][string]$Mode = 'All',
    [ValidateRange(10, 120)][int]$TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
function Get-ProjectPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path $projectRoot $Path))
}
function Quote-Argument([string]$Value) {
    if ($Value.Contains('"')) { throw 'Argumento com aspas nao suportado.' }
    return '"' + $Value.Replace('\', '/') + '"'
}

$exePath = Get-ProjectPath $Executable
$logRoot = Get-ProjectPath $LogDirectory
$debuggerPath = Join-Path $projectRoot '.tools\w64devkit\bin\gdb.exe'
$iwadPath = Join-Path $projectRoot 'content\iwad\freedoom2.wad'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$results = New-Object 'System.Collections.Generic.List[object]'

function Invoke-ProcessProbe([string]$Name, [string]$Program, [string[]]$Arguments) {
    $caseDir = Join-Path $logRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    $stdoutPath = Join-Path $caseDir 'stdout.log'
    $stderrPath = Join-Path $caseDir 'stderr.log'
    $argumentLine = ($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' '
    $startArguments = @{
        FilePath = $Program
        WorkingDirectory = $caseDir
        WindowStyle = 'Hidden'
        PassThru = $true
        RedirectStandardOutput = $stdoutPath
        RedirectStandardError = $stderrPath
    }
    if ($Arguments.Count -gt 0) { $startArguments.ArgumentList = $argumentLine }
    $process = Start-Process @startArguments
    $null = $process.Handle
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (!$completed) {
        & taskkill.exe /PID $process.Id /T /F | Out-Null
        $process.WaitForExit()
    }
    $process.WaitForExit()
    $output = [IO.File]::ReadAllText($stdoutPath) + [IO.File]::ReadAllText($stderrPath)
    $probe = [pscustomobject][ordered]@{
        case = $Name
        completed = $completed
        exit_code = $process.ExitCode
        output = $output
        stdout = $stdoutPath
        stderr = $stderrPath
    }
    $process.Dispose()
    return $probe
}

function Add-Result($Probe, [bool]$Passed, $Details) {
    $results.Add([pscustomobject][ordered]@{
        case = $Probe.case
        passed = $Passed
        completed = $Probe.completed
        exit_code = $Probe.exit_code
        details = $Details
        stdout = $Probe.stdout
        stderr = $Probe.stderr
    })
    Write-Host ($Probe.case + ': ' + $(if ($Passed) { 'PASS' } else { 'FAIL' }))
    if (!$Passed) { Write-Host $Probe.output }
}

function Invoke-GdbProbe([string]$Name, [string]$Commands, [string[]]$GameArguments) {
    $caseDir = Join-Path $logRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    $configPath = Join-Path $caseDir 'default.cfg'
    $extraConfigPath = Join-Path $caseDir 'crispy-doom.cfg'
    [IO.File]::WriteAllText($configPath, '', [Text.Encoding]::ASCII)
    [IO.File]::WriteAllText($extraConfigPath,
        "fullscreen 0`nforce_software_renderer 1`nwindow_width 640`nwindow_height 400`nsmooth_pixel_scaling 0`n",
        [Text.Encoding]::ASCII)
    $arguments = @('-iwad', $iwadPath, '-config', $configPath, '-extraconfig', $extraConfigPath,
        '-savedir', $caseDir, '-nosound', '-nogui', '-window') + $GameArguments
    $argumentLine = ($arguments | ForEach-Object { Quote-Argument $_ }) -join ' '
    $gdbHeader = @"
set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args $argumentLine
"@
    $commandPath = Join-Path $caseDir 'trace.gdb'
    [IO.File]::WriteAllText($commandPath, $gdbHeader + "`n" + $Commands, [Text.Encoding]::ASCII)
    return Invoke-ProcessProbe $Name $debuggerPath @('-nx', '-q', '-batch', '-x', $commandPath, $exePath)
}

if ($Mode -in @('All', 'Integration')) {
    # ADS applies the ADS FOV; installing a scope tightens it; releasing ADS
    # restores the default. A capture shows the scope overlay and its FOV.
    $commands = @'
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
set $ticks = 0
set $fov_ads = 0
set $fov_scope = 0
set $fov_off = 0
set $shot_sent = 0
break *D_ProcessEvents
commands
silent
if $ticks == 58 && !$shot_sent && gamestate == GS_LEVEL
set $shot_sent = 1
set variable key_menu_screenshot = 128
queue_key key_menu_screenshot
end
continue
end
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 30
set variable players[0].readyweapon = wp_chaingun
set variable players[0].pendingweapon = wp_nochange
end
if $ticks >= 40 && $ticks <= 60
set variable players[0].cmd.buttons2 = 2
end
if $ticks == 55
set $fov_ads = CR_RenderFOV()
set variable cr_players[0].weapon.attachments[2] = 4
end
if $ticks == 60
set $fov_scope = CR_RenderFOV()
end
if $ticks == 65
set variable players[0].cmd.buttons2 = 0
end
if $ticks == 75
set $fov_off = CR_RenderFOV()
printf "F10_FOV ads=%d scope=%d off=%d\n", $fov_ads, $fov_scope, $fov_off
end
if $ticks == 80
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'ads-fov' $commands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $match = [regex]::Match($probe.output, 'F10_FOV ads=(\d+) scope=(\d+) off=(\d+)')
    $shotFiles = @(Get-ChildItem -LiteralPath (Join-Path $logRoot $probe.case) -File |
        Where-Object { $_.Name -like 'DOOM*' -and ($_.Extension -eq '.png' -or $_.Extension -eq '.pcx') })
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and
        [int]$match.Groups[1].Value -eq 1024 -and
        [int]$match.Groups[2].Value -eq 768 -and
        [int]$match.Groups[3].Value -eq 2048 -and
        $shotFiles.Count -ge 1
    Add-Result $probe $passed @{
        fov = $match.Value
        screenshot = $(if ($shotFiles.Count -ge 1) { $shotFiles[0].Name } else { $null })
    }

    # Vanilla keeps the fixed projection.
    $vanillaCommands = @'
set $ticks = 0
set $fov = 0
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 40
set $fov = CR_RenderFOV()
printf "F10_VANILLA fov=%d\n", $fov
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'vanilla-fov-isolated' $vanillaCommands @('-warp', '1')
    $match = [regex]::Match($probe.output, 'F10_VANILLA fov=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -eq 2048
    Add-Result $probe $passed $match.Value
}

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    mode = $Mode
    executable_sha256 = $(if (Test-Path -LiteralPath $exePath) { (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
    limitations = @('F10 parcial: apenas FOV/scope. Performance, playtest e ajustes de conteudo seguem pendentes.',
        'Transicao de FOV e instantanea, como permite o plano.',
        'Teste headless (SDL dummy, -nosound).')
    results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
