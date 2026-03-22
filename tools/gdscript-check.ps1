<#
.SYNOPSIS
Runs parsing, linting, formatting, and Godot validation checks on GDScript files.

.DESCRIPTION
This script runs a full set of checks on all project `.gd` files and any
discovered GDUnit test targets. It returns a non-zero exit code if any check fails.

.PARAMETER Fix
If specified, auto-formats files in-place instead of checking formatting only.

.PARAMETER ProjectRoot
Optional path to the Godot project root. If omitted, the script searches upward for `project.godot`.

.PARAMETER GodotBin
Optional path to the Godot executable. If omitted, the script checks `GODOT_BIN`, `GODOT4_BIN`,
and then common `godot*` commands on PATH.

.PARAMETER GdUnitTarget
Optional GDUnit test target path(s). Each entry may be a `res://` path, a path relative to the
project root, or an absolute filesystem path. If omitted, test targets are discovered from the
project's test scripts.
#>

[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$RunTests,
    [int]$TimeoutSeconds = 180,
    [string]$ProjectRoot = $null,
    [string]$GodotBin = $null,
    [string[]]$GdUnitTarget = @()
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

function Get-ElapsedTime {
    param()
    $ts = (New-TimeSpan -Start $script:CheckStartTime -End (Get-Date))
    return '{0:00}:{1:00}:{2:00}' -f $ts.Hours, $ts.Minutes, $ts.Seconds
}

function Write-StepStatus {
    param(
        [string]$Activity,
        [int]$Step,
        [int]$Total
    )

    $elapsed = Get-ElapsedTime
    $percent = 0
    if ($Total -gt 0) {
        $percent = [int]((100.0 * $Step) / $Total)
    }

    Write-Progress -Activity "[gdscript-check] $Activity" -Status "Elapsed $elapsed" -PercentComplete $percent -CurrentOperation "Step $Step/$Total"
    Write-Host "[gdscript-check] $Activity (step $Step/$Total, $percent% complete, elapsed $elapsed)"
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


function Join-ArgumentList {
    param(
        [string[]]$Arguments = @()
    )

    $parts = @()
    foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            $parts += '"' + ($argument -replace '"', '\"') + '"'
        } else {
            $parts += $argument
        }
    }

    return ($parts -join ' ')
}


function Get-ProcessStartInfo {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $extension = [System.IO.Path]::GetExtension($FilePath)
    if ($extension -ieq '.cmd' -or $extension -ieq '.bat') {
        $argumentString = Join-ArgumentList -Arguments $Arguments
        $cmdCommand = '"' + $FilePath + '"'
        if (-not [string]::IsNullOrWhiteSpace($argumentString)) {
            $cmdCommand += ' ' + $argumentString
        }
        return [pscustomobject]@{
            FilePath = 'cmd.exe'
            ArgumentString = '/d /c "' + $cmdCommand + '"'
            DisplayCommandLine = Join-CommandLine -FilePath $FilePath -Arguments $Arguments
        }
    }

    return [pscustomobject]@{
        FilePath = $FilePath
        ArgumentString = Join-ArgumentList -Arguments $Arguments
        DisplayCommandLine = Join-CommandLine -FilePath $FilePath -Arguments $Arguments
    }
}


function Invoke-ExternalProgram {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 0
    )

    $startInfo = Get-ProcessStartInfo -FilePath $FilePath -Arguments $Arguments
    $commandLine = $startInfo.DisplayCommandLine
    Write-Verbose ("[gdscript-check] cmdline: {0}" -f $commandLine)

    $captures = Get-CapturePaths
    $process = $null
    try {
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $startInfo.FilePath
        $processStartInfo.Arguments = $startInfo.ArgumentString
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.CreateNoWindow = $true

        $stdoutBuilder = New-Object System.Text.StringBuilder
        $stderrBuilder = New-Object System.Text.StringBuilder

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        $process.add_OutputDataReceived({
            param($sender, $eventArgs)
            if ($null -ne $eventArgs.Data) {
                [void]$stdoutBuilder.AppendLine($eventArgs.Data)
            }
        })
        $process.add_ErrorDataReceived({
            param($sender, $eventArgs)
            if ($null -ne $eventArgs.Data) {
                [void]$stderrBuilder.AppendLine($eventArgs.Data)
            }
        })

        [void]$process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        if ($TimeoutSeconds -gt 0) {
            $completed = $process.WaitForExit($TimeoutSeconds * 1000)
            if (-not $completed) {
                try {
                    $process.Kill()
                } catch {
                }
                throw (New-CheckException -Message "[gdscript-check] $FilePath timeout after $TimeoutSeconds seconds" -ExitCode 124)
            }
        }

        $process.WaitForExit()
        $stdout = $stdoutBuilder.ToString()
        $stderr = $stderrBuilder.ToString()

        return [pscustomobject]@{
            FilePath = $FilePath
            Arguments = $Arguments
            CommandLine = $commandLine
            ExitCode = $process.ExitCode
            Stdout = $stdout
            Stderr = $stderr
            CombinedOutput = (($stdout, $stderr) -join "`n").Trim()
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            try {
                $process.Kill()
            } catch {
            }
        }
        Remove-Item -Path $captures.Stdout, $captures.Stderr -ErrorAction SilentlyContinue
    }
}


