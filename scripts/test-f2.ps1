param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase2',
    [ValidateSet('All', 'Logic', 'Integration', 'Vanilla')][string]$Mode = 'All',
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
$demoPath = Join-Path $logRoot 'vanilla-smoke-f2.lmp'
# Frozen result of the unmodified Crispy Doom 7.1 baseline (same as F1).
$baselineSnapshot = 'SNAPSHOT map=1 gametic=175 leveltime=170 x=8718787 y=-12575414 z=-2097152 angle=1342177280 health=100 mobjhealth=100 bullets=46 rng=34 paused=0'
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
    # Windows PowerShell 5.1 can lose ExitCode for a short-lived native
    # process unless its handle is opened before the timed wait.
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
    $fixturePath = Join-Path $logRoot 'f2-suit-test.exe'
    $sdlHeader = Join-Path $projectRoot '.deps\SDL2-2.32.10\x86_64-w64-mingw32\include\SDL2'
    $compileArguments = @('-std=c99', '-Wall', '-Wextra', '-Werror', '-I', (Join-Path $projectRoot 'src'),
        '-I', (Join-Path $projectRoot 'src\doom'), '-I', (Join-Path $projectRoot 'build'), '-I', $sdlHeader,
        (Join-Path $PSScriptRoot 'f2-suit-test.c'), (Join-Path $projectRoot 'src\m_fixed.c'),
        (Join-Path $projectRoot 'src\doom\cr_input.c'),
        (Join-Path $projectRoot 'src\doom\cr_nanosuit.c'),
        (Join-Path $projectRoot 'src\doom\cr_player.c'), '-o', $fixturePath)
    $compile = Invoke-ProcessProbe 'logic-compile' $compilerPath $compileArguments
    Add-Result $compile ($compile.completed -and $compile.exit_code -eq 0) 'Real cr_nanosuit.c/cr_player.c/cr_input.c with engine boundary stubs; warnings are errors.'
    if ($compile.completed -and $compile.exit_code -eq 0) {
        $probe = Invoke-ProcessProbe 'logic' $fixturePath @()
        $match = [regex]::Match($probe.output, 'F2_LOGIC PASS assertions=(\d+)')
        Add-Result $probe ($probe.completed -and $probe.exit_code -eq 0 -and $match.Success) @{
            assertions = $(if ($match.Success) { [int]$match.Groups[1].Value } else { $null })
        }
    }
}

