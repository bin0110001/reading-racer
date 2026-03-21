<#
.SYNOPSIS
Runs parsing, linting, formatting, and Godot validation checks on GDScript files.

.DESCRIPTION
This script runs a full set of checks on all `.gd` files under `scripts/` and
`test/scripts/`. It returns a non-zero exit code if any check fails.

.PARAMETER Fix
If specified, auto-formats files in-place instead of checking formatting only.
#>

[CmdletBinding()]
param(
    [switch]$Fix
)

Set-StrictMode -Version Latest

$script:ToolScriptRoot = Split-Path -Parent $PSCommandPath


function New-CheckException {
    param(
        [string]$Message,
        [int]$ExitCode = 1
    )

    $exception = [System.Exception]::new($Message)
    $exception.Data['ExitCode'] = $ExitCode
    return $exception
}


function Get-CapturePaths {
    $id = [guid]::NewGuid().ToString('N')
    return [pscustomobject]@{
        Stdout = Join-Path $env:TEMP "gdscript-check.$id.stdout.txt"
        Stderr = Join-Path $env:TEMP "gdscript-check.$id.stderr.txt"
    }
}


function Join-CommandLine {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $parts = @($FilePath)
    foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            $parts += '"' + ($argument -replace '"', '\"') + '"'
        } else {
            $parts += $argument
        }
    }

    return ($parts -join ' ')
}


function Invoke-ExternalProgram {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $captures = Get-CapturePaths
    try {
        Write-Verbose ("[gdscript-check] cmdline: {0}" -f (Join-CommandLine -FilePath $FilePath -Arguments $Arguments))
        $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput $captures.Stdout -RedirectStandardError $captures.Stderr

        $stdout = if (Test-Path $captures.Stdout) { Get-Content $captures.Stdout -Raw } else { '' }
        $stderr = if (Test-Path $captures.Stderr) { Get-Content $captures.Stderr -Raw } else { '' }

        return [pscustomobject]@{
            FilePath = $FilePath
            Arguments = $Arguments
            CommandLine = Join-CommandLine -FilePath $FilePath -Arguments $Arguments
            ExitCode = $process.ExitCode
            Stdout = $stdout
            Stderr = $stderr
            CombinedOutput = (($stdout, $stderr) -join "`n").Trim()
        }
    } finally {
        Remove-Item $captures.Stdout, $captures.Stderr -ErrorAction SilentlyContinue
    }
}


function Assert-ProgramSucceeded {
    param(
        $Result,
        [string]$Context
    )

    if ($Result.ExitCode -eq 0) {
        return
    }

    $message = @(
        "[gdscript-check] $Context failed with exit code $($Result.ExitCode)",
        "[gdscript-check] cmdline: $($Result.CommandLine)"
    )

    if ($Result.Stdout) {
        $message += "[gdscript-check] stdout: $($Result.Stdout.Trim())"
    }
    if ($Result.Stderr) {
        $message += "[gdscript-check] stderr: $($Result.Stderr.Trim())"
    }

    throw (New-CheckException -Message ($message -join [Environment]::NewLine) -ExitCode $Result.ExitCode)
}


function Get-RepoRoot {
    return (Resolve-Path (Join-Path $script:ToolScriptRoot '..')).Path
}


function Get-GdScriptFiles {
    param(
        [string]$RepoRoot
    )

    $paths = @(
        Join-Path $RepoRoot 'scripts'
        Join-Path $RepoRoot 'test\scripts'
    )

    $files = @(Get-ChildItem -Path $paths -Recurse -Filter *.gd -File | Select-Object -ExpandProperty FullName | Sort-Object)
    if (-not $files) {
        throw (New-CheckException -Message '[gdscript-check] No .gd files found under scripts/ or test/scripts/' -ExitCode 1)
    }

    return $files
}


