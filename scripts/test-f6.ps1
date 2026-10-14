param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase6',
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
    # Perception: a KPA facing the player at 140 units must escalate to combat
    # and deal rifle damage.
    $perceptionCommands = @'
set $ticks = 0
set $kpa = 0
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].mo->angle = 0
set $kpa = (mobj_t*) P_SpawnMobj(players[0].mo->x + 140 * 65536, players[0].mo->y, -2147483648, MT_CR_KPA)
set $kpa->angle = 2147483648
end
if $ticks == 300
printf "F6_PERCEPTION state=%d suspicion=%d health=%d energy=%d registered=%d\n", CR_AIStateOf($kpa), CR_AISuspicionOf($kpa), players[0].health, cr_players[0].suit.energy, CR_AIRegisteredCount()
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'perception-combat' $perceptionCommands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $match = [regex]::Match($probe.output, 'F6_PERCEPTION state=(\d+) suspicion=(\d+) health=(\d+) energy=(\d+) registered=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -ge 3 -and
        ([int]$match.Groups[3].Value -lt 100 -or [int]$match.Groups[4].Value -lt 100) -and
        [int]$match.Groups[5].Value -eq 1
    Add-Result $probe $passed $match.Value

    # Noise: an unsuppressed shot at 600 units brings a back-turned KPA to
    # INVESTIGATE; the same shot with a suppressor leaves it in PATROL.
    $noiseTemplate = @'
set $ticks = 0
set $kpa = 0
set $before = -1
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].mo->angle = 0
{ATTACH}
set $kpa = (mobj_t*) P_SpawnMobj(players[0].mo->x + 600 * 65536, players[0].mo->y, -2147483648, MT_CR_KPA)
set $kpa->angle = 0
end
if $ticks == 20
set $before = CR_AIStateOf($kpa)
end
if $ticks >= 30 && $ticks <= 34
set variable players[0].cmd.buttons = 1
end
if $ticks == 80
printf "F6_NOISE before=%d after=%d suspicion=%d noises=%d\n", $before, CR_AIStateOf($kpa), CR_AISuspicionOf($kpa), CR_SoundNoiseCount()
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $noiseCommands = $noiseTemplate.Replace('{ATTACH}', '')
    $probe = Invoke-GdbProbe 'noise-unsuppressed' $noiseCommands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $match = [regex]::Match($probe.output, 'F6_NOISE before=(\d+) after=(\d+) suspicion=(\d+) noises=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -eq 0 -and
        [int]$match.Groups[2].Value -ge 2 -and [int]$match.Groups[4].Value -ge 1
    Add-Result $probe $passed $match.Value

    $noiseSuppressedCommands = $noiseTemplate.Replace('{ATTACH}', 'set variable cr_players[0].weapon.attachments[1] = 1')
    $probe = Invoke-GdbProbe 'noise-suppressed' $noiseSuppressedCommands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $match = [regex]::Match($probe.output, 'F6_NOISE before=(\d+) after=(\d+) suspicion=(\d+) noises=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -eq 0 -and
        [int]$match.Groups[2].Value -eq 0 -and [int]$match.Groups[3].Value -eq 0
    Add-Result $probe $passed $match.Value

    # Cloak: the same sight line under Cloak must not reach the investigate
    # threshold over the same window that ended in combat without it.
    $cloakCommands = @'
set $ticks = 0
set $kpa = 0
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].mo->angle = 0
set variable cr_players[0].suit.mode = 3
set variable cr_players[0].suit.energy = 100
set $kpa = (mobj_t*) P_SpawnMobj(players[0].mo->x + 400 * 65536, players[0].mo->y, -2147483648, MT_CR_KPA)
set $kpa->angle = 2147483648
end
if $ticks == 200
printf "F6_CLOAK state=%d suspicion=%d health=%d energy=%d\n", CR_AIStateOf($kpa), CR_AISuspicionOf($kpa), players[0].health, cr_players[0].suit.energy
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'cloak-delays-detection' $cloakCommands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $match = [regex]::Match($probe.output, 'F6_CLOAK state=(\d+) suspicion=(\d+) health=(\d+) energy=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -le 1 -and
        [int]$match.Groups[2].Value -lt 50 -and [int]$match.Groups[3].Value -eq 100
    Add-Result $probe $passed $match.Value

    # Removal: killing and removing the actor must clear the registry and not
    # crash the following tics.
    $removeCommands = @'
set $ticks = 0
set $kpa = 0
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set $kpa = (mobj_t*) P_SpawnMobj(players[0].mo->x + 140 * 65536, players[0].mo->y, -2147483648, MT_CR_KPA)
end
if $ticks == 20
call P_DamageMobj($kpa, players[0].mo, players[0].mo, 500)
end
if $ticks == 22
call P_RemoveMobj($kpa)
end
if $ticks == 40
printf "F6_REMOVE registered=%d alive=%d\n", CR_AIRegisteredCount(), CR_AIAliveCount()
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'kill-and-remove' $removeCommands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $match = [regex]::Match($probe.output, 'F6_REMOVE registered=(\d+) alive=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -eq 0 -and [int]$match.Groups[2].Value -eq 0
    Add-Result $probe $passed $match.Value

    # Loss of contact: after combat is established, moving the player beyond
    # sight range must end in SEARCH/RETURN, not permanent combat.
    $lossCommands = @'
set $ticks = 0
set $kpa = 0
set $combat_seen = 0
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable players[0].mo->angle = 0
set $kpa = (mobj_t*) P_SpawnMobj(players[0].mo->x + 140 * 65536, players[0].mo->y, -2147483648, MT_CR_KPA)
set $kpa->angle = 2147483648
end
if $ticks == 120
if CR_AIStateOf($kpa) == 4
set $combat_seen = 1
end
set variable players[0].mo->x = players[0].mo->x + 6000 * 65536
end
if $ticks == 600
printf "F6_LOSS combat_seen=%d state=%d suspicion=%d\n", $combat_seen, CR_AIStateOf($kpa), CR_AISuspicionOf($kpa)
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'loss-of-contact' $lossCommands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $match = [regex]::Match($probe.output, 'F6_LOSS combat_seen=(\d+) state=(\d+) suspicion=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -eq 1 -and
        [int]$match.Groups[2].Value -ne 4
    Add-Result $probe $passed $match.Value

    # Vanilla: no registry activity without the mode.
    $vanillaCommands = @'
set $ticks = 0
set $spawns = 0
set $thinks = 0
break *CR_AIOnSpawn
commands
silent
set $spawns = $spawns + 1
continue
end
break *CR_AIThink
commands
silent
set $thinks = $thinks + 1
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 60
printf "F6_VANILLA ticks=%d spawns=%d thinks=%d registered=%d\n", $ticks, $spawns, $thinks, CR_AIRegisteredCount()
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'vanilla-ai-isolated' $vanillaCommands @('-warp', '1')
    $match = [regex]::Match($probe.output, 'F6_VANILLA ticks=(\d+) spawns=(\d+) thinks=(\d+) registered=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[2].Value -eq 0 -and
        [int]$match.Groups[3].Value -eq 0 -and [int]$match.Groups[4].Value -eq 0 -and
        !$probe.output.Contains('[CRYSIS] mode enabled')
    Add-Result $probe $passed $match.Value
}

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    mode = $Mode
    executable_sha256 = $(if (Test-Path -LiteralPath $exePath) { (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
    limitations = @('Atores sao criados por GDB porque o mapa tecnico ainda nao existe (F2.8/F9).',
        'Quebra de LOS e busca nao foram exercitadas por falta de geometria dedicada.',
        'Teste headless (SDL dummy, -nosound); sem playtest humano.')
    results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
