param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase1',
    [ValidateSet('All', 'Logic', 'Cli', 'Integration', 'Vanilla')][string]$Mode = 'All',
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
$demoPath = Join-Path $logRoot 'vanilla-smoke.lmp'
# Frozen result of the unmodified Crispy Doom 7.1 baseline, SHA256
# c21b894fdf2a1e0de2db757d9d2710ae901f285ddc39d017c7ba0f3606576047.
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
    # Drain redirected streams after the asynchronous WaitForExit overload.
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
    $fixturePath = Join-Path $logRoot 'f1-state-test.exe'
    $sdlHeader = Join-Path $projectRoot '.deps\SDL2-2.32.10\x86_64-w64-mingw32\include\SDL2'
    $compileArguments = @('-std=c99', '-Wall', '-Wextra', '-Werror', '-I', (Join-Path $projectRoot 'src'),
        '-I', (Join-Path $projectRoot 'src\doom'), '-I', (Join-Path $projectRoot 'build'), '-I', $sdlHeader,
        (Join-Path $PSScriptRoot 'f1-state-test.c'), (Join-Path $projectRoot 'src\doom\cr_input.c'),
        (Join-Path $projectRoot 'src\doom\cr_player.c'), '-o', $fixturePath)
    $compile = Invoke-ProcessProbe 'logic-compile' $compilerPath $compileArguments
    Add-Result $compile ($compile.completed -and $compile.exit_code -eq 0) 'Real cr_input.c/cr_player.c with engine boundary stubs; warnings are errors.'
    if ($compile.completed -and $compile.exit_code -eq 0) {
        $probe = Invoke-ProcessProbe 'logic' $fixturePath @()
        $match = [regex]::Match($probe.output, 'F1_LOGIC PASS assertions=(\d+) ticcmd_size=(\d+)')
        Add-Result $probe ($probe.completed -and $probe.exit_code -eq 0 -and $match.Success) @{
            assertions = $(if ($match.Success) { [int]$match.Groups[1].Value } else { $null })
            ticcmd_size = $(if ($match.Success) { [int]$match.Groups[2].Value } else { $null })
        }
    }
}

if ($Mode -in @('All', 'Cli')) {
    # No IWAD is supplied. Each option must be rejected before data loading,
    # network initialization or startup actions can open a demo/save file.
    $blockedCases = @(
        @('-playdemo', 'missing-f1-demo'), @('-timedemo', 'missing-f1-demo'),
        @('-record', 'blocked-f1-demo'), @('-recordfrom', '0', 'blocked-f1-demo'),
        @('-recordfromto', 'missing-f1-demo', 'blocked-f1-demo'), @('-loadgame', '0'),
        @('-connect', '127.0.0.1'), @('-server'), @('-privateserver'), @('-autojoin'),
        @('-dedicated'), @('-search'), @('-query', '127.0.0.1'), @('-localsearch'),
        @('-solo-net'), @('-netdemo'), @('-drone'), @('-left'), @('-right'),
        @('-deathmatch'), @('-altdeath'), @('-dm3'), @('-net')
    )
    foreach ($blocked in $blockedCases) {
        $name = 'cli-' + $blocked[0].TrimStart('-')
        $probe = Invoke-ProcessProbe $name $exePath (@('-crysis', '-nogui', '-nosound') + $blocked)
        $passed = $probe.completed -and $probe.exit_code -ne 0 -and
            $probe.output.Contains('[CRYSIS]') -and $probe.output.Contains($blocked[0]) -and
            !$probe.output.Contains('W_Init:') -and !$probe.output.Contains('NET_Init:') -and
            !$probe.output.Contains('Playing demo ') -and
            @(Get-ChildItem -LiteralPath (Join-Path $logRoot $name) -File -Filter '*.lmp').Count -eq 0 -and
            @(Get-ChildItem -LiteralPath (Join-Path $logRoot $name) -File -Filter '*.dsg').Count -eq 0
        Add-Result $probe $passed @{ rejected_option = $blocked[0]; iwad_supplied = $false }
    }
    $probe = Invoke-ProcessProbe 'cli-record-without-value' $exePath @('-crysis', '-nogui', '-record')
    Add-Result $probe ($probe.completed -and $probe.exit_code -ne 0 -and
        $probe.output.Contains('[CRYSIS] -record') -and !$probe.output.Contains('W_Init:')) @{
            rejected_option = '-record'; malformed_option = $true
        }
    $responsePath = Join-Path $logRoot 'blocked-response.rsp'
    [IO.File]::WriteAllText($responsePath, '-crysis -nogui -playdemo missing-response-demo', [Text.Encoding]::ASCII)
    $probe = Invoke-ProcessProbe 'cli-response-demo' $exePath @(('@' + $responsePath))
    Add-Result $probe ($probe.completed -and $probe.exit_code -ne 0 -and
        $probe.output.Contains('[CRYSIS] -playdemo') -and !$probe.output.Contains('W_Init:')) @{
            rejected_option = '-playdemo'; response_file = $true
        }
}