function Convert-ToResPath {
    param(
        [string]$RepoRoot,
        [string]$FilePath
    )

    $normalizedRoot = ((Resolve-Path $RepoRoot).Path.TrimEnd('\') + '\')
    $rootUri = New-Object System.Uri($normalizedRoot)
    $fileUri = New-Object System.Uri((Resolve-Path $FilePath).Path)
    $relativePath = [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($fileUri).ToString())
    return 'res://' + ($relativePath -replace '\\', '/')
}


function Test-IsTestScriptPath {
    param(
        [string]$RepoRoot,
        [string]$FilePath
    )

    $resPath = Convert-ToResPath -RepoRoot $RepoRoot -FilePath $FilePath
    return $resPath.StartsWith('res://test/scripts/', [System.StringComparison]::OrdinalIgnoreCase)
}


function Get-GodotCompilerIssues {
    param(
        [string]$OutputText
    )

    if ([string]::IsNullOrWhiteSpace($OutputText)) {
        return [object[]]@()
    }

    $normalized = [regex]::Replace($OutputText, '\r?\n\s*', ' ')
    $issues = New-Object System.Collections.Generic.List[object]
    $seen = New-Object System.Collections.Generic.HashSet[string]

    $parseMatches = [regex]::Matches(
        $normalized,
        'SCRIPT ERROR:\s+Parse Error:\s+(?<message>.+?)\s+at:\s+GDScript::reload\s+\((?<script>res://[^:]+):(?<line>\d+)\)',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    foreach ($match in $parseMatches) {
        $key = "ParseError|$($match.Groups['script'].Value)|$($match.Groups['line'].Value)|$($match.Groups['message'].Value)"
        if ($seen.Add($key)) {
            $issues.Add([pscustomobject]@{
                Kind = 'ParseError'
                ScriptPath = $match.Groups['script'].Value
                Line = [int]$match.Groups['line'].Value
                Message = $match.Groups['message'].Value.Trim()
            })
        }
    }

    $loadMatches = [regex]::Matches(
        $normalized,
        'ERROR:\s+Failed to load script "(?<script>res://[^"]+)" with error "(?<message>[^"]+)"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    foreach ($match in $loadMatches) {
        $key = "LoadFailure|$($match.Groups['script'].Value)|$($match.Groups['message'].Value)"
        if ($seen.Add($key)) {
            $issues.Add([pscustomobject]@{
                Kind = 'LoadFailure'
                ScriptPath = $match.Groups['script'].Value
                Line = $null
                Message = $match.Groups['message'].Value.Trim()
            })
        }
    }

    return $issues.ToArray()
}


function Write-GodotValidationFailures {
    param(
        [object[]]$Failures,
        [string]$Label
    )

    Write-Host "[gdscript-check] ERROR: Godot validation found issues in ${Label}:" -ForegroundColor Red
    foreach ($failure in $Failures) {
        Write-Host "  Script: $($failure.ResPath)"
        Write-Host "    Exit code: $($failure.ExitCode)"
        if ($failure.Issues.Count -gt 0) {
            foreach ($issue in $failure.Issues) {
                if ($null -ne $issue.Line) {
                    Write-Host "    [$($issue.Kind)] line $($issue.Line): $($issue.Message)"
                } else {
                    Write-Host "    [$($issue.Kind)] $($issue.Message)"
                }
            }
        } else {
            if ($failure.Stdout) {
                Write-Host "    Stdout: $($failure.Stdout.Trim())"
            }
            if ($failure.Stderr) {
                Write-Host "    Stderr: $($failure.Stderr.Trim())"
            }
        }
    }
}


function Invoke-GodotCompilationChecks {
    param(
        [string]$RepoRoot,
        [string]$GodotExe,
        [string[]]$Files,
        [string]$Label
    )

    if (-not $Files) {
        Write-Host "[gdscript-check] No $Label .gd files to validate with Godot."
        return @()
    }

    Write-Host "[gdscript-check] Running Godot validation on $($Files.Count) $Label file(s)"
    $failures = New-Object System.Collections.Generic.List[object]

    foreach ($file in $Files) {
        $resPath = Convert-ToResPath -RepoRoot $RepoRoot -FilePath $file
        $result = Invoke-ExternalProgram -FilePath $GodotExe -Arguments @('--headless', '--path', $RepoRoot, '--script', $resPath, '--check-only')
        $issues = @(Get-GodotCompilerIssues -OutputText $result.CombinedOutput)

        if ($result.ExitCode -ne 0 -or $issues.Count -gt 0) {
            $failures.Add([pscustomobject]@{
                FilePath = $file
                ResPath = $resPath
                ExitCode = $result.ExitCode
                Issues = @($issues)
                Stdout = $result.Stdout
                Stderr = $result.Stderr
            })
        }
    }

    if ($failures.Count -gt 0) {
        Write-GodotValidationFailures -Failures $failures.ToArray() -Label $Label
        throw (New-CheckException -Message "[gdscript-check] Godot validation failed for $Label scripts." -ExitCode 1)
    }

    Write-Host "[gdscript-check] Godot validation passed for $Label scripts."
    return @()
}


function Get-ReadingTestMethodNames {
    param(
        [string]$RepoRoot
    )

    $readingTestDir = Join-Path $RepoRoot 'test\scripts\systems'
    if (-not (Test-Path $readingTestDir)) {
        return @()
    }

    $methodNames = New-Object System.Collections.Generic.List[string]
    $files = Get-ChildItem -Path $readingTestDir -Filter 'test_reading_*' -File -Recurse
    foreach ($file in $files) {
        $contents = Get-Content -Path $file.FullName -Raw
        $matches = [regex]::Matches($contents, 'func\s+(test_reading_[a-zA-Z0-9_]+)')
        foreach ($match in $matches) {
            $methodNames.Add($match.Groups[1].Value)
        }
    }

    return @($methodNames | Select-Object -Unique)
}


function Get-DotnetAssemblyName {
    param(
        [string]$RepoRoot
    )

    $projectFile = Join-Path $RepoRoot 'project.godot'
    if (-not (Test-Path $projectFile)) {
        return $null
    }

    $match = Select-String -Path $projectFile -Pattern '^project/assembly_name="(?<name>[^"]+)"' | Select-Object -First 1
    if ($null -eq $match) {
        return $null
    }

    return $match.Matches[0].Groups['name'].Value
}


function Test-ProjectUsesCSharp {
    param(
        [string]$RepoRoot
    )

    $scriptRoots = @(
        Join-Path $RepoRoot 'scripts'
        Join-Path $RepoRoot 'test'
    )

    foreach ($path in $scriptRoots) {
        if ((Test-Path $path) -and (Get-ChildItem -Path $path -Recurse -Filter *.cs -File | Select-Object -First 1)) {
            return $true
        }
    }

    return $false
}


function Invoke-GdScriptCheck {
    param(
        [switch]$Fix
    )

    $repoRoot = Get-RepoRoot
    Set-Location $repoRoot
    Write-Host "[gdscript-check] Running in: $repoRoot"

    $gdparseCmd = Get-Command gdparse -ErrorAction SilentlyContinue
    $gdlintCmd = Get-Command gdlint -ErrorAction SilentlyContinue
    $gdformatCmd = Get-Command gdformat -ErrorAction SilentlyContinue

    $gdparse = if ($gdparseCmd) { $gdparseCmd.Source } else { $null }
    $gdlint = if ($gdlintCmd) { $gdlintCmd.Source } else { $null }
    $gdformat = if ($gdformatCmd) { $gdformatCmd.Source } else { $null }
    $usePython = -not ($gdparse -and $gdlint -and $gdformat)

    if ($usePython) {
        Write-Host '[gdscript-check] Warning: gdtoolkit CLI scripts were not found on PATH. Falling back to python -m invocations.'
    }

    $gdFiles = Get-GdScriptFiles -RepoRoot $repoRoot
    Write-Host "[gdscript-check] Found $($gdFiles.Count) .gd files"

    if ($usePython) {
        Write-Host "[gdscript-check] Running gdparse on $($gdFiles.Count) file(s)"
        $parseResult = Invoke-ExternalProgram -FilePath 'python' -Arguments (@('-m', 'gdtoolkit.parser') + $gdFiles)
    } else {
        Write-Host "[gdscript-check] Running gdparse on $($gdFiles.Count) file(s)"
        $parseResult = Invoke-ExternalProgram -FilePath $gdparse -Arguments $gdFiles
    }
    Assert-ProgramSucceeded -Result $parseResult -Context 'gdparse'

    if ($usePython) {
        Write-Host "[gdscript-check] Running gdlint on $($gdFiles.Count) file(s)"
        $lintResult = Invoke-ExternalProgram -FilePath 'python' -Arguments (@('-m', 'gdtoolkit.linter') + $gdFiles)
    } else {
        Write-Host "[gdscript-check] Running gdlint on $($gdFiles.Count) file(s)"
        $lintResult = Invoke-ExternalProgram -FilePath $gdlint -Arguments $gdFiles
    }
    Assert-ProgramSucceeded -Result $lintResult -Context 'gdlint'

    if ($usePython) {
        $formatArgs = @('-m', 'gdtoolkit.formatter')
        if ($Fix) {
            Write-Host '[gdscript-check] Running formatter (in-place)'
            $formatArgs += $gdFiles
        } else {
            Write-Host '[gdscript-check] Running formatter in check mode (use -Fix to apply changes)'
            $formatArgs += @('--check') + $gdFiles
        }
        $formatResult = Invoke-ExternalProgram -FilePath 'python' -Arguments $formatArgs
    } else {
        if ($Fix) {
            Write-Host "[gdscript-check] Running formatter (in-place) on $($gdFiles.Count) file(s)"
            $formatResult = Invoke-ExternalProgram -FilePath $gdformat -Arguments $gdFiles
        } else {
            Write-Host "[gdscript-check] Running formatter in check mode (use -Fix to apply changes) on $($gdFiles.Count) file(s)"
            $formatResult = Invoke-ExternalProgram -FilePath $gdformat -Arguments (@('--check') + $gdFiles)
        }
    }
    Assert-ProgramSucceeded -Result $formatResult -Context 'gdformat'

    $godotExe = 'D:\Gadot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe'
    if (-not (Test-Path $godotExe)) {
        Write-Host "[gdscript-check] Warning: Godot executable not found at $godotExe. Skipping Godot validation." -ForegroundColor Yellow
        Write-Host '[gdscript-check] Note: test files are not validated via Godot/GDUnit when Godot is unavailable.'
        Write-Host '[gdscript-check] ✅ All checks passed.' -ForegroundColor Green
        return
    }

    $nonTestFiles = @($gdFiles | Where-Object { -not (Test-IsTestScriptPath -RepoRoot $repoRoot -FilePath $_) })
    $testFiles = @($gdFiles | Where-Object { Test-IsTestScriptPath -RepoRoot $repoRoot -FilePath $_ })

    Invoke-GodotCompilationChecks -RepoRoot $repoRoot -GodotExe $godotExe -Files $nonTestFiles -Label 'non-test'
    Invoke-GodotCompilationChecks -RepoRoot $repoRoot -GodotExe $godotExe -Files $testFiles -Label 'test'

    if ($testFiles.Count -gt 0) {
        $assemblyName = Get-DotnetAssemblyName -RepoRoot $repoRoot
        if ($assemblyName -and (Test-ProjectUsesCSharp -RepoRoot $repoRoot)) {
            $csprojPath = Join-Path $repoRoot ("{0}.csproj" -f $assemblyName)
            if (-not (Test-Path $csprojPath)) {
                throw (New-CheckException -Message ("[gdscript-check] Missing Godot .NET project file: {0}. GDUnit runtime currently fails with '.NET: Failed to load project assembly'. Generate or restore {1} before running the full validation pipeline." -f $csprojPath, [System.IO.Path]::GetFileName($csprojPath)) -ExitCode 1)
            }
        }

        $gdUnitCmd = 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd'
        $gdUnitCmdFile = Join-Path $repoRoot 'addons\gdUnit4\bin\GdUnitCmdTool.gd'
        if (-not (Test-Path $gdUnitCmdFile)) {
            throw (New-CheckException -Message "[gdscript-check] GDUnit command script not found at $gdUnitCmdFile" -ExitCode 1)
        }

        Write-Host '[gdscript-check] Running GDUnit CLI on test scripts'
        $gdUnitResult = Invoke-ExternalProgram -FilePath $godotExe -Arguments @('--headless', '--path', $repoRoot, '-s', $gdUnitCmd, '--verbose', '-a', 'test/scripts', '--ignoreHeadlessMode')

        if ($gdUnitResult.ExitCode -ne 0 -and $gdUnitResult.ExitCode -ne 101) {
            Assert-ProgramSucceeded -Result $gdUnitResult -Context 'GDUnit CLI'
        }

        $gdUnitIssues = @(Get-GodotCompilerIssues -OutputText $gdUnitResult.CombinedOutput)
        if ($gdUnitIssues.Count -gt 0) {
            $failure = [pscustomobject]@{
                ResPath = 'res://test/scripts'
                ExitCode = $gdUnitResult.ExitCode
                Issues = @($gdUnitIssues)
                Stdout = $gdUnitResult.Stdout
                Stderr = $gdUnitResult.Stderr
            }
            Write-GodotValidationFailures -Failures @($failure) -Label 'GDUnit execution output'
            throw (New-CheckException -Message '[gdscript-check] GDUnit output reported script compilation failures.' -ExitCode 1)
        }

        $requiredTests = @(
            'test_reading_mode_complete_word_transitions_next_entry',
            'test_reading_mode_progresses_to_second_word_placement_grid'
        )
        $missingTests = @()
        foreach ($testName in $requiredTests) {
            if (-not ($gdUnitResult.Stdout -match [regex]::Escape($testName))) {
                $missingTests += $testName
            }
        }

        if ($missingTests.Count -gt 0) {
            throw (New-CheckException -Message ("[gdscript-check] Missing required test(s) from GDUnit output: {0}{1}[gdscript-check] stdout: {2}" -f ($missingTests -join ', '), [Environment]::NewLine, $gdUnitResult.Stdout.Trim()) -ExitCode 1)
        }

        $readingTestMethods = Get-ReadingTestMethodNames -RepoRoot $repoRoot
        $readingTestMethodFound = $false
        foreach ($methodName in $readingTestMethods) {
            if ($gdUnitResult.Stdout -match [regex]::Escape($methodName)) {
                $readingTestMethodFound = $true
                break
            }
        }

        if (-not $readingTestMethodFound -and $readingTestMethods.Count -gt 0) {
            throw (New-CheckException -Message ("[gdscript-check] No test_reading_* methods were detected in GDUnit output. At least one must run.{0}[gdscript-check] stdout: {1}" -f [Environment]::NewLine, $gdUnitResult.Stdout.Trim()) -ExitCode 1)
        }

        Write-Host "[gdscript-check] GDUnit CLI tests executed. (exit code $($gdUnitResult.ExitCode))"
    } else {
        Write-Host '[gdscript-check] No test scripts found under test/scripts/.'
    }

    Write-Host '[gdscript-check] ✅ All checks passed.' -ForegroundColor Green
}


if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-GdScriptCheck -Fix:$Fix
    } catch {
        $exitCode = 1
        if ($_.Exception.Data.Contains('ExitCode')) {
            $exitCode = [int]$_.Exception.Data['ExitCode']
        }
        Write-Error $_.Exception.Message
        exit $exitCode
    }
}
