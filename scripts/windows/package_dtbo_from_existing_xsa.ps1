[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputDir,
    [string]$GitSha,
    [string]$ArtifactPrefix = 'daphne_selftrigger',
    [string]$OverlayPrefix = 'daphne_selftrigger_ol',
    [string]$Board = 'k26c',
    [string]$WslDistro = 'Debian',
    [string]$VitisRoot = 'C:\Xilinx\Vitis\2024.1',
    [string]$DtgGitBranch = 'xlnx_rel_v2024.1',
    [switch]$ForceRegenerateDtg
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)
    (Resolve-Path -LiteralPath $PathValue).Path
}

function Convert-WindowsPathToWsl {
    param([Parameter(Mandatory = $true)][string]$PathValue)

    $resolved = Resolve-FullPath -PathValue $PathValue
    if ($resolved -notmatch '^(?<drive>[A-Za-z]):\\(?<rest>.*)$') {
        throw "Cannot convert Windows path to WSL form: $resolved"
    }

    $drive = $Matches.drive.ToLowerInvariant()
    $rest = $Matches.rest -replace '\\', '/'
    if ([string]::IsNullOrEmpty($rest)) {
        return "/mnt/$drive"
    }

    return "/mnt/$drive/$rest"
}

function Find-BuildArtifact {
    param(
        [Parameter(Mandatory = $true)][string]$SearchDir,
        [Parameter(Mandatory = $true)][string]$Prefix
    )

    $pattern = "${Prefix}_*.xsa"
    $matches = @(Get-ChildItem -LiteralPath $SearchDir -Filter $pattern -File | Sort-Object LastWriteTimeUtc, Name)
    if ($matches.Count -eq 0) {
        throw "No $pattern artifact found in $SearchDir"
    }

    return $matches[-1]
}

function Remove-GeneratedDeviceTreeDir {
    param([Parameter(Mandatory = $true)][string]$GeneratedDir)

    if (Test-Path -LiteralPath $GeneratedDir) {
        Write-Host "INFO: removing stale generated DT directory $GeneratedDir"
        Remove-Item -LiteralPath $GeneratedDir -Recurse -Force
    }
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Join-Path $PSScriptRoot '..\..'
}
$RepoRoot = Resolve-FullPath -PathValue $RepoRoot

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'scripts\package\complete_dtbo_bundle.sh'))) {
    throw "Repo root does not look like daphne-firmware: $RepoRoot"
}

if ([string]::IsNullOrEmpty($OutputDir)) {
    if ([string]::IsNullOrEmpty($GitSha)) {
        $OutputDir = Join-Path $RepoRoot 'xilinx\output'
    } else {
        $OutputDir = Join-Path $RepoRoot "xilinx\output-$GitSha"
    }
}

$OutputDir = Resolve-FullPath -PathValue $OutputDir
$XsctBat = Join-Path $VitisRoot 'bin\xsct.bat'

if (-not (Test-Path -LiteralPath $XsctBat)) {
    throw "XSCT launcher not found at $XsctBat"
}

$XsaFile = Find-BuildArtifact -SearchDir $OutputDir -Prefix $ArtifactPrefix
if ([string]::IsNullOrEmpty($GitSha)) {
    $GitSha = $XsaFile.BaseName.Substring($ArtifactPrefix.Length + 1)
}

$BinFile = Join-Path $OutputDir "${ArtifactPrefix}_${GitSha}.bin"
if (-not (Test-Path -LiteralPath $BinFile)) {
    throw "Expected bitstream binary not found at $BinFile"
}

$GeneratedDir = Join-Path $OutputDir "${ArtifactPrefix}_${GitSha}"
$PlDtsi = $null
if (Test-Path -LiteralPath $GeneratedDir) {
    $PlDtsi = Get-ChildItem -LiteralPath $GeneratedDir -Recurse -Filter 'pl.dtsi' -File -ErrorAction SilentlyContinue | Select-Object -First 1
}

if ($ForceRegenerateDtg -or -not $PlDtsi) {
    if ($ForceRegenerateDtg -or (Test-Path -LiteralPath $GeneratedDir)) {
        Remove-GeneratedDeviceTreeDir -GeneratedDir $GeneratedDir
    }

    $OutputDirUnix = $OutputDir -replace '\\', '/'
    $PlatformName = "${ArtifactPrefix}_${GitSha}"
    $XsctEval = "createdts -hw `"$($XsaFile.Name)`" -zocl -platform-name `"$PlatformName`" -git-branch `"$DtgGitBranch`" -overlay -out `"$OutputDirUnix`"; exit"

    Write-Host "INFO: bootstrapping pl.dtsi with Windows XSCT"
    Write-Host "INFO: xsct dir   = $OutputDir"
    Write-Host "INFO: xsa       = $($XsaFile.Name)"
    Push-Location $OutputDir
    try {
        & $XsctBat -eval $XsctEval
        if ($LASTEXITCODE -ne 0) {
            throw "XSCT createdts failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }

    $PlDtsi = Get-ChildItem -LiteralPath $GeneratedDir -Recurse -Filter 'pl.dtsi' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $PlDtsi) {
        throw "XSCT completed but no pl.dtsi was generated under $GeneratedDir"
    }
} else {
    Write-Host "INFO: reusing existing pl.dtsi at $($PlDtsi.FullName)"
}

$RepoRootWsl = Convert-WindowsPathToWsl -PathValue $RepoRoot
$OutputDirWsl = Convert-WindowsPathToWsl -PathValue $OutputDir
$BashCommand = @"
cd '$RepoRootWsl' &&
export DAPHNE_FIRMWARE_ROOT='$RepoRootWsl' &&
source scripts/wsl/setup_windows_xilinx.sh &&
export DAPHNE_BOARD='$Board' &&
export DAPHNE_GIT_SHA='$GitSha' &&
./scripts/package/complete_dtbo_bundle.sh '$OutputDirWsl'
"@

Write-Host "INFO: packaging DTBO bundle through WSL"
& wsl.exe -d $WslDistro bash -lc $BashCommand
if ($LASTEXITCODE -ne 0) {
    throw "WSL DTBO packaging failed with exit code $LASTEXITCODE"
}

$DtboFile = Join-Path $OutputDir "${ArtifactPrefix}_${GitSha}.dtbo"
$OverlayZip = Join-Path $OutputDir "${OverlayPrefix}_${GitSha}.zip"
$ShaFile = Join-Path $OutputDir 'SHA256SUMS'

foreach ($Expected in @($DtboFile, $OverlayZip, $ShaFile)) {
    if (-not (Test-Path -LiteralPath $Expected)) {
        throw "Expected packaging artifact not found: $Expected"
    }
}

Write-Host "INFO: generated artifacts:"
Write-Host "  $DtboFile"
Write-Host "  $OverlayZip"
Write-Host "  $ShaFile"
