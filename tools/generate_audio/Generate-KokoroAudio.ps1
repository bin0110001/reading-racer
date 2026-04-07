<#
.SYNOPSIS
    Generates Kokoro TTS audio files from the example command list.

.DESCRIPTION
    Parses tools/generate_audio/KokoroTTS-Generate.txt for prompt/output pairs and
    invokes kokoro-tts for each entry.

    By default, it only generates missing files. Use -Force to regenerate all files.

.PARAMETER OutputDir
    Target directory where generated WAV files are created.

.PARAMETER Force
    Regenerate every file, even when the output already exists.

.PARAMETER Voice
    Kokoro voice name.

.PARAMETER Speed
    Voice speed.

.PARAMETER Lang
    Language code.

.PARAMETER ModelPath
    Optional locally-hosted Kokoro ONNX model file path. If provided and exists,
    this will be passed as "--model <path>" to kokoro-tts.

.PARAMETER KokoroTtsExe
    kokoro-tts executable name or path.

.PARAMETER TempDir
    Temporary directory used for text input files.
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$GenerateAllWords,
    [string]$OutputDir,
    [string]$WordsRoot,
    [string]$TempDir = (Join-Path $env:TEMP 'UnityKokoroTTS'),
    [string]$Voice = 'af_heart',
    [int]$Speed = 1,
    [string]$Lang = 'en-us',
    [string]$ModelPath,
    [string]$VoicesPath,
    [string]$KokoroTtsExe = 'kokoro-tts'
)

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $WordsRoot) { $WordsRoot = Resolve-Path -Path (Join-Path $scriptDir '..\..\audio\words') -ErrorAction SilentlyContinue }
if (-not $WordsRoot) { $WordsRoot = Join-Path $scriptDir '..\..\audio\words' }
if (-not $OutputDir) { $OutputDir = Join-Path $scriptDir 'KokoroEnglish' }
if (-not $ModelPath) { $ModelPath = Join-Path $scriptDir 'kokoro-v1.0.onnx' }
if (-not $VoicesPath) { $VoicesPath = Join-Path $scriptDir 'voices-v1.0.bin' }
$sourceFile = Join-Path $scriptDir 'KokoroTTS-Generate.txt'

function Normalize-FilenameComponent {
    param([string]$Value)
    $normalized = $Value.Trim().ToLower()
    $normalized = $normalized -replace '[\/\\|\s,\"]', ''
    $normalized = $normalized -replace '[^a-z0-9!-]', ''
    return $normalized
}

function Get-CompactPronunciation {
    param([string]$Pronunciation)
    $compact = $Pronunciation.Trim()
    if ([string]::IsNullOrWhiteSpace($compact)) { return '' }
    $compact = $compact -replace '[\/\s,|]', ''
    return $compact
}

function Build-AudioHints {
    param(
        [string]$AudioHintText,
        [string]$SimplePronunciation,
        [string]$StrictPronunciation
    )
    $hints = @()
    if (-not [string]::IsNullOrWhiteSpace($AudioHintText)) {
        $parts = $AudioHintText -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        if ($parts.Count -gt 0) { return $parts }
    }

    $simpleHint = Get-CompactPronunciation $SimplePronunciation
    $strictHint = Get-CompactPronunciation $StrictPronunciation
    if ($strictHint -and $simpleHint -ne $strictHint) {
        $hints += $strictHint
    }
    return $hints
}

function Build-OutputFileName {
    param(
        [string]$WordText,
        [string[]]$AudioHints,
        [hashtable]$ExistingPaths
    )
    $base = Normalize-FilenameComponent $WordText
    if ([string]::IsNullOrWhiteSpace($base)) { $base = 'word' }

    if ($AudioHints.Count -gt 0) {
        $hint = Normalize-FilenameComponent $AudioHints[0]
        if (-not [string]::IsNullOrWhiteSpace($hint)) {
            $base = "$base-$hint"
        }
    }

    $candidate = "$base.wav"
    $index = 1
    while ($ExistingPaths.ContainsKey($candidate)) {
        $candidate = "$base-$index.wav"
        $index++
    }

    $ExistingPaths[$candidate] = $true
    return $candidate
}

function Get-RowFieldValue {
    param(
        [Parameter(Mandatory=$true)]$Row,
        [Parameter(Mandatory=$true)]$FieldNames
    )

    foreach ($fieldName in $FieldNames) {
        if ($Row.PSObject.Properties.Name -contains $fieldName) {
            $value = $Row.$fieldName
            if ($value -ne $null) {
                return $value.ToString()
            }
        }
    }
    return ''
}

