<#
.SYNOPSIS
Runs parsing, linting, and formatting checks on GDScript files using gdtoolkit.

.DESCRIPTION
This script runs a full set of checks on all `.gd` files under `scripts/`.
It will return a non-zero exit code if any check fails.

.PARAMETER Fix
If specified, will auto-format files in-place (instead of just checking formatting).

.PARAMETER Verbose
Show additional output.
#>

[CmdletBinding()]
param(
    [switch]$Fix
)

Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptRoot "..")
Set-Location $repoRoot

Write-Host "[gdscript-check] Running in: $repoRoot"

function Run-Program {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $escapedArgs = $Arguments | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }
    $cmdline = "$Name $($escapedArgs -join ' ')"

    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Host "[gdscript-check] cmdline: $cmdline" -ForegroundColor Cyan
    }

    $process = Start-Process -FilePath cmd -ArgumentList @('/c', $cmdline) -NoNewWindow -Wait -PassThru -RedirectStandardError "${env:TEMP}\gdscript-check.stderr.txt" -RedirectStandardOutput "${env:TEMP}\gdscript-check.stdout.txt"
    if ($process.ExitCode -ne 0) {
        Write-Error "[gdscript-check] Command failed with exit code $($process.ExitCode)"
        Write-Error "[gdscript-check] stdout: $(Get-Content "${env:TEMP}\gdscript-check.stdout.txt" -Raw)"
        Write-Error "[gdscript-check] stderr: $(Get-Content "${env:TEMP}\gdscript-check.stderr.txt" -Raw)"
        exit $process.ExitCode
    }
}

# Prefer the installed wrapper scripts (gdparse/gdlint/gdformat) if available.
$gdparseCmd = Get-Command gdparse -ErrorAction SilentlyContinue
$gdlintCmd = Get-Command gdlint -ErrorAction SilentlyContinue
$gdformatCmd = Get-Command gdformat -ErrorAction SilentlyContinue

$gdparse = if ($gdparseCmd) { $gdparseCmd.Source } else { $null }
$gdlint = if ($gdlintCmd) { $gdlintCmd.Source } else { $null }
$gdformat = if ($gdformatCmd) { $gdformatCmd.Source } else { $null }

if (-not $gdparse -or -not $gdlint -or -not $gdformat) {
    Write-Host "[gdscript-check] Warning: gdtoolkit CLI scripts (gdparse/gdlint/gdformat) were not found on PATH. Falling back to python -m invocations."
    $usePython = $true
} else {
    $usePython = $false
}

# Find all GDScript files in the scripts/ and test/scripts/ folders.
$gdFiles = @(Get-ChildItem -Path scripts,test/scripts -Recurse -Filter *.gd | Select-Object -ExpandProperty FullName)
if (-not $gdFiles) {
    Write-Error "[gdscript-check] No .gd files found under scripts/ or test/scripts/"
    exit 1
}

Write-Host "[gdscript-check] Found $($gdFiles.Count) .gd files"

# 1) Parse (syntax check)
if ($usePython) {
    $parseArgs = @("-m", "gdtoolkit.parser") + $gdFiles
    Run-Program -Name "python" -Arguments $parseArgs
} else {
    Write-Host "[gdscript-check] Running gdparse on $($gdFiles.Count) file(s)"
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Host "[gdscript-check] Files: $($gdFiles -join ' ')"
    }
    Run-Program -Name $gdparse -Arguments $gdFiles
}

# 2) Lint
if ($usePython) {
    $lintArgs = @("-m", "gdtoolkit.linter") + $gdFiles
    Run-Program -Name "python" -Arguments $lintArgs
} else {
    Write-Host "[gdscript-check] Running gdlint on $($gdFiles.Count) file(s)"
    if ($PSBoundParameters.ContainsKey('Verbose')) {
        Write-Host "[gdscript-check] Files: $($gdFiles -join ' ')"
    }
    Run-Program -Name $gdlint -Arguments $gdFiles
}

# 3) Formatting
if ($usePython) {
    $formatArgs = @("-m", "gdtoolkit.formatter")
    if ($Fix) {
        $formatArgs += $gdFiles
        Write-Host "[gdscript-check] Running formatter (in-place)"
    } else {
        $formatArgs += @("--check") + $gdFiles
        Write-Host "[gdscript-check] Running formatter in check mode (use -Fix to apply changes)"
    }
    Run-Program -Name "python" -Arguments $formatArgs
} else {
    if ($Fix) {
        Write-Host "[gdscript-check] Running formatter (in-place) on $($gdFiles.Count) file(s)"
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            Write-Host "[gdscript-check] Files: $($gdFiles -join ' ')"
        }
        Run-Program -Name $gdformat -Arguments $gdFiles
    } else {
        Write-Host "[gdscript-check] Running formatter in check mode (use -Fix to apply changes) on $($gdFiles.Count) file(s)"
        if ($PSBoundParameters.ContainsKey('Verbose')) {
            Write-Host "[gdscript-check] Files: $($gdFiles -join ' ')"
        }
        $formatArgs = @("--check") + $gdFiles
        Run-Program -Name $gdformat -Arguments $formatArgs
    }
}

