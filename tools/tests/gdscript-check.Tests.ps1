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


Describe 'Test-IsTestScriptPath' {
	It 'classifies test scripts separately from source scripts' {
		$repoRoot = 'C:\Projects\reading-racer'

		(Test-IsTestScriptPath -RepoRoot $repoRoot -FilePath 'C:\Projects\reading-racer\test\scripts\systems\test_reading_mode_setup.gd') | Should Be $true
		(Test-IsTestScriptPath -RepoRoot $repoRoot -FilePath 'C:\Projects\reading-racer\scripts\reading\reading_mode.gd') | Should Be $false
	}
}


Describe 'Dotnet preflight helpers' {
	It 'reads the configured Godot assembly name' {
		(Get-DotnetAssemblyName -RepoRoot 'C:\Projects\reading-racer') | Should Be 'ReadingRacer'
	}

	It 'detects C# usage in the project scripts' {
		(Test-ProjectUsesCSharp -RepoRoot 'C:\Projects\reading-racer') | Should Be $true
	}
}