function Build-WordEntriesFromCsv {
    param([string]$RootPath)

    $entries = [System.Collections.Generic.List[PSObject]]::new()
    $groups = Get-ChildItem -Path $RootPath -Directory -ErrorAction SilentlyContinue
    foreach ($group in $groups) {
        $csvFile = Get-ChildItem -Path $group.FullName -File | Where-Object { $_.Name -in 'Words.csv', 'words.csv' } | Select-Object -First 1
        if (-not $csvFile) { continue }

        $rows = Import-Csv -Path $csvFile.FullName -ErrorAction Stop
        $existingNames = @{}
        foreach ($row in $rows) {
            $wordText = (Get-RowFieldValue $row @('Word')).Trim()
            if ([string]::IsNullOrWhiteSpace($wordText)) { continue }

            $audioHintText = (Get-RowFieldValue $row @('Audio Hint', 'audio hint', 'Pronunciation Hint', 'pronunciation hint')).Trim()
            $simplePron = (Get-RowFieldValue $row @('Simple Pronunciation', 'simple pronunciation')).Trim()
            $strictPron = (Get-RowFieldValue $row @('Strict Pronunciation', 'strict pronunciation')).Trim()
            $audioHints = Build-AudioHints $audioHintText $simplePron $strictPron
            $fileName = Build-OutputFileName $wordText $audioHints $existingNames
            $entries.Add([PSCustomObject]@{
                Prompt = $wordText
                OutputFileName = $fileName
                OutputDir = $group.FullName
            })
        }
    }
    return $entries
}

if ($GenerateAllWords -and -not (Test-Path $WordsRoot)) {
    throw "Could not find words root directory: $WordsRoot"
}

if ($GenerateAllWords) {
    Write-Host "Generating all word audio from CSV groups under: $WordsRoot"
    $entries = Build-WordEntriesFromCsv $WordsRoot
    if ($entries.Count -eq 0) {
        throw "No Words.csv files were found under $WordsRoot or no word rows were available."
    }
} else {
    if (-not (Test-Path $sourceFile)) {
        throw "Could not find the source sample file: $sourceFile"
    }

    $rawLines = Get-Content -Path $sourceFile -ErrorAction Stop
    $entries = [System.Collections.Generic.List[PSObject]]::new()
    for ($index = 0; $index -lt $rawLines.Count; $index++) {
        $line = $rawLines[$index]
        if ($line -match '^[ \t]*echo[ \t]+(.*?)[ \t]*>[ \t]*"([^"]+)"') {
            $prompt = $matches[1]
            $inputPath = $matches[2]
            $nextIndex = $index + 1
            if ($nextIndex -ge $rawLines.Count) {
                continue
            }

            $nextLine = $rawLines[$nextIndex]
            if ($nextLine -match '^[ \t]*kokoro-tts[ \t]+"[^"]+"[ \t]+"([^"]+)"') {
                $outputPath = $matches[1]
                $entries.Add([PSCustomObject]@{
                    Prompt = $prompt
                    OutputFileName = [System.IO.Path]::GetFileName($outputPath)
                    SampleOutputPath = $outputPath
                    OutputDir = $OutputDir
                })
            }
        }
    }

    if ($entries.Count -eq 0) {
        throw "No prompt/output pairs were found in $sourceFile. Please verify the file format."
    }
}

$kokoroCmd = Get-Command $KokoroTtsExe -ErrorAction SilentlyContinue
if (-not $kokoroCmd) {
    throw "kokoro-tts was not found on PATH. Please install kokoro-tts or pass -KokoroTtsExe with the executable path."
}

if (-not $GenerateAllWords) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

Write-Host "Generating Kokoro audio files"
Write-Host "Using temporary directory: $TempDir"
if ($GenerateAllWords) {
    Write-Host "Using word CSV source root: $WordsRoot"
} else {
    Write-Host "Generating to: $OutputDir"
}
if ($Force) { Write-Host "Force mode enabled: regenerating all files." }
else { Write-Host "Default mode: only missing output files will be generated." }

$completed = 0
$skipped = 0
$failed = 0

foreach ($entry in $entries) {
    $targetDir = $entry.OutputDir
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $targetPath = Join-Path $targetDir $entry.OutputFileName
    if ((-not $Force) -and (Test-Path $targetPath)) {
        Write-Host "Skipping existing file: $($entry.OutputFileName) in $targetDir"
        $skipped++
        continue
    }

    $temporaryInput = Join-Path $TempDir ([System.IO.Path]::GetRandomFileName() + '.txt')
    [System.IO.File]::WriteAllText($temporaryInput, $entry.Prompt)

    $arguments = @(
        $temporaryInput,
        $targetPath,
        '--voice', $Voice,
        '--speed', $Speed.ToString(),
        '--lang', $Lang
    )

    if ((Test-Path $ModelPath) -and $ModelPath.Trim()) {
        $arguments += @('--model', $ModelPath)
    }

    if ((Test-Path $VoicesPath) -and $VoicesPath.Trim()) {
        $arguments += @('--voices', $VoicesPath)
    }

    Write-Host "Generating: $($entry.OutputFileName) in $targetDir" -NoNewline
    try {
        $process = Start-Process -FilePath $kokoroCmd.Source -ArgumentList $arguments -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            throw "kokoro-tts exited with code $($process.ExitCode)"
        }
        Write-Host " ... done"
        $completed++
    } catch {
        Write-Host " ... failed: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    } finally {
        if (Test-Path $temporaryInput) { Remove-Item -Path $temporaryInput -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host "Finished. Generated: $completed. Skipped: $skipped. Failed: $failed."
if ($failed -gt 0) { exit 1 }
