param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase3',
    [ValidateSet('All', 'Logic', 'Integration')][string]$Mode = 'All',
    [ValidateRange(10, 120)][int]$TimeoutSeconds = 30
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
$compilerPath = Join-Path $projectRoot '.tools\w64devkit\bin\gcc.exe'
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

if ($Mode -in @('All', 'Logic')) {
    $fixturePath = Join-Path $logRoot 'f3-regen-test.exe'
    $sdlHeader = Join-Path $projectRoot '.deps\SDL2-2.32.10\x86_64-w64-mingw32\include\SDL2'
    $compileArguments = @('-std=c99', '-Wall', '-Wextra', '-Werror', '-I', (Join-Path $projectRoot 'src'),
        '-I', (Join-Path $projectRoot 'src\doom'), '-I', (Join-Path $projectRoot 'build'), '-I', $sdlHeader,
        (Join-Path $PSScriptRoot 'f3-regen-test.c'), (Join-Path $projectRoot 'src\m_fixed.c'),
        (Join-Path $projectRoot 'src\doom\cr_input.c'),
        (Join-Path $projectRoot 'src\doom\cr_nanosuit.c'),
        (Join-Path $projectRoot 'src\doom\cr_player.c'), '-o', $fixturePath)
    $compile = Invoke-ProcessProbe 'logic-compile' $compilerPath $compileArguments
    Add-Result $compile ($compile.completed -and $compile.exit_code -eq 0) 'Real cr_player.c regeneration with engine boundary stubs; warnings are errors.'
    if ($compile.completed -and $compile.exit_code -eq 0) {
        $probe = Invoke-ProcessProbe 'logic' $fixturePath @()
        $match = [regex]::Match($probe.output, 'F3_LOGIC PASS assertions=(\d+)')
        Add-Result $probe ($probe.completed -and $probe.exit_code -eq 0 -and $match.Success) @{
            assertions = $(if ($match.Success) { [int]$match.Groups[1].Value } else { $null })
        }
    }
}

if ($Mode -in @('All', 'Integration')) {
    # Regeneration in the real tick path; pause must freeze it. A screenshot
    # taken through the normal key path proves the HUD draw runs headlessly.
    $commands = @'
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
set $gtics = 0
set $ptics = 0
set $hud_draws = 0
set $regen_after = 0
set $mobj_health = 0
set $pause_health = -1
set $pause_frozen = 0
set $shot_sent = 0
break *G_Ticker
commands
silent
set $gtics = $gtics + 1
if $gtics == 5
set variable players[0].health = 60
set variable players[0].mo->health = 60
set variable cr_players[0].last_damage_tic = leveltime
end
if $gtics == 200
set $regen_after = players[0].health
set $mobj_health = players[0].mo->health
printf "F3_REGEN after195=%d mobj=%d\n", $regen_after, $mobj_health
end
if $gtics == 210
set variable paused = 1
set $pause_health = players[0].health
end
if $gtics == 240
set $pause_frozen = (players[0].health == $pause_health)
set variable paused = 0
printf "F3_PAUSE health_before=%d frozen=%d\n", $pause_health, $pause_frozen
end
if $gtics == 300
printf "F3_HUD draws=%d energy=%d mode=%d\n", $hud_draws, cr_players[0].suit.energy, cr_players[0].suit.mode
set $pc = (void*)I_Quit
end
continue
end
break *CR_HUDDraw
commands
silent
set $hud_draws = $hud_draws + 1
continue
end
break *D_ProcessEvents
commands
silent
if $gtics == 280 && !$shot_sent && gamestate == GS_LEVEL
set $shot_sent = 1
set variable key_menu_screenshot = 128
set variable png_screenshots = 1
queue_key key_menu_screenshot
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'engine-regen-hud' $commands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $regenMatch = [regex]::Match($probe.output, 'F3_REGEN after195=(\d+) mobj=(\d+)')
    $pauseMatch = [regex]::Match($probe.output, 'F3_PAUSE health_before=(\d+) frozen=(\d+)')
    $hudMatch = [regex]::Match($probe.output, 'F3_HUD draws=(\d+) energy=(\d+) mode=(\d+)')
    $shotFiles = @(Get-ChildItem -LiteralPath (Join-Path $logRoot $probe.case) -File |
        Where-Object { $_.Name -like 'DOOM*' -and ($_.Extension -eq '.png' -or $_.Extension -eq '.pcx') })
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $regenMatch.Success -and [int]$regenMatch.Groups[1].Value -gt 60 -and
        [int]$regenMatch.Groups[1].Value -lt 100 -and
        [int]$regenMatch.Groups[2].Value -eq [int]$regenMatch.Groups[1].Value -and
        $pauseMatch.Success -and [int]$pauseMatch.Groups[2].Value -eq 1 -and
        $hudMatch.Success -and [int]$hudMatch.Groups[1].Value -gt 0 -and
        $shotFiles.Count -ge 1 -and $shotFiles[0].Length -gt 1000
    Add-Result $probe $passed @{
        regen = $regenMatch.Value
        pause = $pauseMatch.Value
        hud = $hudMatch.Value
        screenshot = $(if ($shotFiles.Count -ge 1) { $shotFiles[0].Name + ' ' + $shotFiles[0].Length } else { $null })
    }

    # Vanilla must never reach the Crysis HUD draw or regeneration path.
    $vanillaCommands = @'
set $gtics = 0
set $hud_draws = 0
set $crysis_thinks = 0
break *CR_HUDDraw
commands
silent
set $hud_draws = $hud_draws + 1
continue
end
break *CR_PlayerThink
commands
silent
set $crysis_thinks = $crysis_thinks + 1
continue
end
break *G_Ticker
commands
silent
set $gtics = $gtics + 1
if $gtics == 60
printf "F3_VANILLA ticks=%d hud_draws=%d crysis_thinks=%d\n", $gtics, $hud_draws, $crysis_thinks
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'vanilla-hud-isolated' $vanillaCommands @('-warp', '1')
    $vanillaMatch = [regex]::Match($probe.output, 'F3_VANILLA ticks=(\d+) hud_draws=(\d+) crysis_thinks=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $vanillaMatch.Success -and [int]$vanillaMatch.Groups[1].Value -ge 60 -and
        [int]$vanillaMatch.Groups[2].Value -eq 0 -and [int]$vanillaMatch.Groups[3].Value -eq 0 -and
        !$probe.output.Contains('[CRYSIS] mode enabled')
    Add-Result $probe $passed $vanillaMatch.Value
}

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    mode = $Mode
    executable_sha256 = $(if (Test-Path -LiteralPath $exePath) { (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
    limitations = @('Regeneracao e verificada por estado; o HUD e verificado pelo desenho executado e por captura, nao pixel a pixel.',
        'SDL dummy e -nosound; imagem perceptivel nao avaliada.',
        'A captura prova que o desenho rodou sem crash, nao a legibilidade visual exata.')
    results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
