param(
    [ValidateSet('Crysis', 'Vanilla')]
    [string]$Mode = 'Crysis',
    [ValidateSet('Freedoom', 'Technical')]
    [string]$Scenario = 'Freedoom',
    [switch]$Build,
    [switch]$DebugInput,
    [string[]]$GameArguments = @()
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$executablePath = Join-Path $projectRoot 'build\src\crispy-doom.exe'
$iwadPath = Join-Path $projectRoot 'content\iwad\freedoom2.wad'
$pwadPath = Join-Path $projectRoot 'content\pwad\crysis-technical.wad'
$runDirectory = Join-Path $projectRoot 'build\run'

function ConvertTo-NativeArgument([string]$Argument) {
    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') { return $Argument }
    # Start-Process joins ArgumentList. Preserve spaces, quotes and trailing
    # backslashes according to the Windows native argument parsing rules.
    $escapedArgument = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    $escapedArgument = [regex]::Replace($escapedArgument, '(\\+)$', '$1$1')
    return '"' + $escapedArgument + '"'
}

Push-Location -LiteralPath $projectRoot
try {
    if ($Scenario -eq 'Technical') {
        if ($Mode -ne 'Crysis') {
            throw 'O mapa tecnico requer -Mode Crysis; use -Scenario Freedoom para comparar com o vanilla.'
        }
        if (!(Test-Path -LiteralPath $pwadPath)) {
            throw 'PWAD tecnico ausente: content/pwad/crysis-technical.wad. Restaure o arquivo versionado ou regenere com scripts/make-technical-pwad.py (Python 3).'
        }
    }

    if (!$Build -and !(Test-Path -LiteralPath $executablePath)) {
        throw 'Executavel ausente. Use a task "Crysis: preparar e executar (MAP01)" ou scripts/run-game.ps1 -Build.'
    }

    & (Join-Path $PSScriptRoot 'setup-iwad.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Preparacao do IWAD falhou.' }

    if ($Build) {
        & (Join-Path $PSScriptRoot 'setup-build.ps1') -Build -LogPrefix zed
    }
    & (Join-Path $PSScriptRoot 'prepare-run.ps1')

    $engineArguments = @(
        '-iwad', $iwadPath,
        '-warp', '1', '-window',
        '-config', (Join-Path $runDirectory 'default.cfg'),
        '-extraconfig', (Join-Path $runDirectory 'crispy-doom.cfg'),
        '-savedir', $runDirectory
    )
    if ($Scenario -eq 'Technical') { $engineArguments += @('-file', $pwadPath) }
    if ($Mode -eq 'Crysis') { $engineArguments += '-crysis' }
    if ($Mode -eq 'Crysis' -and $DebugInput) { $engineArguments += '-crdebug' }
    # Doom reads the first occurrence of an option, so explicit overrides
    # precede the defaults (also permits isolated configs for smoke runs).
    $engineArguments = $GameArguments + $engineArguments
    $commandArguments = ($engineArguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    # Wait explicitly for this GUI executable so the editor task stays active
    # and reports the game's own exit status under Windows PowerShell.
    $gameProcess = Start-Process -FilePath $executablePath -ArgumentList $commandArguments -NoNewWindow -Wait -PassThru
    $gameExitCode = $gameProcess.ExitCode
    $gameProcess.Dispose()
    exit $gameExitCode
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
finally {
    Pop-Location
}
