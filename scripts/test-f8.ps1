param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase8',
    [ValidateSet('All', 'Logic', 'Integration')][string]$Mode = 'All',
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
    $fixturePath = Join-Path $logRoot 'f8-objective-test.exe'
    $compileArguments = @('-std=c99', '-Wall', '-Wextra', '-Werror', '-I', (Join-Path $projectRoot 'src'),
        '-I', (Join-Path $projectRoot 'src\doom'), '-I', (Join-Path $projectRoot 'build'),
        (Join-Path $PSScriptRoot 'f8-objective-test.c'),
        (Join-Path $projectRoot 'src\doom\cr_objective.c'), '-o', $fixturePath)
    $compile = Invoke-ProcessProbe 'logic-compile' $compilerPath $compileArguments
    Add-Result $compile ($compile.completed -and $compile.exit_code -eq 0) 'Real cr_objective.c; warnings are errors.'
    if ($compile.completed -and $compile.exit_code -eq 0) {
        $probe = Invoke-ProcessProbe 'logic' $fixturePath @()
        $match = [regex]::Match($probe.output, 'F8_LOGIC PASS assertions=(\d+)')
        Add-Result $probe ($probe.completed -and $probe.exit_code -eq 0 -and $match.Success) @{
            assertions = $(if ($match.Success) { [int]$match.Groups[1].Value } else { $null })
        }
    }
}

if ($Mode -in @('All', 'Integration')) {
    # Drive the engine use-dispatch with real linedefs: mutate lines[0] to a
    # project special and call the vanilla entry point the game uses.
    $commands = @'
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = $arg0
set variable events[eventhead].data3 = $arg0
set variable eventhead = (eventhead + 1) % 64
end
define queue_key_up
set variable events[eventhead].type = ev_keyup
set variable events[eventhead].data1 = $arg0
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
set $ticks = 0
set $refuse_map = 0
set $shot_sent = 0
set $wi_sent = 0
break *D_ProcessEvents
commands
silent
if $ticks == 52 && !$shot_sent && gamestate == GS_LEVEL
set $shot_sent = 1
set variable key_menu_screenshot = 128
queue_key key_menu_screenshot
end
if $ticks > 65 && gamestate != GS_LEVEL
if $ticks == 70 || $ticks == 80 || $ticks == 90
queue_key key_fire
end
if $ticks == 75 || $ticks == 85 || $ticks == 95
queue_key_up key_fire
end
end
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 20
set variable lines[0].special = 302
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
set $refuse_map = gamemap
end
if $ticks == 25
set variable lines[0].special = 301
set variable lines[0].tag = 1
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 30
set variable lines[0].special = 301
set variable lines[0].tag = 1
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 35
set variable lines[0].special = 301
set variable lines[0].tag = 2
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 38
set variable lines[0].special = 301
set variable lines[0].tag = 2
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 42
set variable lines[0].special = 303
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 50
printf "F8_STATES o1=%d o2=%d o3=%d o4=%d canexit=%d map=%d\n", CR_ObjectiveState(1), CR_ObjectiveState(2), CR_ObjectiveState(3), CR_ObjectiveState(4), CR_ObjectiveCanExit(), gamemap
end
if $ticks == 60
set variable lines[0].special = 302
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
end
if $ticks == 120
printf "F8_EXIT refuse_map=%d o4=%d map=%d state=%d\n", $refuse_map, CR_ObjectiveState(4), gamemap, gamestate
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'mission-objectives' $commands @('-crysis', '-crdebug', '-warp', '1', '-nomonsters')
    $statesMatch = [regex]::Match($probe.output, 'F8_STATES o1=(\d+) o2=(\d+) o3=(\d+) o4=(\d+) canexit=(\d+) map=(\d+)')
    $exitMatch = [regex]::Match($probe.output, 'F8_EXIT refuse_map=(\d+) o4=(\d+) map=(\d+) state=(\d+)')
    $shotFiles = @(Get-ChildItem -LiteralPath (Join-Path $logRoot $probe.case) -File |
        Where-Object { $_.Name -like 'DOOM*' -and ($_.Extension -eq '.png' -or $_.Extension -eq '.pcx') })
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $statesMatch.Success -and
        [int]$statesMatch.Groups[1].Value -eq 2 -and
        [int]$statesMatch.Groups[2].Value -eq 2 -and
        [int]$statesMatch.Groups[3].Value -eq 2 -and
        [int]$statesMatch.Groups[4].Value -eq 0 -and
        [int]$statesMatch.Groups[5].Value -eq 1 -and
        $exitMatch.Success -and
        [int]$exitMatch.Groups[1].Value -eq 1 -and   # Early exit refused.
        [int]$exitMatch.Groups[2].Value -eq 2 -and   # Exit objective completed.
        [int]$exitMatch.Groups[3].Value -eq 2 -and   # Advanced to MAP02.
        [int]$exitMatch.Groups[4].Value -eq 0 -and   # Back in a level.
        $shotFiles.Count -ge 1
    Add-Result $probe $passed @{
        states = $statesMatch.Value
        exit = $exitMatch.Value
        screenshot = $(if ($shotFiles.Count -ge 1) { $shotFiles[0].Name } else { $null })
        objective_message = $(if ($probe.output -match 'OBJECTIVE COMPLETE') { 'yes' } else { 'no' })
    }

    # Vanilla: reserved specials stay inert without the mode.
    $vanillaCommands = @'
set $ticks = 0
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 30
set variable lines[0].special = 303
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
set variable lines[0].special = 301
set variable lines[0].tag = 1
call P_UseSpecialLine(players[0].mo, &lines[0], 0)
printf "F8_VANILLA o1=%d o3=%d map=%d\n", CR_ObjectiveState(1), CR_ObjectiveState(3), gamemap
end
if $ticks == 40
set $pc = (void*)I_Quit
end
continue
end
run
'@
    $probe = Invoke-GdbProbe 'vanilla-objectives-isolated' $vanillaCommands @('-warp', '1')
    $match = [regex]::Match($probe.output, 'F8_VANILLA o1=(\d+) o3=(\d+) map=(\d+)')
    $passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
        $match.Success -and [int]$match.Groups[1].Value -eq 0 -and
        [int]$match.Groups[2].Value -eq 0 -and [int]$match.Groups[3].Value -eq 1 -and
        !$probe.output.Contains('[CRYSIS] mode enabled')
    Add-Result $probe $passed $match.Value
}

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    mode = $Mode
    executable_sha256 = $(if (Test-Path -LiteralPath $exePath) { (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
    limitations = @('Linhas de mapa reais foram reaproveitadas no teste; o mapa tecnico com os specials ainda nao existe.',
        'SSaida validada ate MAP02 do IWAD; o fluxo completo depende do slice (F9).',
        'Teste headless (SDL dummy, -nosound).')
    results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