# 4) Godot validation (strict parser check)
# Godot is stricter than gdtoolkit and catches errors like Variant type inference
$godotExe = "D:\Gadot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe"

$godotFiles = $gdFiles | Where-Object { $_ -notmatch "\\test\\scripts\\" }
$testFiles = $gdFiles | Where-Object { $_ -match "\\test\\scripts\\" }

if (Test-Path $godotExe) {
    if ($godotFiles) {
        Write-Host "[gdscript-check] Running Godot validation on $($godotFiles.Count) non-test file(s)"
        $godotErrors = @()
        
        foreach ($file in $godotFiles) {
            $process = Start-Process -FilePath $godotExe -ArgumentList @("--headless", "--script", $file, "--check-only") -NoNewWindow -Wait -PassThru -RedirectStandardError "${env:TEMP}\godot.stderr.txt" -RedirectStandardOutput "${env:TEMP}\godot.stdout.txt"
            
            $stderr = Get-Content "${env:TEMP}\godot.stderr.txt" -Raw -ErrorAction SilentlyContinue
            $stdout = Get-Content "${env:TEMP}\godot.stdout.txt" -Raw -ErrorAction SilentlyContinue
            
            if ($process.ExitCode -ne 0 -or $stderr -match "error|Error|ERROR" -or $stdout -match "error|Error|ERROR") {
                $godotErrors += @{
                    File   = $file
                    ExitCode = $process.ExitCode
                    Stderr = $stderr
                    Stdout = $stdout
                }
            }
        }
        
        if ($godotErrors.Count -gt 0) {
            Write-Host "[gdscript-check] ❌ Godot validation found issues:" -ForegroundColor Red
            foreach ($errorItem in $godotErrors) {
                Write-Host "  File: $($errorItem.File)"
                Write-Host "    Exit code: $($errorItem.ExitCode)"
                if ($errorItem.Stderr) { Write-Host "    Stderr: $($errorItem.Stderr)" }
                if ($errorItem.Stdout) { Write-Host "    Stdout: $($errorItem.Stdout)" }
            }
            exit 1
        } else {
            Write-Host "[gdscript-check] Godot validation passed for non-test scripts."
        }
    } else {
        Write-Host "[gdscript-check] No non-test .gd files to validate with Godot."
    }

    if ($testFiles) {
        $gdUnitCmd = "addons/gdUnit4/bin/GdUnitCmdTool.gd"
        if (-not (Test-Path $gdUnitCmd)) {
            Write-Error "[gdscript-check] GDUnit command script not found at $gdUnitCmd"
            exit 1
        }

        Write-Host "[gdscript-check] Running GDUnit CLI on test scripts"
        # GDUnit commandline returns 100 for test failures and 101 for success with warnings/orphans.
        $gdUnitArgs = @("-s", $gdUnitCmd, "--headless", "--verbose", "-a", "test/scripts", "--ignoreHeadlessMode")
        $escaped = $gdUnitArgs | ForEach-Object { '"' + ($_ -replace '"', '""') + '"' }
        $cmdline = "$godotExe $($escaped -join ' ')"

        $process = Start-Process -FilePath cmd -ArgumentList @('/c', $cmdline) -NoNewWindow -Wait -PassThru -RedirectStandardOutput "${env:TEMP}\gdscript-check.stdout.txt" -RedirectStandardError "${env:TEMP}\gdscript-check.stderr.txt"
        $stdout = Get-Content "${env:TEMP}\gdscript-check.stdout.txt" -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content "${env:TEMP}\gdscript-check.stderr.txt" -Raw -ErrorAction SilentlyContinue

        if ($process.ExitCode -ne 0 -and $process.ExitCode -ne 101) {
            Write-Error "[gdscript-check] GDUnit CLI command failed with exit code $($process.ExitCode)"
            Write-Error "[gdscript-check] stdout: $stdout"
            Write-Error "[gdscript-check] stderr: $stderr"
            exit $process.ExitCode
        }
        Write-Host "[gdscript-check] GDUnit CLI tests executed. (exit code $($process.ExitCode))"
    } else {
        Write-Host "[gdscript-check] No test scripts found under test/scripts/."
    }
} else {
    Write-Host "[gdscript-check] Warning: Godot executable not found at $godotExe. Skipping Godot validation." -ForegroundColor Yellow
    Write-Host "[gdscript-check] Note: test files are not validated via Godot/GDUnit when Godot is unavailable."
}

Write-Host "[gdscript-check] ✅ All checks passed." -ForegroundColor Green
