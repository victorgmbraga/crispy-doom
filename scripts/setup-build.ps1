param(
    [switch]$Configure,
    [switch]$Build,
    [string]$BuildDirectory = 'build',
    [string]$LogPrefix = 'build',
    [ValidateRange(1,64)]
    [int]$Jobs = 4
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = Join-Path $projectRoot '.tools'
$depsRoot = Join-Path $projectRoot '.deps'
$downloadsRoot = Join-Path $toolsRoot 'downloads'

function Invoke-LoggedNative {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$LogFile
    )
    $previousErrorAction = $ErrorActionPreference
    try {
        # PowerShell 5.1 turns native stderr (including successful CMake
        # warnings) into ErrorRecords. The process exit code decides success.
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments 2>&1 | Tee-Object -FilePath $LogFile -ErrorAction Stop
        $nativeExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($nativeExitCode -ne 0) {
        throw ('Command failed with exit code ' + $nativeExitCode + ': ' + $Executable)
    }
}

# Official portable packages; no machine-wide installation or PATH changes.
$packages = @(
    @{
        Name = 'w64devkit-x64-2.10.0.7z.exe'
        Url = 'https://github.com/skeeto/w64devkit/releases/download/v2.10.0/w64devkit-x64-2.10.0.7z.exe'
        Sha256 = '18d0a4c71a166f8401ab6305781bec5882b40b5e06ba9807c61cb5f3b3c6325e'
        Destination = $toolsRoot
        Marker = (Join-Path $toolsRoot 'w64devkit/bin/gcc.exe')
    },
    @{
        Name = 'cmake-3.31.12-windows-x86_64.zip'
        Url = 'https://github.com/Kitware/CMake/releases/download/v3.31.12/cmake-3.31.12-windows-x86_64.zip'
        Sha256 = '0c4baa40f28b3f8225eb3fdf6946c987b4fe901403b4eaf2fbbd9378100aaa0c'
        Destination = $toolsRoot
        Marker = (Join-Path $toolsRoot 'cmake-3.31.12-windows-x86_64/bin/cmake.exe')
    },
    @{
        Name = 'SDL2-devel-2.32.10-mingw.zip'
        Url = 'https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-devel-2.32.10-mingw.zip'
        Sha256 = 'f15cff5fca62ec9381a016ef1d42a95c638cd72d2f226ba5781c76fe43dbd1ac'
        Destination = $depsRoot
        Marker = (Join-Path $depsRoot 'SDL2-2.32.10/x86_64-w64-mingw32/bin/SDL2.dll')
    },
    @{
        Name = 'SDL2_mixer-devel-2.8.2-mingw.zip'
        Url = 'https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.8.2/SDL2_mixer-devel-2.8.2-mingw.zip'
        Sha256 = 'b09f5541f328fd49b420c866b2a4e79b653b4fa4e9d7270674eb10d21730c7b8'
        Destination = $depsRoot
        Marker = (Join-Path $depsRoot 'SDL2_mixer-2.8.2/x86_64-w64-mingw32/bin/SDL2_mixer.dll')
    },
    @{
        Name = 'SDL2_net-devel-2.4.0-mingw.zip'
        Url = 'https://github.com/libsdl-org/SDL_net/releases/download/release-2.4.0/SDL2_net-devel-2.4.0-mingw.zip'
        Sha256 = '428c85e46a0c44f7c227e8ed309e062f67c2000f8739c6636a87590d9455b926'
        Destination = $depsRoot
        Marker = (Join-Path $depsRoot 'SDL2_net-2.4.0/x86_64-w64-mingw32/bin/SDL2_net.dll')
    }
)

New-Item -ItemType Directory -Path $downloadsRoot,$depsRoot -Force | Out-Null
foreach ($package in $packages) {
    $archivePath = Join-Path $downloadsRoot $package.Name
    if (!(Test-Path -LiteralPath $archivePath)) {
        Write-Host ('Downloading ' + $package.Name)
        Invoke-WebRequest -Uri $package.Url -OutFile $archivePath
    }
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $package.Sha256) {
        throw ('SHA256 mismatch: ' + $package.Name)
    }
    if (!(Test-Path -LiteralPath $package.Marker)) {
        Write-Host ('Extracting ' + $package.Name)
        if ($package.Name.EndsWith('.exe')) {
            $extractor = Start-Process -FilePath $archivePath -ArgumentList @('-y',('-o"' + $package.Destination + '"')) -Wait -PassThru -WindowStyle Hidden
            if ($extractor.ExitCode -ne 0) { throw 'w64devkit extraction failed.' }
        } else {
            Expand-Archive -LiteralPath $archivePath -DestinationPath $package.Destination -Force
        }
        if (!(Test-Path -LiteralPath $package.Marker)) {
            throw ('Expected package file missing: ' + $package.Marker)
        }
    }
}