if ($Mode -in @('All', 'Integration')) {
    # Mutate only state variables from breakpoints; the engine's own tick path
    # owns every transition. Firing uses the real weapon path (BT_ATTACK).
    $commands = @'
set $ticks = 0
set $cloak_start = 0
set $cloak_energy = 0
set $cloak_broken = 0
set $speed_start = 0
set $speed_energy = 0
set $regen_before = 0
set $regen_after = 0
set $jump_normal = 0
set $strength_jump = 0
set $strength_cost = 0
break *CR_PlayerThink
commands
silent
set $ticks = $ticks + 1
if $ticks == 5
set variable cr_players[0].suit.mode = 3
set variable cr_players[0].suit.energy = 100
set variable cr_players[0].suit.recharge_block_until = 0
set $cloak_start = 100
end
if $ticks >= 5 && $ticks <= 19
set variable players[0].cmd.forwardmove = 25
end
if $ticks == 20
set $cloak_energy = cr_players[0].suit.energy
printf "F2_CLOAK start=%d after15=%d mode=%d\n", $cloak_start, $cloak_energy, cr_players[0].suit.mode
end
if $ticks == 25
set variable players[0].cmd.buttons = 1
end
if $ticks == 30
printf "F2_FIRE mode=%d energy=%d visible=%d\n", cr_players[0].suit.mode, cr_players[0].suit.energy, cr_players[0].suit.cloak_visible
if cr_players[0].suit.mode == 0 && cr_players[0].suit.energy == 0
set $cloak_broken = 1
end
set variable players[0].cmd.buttons = 0
end
if $ticks == 35
set variable cr_players[0].suit.mode = 2
set variable cr_players[0].suit.energy = 100
set variable cr_players[0].suit.recharge_block_until = 0
set $speed_start = 100
end
if $ticks >= 35 && $ticks <= 49
set variable players[0].cmd.buttons2 = players[0].cmd.buttons2 | 1
set variable players[0].cmd.forwardmove = 25
end
if $ticks == 50
set $speed_energy = cr_players[0].suit.energy
printf "F2_SPEED start=%d after15=%d\n", $speed_start, $speed_energy
end
if $ticks == 55
set variable players[0].cmd.buttons2 = 0
set variable players[0].cmd.forwardmove = 0
set variable cr_players[0].suit.mode = 0
set variable cr_players[0].suit.energy = 50
set variable cr_players[0].suit.recharge_block_until = leveltime + 35
set $regen_before = 50
end
if $ticks == 100
set $regen_after = cr_players[0].suit.energy
printf "F2_RECHARGE before=%d after=%d block=%d leveltime=%d\n", $regen_before, $regen_after, cr_players[0].suit.recharge_block_until, leveltime
end
if $ticks == 110
set variable cr_players[0].suit.mode = 1
set variable cr_players[0].suit.energy = 100
set variable players[0].jumpTics = 0
set variable players[0].mo->z = players[0].mo->floorz
set variable players[0].cmd.arti = 128
end
if $ticks == 111
set $strength_jump = players[0].mo->momz
set $strength_cost = 100 - cr_players[0].suit.energy
set variable players[0].cmd.arti = 0
end
if $ticks == 120
set variable cr_players[0].suit.mode = 0
set variable cr_players[0].suit.energy = 100
set variable players[0].jumpTics = 0
set variable players[0].mo->z = players[0].mo->floorz
set variable players[0].cmd.arti = 128
end
if $ticks == 121
set $jump_normal = players[0].mo->momz
set variable players[0].cmd.arti = 0
end
if $ticks == 130
printf "F2_JUMP normal=%d strength=%d cost=%d\n", $jump_normal, $strength_jump, $strength_cost
printf "F2_ENGINE cloak_broken=%d\n", $cloak_broken
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'engine-suit' $commands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $cloakMatch = [regex]::Match($probe.output, 'F2_CLOAK start=(\d+) after15=(\d+) mode=(\d+)')
    $fireMatch = [regex]::Match($probe.output, 'F2_FIRE mode=(\d+) energy=(\d+) visible=(\d+)')
    $speedMatch = [regex]::Match($probe.output, 'F2_SPEED start=(\d+) after15=(\d+)')
    $rechargeMatch = [regex]::Match($probe.output, 'F2_RECHARGE before=(\d+) after=(\d+) block=(\d+)')
    $jumpMatch = [regex]::Match($probe.output, 'F2_JUMP normal=(\d+) strength=(\d+) cost=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $probe.output.Contains('F2_ENGINE cloak_broken=1') -and
        $cloakMatch.Success -and [int]$cloakMatch.Groups[2].Value -lt [int]$cloakMatch.Groups[1].Value -and
        [int]$cloakMatch.Groups[2].Value -ge 94 -and [int]$cloakMatch.Groups[3].Value -eq 3 -and
        $fireMatch.Success -and [int]$fireMatch.Groups[1].Value -eq 0 -and [int]$fireMatch.Groups[2].Value -eq 0 -and
        [int]$fireMatch.Groups[3].Value -eq 1 -and
        $speedMatch.Success -and [int]$speedMatch.Groups[2].Value -lt [int]$speedMatch.Groups[1].Value -and
        [int]$speedMatch.Groups[2].Value -ge 94 -and
        $rechargeMatch.Success -and [int]$rechargeMatch.Groups[2].Value -gt [int]$rechargeMatch.Groups[1].Value -and
        $jumpMatch.Success -and [int]$jumpMatch.Groups[2].Value -gt [int]$jumpMatch.Groups[1].Value -and
        [int]$jumpMatch.Groups[3].Value -eq 10
    Add-Result $probe $passed @{
        cloak = $cloakMatch.Value
        fire = $fireMatch.Value
        speed = $speedMatch.Value
        recharge = $rechargeMatch.Value
        jump = $jumpMatch.Value
        cloak_broken = $probe.output.Contains('F2_ENGINE cloak_broken=1')
    }

    # Vanilla must never run the suit tick or the Crysis player think.
    $vanillaCommands = @'
set $ticks = 0
set $suit_ticks = 0
set $crysis_thinks = 0
break *CR_SuitTick
commands
silent
set $suit_ticks = $suit_ticks + 1
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
set $ticks = $ticks + 1
if $ticks == 60
printf "F2_VANILLA ticks=%d suit_ticks=%d crysis_thinks=%d\n", $ticks, $suit_ticks, $crysis_thinks
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'vanilla-suit-isolated' $vanillaCommands @('-warp', '1')
    $vanillaMatch = [regex]::Match($probe.output, 'F2_VANILLA ticks=(\d+) suit_ticks=(\d+) crysis_thinks=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $vanillaMatch.Success -and [int]$vanillaMatch.Groups[1].Value -ge 60 -and
        [int]$vanillaMatch.Groups[2].Value -eq 0 -and [int]$vanillaMatch.Groups[3].Value -eq 0 -and
        !$probe.output.Contains('[CRYSIS] mode enabled')
    Add-Result $probe $passed $vanillaMatch.Value
}

if ($Mode -in @('All', 'Vanilla')) {
    # Same 175-command vanilla 1.9 fixture as F0/F1; the snapshot must match
    # the original 7.1 baseline exactly.
    $demoBytes = New-Object 'System.Collections.Generic.List[byte]'
    $demoBytes.AddRange([byte[]]@(109, 2, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0))
    for ($tic = 0; $tic -lt 175; $tic++) {
        [byte]$forward = 0; [byte]$turn = 0; [byte]$buttons = 0
        if ($tic -ge 10 -and $tic -lt 45) { $forward = 25 }
        if ($tic -ge 45 -and $tic -lt 65) { $turn = 4 }
        if ($tic -ge 65 -and $tic -lt 115) { $buttons = 1 }
        if ($tic -eq 120) { $buttons = 2 }
        if ($tic -eq 135 -or $tic -eq 140) { $buttons = 129 }
        $demoBytes.AddRange([byte[]]@($forward, 0, $turn, $buttons))
    }
    $demoBytes.Add(128)
    [IO.File]::WriteAllBytes($demoPath, $demoBytes.ToArray())
    $fixtureHash = (Get-FileHash -LiteralPath $demoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($fixtureHash -ne '7200bae8be45a224666fd7173a0c0e41aabde372b3182ca49975e1dc7b2cf5ce') {
        throw 'A demo de regressao divergiu da fixture vanilla F0.'
    }
    $commands = @'
break I_Quit
commands
silent
printf "SNAPSHOT map=%d gametic=%d leveltime=%d x=%d y=%d z=%d angle=%u health=%d mobjhealth=%d bullets=%d rng=%d paused=%d\n", gamemap, gametic, leveltime, players[0].mo->x, players[0].mo->y, players[0].mo->z, players[0].mo->angle, players[0].health, players[0].mo->health, players[0].ammo[0], prndindex, paused
continue
end
run
'@
    $probe = Invoke-GdbProbe 'vanilla-snapshot' $commands @('-playdemo', $demoPath)
    $snapshots = [regex]::Matches($probe.output, '(?m)^SNAPSHOT [^\r\n]+')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $snapshots.Count -eq 1 -and $snapshots[0].Value -eq $baselineSnapshot -and
        !$probe.output.Contains('[CRYSIS] mode enabled')
    Add-Result $probe $passed @{ baseline_snapshot = $baselineSnapshot;
        actual_snapshot = $(if ($snapshots.Count -eq 1) { $snapshots[0].Value } else { $null }) }
}

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    mode = $Mode
    executable_sha256 = $(if (Test-Path -LiteralPath $exePath) { (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
    limitations = @('Harness usa modulos reais e stubs nas fronteiras; nao valida SDL/teclado fisico.',
        'GDB muta apenas variaveis de estado; o tick real do motor executa as transicoes.',
        'SDL dummy e -nosound; imagem e audio perceptiveis nao verificados.',
        'Absorcao de dano e verificada em logica; o caminho P_DamageMobj nao e chamado no probe de engine.')
    results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