function Invoke-PowerShellExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    $commandLine = Join-CommandLine -FilePath $FilePath -Arguments $Arguments
    Write-Verbose ("[gdscript-check] cmdline: {0}" -f $commandLine)

    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $stdout = ($output | ForEach-Object { $_.ToString() }) -join "`n"

    return [pscustomobject]@{
        FilePath = $FilePath
        Arguments = $Arguments
        CommandLine = $commandLine
        ExitCode = $exitCode
        Stdout = $stdout
        Stderr = ''
        CombinedOutput = $stdout.Trim()
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

    $elapsed = Get-ElapsedTime
    $message = @(
        "[gdscript-check] $Context failed with exit code $($Result.ExitCode) (elapsed $elapsed)",
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


function Get-ProjectRoot {
    param(
        [string]$ExplicitRoot = $null
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitRoot)) {
        $resolvedExplicitRoot = (Resolve-Path $ExplicitRoot -ErrorAction Stop).Path
        if (-not (Test-Path (Join-Path $resolvedExplicitRoot 'project.godot'))) {
            throw (New-CheckException -Message "[gdscript-check] No project.godot found under explicit ProjectRoot: $resolvedExplicitRoot" -ExitCode 1)
        }
        return $resolvedExplicitRoot
    }

    $currentPath = (Resolve-Path (Join-Path $script:ToolScriptRoot '..')).Path
    while (-not [string]::IsNullOrWhiteSpace($currentPath)) {
        if (Test-Path (Join-Path $currentPath 'project.godot')) {
            return $currentPath
        }

        $parentPath = Split-Path $currentPath -Parent
        if ([string]::IsNullOrWhiteSpace($parentPath) -or $parentPath -eq $currentPath) {
            break
        }
        $currentPath = $parentPath
    }

    throw (New-CheckException -Message '[gdscript-check] Could not locate project.godot. Set -ProjectRoot to the Godot project directory.' -ExitCode 1)
}


function Get-GdScriptFiles {
    param(
        [string]$ProjectRoot
    )

    $excludedPrefixes = @(
        '.git/',
        '.godot/',
        '.venv/',
        'reports/',
        'addons/gdUnit4/'
    )

    $files = @(
        Get-ChildItem -Path $ProjectRoot -Recurse -Filter *.gd -File |
        Where-Object {
            $relativePath = (Convert-ToResPath -RepoRoot $ProjectRoot -FilePath $_.FullName).Substring(6)
            foreach ($prefix in $excludedPrefixes) {
                if ($relativePath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $false
                }
            }
            return $true
        } |
        Select-Object -ExpandProperty FullName |
        Sort-Object
    )

    if (-not $files) {
        throw (New-CheckException -Message '[gdscript-check] No project .gd files were found.' -ExitCode 1)
    }

    return $files
}


function Get-GodotExecutablePath {
    param(
        [string]$ConfiguredPath = $null
    )

    foreach ($candidate in @($ConfiguredPath, $env:GODOT_BIN, $env:GODOT4_BIN)) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    foreach ($commandName in @('godot', 'godot4', 'godot-mono', 'godot4-mono')) {
        $command = Get-Command $commandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            return $command.Source
        }
    }

    $wildcardMatch = Get-Command 'godot*' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($wildcardMatch) {
        return $wildcardMatch.Source
    }

    return $null
}


function Get-GdUnitCommandInfo {
    param(
        [string]$ProjectRoot
    )

    $gdUnitCmdFile = Join-Path $ProjectRoot 'addons\gdUnit4\bin\GdUnitCmdTool.gd'
    if (-not (Test-Path $gdUnitCmdFile)) {
        return $null
    }

    return [pscustomobject]@{
        FilePath = $gdUnitCmdFile
        ResPath = 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd'
    }
}