$compilerBin = Join-Path $toolsRoot 'w64devkit/bin'
$cmakeBin = Join-Path $toolsRoot 'cmake-3.31.12-windows-x86_64/bin'
$cmakeExe = Join-Path $cmakeBin 'cmake.exe'
$sdlPrefix = Join-Path $depsRoot 'SDL2-2.32.10/x86_64-w64-mingw32'
$mixerPrefix = Join-Path $depsRoot 'SDL2_mixer-2.8.2/x86_64-w64-mingw32'
$netPrefix = Join-Path $depsRoot 'SDL2_net-2.4.0/x86_64-w64-mingw32'
$compilerPath = (Join-Path $compilerBin 'gcc.exe').Replace('\','/')
$makePath = (Join-Path $compilerBin 'make.exe').Replace('\','/')
$resourceCompilerPath = (Join-Path $compilerBin 'windres.exe').Replace('\','/')
$dependencyPrefixes = ($sdlPrefix + ';' + $mixerPrefix + ';' + $netPrefix).Replace('\','/')
$originalPath = $env:PATH
try {
    $env:PATH = $compilerBin + ';' + $cmakeBin + ';' + $env:PATH
    & (Join-Path $compilerBin 'gcc.exe') --version | Select-Object -First 1
    & $cmakeExe --version | Select-Object -First 1
    if ($Configure -or $Build) {
        $logsRoot = Join-Path $projectRoot 'docs/validacao/logs'
        New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null
        # Upstream 7.1 src/i_video.c calls pow without including math.h.
        # Force the header for GCC 16 while preserving the original baseline
        # source; use identical flags when building the Crysis fork.
        $configureArguments = @('-S', $projectRoot, '-B', (Join-Path $projectRoot $BuildDirectory), '-G', 'MinGW Makefiles', '-DCMAKE_BUILD_TYPE=RelWithDebInfo', '-DCMAKE_C_FLAGS=-include math.h', ('-DCMAKE_C_COMPILER=' + $compilerPath), ('-DCMAKE_MAKE_PROGRAM=' + $makePath), ('-DCMAKE_RC_COMPILER=' + $resourceCompilerPath), ('-DCMAKE_PREFIX_PATH=' + $dependencyPrefixes))
        Invoke-LoggedNative -Executable $cmakeExe -Arguments $configureArguments -LogFile (Join-Path $logsRoot ($LogPrefix + '-configure.log'))
    }
    if ($Build) {
        $buildArguments = @('--build', (Join-Path $projectRoot $BuildDirectory), '--target', 'crispy-doom', '--parallel', $Jobs)
        Invoke-LoggedNative -Executable $cmakeExe -Arguments $buildArguments -LogFile (Join-Path $logsRoot ($LogPrefix + '-build.log'))
        $binaryRoot = Join-Path $projectRoot ($BuildDirectory + '/src')
        foreach ($prefix in @($sdlPrefix,$mixerPrefix,$netPrefix)) {
            Get-ChildItem -LiteralPath (Join-Path $prefix 'bin') -Filter '*.dll' | Copy-Item -Destination $binaryRoot -Force
        }
        Write-Host ('Built: ' + (Join-Path $binaryRoot 'crispy-doom.exe'))
    }
} finally {
    $env:PATH = $originalPath
}
