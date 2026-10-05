param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\fase1-storage',
    [ValidateRange(10, 120)][int]$TimeoutSeconds = 30
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$exePath = [IO.Path]::GetFullPath((Join-Path $projectRoot $Executable))
$debuggerPath = Join-Path $projectRoot '.tools\w64devkit\bin\gdb.exe'
$iwadPath = Join-Path $projectRoot 'content\iwad\freedoom2.wad'
$logRoot = Join-Path (Join-Path $projectRoot $LogDirectory) ('run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$results = @()
function Quote-Gdb([string]$Value) {
    if ($Value.Contains('"')) { throw 'Caminho com aspas nao suportado.' }
    return '"' + $Value.Replace('\', '/') + '"'
}
function Invoke-Probe([string]$Name, [string]$Commands, [string]$Options) {
    $caseDir = Join-Path $logRoot $Name
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    $defaultCfg = Join-Path $caseDir 'default.cfg'
    $extraCfg = Join-Path $caseDir 'crispy-doom.cfg'
    [IO.File]::WriteAllText($defaultCfg, '', [Text.Encoding]::ASCII)
    [IO.File]::WriteAllText($extraCfg, "fullscreen 0`nforce_software_renderer 1`nsmooth_pixel_scaling 0`n", [Text.Encoding]::ASCII)
    $gameArgs = '-iwad ' + (Quote-Gdb $iwadPath) + ' -config ' + (Quote-Gdb $defaultCfg) +
        ' -extraconfig ' + (Quote-Gdb $extraCfg) + ' -savedir ' + (Quote-Gdb $caseDir) +
        ' -window -nosound -nogui ' + $Options
    $header = @"
set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args $gameArgs
"@
    $commandFile = Join-Path $caseDir 'trace.gdb'
    [IO.File]::WriteAllText($commandFile, $header + "`n" + $Commands, [Text.Encoding]::ASCII)
    $stdout = Join-Path $caseDir 'stdout.log'
    $stderr = Join-Path $caseDir 'stderr.log'
    $process = Start-Process -FilePath $debuggerPath -ArgumentList ('-nx -q -batch -x ' + (Quote-Gdb $commandFile) + ' ' + (Quote-Gdb $exePath)) `
        -WorkingDirectory $caseDir -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    # PS 5.1 can lose ExitCode for short processes without a cached handle.
    $null = $process.Handle
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (!$completed) {
        & taskkill.exe /PID $process.Id /T /F | Out-Null
    }
    $process.WaitForExit()
    $result = [pscustomobject]@{ name = $Name; completed = $completed; exit_code = $process.ExitCode;
        output = ([IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr)); directory = $caseDir }
    $process.Dispose()
    return $result
}

$storageCommands = @'
set $ticks = 0
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 15
set variable players[0].health = 77
set variable players[0].mo->health = 77
end
if $ticks == 20
set variable savegameslot = 0
set {char[16]} savedescription = "F1 VANILLA TEST"
set variable gameaction = ga_savegame
end
if $ticks == 25
printf "F1_STORAGE saved action=%d health=%d\n", gameaction, players[0].health
set variable players[0].health = 17
set variable players[0].mo->health = 17
end
if $ticks == 30
set variable gameaction = ga_loadgame
end
if $ticks == 31
printf "F1_STORAGE loaded action=%d health=%d mobjhealth=%d map=%d\n", gameaction, players[0].health, players[0].mo->health, gamemap
end
if $ticks == 45
set $pc = (void*)I_Quit
end
continue
end
run
'@
$storage = Invoke-Probe 'save-load' $storageCommands '-warp 1 -nomonsters'
$saves = @(Get-ChildItem -LiteralPath $storage.directory -Recurse -File -Filter '*.dsg')
$storagePassed = $storage.completed -and $storage.exit_code -eq 0 -and $storage.output.Contains('exited normally') -and
    $storage.output.Contains('F1_STORAGE saved action=0 health=77') -and
    $storage.output.Contains('F1_STORAGE loaded action=0 health=77 mobjhealth=77 map=1') -and
    $saves.Count -eq 1 -and $saves[0].Length -gt 100
$results += [pscustomobject]@{ case = 'save-load'; passed = $storagePassed; exit_code = $storage.exit_code; save_files = $saves.Count }
Write-Host ('vanilla save/load: ' + $storagePassed)
if (!$storagePassed) { Write-Host $storage.output }

$demoBase = Join-Path $logRoot 'vanilla-record'
$recordCommands = @'
set $ticks = 0
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks >= 10 && $ticks < 35
set variable netcmds[0].forwardmove = 25
end
if $ticks >= 36 && $ticks < 50
set variable netcmds[0].angleturn = 512
end
if $ticks >= 45 && $ticks < 65
set variable netcmds[0].buttons = 1
end
if $ticks == 70
set $pc = (void*)I_Quit
end
continue
end
break I_Quit
commands
silent
printf "STORAGE_SNAPSHOT map=%d gametic=%d leveltime=%d x=%d y=%d z=%d angle=%u health=%d bullets=%d rng=%d\n", gamemap, gametic, leveltime, players[0].mo->x, players[0].mo->y, players[0].mo->z, players[0].mo->angle, players[0].health, players[0].ammo[0], prndindex
continue
end
run
'@
$record = Invoke-Probe 'record' $recordCommands ('-warp 1 -nomonsters -record ' + (Quote-Gdb $demoBase))
$demoFile = $demoBase + '.lmp'
$recordSnapshots = [regex]::Matches($record.output, '(?m)^STORAGE_SNAPSHOT [^\r\n]+')
$recordPassed = $record.completed -and $record.exit_code -eq 0 -and $record.output.Contains('recorded') -and
    (Test-Path -LiteralPath $demoFile) -and (Get-Item -LiteralPath $demoFile).Length -gt 100 -and $recordSnapshots.Count -eq 1
$results += [pscustomobject]@{ case = 'record'; passed = $recordPassed; exit_code = $record.exit_code; demo = $demoFile }
Write-Host ('vanilla record: ' + $recordPassed)
if (!$recordPassed) { Write-Host $record.output }
if ($recordPassed) {
    $playCommands = $recordCommands.Substring($recordCommands.IndexOf('break I_Quit'))
    $play = Invoke-Probe 'play-recorded' $playCommands ('-playdemo ' + (Quote-Gdb $demoFile))
    $playSnapshots = [regex]::Matches($play.output, '(?m)^STORAGE_SNAPSHOT [^\r\n]+')
    $playPassed = $play.completed -and $play.exit_code -eq 0 -and $play.output.Contains('exited normally') -and
        $playSnapshots.Count -eq 1 -and $playSnapshots[0].Value -eq $recordSnapshots[0].Value
    $results += [pscustomobject]@{ case = 'play-recorded'; passed = $playPassed; exit_code = $play.exit_code;
        recorded_snapshot = $recordSnapshots[0].Value; played_snapshot = $(if ($playSnapshots.Count -eq 1) { $playSnapshots[0].Value } else { $null }) }
    Write-Host ('vanilla play recorded demo: ' + $playPassed)
    if (!$playPassed) { Write-Host $play.output }
}
@{ method = 'isolated GDB save/load and native demo record/playback'; results = $results;
    executable_sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant();
    limitations = 'GDB supplies gameactions/commands; SDL dummy; no keyboard/audio/visual playtest.' } |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
