. (Join-Path $PSScriptRoot '..\gdscript-check.ps1')


Describe 'Get-GodotCompilerIssues' {
	It 'parses specific parse errors and load failures from Godot output' {
		$output = @"
SCRIPT ERROR: Parse Error: Identifier "WORD_START_X" not declared in the current scope.
    at: GDScript::reload (res://test/scripts/systems/test_reading_mode_setup.gd:237)
SCRIPT ERROR: Parse Error: Identifier "PLAYER_START_X" not declared in the current scope.
    at: GDScript::reload (res://test/scripts/systems/test_reading_mode_setup.gd:237)
ERROR: Failed to load script "res://test/scripts/systems/test_reading_mode_setup.gd" with error "Parse error".
    at: load (modules/gdscript/gdscript.cpp:2907)
"@

		$issues = Get-GodotCompilerIssues -OutputText $output

		$parseIssues = @($issues | Where-Object { $_.Kind -eq 'ParseError' })
		$loadFailure = @($issues | Where-Object { $_.Kind -eq 'LoadFailure' })

		$parseIssues.Count | Should Be 2
		$loadFailure.Count | Should Be 1
		$parseIssues[0].ScriptPath | Should Be 'res://test/scripts/systems/test_reading_mode_setup.gd'
		$parseIssues[0].Line | Should Be 237
		$loadFailure[0].Message | Should Be 'Parse error'
	}

	It 'returns no issues for empty output' {
		@(Get-GodotCompilerIssues -OutputText '').Count | Should Be 0
	}
}


Describe 'Get-GdUnitReportSummary' {
	It 'parses failures and errors from a GDUnit results.xml file' {
		$tempFile = Join-Path $env:TEMP ("gdunit-results-{0}.xml" -f ([guid]::NewGuid().ToString('N')))
		$xml = @"
<?xml version="1.0" encoding="UTF-8" ?>
<testsuites id="2026-03-22" name="report_test" tests="3" failures="1" skipped="0" flaky="0" time="0.000">
	<testsuite id="1" name="suite_a" package="test/scripts/systems" tests="2" failures="1" errors="0" skipped="0" flaky="0" time="0.100">
		<testcase name="test_failure" classname="suite_a" time="0.010">
			<failure message="FAILED: res://test/scripts/systems/test_a.gd:10" type="FAILURE"><![CDATA[
Expecting true but was false
]]></failure>
		</testcase>
	</testsuite>
	<testsuite id="2" name="suite_b" package="test/scripts/systems" tests="1" failures="0" errors="1" skipped="0" flaky="0" time="0.100">
		<testcase name="test_error" classname="suite_b" time="0.010">
			<error message="ERROR: res://test/scripts/systems/test_b.gd:25" type="ABORT"><![CDATA[
Godot Runtime Error !
]]></error>
		</testcase>
	</testsuite>
</testsuites>
"@

		Set-Content -Path $tempFile -Value $xml -Encoding UTF8

		try {
			$summary = Get-GdUnitReportSummary -ResultsPath $tempFile

			$summary.TotalTests | Should Be 3
			$summary.FailureCount | Should Be 1
			$summary.ErrorCount | Should Be 1
			$summary.Issues.Count | Should Be 2
			$summary.Issues[0].SuiteName | Should Be 'suite_a'
			$summary.Issues[0].TestName | Should Be 'test_failure'
			$summary.Issues[0].Kind | Should Be 'Failure'
			$summary.Issues[1].Kind | Should Be 'Error'
		} finally {
			Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
		}
	}
}


Describe 'Get-GdUnitTargetResPaths' {
	It 'discovers preferred GDUnit roots from test files' {
		$projectRoot = Join-Path $env:TEMP ("gdunit-targets-{0}" -f ([guid]::NewGuid().ToString('N')))
		$testScript = Join-Path $projectRoot 'test\scripts\systems\test_main.gd'
		$testsScript = Join-Path $projectRoot 'tests\scripts\systems\test_other.gd'

		New-Item -ItemType Directory -Path (Split-Path $testScript -Parent) -Force | Out-Null
		New-Item -ItemType Directory -Path (Split-Path $testsScript -Parent) -Force | Out-Null
		Set-Content -Path $testScript -Value 'extends Node' -Encoding UTF8
		Set-Content -Path $testsScript -Value 'extends Node' -Encoding UTF8

		try {
			$targets = @(Get-GdUnitTargetResPaths -RepoRoot $projectRoot -TestFiles @($testScript, $testsScript))

			$targets.Count | Should Be 2
			$targets[0] | Should Be 'res://test/scripts'
			$targets[1] | Should Be 'res://tests/scripts'
		} finally {
			Remove-Item -Path $projectRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}

	It 'resolves configured GDUnit targets from project-relative and res paths' {
		$projectRoot = Join-Path $env:TEMP ("gdunit-configured-targets-{0}" -f ([guid]::NewGuid().ToString('N')))
		$testDir = Join-Path $projectRoot 'test\scripts'
		$testsDir = Join-Path $projectRoot 'tests\scripts'

		New-Item -ItemType Directory -Path $testDir -Force | Out-Null
		New-Item -ItemType Directory -Path $testsDir -Force | Out-Null

		try {
			$targets = @(Get-GdUnitTargetResPaths -RepoRoot $projectRoot -ConfiguredTargets @('test/scripts', 'res://tests/scripts'))

			$targets.Count | Should Be 2
			$targets[0] | Should Be 'res://test/scripts'
			$targets[1] | Should Be 'res://tests/scripts'
		} finally {
			Remove-Item -Path $projectRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}


Describe 'Get-GdUnitOrphanSummary' {
	It 'detects orphan warnings and guidance in GDUnit output' {
		$output = @"
WARNING: Found 1 possible orphan nodes.
Add 'collect_orphan_node_details()' to the end of the test to collect details.
 25 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 1 orphans |
"@

		$summary = Get-GdUnitOrphanSummary -OutputText $output

		$summary.HasOrphans | Should Be $true
		$summary.Count | Should Be 1
		$summary.DetailLines.Count | Should Be 3
	}

	It 'returns no orphan issues for regular passing output' {
		$summary = Get-GdUnitOrphanSummary -OutputText ' 32 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |'

		$summary.HasOrphans | Should Be $false
		$summary.Count | Should Be 0
		$summary.DetailLines.Count | Should Be 0
	}
}


Describe 'Get-LatestGdUnitResultsPath' {
	It 'returns the newest GDUnit results.xml newer than the provided time' {
		$repoRoot = Join-Path $env:TEMP ("gdunit-repo-{0}" -f ([guid]::NewGuid().ToString('N')))
		$newerDir = Join-Path $repoRoot 'reports\report_new'
		$olderDir = Join-Path $repoRoot 'reports\report_old'
		$newerFile = Join-Path $newerDir 'results.xml'
		$olderFile = Join-Path $olderDir 'results.xml'
		$threshold = Get-Date

		New-Item -ItemType Directory -Path $newerDir -Force | Out-Null
		New-Item -ItemType Directory -Path $olderDir -Force | Out-Null
		Set-Content -Path $olderFile -Value '<testsuites tests="0" failures="0" />' -Encoding UTF8
		Set-Content -Path $newerFile -Value '<testsuites tests="0" failures="0" />' -Encoding UTF8
		(Get-Item $olderFile).LastWriteTime = $threshold.AddMinutes(-2)
		(Get-Item $newerFile).LastWriteTime = $threshold.AddSeconds(2)

		try {
			(Get-LatestGdUnitResultsPath -RepoRoot $repoRoot -NotBefore $threshold) | Should Be $newerFile
		} finally {
			Remove-Item -Path $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}

	It 'limits discovery to an explicit report root when provided' {
		$repoRoot = Join-Path $env:TEMP ("gdunit-repo-{0}" -f ([guid]::NewGuid().ToString('N')))
		$defaultDir = Join-Path $repoRoot 'reports\report_99'
		$runRoot = Join-Path $repoRoot 'reports\gdscript-check\run-test'
		$runDir = Join-Path $runRoot 'report_1'
		$defaultFile = Join-Path $defaultDir 'results.xml'
		$runFile = Join-Path $runDir 'results.xml'

		New-Item -ItemType Directory -Path $defaultDir -Force | Out-Null
		New-Item -ItemType Directory -Path $runDir -Force | Out-Null
		Set-Content -Path $defaultFile -Value '<testsuites tests="1" failures="1" />' -Encoding UTF8
		Set-Content -Path $runFile -Value '<testsuites tests="2" failures="0" />' -Encoding UTF8

		try {
			(Get-LatestGdUnitResultsPath -RepoRoot $repoRoot -ReportsRoot $runRoot) | Should Be $runFile
		} finally {
			Remove-Item -Path $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}


Describe 'Get-ProjectRoot' {
	It 'returns an explicit project root when project.godot exists there' {
		$projectRoot = Join-Path $env:TEMP ("godot-project-{0}" -f ([guid]::NewGuid().ToString('N')))
		New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
		Set-Content -Path (Join-Path $projectRoot 'project.godot') -Value 'config_version=5' -Encoding UTF8

		try {
			(Get-ProjectRoot -ExplicitRoot $projectRoot) | Should Be $projectRoot
		} finally {
			Remove-Item -Path $projectRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}


Describe 'Get-GdScriptFiles' {
	It 'collects project scripts and excludes reports and gdUnit addon files' {
		$projectRoot = Join-Path $env:TEMP ("gd-files-{0}" -f ([guid]::NewGuid().ToString('N')))
		$mainScript = Join-Path $projectRoot 'scripts\main.gd'
		$testScript = Join-Path $projectRoot 'test\scripts\test_main.gd'
		$gdUnitScript = Join-Path $projectRoot 'addons\gdUnit4\bin\GdUnitCmdTool.gd'
		$reportScript = Join-Path $projectRoot 'reports\report_1\ignored.gd'

		New-Item -ItemType Directory -Path (Split-Path $mainScript -Parent) -Force | Out-Null
		New-Item -ItemType Directory -Path (Split-Path $testScript -Parent) -Force | Out-Null
		New-Item -ItemType Directory -Path (Split-Path $gdUnitScript -Parent) -Force | Out-Null
		New-Item -ItemType Directory -Path (Split-Path $reportScript -Parent) -Force | Out-Null
		Set-Content -Path $mainScript -Value 'extends Node' -Encoding UTF8
		Set-Content -Path $testScript -Value 'extends Node' -Encoding UTF8
		Set-Content -Path $gdUnitScript -Value 'extends Node' -Encoding UTF8
		Set-Content -Path $reportScript -Value 'extends Node' -Encoding UTF8

		try {
			$files = @(Get-GdScriptFiles -ProjectRoot $projectRoot)

			($files -contains $mainScript) | Should Be $true
			($files -contains $testScript) | Should Be $true
			($files -contains $gdUnitScript) | Should Be $false
			($files -contains $reportScript) | Should Be $false
		} finally {
			Remove-Item -Path $projectRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}


Describe 'Test-IsTestScriptPath' {
	It 'classifies test scripts separately from source scripts' {
		$repoRoot = Join-Path $env:TEMP ("gdscript-check-paths-{0}" -f ([guid]::NewGuid().ToString('N')))
		$testScript = Join-Path $repoRoot 'test\scripts\systems\test_reading_mode_setup.gd'
		$testsScript = Join-Path $repoRoot 'tests\scripts\systems\test_other.gd'
		$sourceScript = Join-Path $repoRoot 'scripts\reading\reading_mode.gd'

		New-Item -ItemType Directory -Path (Split-Path $testScript -Parent) -Force | Out-Null
		New-Item -ItemType Directory -Path (Split-Path $testsScript -Parent) -Force | Out-Null
		New-Item -ItemType Directory -Path (Split-Path $sourceScript -Parent) -Force | Out-Null
		Set-Content -Path $testScript -Value 'extends Node' -Encoding UTF8
		Set-Content -Path $testsScript -Value 'extends Node' -Encoding UTF8
		Set-Content -Path $sourceScript -Value 'extends Node' -Encoding UTF8

		try {
			(Test-IsTestScriptPath -RepoRoot $repoRoot -FilePath $testScript) | Should Be $true
			(Test-IsTestScriptPath -RepoRoot $repoRoot -FilePath $testsScript) | Should Be $true
			(Test-IsTestScriptPath -RepoRoot $repoRoot -FilePath $sourceScript) | Should Be $false
		} finally {
			Remove-Item -Path $repoRoot -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}

Describe 'Get-GodotExecutablePath' {
	It 'prefers an explicit path when provided' {
		$tempDir = Join-Path $env:TEMP ("godot-bin-{0}" -f ([guid]::NewGuid().ToString('N')))
		$tempExe = Join-Path $tempDir 'Godot.exe'
		New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
		Set-Content -Path $tempExe -Value '' -Encoding UTF8

		try {
			(Get-GodotExecutablePath -ConfiguredPath $tempExe) | Should Be $tempExe
		} finally {
			Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
		}
	}

	It 'uses GODOT_BIN when it points to an existing executable' {
		$tempDir = Join-Path $env:TEMP ("godot-env-{0}" -f ([guid]::NewGuid().ToString('N')))
		$tempExe = Join-Path $tempDir 'Godot.exe'
		$originalGodotBin = $env:GODOT_BIN
		New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
		Set-Content -Path $tempExe -Value '' -Encoding UTF8
		$env:GODOT_BIN = $tempExe

		try {
			(Get-GodotExecutablePath) | Should Be $tempExe
		} finally {
			$env:GODOT_BIN = $originalGodotBin
			Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}


