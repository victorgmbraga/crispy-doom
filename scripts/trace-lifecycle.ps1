param(
    [string]$Executable = 'build\src\crispy-doom.exe',
    [string]$LogDirectory = 'docs\validacao\logs\lifecycle',
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
$logRoot = Get-ProjectPath $LogDirectory
$debuggerPath = Join-Path $projectRoot '.tools\w64devkit\bin\gdb.exe'
$iwadPath = Join-Path $projectRoot 'content\iwad\freedoom2.wad'
foreach ($requiredPath in @($exePath, $debuggerPath, $iwadPath)) {
    if (!(Test-Path -LiteralPath $requiredPath)) { throw "Arquivo requerido ausente: $requiredPath" }
}
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$results = @()
foreach ($caseName in @('vanilla', 'crysis')) {
    $caseDir = Join-Path $logRoot $caseName
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
    $configPath = Join-Path $caseDir 'default.cfg'
    $extraConfigPath = Join-Path $caseDir 'crispy-doom.cfg'
    [IO.File]::WriteAllText($configPath, '', [Text.Encoding]::ASCII)
    [IO.File]::WriteAllText($extraConfigPath, "fullscreen 0`nforce_software_renderer 1`nwindow_width 640`nwindow_height 400`nsmooth_pixel_scaling 0`n", [Text.Encoding]::ASCII)
    $gameArguments = '-iwad ' + (Quote-GdbPath $iwadPath) + ' -config ' + (Quote-GdbPath $configPath) +
        ' -extraconfig ' + (Quote-GdbPath $extraConfigPath) + ' -savedir ' + (Quote-GdbPath $caseDir) +
        ' -nosound -nogui -window -warp 1 -nomonsters'
    if ($caseName -eq 'crysis') { $gameArguments += ' -crysis' }
    # Integration probe: GDB changes only the running process. Existing game
    # actions drive new-game, reload, completion and next-map paths. This is
    # explicitly not a keyboard/menu playtest or a demo-compatible scenario.
    $gdbTemplate = @'
set pagination off
set confirm off
set breakpoint pending on
set environment SDL_VIDEODRIVER dummy
set environment SDL_AUDIODRIVER dummy
set environment SDL_RENDER_DRIVER software
set args @GAME_ARGS@
set $ticks = 0
set $newgames = 0
set $levels = 0
set $crnew = 0
set $crstart = 0
set $crclean = 0
set $crticks = 0
set $menu_frozen = 0
set $pause_frozen = 0
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
break CR_NewGame
commands
silent
set $crnew = $crnew + 1
continue
end
break CR_LevelStart
commands
silent
set $crstart = $crstart + 1
continue
end
break CR_LevelEnd
commands
silent
if cr_level_started
set $crclean = $crclean + 1
end
continue
end
break CR_Ticker
commands
silent
set $crticks = $crticks + 1
continue
end
break SDL_Quit
commands
silent
if $quit_requested
printf "LIFECYCLE_FINAL map=%d ticks=%d newgames=%d levels=%d crnew=%d crstart=%d crclean=%d crticks=%d menu_frozen=%d pause_frozen=%d level_active=%d\n", gamemap, $ticks, $newgames, $levels, $crnew, $crstart, $crclean, $crticks, $menu_frozen, $pause_frozen, cr_level_started
end
continue
end
break *G_Ticker
commands
silent
set $ticks = $ticks + 1
if $ticks == 20
set $menu_leveltime = leveltime
set $menu_crticks = $crticks
set variable menuactive = 1
end
if $ticks == 30
set $menu_frozen = (leveltime == $menu_leveltime && $crticks == $menu_crticks)
set variable menuactive = 0
end
if $ticks == 40
set $pause_leveltime = leveltime
set $pause_crticks = $crticks
set variable paused = 1
end
if $ticks == 45
set $pause_frozen = (leveltime == $pause_leveltime && $crticks == $pause_crticks)
set variable paused = 0
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
if $ticks == 110
set variable gameaction = ga_completed
end
if $ticks == 120
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
    $gdbCommands = $gdbTemplate.Replace('@GAME_ARGS@', $gameArguments)
    $commandPath = Join-Path $caseDir 'trace.gdb'
    [IO.File]::WriteAllText($commandPath, $gdbCommands, [Text.Encoding]::ASCII)
    $stdoutPath = Join-Path $caseDir 'stdout.log'
    $stderrPath = Join-Path $caseDir 'stderr.log'
    $debuggerArguments = '-nx -q -batch -x ' + (Quote-GdbPath $commandPath) + ' ' + (Quote-GdbPath $exePath)
    $process = Start-Process -FilePath $debuggerPath -ArgumentList $debuggerArguments -WorkingDirectory $projectRoot `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (!$completed) {
        & taskkill.exe /PID $process.Id /T /F | Out-Null
        $process.WaitForExit()
    }
    $process.Refresh()
    $output = [IO.File]::ReadAllText($stdoutPath) + [IO.File]::ReadAllText($stderrPath)
    $traceMatch = [regex]::Match($output, '(?m)^LIFECYCLE_FINAL [^\r\n]+')
    $traceText = $null
    if ($traceMatch.Success) { $traceText = $traceMatch.Value }
    $expectedCr = 'crnew=0 crstart=0 crclean=0 crticks=0'
    if ($caseName -eq 'crysis') { $expectedCr = 'crnew=2 crstart=4 crclean=4 crticks=124' }
    # At G_Ticker entry, redirect the instruction pointer to the noreturn
    # I_Quit path. This avoids inferior function calls nested under breakpoints.
    # The normal engine exit callbacks run before the SDL_Quit observation.
    $passed = $completed -and $process.ExitCode -eq 0 -and $output.Contains('exited normally') -and
        $traceMatch.Success -and $traceText.Contains('map=2 ticks=150 newgames=2 levels=4') -and
        $traceText.Contains($expectedCr) -and $traceText.Contains('menu_frozen=1 pause_frozen=1 level_active=0')
    $results += [pscustomobject][ordered]@{
        case = $caseName
        passed = $passed
        completed = $completed
        debugger_exit_code = $process.ExitCode
        trace = $traceText
        stdout = $stdoutPath
        stderr = $stderrPath
    }
    Write-Host ($caseName + ': ' + $(if ($passed) { 'PASS' } else { 'FAIL' }))
    if ($traceText) { Write-Host $traceText }
    $process.Dispose()
}
$report = [ordered]@{
    generated_at = (Get-Date).ToString('o')
    method = 'gdb-injected-existing-lifecycle-actions'
    executable_sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
    limitations = @('Aciona estados e gameaction pelo debugger; nao prova input de teclado/menu.',
        'SDL dummy e -nosound; imagem/audio perceptiveis nao verificados.',
        'GDB redireciona o PC para I_Quit no tic 150; encerramento nao foi solicitado pelo teclado.')
    results = $results
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logRoot 'result.json') -Encoding UTF8
if (@($results | Where-Object { !$_.passed }).Count -gt 0) { exit 1 }
exit 0