if ($Mode -in @('All', 'Integration')) {
    # Inject events into the real queue before D_ProcessEvents. This runs the
    # responder/menu/command-builder path, without replacing engine logic or
    # calling inferior functions from inside a breakpoint.
    $inputCommands = @'
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
define queue_focus
set variable events[eventhead].type = ev_focus
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
define queue_key_up
set variable events[eventhead].type = ev_keyup
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
define queue_mouse
set variable mouse_button_state = $arg0
set variable events[eventhead].type = ev_mouse
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = 8
set variable events[eventhead].data3 = 4
set variable eventhead = (eventhead + 1) % 64
end
set $polls = 0
set $producer = 0
set $producer_no_autorun = 0
set $focus_clear = 0
set $menu_clear = 0
set $save_load_blocks = 0
break CR_RejectUnsupported
commands
silent
if feature[0] == 115 && feature[4] == 47
set $save_load_blocks = $save_load_blocks + 1
end
continue
end
break CR_BuildTiccmd
commands
silent
if $polls >= 1 && $polls < 12
if cmd->forwardmove == 25 && cmd->sidemove == 0 && cmd->angleturn != 0 && (cmd->arti & 128) && cmd->lookdir != 0 && !(cmd->buttons & 2)
set $producer = 1
printf "F1_PRODUCER forward=%d side=%d angle=%d jump=%d look=%d use=%d autorun=%d\n", cmd->forwardmove, cmd->sidemove, cmd->angleturn, cmd->arti, cmd->lookdir, cmd->buttons & 2, joybspeed
end
end
if $polls == 19
set $menu_clear = (cmd->forwardmove == 0 && cmd->sidemove == 0 && !(cmd->buttons & 2) && !cr_keys[key_up] && !cr_keys[key_alt_up] && !cr_keys[key_cr_interact] && !cr_keys[key_cr_sprint] && !cr_players[0].buttons_down && mouse_button_state == 0)
end
if $polls == 15
set $producer_no_autorun = (cmd->forwardmove == 25 && cmd->sidemove == 0 && joybspeed == 2)
end
continue
end
break *D_ProcessEvents
commands
silent
if gamestate == GS_LEVEL
set $polls = $polls + 1
if $polls == 1
set variable crispy->jump = 1
set variable crispy->freelook = 1
set variable crispy->mouselook = 1
set variable joybspeed = 20
queue_key key_up
queue_key key_alt_up
queue_key key_cr_sprint
queue_key key_cr_reload
queue_key key_jump
queue_key key_toggleautorun
queue_mouse 2
end
if $polls == 12
queue_focus 0
end
if $polls == 13
set $focus_clear = (cr_players[0].buttons_down == 0 && !cr_players[0].sprinting && !cr_players[0].ads && !gamekeydown[key_up] && !gamekeydown[key_alt_up] && !gamekeydown[key_speed] && !gamekeydown[key_jump] && mouse_button_state == 0)
end
if $polls == 15
set variable joybspeed = 2
queue_focus 1
queue_key key_up
queue_key key_alt_up
queue_key key_cr_interact
queue_key key_cr_sprint
queue_mouse 2
end
if $polls == 16
queue_key key_menu_activate
end
if $polls == 17
queue_key_up key_up
queue_key_up key_alt_up
queue_key_up key_cr_interact
queue_key_up key_cr_sprint
end
if $polls == 18
queue_key key_menu_activate
end
if $polls == 20
queue_key key_menu_save
end
if $polls == 21
queue_key key_menu_confirm
queue_key key_menu_activate
end
if $polls == 24
queue_key key_menu_load
end
if $polls == 25
queue_key key_menu_confirm
queue_key key_menu_activate
end
if $polls == 28
queue_key key_menu_qsave
end
if $polls == 29
queue_key key_menu_confirm
end
if $polls == 32
queue_key key_menu_qload
end
if $polls == 33
queue_key key_menu_confirm
end
if $polls == 40
printf "F1_INPUT polls=%d producer=%d producer_no_autorun=%d focus_clear=%d menu_clear=%d menu_blocks=%d save_entry=%d action=%d\n", $polls, $producer, $producer_no_autorun, $focus_clear, $menu_clear, $save_load_blocks, saveStringEnter, gameaction
set $pc = (void*)I_Quit
end
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'engine-input-menus' $inputCommands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $expectedInput = 'F1_INPUT polls=40 producer=1 producer_no_autorun=1 focus_clear=1 menu_clear=1 menu_blocks=4 save_entry=0 action=0'
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $probe.output.Contains($expectedInput) -and
        @(Get-ChildItem -LiteralPath (Join-Path $logRoot $probe.case) -File -Filter '*.dsg').Count -eq 0
    Add-Result $probe $passed $expectedInput

    $commands = @'
set $ticks = 0
set $simticks = 0
set $newgames = 0
set $levels = 0
set $resets = 0
set $menu_frozen = 0
set $pause_frozen = 0
set $expect_reset = 0
set $quit_requested = 0
break G_InitNew
commands
silent
set $newgames = $newgames + 1
continue
end
break P_SetupLevel
commands
silent
set $levels = $levels + 1
continue
end
break *CR_Ticker
commands
silent
set $simticks = $simticks + 1
if $expect_reset
if cr_players[0].initialized && cr_players[0].buttons_down == 0 && cr_players[0].buttons_pressed == 0 && cr_players[0].buttons_released == 0 && !cr_players[0].sprinting && !cr_players[0].ads && !cr_players[0].crouching
set $resets = $resets + 1
end
set $expect_reset = 0
end
if $simticks == 1
set variable players[0].cmd.buttons2 = 255
end
if $simticks == 2
printf "F1_ENGINE first down=%d pressed=%d released=%d sprint=%d ads=%d crouch=%d\n", cr_players[0].buttons_down, cr_players[0].buttons_pressed, cr_players[0].buttons_released, cr_players[0].sprinting, cr_players[0].ads, cr_players[0].crouching
set variable players[0].cmd.buttons2 = 255
end
if $simticks == 3
printf "F1_ENGINE held down=%d pressed=%d released=%d\n", cr_players[0].buttons_down, cr_players[0].buttons_pressed, cr_players[0].buttons_released
set variable players[0].cmd.buttons2 = 0
end
if $simticks == 4
printf "F1_ENGINE release down=%d pressed=%d released=%d\n", cr_players[0].buttons_down, cr_players[0].buttons_pressed, cr_players[0].buttons_released
set variable players[0].cmd.buttons2 = 255
end
if $simticks == 5
printf "F1_ENGINE repress down=%d pressed=%d released=%d\n", cr_players[0].buttons_down, cr_players[0].buttons_pressed, cr_players[0].buttons_released
end
continue
end
break SDL_Quit
commands
silent
if $quit_requested
printf "F1_LIFECYCLE map=%d ticks=%d newgames=%d levels=%d resets=%d menu_frozen=%d pause_frozen=%d active=%d demo=%d recording=%d action=%d\n", gamemap, $ticks, $newgames, $levels, $resets, $menu_frozen, $pause_frozen, cr_level_started, demoplayback, demorecording, gameaction
end
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 30
set $menu_leveltime = leveltime
set $menu_simticks = $simticks
set variable menuactive = 1
end
if $ticks == 40
set $menu_frozen = (leveltime == $menu_leveltime && $simticks == $menu_simticks)
set variable menuactive = 0
end
if $ticks == 50
set $pause_leveltime = leveltime
set $pause_simticks = $simticks
set variable paused = 1
end
if $ticks == 55
set $pause_frozen = (leveltime == $pause_leveltime && $simticks == $pause_simticks)
set variable paused = 0
end
if $ticks == 60 || $ticks == 90 || $ticks == 140
set variable cr_players[0].buttons_down = 255
set variable cr_players[0].buttons_pressed = 255
set variable cr_players[0].buttons_released = 255
set variable cr_players[0].sprinting = 1
set variable cr_players[0].ads = 1
set variable cr_players[0].crouching = 1
set $expect_reset = 1
end
if $ticks == 60
set variable d_skill = gameskill
set variable d_episode = gameepisode
set variable d_map = gamemap
set variable gameaction = ga_newgame
end
if $ticks == 90
set variable gameaction = ga_loadlevel
end
if $ticks == 100
set variable gameaction = ga_savegame
end
if $ticks == 110
set variable gameaction = ga_loadgame
end
if $ticks == 120
set variable gameaction = ga_playdemo
end
if $ticks == 130
set variable gameaction = ga_completed
end
if $ticks == 140
set variable gameaction = ga_worlddone
end
if $ticks == 150
set $quit_requested = 1
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'engine-state-lifecycle' $commands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $expected = @(
        'F1_ENGINE first down=255 pressed=255 released=0 sprint=1 ads=1 crouch=1',
        'F1_ENGINE held down=255 pressed=0 released=0',
        'F1_ENGINE release down=0 pressed=0 released=255',
        'F1_ENGINE repress down=255 pressed=255 released=0',
        'F1_LIFECYCLE map=2 ticks=150 newgames=2 levels=4 resets=3 menu_frozen=1 pause_frozen=1 active=0 demo=0 recording=0 action=0'
    )
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally')
    foreach ($line in $expected) { $passed = $passed -and $probe.output.Contains($line) }
    $inputTransitions = [regex]::Matches($probe.output, '\[CRYSIS\] input player=0').Count
    $passed = $passed -and $inputTransitions -eq 4
    $saveFiles = @(Get-ChildItem -LiteralPath (Join-Path $logRoot $probe.case) -File -Filter '*.dsg').Count
    $passed = $passed -and $saveFiles -eq 0
    Add-Result $probe $passed @{ expected_traces = $expected; save_files = $saveFiles;
        debug_input_transitions = $inputTransitions }

    # Force 20 title page advances without waiting for their visual timers.
    # Attract mode must keep the title/menu usable and never dispatch a demo.
    $titleCommands = @'
set $ticks = 0
set $demo_attempts = 0
set $title_pages = 0
set $menu_opened = 0
set $menu_sent = 0
break *D_ProcessEvents
commands
silent
if gamestate == GS_DEMOSCREEN && !$menu_sent
set $menu_sent = 1
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = key_menu_activate
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
continue
end
break G_DeferedPlayDemo
commands
silent
set $demo_attempts = $demo_attempts + 1
continue
end
break G_DoPlayDemo
commands
silent
set $demo_attempts = $demo_attempts + 1
continue
end
break D_DoAdvanceDemo
commands
silent
set $title_pages = $title_pages + 1
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
set variable advancedemo = 1
if menuactive
set $menu_opened = 1
end
if $ticks == 20
printf "F1_TITLE ticks=%d pages=%d demo_attempts=%d state=%d active=%d menu_opened=%d\n", $ticks, $title_pages, $demo_attempts, gamestate, cr_level_started, $menu_opened
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'title' $titleCommands @('-crysis')
    $titleMatch = [regex]::Match($probe.output, 'F1_TITLE ticks=20 pages=(\d+) demo_attempts=0 state=3 active=0 menu_opened=1')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $titleMatch.Success -and [int]$titleMatch.Groups[1].Value -ge 15
    Add-Result $probe $passed $(if ($titleMatch.Success) { $titleMatch.Value } else { 'missing title trace' })
}

if ($Mode -in @('All', 'Vanilla')) {
    # Generate the same 175-command vanilla 1.9 fixture as the F0 baseline;
    # the suite does not depend on retained smoke-test log files.
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
        'GDB injeta ticcmds e gameactions; nao substitui playtest de menus e foco de janela.',
        'SDL dummy e -nosound; imagem e audio perceptiveis nao verificados.',
        'Regressao vanilla usa uma demo controlada, nao uma suite completa de save/netgame.')
    results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
