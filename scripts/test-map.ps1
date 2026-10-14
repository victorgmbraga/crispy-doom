param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase9',
    [string]$Pwad = 'content\pwad\crysis-technical.wad',
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
$pwadPath = Get-ProjectPath $Pwad
if (!(Test-Path -LiteralPath $pwadPath)) {
    throw 'PWAD tecnico ausente. Execute: python scripts/make-technical-pwad.py content/iwad/freedoom2.wad content/pwad/crysis-technical.wad'
}
$infoPath = $pwadPath -replace '\.wad$', '.info'
if (!(Test-Path -LiteralPath $infoPath)) {
    throw 'Metadados do PWAD tecnico ausentes (.info). Regenere o PWAD.'
}
$mapInfo = @{}
foreach ($line in Get-Content -LiteralPath $infoPath) {
    $parts = $line.Split('=')
    if ($parts.Count -eq 2) { $mapInfo[$parts[0].Trim()] = $parts[1].Trim() }
}
$o1line = $mapInfo['objective1']
$o2line = $mapInfo['objective2']
$jamline = $mapInfo['jammer']
$exitline = $mapInfo['exit']
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

$commands = @"
define queue_key
set variable events[eventhead].type = ev_keydown
set variable events[eventhead].data1 = `$arg0
set variable events[eventhead].data2 = `$arg0
set variable events[eventhead].data3 = `$arg0
set variable eventhead = (eventhead + 1) % 64
end
define queue_key_up
set variable events[eventhead].type = ev_keyup
set variable events[eventhead].data1 = `$arg0
set variable events[eventhead].data2 = 0
set variable events[eventhead].data3 = 0
set variable eventhead = (eventhead + 1) % 64
end
set `$ticks = 0
set `$kpa = -1
set `$o1line = $o1line
set `$o2line = $o2line
set `$jamline = $jamline
set `$exitline = $exitline
set `$shot_sent = 0
break *D_ProcessEvents
commands
silent
if `$ticks == 15 && !`$shot_sent && gamestate == GS_LEVEL
set `$shot_sent = 1
set variable key_menu_screenshot = 128
queue_key key_menu_screenshot
end
continue
end
break *G_Ticker
commands
silent
set `$ticks = `$ticks + 1
if `$ticks == 10
set `$kpa = CR_AIRegisteredCount()
printf "F9_SPECIALS l301tag0=%d l302=%d l303=%d o1idx=%d o2idx=%d jamidx=%d exitidx=%d\n", 0, 0, 0, `$o1line, `$o2line, `$jamline, `$exitline
end
if `$ticks == 20
call P_UseSpecialLine(players[0].mo, &lines[`$o1line], 0)
call P_UseSpecialLine(players[0].mo, &lines[`$o1line], 0)
call P_UseSpecialLine(players[0].mo, &lines[`$o2line], 0)
call P_UseSpecialLine(players[0].mo, &lines[`$o2line], 0)
call P_UseSpecialLine(players[0].mo, &lines[`$jamline], 0)
printf "F9_MAP kpa=%d o1=%d o2=%d o3=%d canexit=%d exitline_special=%d\n", `$kpa, CR_ObjectiveState(1), CR_ObjectiveState(2), CR_ObjectiveState(3), CR_ObjectiveCanExit(), lines[`$exitline].special
end
if `$ticks == 30
call P_UseSpecialLine(players[0].mo, &lines[`$exitline], 0)
end
if `$ticks > 35 && gamestate != GS_LEVEL
if `$ticks == 40 || `$ticks == 50 || `$ticks == 60
queue_key key_fire
end
if `$ticks == 45 || `$ticks == 55 || `$ticks == 65
queue_key_up key_fire
end
end
if `$ticks == 120
printf "F9_EXIT map=%d o4=%d state=%d\n", gamemap, CR_ObjectiveState(4), gamestate
set `$pc = (void*)I_Quit
end
continue
end
run
"@

$probe = Invoke-GdbProbe 'technical-map' $commands @('-crysis', '-crdebug', '-file', $pwadPath, '-warp', '1')
$mapMatch = [regex]::Match($probe.output, 'F9_MAP kpa=(\d+) o1=(\d+) o2=(\d+) o3=(\d+) canexit=(\d+) exitline_special=(\d+)')
$exitMatch = [regex]::Match($probe.output, 'F9_EXIT map=(\d+) o4=(\d+) state=(\d+)')
$passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
    $mapMatch.Success -and
    [int]$mapMatch.Groups[1].Value -ge 3 -and
    [int]$mapMatch.Groups[2].Value -eq 2 -and
    [int]$mapMatch.Groups[3].Value -eq 2 -and
    [int]$mapMatch.Groups[4].Value -eq 2 -and
    [int]$mapMatch.Groups[5].Value -eq 1 -and
    [int]$mapMatch.Groups[6].Value -eq 302 -and
    $exitMatch.Success -and
    [int]$exitMatch.Groups[1].Value -eq 2 -and
    [int]$exitMatch.Groups[2].Value -eq 2
Add-Result $probe $passed @{
    map = $mapMatch.Value
    exit = $exitMatch.Value
    screenshot = $(if (@(Get-ChildItem -LiteralPath (Join-Path $logRoot $probe.case) -File -Filter 'DOOM*').Count -ge 1) { 'captured' } else { $null })
}

# Early exit is refused on the real map as well.
$refuseCommands = @"
set `$ticks = 0
set `$exitline = $exitline
break *G_Ticker
commands
silent
set `$ticks = `$ticks + 1
if `$ticks == 10
call P_UseSpecialLine(players[0].mo, &lines[`$exitline], 0)
end
if `$ticks == 40
printf "F9_REFUSE map=%d o4=%d state=%d\n", gamemap, CR_ObjectiveState(4), gamestate
set `$pc = (void*)I_Quit
end
continue
end
run
"@
$probe = Invoke-GdbProbe 'technical-map-refuse' $refuseCommands @('-crysis', '-crdebug', '-file', $pwadPath, '-warp', '1')
$match = [regex]::Match($probe.output, 'F9_REFUSE map=(\d+) o4=(\d+) state=(\d+)')
$passed = $probe.completed -and $probe.exit_code -eq 0 -and $probe.output.Contains('exited normally') -and
    $match.Success -and [int]$match.Groups[1].Value -eq 1 -and
    [int]$match.Groups[2].Value -eq 0 -and [int]$match.Groups[3].Value -eq 0
Add-Result $probe $passed $match.Value

$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    pwad_sha256 = $(if (Test-Path -LiteralPath $pwadPath) { (Get-FileHash -LiteralPath $pwadPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
    executable_sha256 = $(if (Test-Path -LiteralPath $exePath) { (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null })
    limitations = @('Mapa tecnico derivado do MAP01 do Freedoom (geometria intacta); nao e o slice Contact da F9.',
        'Objetivos concluidos por chamadas P_UseSpecialLine; o percurso jogavel completo depende de playtest.',
        'Teste headless (SDL dummy, -nosound).')
    results = @($results.ToArray())
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
