param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase4',
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
    $fixturePath = Join-Path $logRoot 'f4-weapon-test.exe'
    $sdlHeader = Join-Path $projectRoot '.deps\SDL2-2.32.10\x86_64-w64-mingw32\include\SDL2'
    $compileArguments = @('-std=c99', '-Wall', '-Wextra', '-Werror', '-I', (Join-Path $projectRoot 'src'),
        '-I', (Join-Path $projectRoot 'src\doom'), '-I', (Join-Path $projectRoot 'build'), '-I', $sdlHeader,
        (Join-Path $PSScriptRoot 'f4-weapon-test.c'), (Join-Path $projectRoot 'src\m_fixed.c'),
        (Join-Path $projectRoot 'src\doom\cr_nanosuit.c'),
        (Join-Path $projectRoot 'src\doom\cr_player.c'),
        (Join-Path $projectRoot 'src\doom\cr_sound.c'),
        (Join-Path $projectRoot 'src\doom\cr_weapon.c'), '-o', $fixturePath)
    $compile = Invoke-ProcessProbe 'logic-compile' $compilerPath $compileArguments
    Add-Result $compile ($compile.completed -and $compile.exit_code -eq 0) 'Real cr_weapon.c with engine boundary stubs; warnings are errors.'
    if ($compile.completed -and $compile.exit_code -eq 0) {
        $probe = Invoke-ProcessProbe 'logic' $fixturePath @()
        $match = [regex]::Match($probe.output, 'F4_LOGIC PASS assertions=(\d+)')
        Add-Result $probe ($probe.completed -and $probe.exit_code -eq 0 -and $match.Success) @{
            assertions = $(if ($match.Success) { [int]$match.Groups[1].Value } else { $null })
        }
    }
}

if ($Mode -in @('All', 'Integration')) {
    # Drive the real weapon path: BT_ATTACK via cmd, R via buttons2. P_LineAttack
    # is counted to prove vanilla shot actions do not add extra attacks.
    $commands = @'
set $ticks = 0
set $shots = 0
set $shot_mag = -1
set $vanilla_before = -1
set $vanilla_after = -1
set $reload_mag = -1
set $reload_reserve = -1
break *P_LineAttack
commands
silent
set $shots = $shots + 1
continue
end
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].readyweapon = wp_chaingun
set variable players[0].pendingweapon = wp_nochange
set variable cr_players[0].weapon.magazine[2] = 30
set variable cr_players[0].weapon.reserve[2] = 105
set variable cr_players[0].weapon.next_fire_tic = 0
set $vanilla_before = players[0].ammo[0]
end
if $ticks >= 30 && $ticks <= 38
set variable players[0].cmd.buttons = 1
end
if $ticks == 39
set variable players[0].cmd.buttons = 0
set $shot_mag = cr_players[0].weapon.magazine[2]
set $vanilla_after = players[0].ammo[0]
end
if $ticks == 50
set variable players[0].cmd.buttons2 = 4
end
if $ticks == 55
set variable players[0].cmd.buttons2 = 0
end
if $ticks == 120
set $reload_mag = cr_players[0].weapon.magazine[2]
set $reload_reserve = cr_players[0].weapon.reserve[2]
printf "F4_ENGINE shots_mag=%d attacks=%d vanilla_before=%d vanilla_after=%d reload_mag=%d reload_reserve=%d reloading=%d\n", $shot_mag, $shots, $vanilla_before, $vanilla_after, $reload_mag, $reload_reserve, cr_players[0].weapon.reloading
end
if $ticks == 125
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'engine-weapon' $commands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    # The mapped psprite animation (8 tics per cycle) bounds the SCAR below its
    # nominal 600 RPM, so nine tics produce two shots.
    $match = [regex]::Match($probe.output, 'F4_ENGINE shots_mag=(\d+) attacks=(\d+) vanilla_before=(\d+) vanilla_after=(\d+) reload_mag=(\d+) reload_reserve=(\d+) reloading=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and
        [int]$match.Groups[1].Value -eq 28 -and     # Two auto shots in nine tics.
        [int]$match.Groups[2].Value -eq 2 -and      # Exactly our shots, no vanilla attacks.
        [int]$match.Groups[3].Value -eq [int]$match.Groups[4].Value -and
        [int]$match.Groups[5].Value -eq 30 -and
        [int]$match.Groups[6].Value -eq 103 -and    # 105 - 2 reloaded.
        [int]$match.Groups[7].Value -eq 0
    Add-Result $probe $passed $match.Value

    # Vanilla: the Crysis weapon path never runs and the vanilla pistol still
    # consumes clip ammo when the fire key is held.
    $vanillaCommands = @'
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
set $ticks = 0
set $cr_fires = 0
set $cr_ticks = 0
set $ammo_before = -1
set $key_sent = 0
break *CR_WeaponFire
commands
silent
set $cr_fires = $cr_fires + 1
continue
end
break *CR_WeaponTick
commands
silent
set $cr_ticks = $cr_ticks + 1
continue
end
break *D_ProcessEvents
commands
silent
if $ticks == 20 && !$key_sent
set $key_sent = 1
set $ammo_before = players[0].ammo[0]
queue_key key_fire
end
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 60
printf "F4_VANILLA cr_fires=%d cr_ticks=%d ammo_before=%d ammo_after=%d\n", $cr_fires, $cr_ticks, $ammo_before, players[0].ammo[0]
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'vanilla-weapon-isolated' $vanillaCommands @('-warp', '1')
    $match = [regex]::Match($probe.output, 'F4_VANILLA cr_fires=(\d+) cr_ticks=(\d+) ammo_before=(\d+) ammo_after=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -eq 0 -and [int]$match.Groups[2].Value -eq 0 -and
        [int]$match.Groups[4].Value -lt [int]$match.Groups[3].Value -and
        !$probe.output.Contains('[CRYSIS] mode enabled')
    Add-Result $probe $passed $match.Value
}

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    mode = $Mode
    executable_sha256 = $(if (Test-Path -LiteralPath $exePath) { (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
    limitations = @('Munição, cadência e reload sao verificados por estado e contagem de P_LineAttack.',
        'A precisao do spread nao e medida em alvos reais neste harness.',
        'SDL dummy e -nosound; audio nao avaliado.')
    results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
