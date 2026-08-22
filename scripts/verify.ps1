# Ace Rally verification, PowerShell variant of scripts/verify.sh.
# Runs every check in order, stops at the first failure, prints a PASS or FAIL
# banner and exits non-zero on any failure so it works in CI.
#
# Native stderr is redirected inside cmd.exe rather than by PowerShell, because
# Windows PowerShell 5.1 wraps native stderr lines in ErrorRecords and clobbers
# the exit status when you use `2>&1` directly.

$ErrorActionPreference = 'Continue'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$Godot = if ($env:GODOT) { $env:GODOT } else { 'godot' }

# Godot exits 0 even when scripts fail to parse, so the project-load check has to
# read the output as well as the exit code. Measured against 4.7.2.
$ErrorPattern = '^(SCRIPT ERROR|ERROR|USER ERROR|USER SCRIPT ERROR|FATAL):'

$script:StepNumber = 0

function Invoke-Godot {
    param([string]$Arguments)
    $output = & cmd /c "`"$Godot`" $Arguments 2>&1"
    return [pscustomobject]@{
        Output   = $output
        ExitCode = $LASTEXITCODE
    }
}

function Start-Step {
    param([string]$Name)
    $script:StepNumber++
    Write-Output ''
    Write-Output "--- Step $($script:StepNumber): $Name ---"
}

function Stop-WithFailure {
    param([string]$Reason)
    Write-Output ''
    Write-Output '=================================================='
    Write-Output "  FAIL: $Reason"
    Write-Output '=================================================='
    exit 1
}

if (-not (Get-Command $Godot -ErrorAction SilentlyContinue)) {
    Stop-WithFailure "godot not found on PATH (set `$env:GODOT to override)"
}

Write-Output 'Ace Rally verification'
$versionResult = Invoke-Godot '--version'
Write-Output "godot: $($versionResult.Output)"

# ------------------------------------------------------------------------------
Start-Step 'Import assets and register addon class_names'
# On a fresh clone the GUT global classes are not in .godot/global_script_class_cache
# yet, and gut_cmdln.gd refuses to run without them. This step is what makes CI work.
$import = Invoke-Godot '--headless --import --path .'
if ($import.ExitCode -ne 0) {
    $import.Output | Write-Output
    Stop-WithFailure 'asset import failed'
}
Write-Output 'ok'

# ------------------------------------------------------------------------------
Start-Step 'Parse check (project load)'
$parse = Invoke-Godot '--headless --quit --path .'
$parse.Output | Write-Output
if ($parse.ExitCode -ne 0) {
    Stop-WithFailure "parse check exited $($parse.ExitCode)"
}
if ($parse.Output | Select-String -Pattern $ErrorPattern -Quiet) {
    Stop-WithFailure 'parse check reported errors (see output above)'
}
Write-Output 'ok'

# ------------------------------------------------------------------------------
Start-Step 'GUT test suite'
$gut = Invoke-Godot '--headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit'
$gut.Output | Write-Output
if ($gut.ExitCode -ne 0) {
    Stop-WithFailure "GUT suite exited $($gut.ExitCode)"
}

# ------------------------------------------------------------------------------
Write-Output ''
Write-Output '=================================================='
Write-Output '  PASS: all checks succeeded'
Write-Output '=================================================='
exit 0