function Get-PythonExecutablePath {
    param(
        [string]$RepoRoot,
        [string]$CommandPath
    )

    $venvPython = Join-Path $RepoRoot '.venv\Scripts\python.exe'
    if (Test-Path $venvPython) {
        return $venvPython
    }

    return $CommandPath
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


function Convert-FromResPath {
    param(
        [string]$RepoRoot,
        [string]$ResPath
    )

    if ([string]::IsNullOrWhiteSpace($ResPath) -or -not $ResPath.StartsWith('res://', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (New-CheckException -Message "[gdscript-check] Invalid res:// path: $ResPath" -ExitCode 1)
    }

    $relativePath = $ResPath.Substring(6) -replace '/', '\\'
    return Join-Path $RepoRoot $relativePath
}


function Resolve-GdUnitTargetResPath {
    param(
        [string]$RepoRoot,
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        throw (New-CheckException -Message '[gdscript-check] GDUnit target values cannot be empty.' -ExitCode 1)
    }

    $resolvedTargetPath = $null
    if ($Target.StartsWith('res://', [System.StringComparison]::OrdinalIgnoreCase)) {
        $resolvedTargetPath = Convert-FromResPath -RepoRoot $RepoRoot -ResPath $Target
    } elseif ([System.IO.Path]::IsPathRooted($Target)) {
        $resolvedTargetPath = $Target
    } else {
        $resolvedTargetPath = Join-Path $RepoRoot $Target
    }

    if (-not (Test-Path $resolvedTargetPath)) {
        throw (New-CheckException -Message "[gdscript-check] GDUnit target was not found: $Target" -ExitCode 1)
    }

    $resolvedTargetPath = (Resolve-Path $resolvedTargetPath -ErrorAction Stop).Path
    $resolvedTargetResPath = Convert-ToResPath -RepoRoot $RepoRoot -FilePath $resolvedTargetPath
    if ($resolvedTargetResPath -like 'res://../*' -or $resolvedTargetResPath -eq 'res://..') {
        throw (New-CheckException -Message "[gdscript-check] GDUnit target must be inside the project root: $Target" -ExitCode 1)
    }

    return $resolvedTargetResPath
}


function Get-GdUnitTargetResPaths {
    param(
        [string]$RepoRoot,
        [string[]]$TestFiles = @(),
        [string[]]$ConfiguredTargets = @()
    )

    $targets = New-Object System.Collections.Generic.List[string]
    $seen = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($configuredTarget in @($ConfiguredTargets)) {
        $resolvedTarget = Resolve-GdUnitTargetResPath -RepoRoot $RepoRoot -Target $configuredTarget
        if ($seen.Add($resolvedTarget)) {
            $targets.Add($resolvedTarget)
        }
    }

    if ($targets.Count -gt 0) {
        return $targets.ToArray()
    }

    $testResPaths = @($TestFiles | ForEach-Object { Convert-ToResPath -RepoRoot $RepoRoot -FilePath $_ })
    if ($testResPaths.Count -eq 0) {
        return [string[]]@()
    }

    foreach ($preferredRoot in @('res://test/scripts', 'res://tests/scripts', 'res://test', 'res://tests')) {
        $prefix = $preferredRoot + '/'
        $matchingPaths = @($testResPaths | Where-Object { $_ -eq $preferredRoot -or $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })
        if ($matchingPaths.Count -gt 0) {
            $alreadyCovered = $true
            foreach ($matchingPath in $matchingPaths) {
                $coveredByExistingTarget = $false
                foreach ($target in $targets) {
                    if ($matchingPath -eq $target -or $matchingPath.StartsWith($target + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
                        $coveredByExistingTarget = $true
                        break
                    }
                }
                if (-not $coveredByExistingTarget) {
                    $alreadyCovered = $false
                    break
                }
            }

            if (-not $alreadyCovered -and $seen.Add($preferredRoot)) {
                $targets.Add($preferredRoot)
            }
        }
    }

    foreach ($testResPath in ($testResPaths | Sort-Object)) {
        $isCovered = $false
        foreach ($target in $targets) {
            if ($testResPath -eq $target -or $testResPath.StartsWith($target + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
                $isCovered = $true
                break
            }
        }

        if (-not $isCovered -and $seen.Add($testResPath)) {
            $targets.Add($testResPath)
        }
    }

    return $targets.ToArray()
}


function Test-IsTestScriptPath {
    param(
        [string]$RepoRoot,
        [string]$FilePath
    )

    $resPath = Convert-ToResPath -RepoRoot $RepoRoot -FilePath $FilePath
    return (
        $resPath.StartsWith('res://test/', [System.StringComparison]::OrdinalIgnoreCase) -or
        $resPath.StartsWith('res://tests/', [System.StringComparison]::OrdinalIgnoreCase)
    )
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


function Get-GdUnitOrphanSummary {
    param(
        [string]$OutputText
    )

    if ([string]::IsNullOrWhiteSpace($OutputText)) {
        return [pscustomobject]@{
            HasOrphans = $false
            Count = 0
            DetailLines = @()
        }
    }

    $cleanOutput = [regex]::Replace($OutputText, "`e\[[\d;?]*[ -/]*[@-~]", '')
    $lines = @($cleanOutput -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $count = 0
    foreach ($pattern in @(
        'Found\s+(?<count>\d+)\s+possible orphan nodes\.',
        'Detected\s+(?<count>\d+)\s+orphan nodes(?:\s+on test setup)?!',
        '\|\s*(?<count>\d+)\s+orphans\s*\|'
    )) {
        foreach ($match in [regex]::Matches($cleanOutput, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $count = [Math]::Max($count, [int]$match.Groups['count'].Value)
        }
    }

    $detailLines = @(
        $lines |
        Where-Object {
            $_ -match 'collect_orphan_node_details\(\)' -or
            $_ -match 'Found\s+[1-9]\d*\s+possible orphan nodes\.' -or
            $_ -match 'Detected\s+[1-9]\d*\s+orphan nodes(?:\s+on test setup)?!' -or
            $_ -match '\|\s*[1-9]\d*\s+orphans\s*\|'
        } |
        Select-Object -Unique
    )

    return [pscustomobject]@{
        HasOrphans = ($count -gt 0 -or $detailLines.Count -gt 0)
        Count = $count
        DetailLines = $detailLines
    }
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
        [string]$Label,
        [int]$TimeoutSeconds = 0
    )

    Write-Host "[gdscript-check] Running Godot validation for $Label"

    $result = Invoke-PowerShellExternalCommand -FilePath $GodotExe -Arguments @('--headless', '--path', $RepoRoot, '--check-only')
    $issues = @(Get-GodotCompilerIssues -OutputText $result.CombinedOutput)

    if ($result.ExitCode -ne 0 -or $issues.Count -gt 0) {
        $failure = [pscustomobject]@{
            FilePath = $RepoRoot
            ResPath = 'res://'
            ExitCode = $result.ExitCode
            Issues = @($issues)
            Stdout = $result.Stdout
            Stderr = $result.Stderr
        }
        Write-GodotValidationFailures -Failures @($failure) -Label $Label
        throw (New-CheckException -Message "[gdscript-check] Godot validation failed for $Label scripts." -ExitCode 1)
    }

    Write-Host "[gdscript-check] Godot validation passed for $Label."
    return @()

}


function Get-LatestGdUnitResultsPath {
    param(
        [string]$RepoRoot,
        [string]$ReportsRoot = $null,
        [datetime]$NotBefore = [datetime]::MinValue
    )

    if ([string]::IsNullOrWhiteSpace($ReportsRoot)) {
        $reportsRoot = Join-Path $RepoRoot 'reports'
    }
    if (-not (Test-Path $reportsRoot)) {
        return $null
    }

    $candidates = @(
        Get-ChildItem -Path $reportsRoot -Recurse -Filter 'results.xml' -File |
        Where-Object { $_.LastWriteTime -ge $NotBefore } |
        Sort-Object @{
            Expression = {
                $match = [regex]::Match($_.Directory.Name, '^report_(\d+)$')
                if ($match.Success) {
                    return [int]$match.Groups[1].Value
                }
                return -1
            }
            Descending = $true
        }, @{
            Expression = { $_.LastWriteTime }
            Descending = $true
        }
    )

    if ($candidates.Count -eq 0) {
        return $null
    }

    return $candidates[0].FullName
}


function New-GdUnitReportRoot {
    param(
        [string]$RepoRoot
    )

    $reportRoot = Join-Path $RepoRoot (Join-Path 'reports\gdscript-check' ('run-' + [guid]::NewGuid().ToString('N')))
    New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
    return $reportRoot
}


function Get-GdUnitReportSummary {
    param(
        [string]$ResultsPath
    )

    if (-not (Test-Path $ResultsPath)) {
        throw (New-CheckException -Message "[gdscript-check] GDUnit report not found: $ResultsPath" -ExitCode 1)
    }

    [xml]$report = Get-Content -Path $ResultsPath -Raw
    $issues = New-Object System.Collections.Generic.List[object]

    foreach ($suite in @($report.testsuites.testsuite)) {
        foreach ($testcase in @($suite.testcase)) {
            $failureNodes = @()
            $errorNodes = @()
            if ($testcase.PSObject.Properties.Match('failure').Count -gt 0) {
                $failureNodes = @($testcase.failure)
            }
            if ($testcase.PSObject.Properties.Match('error').Count -gt 0) {
                $errorNodes = @($testcase.error)
            }

            foreach ($failureNode in $failureNodes) {
                $issues.Add([pscustomobject]@{
                    Kind = 'Failure'
                    SuiteName = [string]$suite.name
                    TestName = [string]$testcase.name
                    Message = [string]$failureNode.message
                    Details = ([string]$failureNode.'#cdata-section').Trim()
                })
            }

            foreach ($errorNode in $errorNodes) {
                $issues.Add([pscustomobject]@{
                    Kind = 'Error'
                    SuiteName = [string]$suite.name
                    TestName = [string]$testcase.name
                    Message = [string]$errorNode.message
                    Details = ([string]$errorNode.'#cdata-section').Trim()
                })
            }
        }
    }

    return [pscustomobject]@{
        ResultsPath = $ResultsPath
        TotalTests = [int]$report.testsuites.tests
        FailureCount = @($issues | Where-Object { $_.Kind -eq 'Failure' }).Count
        ErrorCount = @($issues | Where-Object { $_.Kind -eq 'Error' }).Count
        Issues = $issues.ToArray()
    }
}


function Write-GdUnitReportFailures {
    param(
        $Summary
    )

    Write-Host "[gdscript-check] ERROR: GDUnit report recorded $($Summary.FailureCount) failure(s) and $($Summary.ErrorCount) error(s)." -ForegroundColor Red
    Write-Host "[gdscript-check] Report: $($Summary.ResultsPath)"
    foreach ($issue in $Summary.Issues) {
        Write-Host "  [$($issue.Kind)] $($issue.SuiteName)::$($issue.TestName)"
        if ($issue.Message) {
            Write-Host "    Message: $($issue.Message)"
        }
        if ($issue.Details) {
            Write-Host "    Details: $($issue.Details -replace '\r?\n', ' | ')"
        }
    }
}


function Write-GdUnitOrphanFailures {
    param(
        $Summary,
        [string]$ResultsPath = $null
    )

    $countLabel = if ($Summary.Count -gt 0) { $Summary.Count } else { 'unknown' }
    Write-Host "[gdscript-check] ERROR: GDUnit reported $countLabel possible orphan node(s)." -ForegroundColor Red
    Write-Host "[gdscript-check] Add 'collect_orphan_node_details()' to the end of the leaking test to collect details."
    if (-not [string]::IsNullOrWhiteSpace($ResultsPath)) {
        Write-Host "[gdscript-check] Report: $ResultsPath"
    }
    foreach ($detailLine in @($Summary.DetailLines | Select-Object -First 8)) {
        Write-Host "  $detailLine"
    }
}


function Wait-ForFreshGdUnitResultsPath {
    param(
        [string]$RepoRoot,
        [string]$ReportsRoot = $null,
        [string]$PreviousResultsPath = $null,
        [datetime]$PreviousWriteTime = [datetime]::MinValue,
        [int]$TimeoutMilliseconds = 15000
    )

    $deadline = (Get-Date).AddMilliseconds($TimeoutMilliseconds)
    do {
        $candidate = Get-LatestGdUnitResultsPath -RepoRoot $RepoRoot -ReportsRoot $ReportsRoot
        if ($candidate) {
            $candidateWriteTime = (Get-Item $candidate).LastWriteTime
            if ($candidate -ne $PreviousResultsPath -or $candidateWriteTime -gt $PreviousWriteTime) {
                return $candidate
            }
        }

        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    return $null
}




function Invoke-GdScriptCheck {
    param(
        [switch]$Fix,
        [string]$ProjectRoot = $null,
        [string]$GodotBin = $null,
        [string[]]$GdUnitTarget = @()
    )

    $repoRoot = Get-ProjectRoot -ExplicitRoot $ProjectRoot
    Set-Location $repoRoot
    $script:CheckStartTime = Get-Date
    $script:CheckCurrentStep = 0
    Write-Host "[gdscript-check] Running in: $repoRoot"

    $gdparseCmd = Get-Command gdparse -ErrorAction SilentlyContinue
    $gdlintCmd = Get-Command gdlint -ErrorAction SilentlyContinue
    $gdformatCmd = Get-Command gdformat -ErrorAction SilentlyContinue
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue

    $gdparse = if ($gdparseCmd) { $gdparseCmd.Source } else { $null }
    $gdlint = if ($gdlintCmd) { $gdlintCmd.Source } else { $null }
    $gdformat = if ($gdformatCmd) { $gdformatCmd.Source } else { $null }
    $python = if ($pythonCmd) { Get-PythonExecutablePath -RepoRoot $repoRoot -CommandPath $pythonCmd.Source } else { 'python' }

    # Prefer python gdtoolkit, because local shims may hang or deviate.
    $usePython = $false
    if ($pythonCmd) {
        $usePython = $true
    } elseif (-not ($gdparse -and $gdlint -and $gdformat)) {
        throw (New-CheckException -Message '[gdscript-check] No parser/linter/formatter commands available.' -ExitCode 2)
    }

    if ($usePython) {
        Write-Host '[gdscript-check] Warning: gdtoolkit CLI scripts were not found on PATH. Falling back to python -m invocations.'
    }

    $gdFiles = Get-GdScriptFiles -ProjectRoot $repoRoot
    $testFiles = @($gdFiles | Where-Object { Test-IsTestScriptPath -RepoRoot $repoRoot -FilePath $_ })
    $gdUnitTargets = @(Get-GdUnitTargetResPaths -RepoRoot $repoRoot -TestFiles $testFiles -ConfiguredTargets $GdUnitTarget)
    $godotExe = Get-GodotExecutablePath -ConfiguredPath $GodotBin
    $gdUnitCommand = Get-GdUnitCommandInfo -ProjectRoot $repoRoot
    $script:CheckTotalSteps = 3
    if ($godotExe) {
        $script:CheckTotalSteps++
        if ($testFiles.Count -gt 0 -and $gdUnitCommand) {
            $script:CheckTotalSteps++
        }
    }
    Write-Host "[gdscript-check] Found $($gdFiles.Count) .gd files"

    $script:CheckCurrentStep++
    Write-StepStatus -Activity 'gdparse' -Step $script:CheckCurrentStep -Total $script:CheckTotalSteps

    if ($usePython) {
        Write-Host "[gdscript-check] Running gdparse on $($gdFiles.Count) file(s)"
        $parseResult = Invoke-PowerShellExternalCommand -FilePath $python -Arguments (@('-m', 'gdtoolkit.parser') + $gdFiles)
    } else {
        Write-Host "[gdscript-check] Running gdparse on $($gdFiles.Count) file(s)"
        $parseResult = Invoke-ExternalProgram -FilePath $gdparse -Arguments $gdFiles -TimeoutSeconds $TimeoutSeconds
    }
    Assert-ProgramSucceeded -Result $parseResult -Context 'gdparse'

    $script:CheckCurrentStep++
    Write-StepStatus -Activity 'gdlint' -Step $script:CheckCurrentStep -Total $script:CheckTotalSteps

    if ($usePython) {
        Write-Host "[gdscript-check] Running gdlint on $($gdFiles.Count) file(s)"
        $lintResult = Invoke-PowerShellExternalCommand -FilePath $python -Arguments (@('-m', 'gdtoolkit.linter') + $gdFiles)
    } else {
        Write-Host "[gdscript-check] Running gdlint on $($gdFiles.Count) file(s)"
        $lintResult = Invoke-ExternalProgram -FilePath $gdlint -Arguments $gdFiles -TimeoutSeconds $TimeoutSeconds
    }
    Assert-ProgramSucceeded -Result $lintResult -Context 'gdlint'

    $script:CheckCurrentStep++
    Write-StepStatus -Activity 'gdformat' -Step $script:CheckCurrentStep -Total $script:CheckTotalSteps

    if ($usePython) {
        $formatArgs = @('-m', 'gdtoolkit.formatter')
        if ($Fix) {
            Write-Host '[gdscript-check] Running formatter (in-place)'
            $formatArgs += $gdFiles
        } else {
            Write-Host '[gdscript-check] Running formatter in check mode (use -Fix to apply changes)'
            $formatArgs += @('--check') + $gdFiles
        }
        $formatResult = Invoke-PowerShellExternalCommand -FilePath $python -Arguments $formatArgs
    } else {
        if ($Fix) {
            Write-Host "[gdscript-check] Running formatter (in-place) on $($gdFiles.Count) file(s)"
            $formatResult = Invoke-ExternalProgram -FilePath $gdformat -Arguments $gdFiles -TimeoutSeconds $TimeoutSeconds
        } else {
            Write-Host "[gdscript-check] Running formatter in check mode (use -Fix to apply changes) on $($gdFiles.Count) file(s)"
            $formatResult = Invoke-ExternalProgram -FilePath $gdformat -Arguments (@('--check') + $gdFiles) -TimeoutSeconds $TimeoutSeconds
        }
    }
    Assert-ProgramSucceeded -Result $formatResult -Context 'gdformat'

    if (-not (Test-Path $godotExe)) {
        Write-Host '[gdscript-check] Warning: Godot executable was not found. Set -GodotBin or GODOT_BIN to enable Godot validation.' -ForegroundColor Yellow
        Write-Host '[gdscript-check] Note: test files are not validated via Godot/GDUnit when Godot is unavailable.'
        Write-Host '[gdscript-check] ✅ All checks passed.' -ForegroundColor Green
        return
    }

    $script:CheckCurrentStep++
    Write-StepStatus -Activity 'Godot compile project scripts' -Step $script:CheckCurrentStep -Total $script:CheckTotalSteps
    Invoke-GodotCompilationChecks -RepoRoot $repoRoot -GodotExe $godotExe -Label 'project scripts' -TimeoutSeconds $TimeoutSeconds

    if ($testFiles.Count -gt 0) {
        if (-not $gdUnitCommand) {
            Write-Host '[gdscript-check] Warning: test scripts were found, but GDUnit was not detected. Skipping GDUnit CLI.' -ForegroundColor Yellow
            Write-Host '[gdscript-check] ✅ All checks passed.' -ForegroundColor Green
            return
        }

        $script:CheckCurrentStep++
        Write-StepStatus -Activity 'GDUnit CLI' -Step $script:CheckCurrentStep -Total $script:CheckTotalSteps
        Write-Host ("[gdscript-check] Running GDUnit CLI on target(s): {0}" -f ($gdUnitTargets -join ', '))
        $gdUnitReportRoot = New-GdUnitReportRoot -RepoRoot $repoRoot
        Write-Host "[gdscript-check] GDUnit report root: $gdUnitReportRoot"
        $previousGdUnitResultsPath = Get-LatestGdUnitResultsPath -RepoRoot $repoRoot -ReportsRoot $gdUnitReportRoot
        $previousGdUnitResultsWriteTime = [datetime]::MinValue
        if ($previousGdUnitResultsPath) {
            $previousGdUnitResultsWriteTime = (Get-Item $previousGdUnitResultsPath).LastWriteTime
        }
        $gdUnitArguments = @('--headless', '--path', $repoRoot, '-s', $gdUnitCommand.ResPath, '--verbose')
        foreach ($gdUnitTargetPath in $gdUnitTargets) {
            $gdUnitArguments += @('-a', $gdUnitTargetPath)
        }
        $gdUnitArguments += @('-rd', $gdUnitReportRoot, '-rc', '1', '--ignoreHeadlessMode')
        $gdUnitResult = Invoke-PowerShellExternalCommand -FilePath $godotExe -Arguments $gdUnitArguments

        # GDUnit command returns 100 for test failures, 101 for success with warnings/orphans.
        # For this GDScript-only project, fallback to allow 1 if it is caused by known runtime warnings.
        $gdUnitIssues = @(Get-GodotCompilerIssues -OutputText $gdUnitResult.CombinedOutput)
        $gdUnitOrphans = Get-GdUnitOrphanSummary -OutputText $gdUnitResult.CombinedOutput

        if ($gdUnitResult.ExitCode -eq 100) {
            Assert-ProgramSucceeded -Result $gdUnitResult -Context 'GDUnit CLI'
        }

        $extraWarnings = $gdUnitResult.CombinedOutput -match 'Failed to load project assembly|Cannot get path of node as it is not in a scene tree|resources still in use at exit'

        if ($gdUnitResult.ExitCode -ne 0 -and $gdUnitResult.ExitCode -ne 101 -and -not $extraWarnings) {
            Assert-ProgramSucceeded -Result $gdUnitResult -Context 'GDUnit CLI'
        }

        if ($gdUnitResult.ExitCode -eq 101 -and -not $gdUnitOrphans.HasOrphans -and -not $extraWarnings) {
            throw (New-CheckException -Message '[gdscript-check] GDUnit exited with warning status 101, but no orphan details were detected in the output.' -ExitCode 1)
        }

        if ($gdUnitIssues.Count -gt 0) {
            $failure = [pscustomobject]@{
                ResPath = ($gdUnitTargets -join ', ')
                ExitCode = $gdUnitResult.ExitCode
                Issues = @($gdUnitIssues)
                Stdout = $gdUnitResult.Stdout
                Stderr = $gdUnitResult.Stderr
            }
            Write-GodotValidationFailures -Failures @($failure) -Label 'GDUnit execution output'
            throw (New-CheckException -Message '[gdscript-check] GDUnit output reported script compilation failures.' -ExitCode 1)
        }

        $gdUnitResultsPath = Wait-ForFreshGdUnitResultsPath -RepoRoot $repoRoot -ReportsRoot $gdUnitReportRoot -PreviousResultsPath $previousGdUnitResultsPath -PreviousWriteTime $previousGdUnitResultsWriteTime
        $gdUnitSummary = $null
        if ($gdUnitResultsPath) {
            $gdUnitSummary = Get-GdUnitReportSummary -ResultsPath $gdUnitResultsPath
            if ($gdUnitSummary.FailureCount -gt 0 -or $gdUnitSummary.ErrorCount -gt 0) {
                Write-GdUnitReportFailures -Summary $gdUnitSummary
                throw (New-CheckException -Message '[gdscript-check] GDUnit report recorded failing tests.' -ExitCode 1)
            }
            if ($gdUnitSummary.TotalTests -le 0) {
                throw (New-CheckException -Message '[gdscript-check] GDUnit report did not record any executed tests.' -ExitCode 1)
            }
            if ($gdUnitOrphans.HasOrphans) {
                Write-GdUnitOrphanFailures -Summary $gdUnitOrphans -ResultsPath $gdUnitSummary.ResultsPath
                throw (New-CheckException -Message '[gdscript-check] GDUnit output reported orphan nodes.' -ExitCode 1)
            }
        } else {
            $stdout = $gdUnitResult.Stdout.Trim()
            if ([string]::IsNullOrWhiteSpace($stdout)) {
                $stdout = '<empty>'
            }
            throw (New-CheckException -Message ("[gdscript-check] GDUnit did not produce a results.xml under '{0}'.{1}[gdscript-check] stdout: {2}" -f $gdUnitReportRoot, [Environment]::NewLine, $stdout) -ExitCode 1)
        }

        Write-Host "[gdscript-check] GDUnit CLI tests executed. (exit code $($gdUnitResult.ExitCode))"
    } else {
        Write-Host '[gdscript-check] No GDUnit test scripts were discovered.'
    }

    Write-Host '[gdscript-check] ✅ All checks passed.' -ForegroundColor Green
}

function Invoke-GdScriptCheckTests {
    if (-not (Get-Command Invoke-Pester -ErrorAction SilentlyContinue)) {
        throw (New-CheckException -Message '[gdscript-check] Pester is required for running tests. Install the Pester module first.' -ExitCode 1)
    }

    $testPath = Join-Path $script:ToolScriptRoot 'tests\gdscript-check.Tests.ps1'
    if (-not (Test-Path $testPath)) {
        throw (New-CheckException -Message "[gdscript-check] Pester test file not found: $testPath" -ExitCode 1)
    }

    $result = Invoke-Pester -Script $testPath -PassThru -Quiet
    if ($result.FailedCount -gt 0) {
        throw (New-CheckException -Message "[gdscript-check] Pester tests failed: $($result.FailedCount) failed" -ExitCode 1)
    }
    Write-Host '[gdscript-check] Pester tests passed.' -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($RunTests) {
            Invoke-GdScriptCheckTests
        } else {
            Invoke-GdScriptCheck -Fix:$Fix -ProjectRoot $ProjectRoot -GodotBin $GodotBin -GdUnitTarget $GdUnitTarget
        }
    } catch {
        $exitCode = 1
        if ($_.Exception.Data.Contains('ExitCode')) {
            $exitCode = [int]$_.Exception.Data['ExitCode']
        }
        Write-Error $_.Exception.Message
        exit $exitCode
    }
}
