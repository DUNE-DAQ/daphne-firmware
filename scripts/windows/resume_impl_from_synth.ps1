[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$GitSha,
    [string]$Board = 'k26c',
    [string]$VivadoRoot = 'C:\Xilinx\Vivado\2024.1',
    [string]$OptDirective = 'ExploreWithRemap',
    [string]$PostPlacePhysoptDirective = 'AddRetime',
    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$PathValue)
    [System.IO.Path]::GetFullPath($PathValue)
}

function Get-RepoGitSha {
    param([Parameter(Mandatory = $true)][string]$RepoRootValue)

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        throw "git is not available on PATH. Pass -GitSha explicitly or install git."
    }

    $sha = (& $git.Source -C $RepoRootValue rev-parse --short=7 HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) {
        throw "Failed to derive git SHA from $RepoRootValue"
    }

    return $sha
}

function Set-Or-RemoveEnv {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
    } else {
        Set-Item "Env:$Name" $Value
    }
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Join-Path $PSScriptRoot '..\..'
}
$RepoRoot = Get-FullPath -PathValue $RepoRoot
if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'xilinx\vivado_resume_from_synth_entry.tcl'))) {
    throw "Repo root does not look like daphne-firmware: $RepoRoot"
}

if ([string]::IsNullOrWhiteSpace($GitSha)) {
    $GitSha = Get-RepoGitSha -RepoRootValue $RepoRoot
}
if ($GitSha -notmatch '^[0-9a-fA-F]+$') {
    throw "Git SHA must be hexadecimal because the BD version generic uses 28'h<sha>. Current value: $GitSha"
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot "xilinx\output-$GitSha"
}
$OutputDir = (Get-FullPath -PathValue $OutputDir) -replace '\\', '/'

$SynthDcp = Join-Path ($OutputDir -replace '/', '\') 'daphne_selftrigger_bd_synth.dcp'
if (-not (Test-Path -LiteralPath $SynthDcp)) {
    throw "Expected synth checkpoint not found at $SynthDcp"
}

$VivadoBat = Join-Path $VivadoRoot 'bin\vivado.bat'
if (-not (Test-Path -LiteralPath $VivadoBat)) {
    throw "Vivado batch launcher not found at $VivadoBat"
}

Set-Or-RemoveEnv -Name DAPHNE_BOARD -Value $Board
Set-Or-RemoveEnv -Name DAPHNE_GIT_SHA -Value $GitSha
Set-Or-RemoveEnv -Name DAPHNE_OUTPUT_DIR -Value $OutputDir
Set-Or-RemoveEnv -Name DAPHNE_OPT_DIRECTIVE -Value $OptDirective
Set-Or-RemoveEnv -Name DAPHNE_POST_PLACE_PHYSOPT_DIRECTIVE -Value $PostPlacePhysoptDirective
Set-Or-RemoveEnv -Name DAPHNE_STOP_AFTER_SYNTH -Value ''

foreach ($Name in @('DAPHNE_PLATFORM_CORE', 'DAPHNE_PLATFORM_TARGET', 'DAPHNE_BD_NAME', 'DAPHNE_BD_WRAPPER_NAME')) {
    Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
}

Write-Host "INFO: repo root   = $RepoRoot"
Write-Host "INFO: git sha     = $GitSha"
Write-Host "INFO: output dir  = $OutputDir"
Write-Host "INFO: synth dcp   = $SynthDcp"
Write-Host "INFO: Vivado      = $VivadoBat"

Push-Location $RepoRoot
try {
    & $VivadoBat -mode batch -source (Join-Path $RepoRoot 'xilinx\vivado_resume_from_synth_entry.tcl')
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado resume failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}
