<#
.SYNOPSIS
  Driftless hot-context discipline gate.

.DESCRIPTION
  Keeps "small AGENTS.md / CLAUDE.md" honest. A repo must not move always-loaded
  instructions into another large document, or make a skill fire for every task,
  just to keep the hot-rules file short on paper.

  This is a structural gate. It checks:

    BLOCKING - Hot-rules files named AGENTS.md or CLAUDE.md stay under a small
               byte budget.
    BLOCKING - Hot-rules files do not say to always read/load/include another
               docs/, profiles/, or skills/ file.
    BLOCKING - SKILL.md frontmatter descriptions do not claim the skill should
               run for every/all/any task, request, session, turn, or work item.

  Conditional references are allowed. "For UI work, read docs/design/DESIGN.md"
  is on-demand. "Always read docs/design/DESIGN.md" is hot-context growth by
  indirection and FAILs.

  Read-only. No network, no secrets, no host-global access. ASCII-only so the
  gate parses under Windows PowerShell 5.1.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [int]$MaxHotBytes = 6000,
  [switch]$SelfTest,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$Command = 'Test-HotContextDiscipline.ps1'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$List,
    [string]$Check,
    [string]$Status,
    [bool]$Blocking,
    [string]$Evidence,
    [string]$NextAction = ''
  )
  $List.Add([pscustomobject]@{
      check = $Check
      status = $Status
      blocking = $Blocking
      evidence = $Evidence
      next_action = $NextAction
    }) | Out-Null
}

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Get-RelativePath {
  param([string]$BasePath, [string]$FullPath)
  $base = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd('\', '/')
  $full = (Resolve-Path -LiteralPath $FullPath).Path
  if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $full.Substring($base.Length).TrimStart('\', '/')
  }
  return $full
}

function Get-TrackedAndUntrackedFiles {
  param([string]$RepoRoot)
  $rels = @()
  $gitOk = $false
  try {
    $rels = @(git -c core.quotepath=false -C $RepoRoot ls-files --cached --others --exclude-standard 2>$null)
    if ($LASTEXITCODE -eq 0) { $gitOk = $true }
  } catch {
    $gitOk = $false
  }
  if ($gitOk) {
    return @($rels | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  }

  $files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Force |
    Where-Object { $_.FullName -notmatch '\\\.git\\|\\\.runtime\\' }
  return @($files | ForEach-Object { Get-RelativePath -BasePath $RepoRoot -FullPath $_.FullName })
}

function Get-FrontmatterDescription {
  param([string[]]$Lines)
  if (@($Lines).Count -eq 0) { return '' }
  $i = 0
  while ($i -lt $Lines.Count -and [string]::IsNullOrWhiteSpace($Lines[$i])) { $i++ }
  if ($i -ge $Lines.Count -or $Lines[$i].Trim() -ne '---') { return '' }
  $i++
  $descLines = [System.Collections.Generic.List[string]]::new()
  while ($i -lt $Lines.Count) {
    $line = $Lines[$i]
    if ($line.Trim() -eq '---') { break }
    if ($line -match '^description:\s*(.*)$') {
      $rest = $Matches[1].Trim()
      if ($rest -eq '>' -or $rest -eq '|' -or $rest -eq '>-' -or $rest -eq '|-') {
        $i++
        while ($i -lt $Lines.Count) {
          $bl = $Lines[$i]
          if ($bl.Trim() -eq '---') { $i--; break }
          if ($bl -match '^[A-Za-z0-9_-]+:\s') { $i--; break }
          if (-not [string]::IsNullOrWhiteSpace($bl)) { $descLines.Add($bl.Trim()) | Out-Null }
          $i++
        }
      } elseif ($rest.Length -gt 0) {
        $descLines.Add($rest.Trim('"').Trim("'")) | Out-Null
      }
    }
    $i++
  }
  if ($descLines.Count -eq 0) { return '' }
  return ($descLines -join ' ').Trim()
}

function Get-HotFileIssues {
  param([string]$RelPath, [string]$Text, [int]$MaxBytes)
  $issues = [System.Collections.Generic.List[string]]::new()
  $bytes = [System.Text.Encoding]::UTF8.GetByteCount($Text)
  if ($bytes -gt $MaxBytes) {
    $issues.Add(("{0}: hot-rules file is {1} bytes, above budget {2}" -f $RelPath, $bytes, $MaxBytes)) | Out-Null
  }

  $autoloadPatterns = @(
    '(?i)\b(always|every session|each session|on startup|at startup|before any task|for every task|for all tasks)\b.{0,120}\b(read|load|include|open|inject|paste)\b.{0,160}\b(docs[\\/]|profiles[\\/]|skills[\\/]|SKILL\.md|README\.md|DESIGN\.md|CONTRACT\.md)',
    '(?i)\b(read|load|include|open|inject|paste)\b.{0,160}\b(docs[\\/]|profiles[\\/]|skills[\\/]|SKILL\.md|README\.md|DESIGN\.md|CONTRACT\.md)\b.{0,120}\b(always|every session|each session|on startup|at startup|before any task|for every task|for all tasks)\b'
  )
  foreach ($pattern in $autoloadPatterns) {
    if ($Text -match $pattern) {
      $snippet = $Matches[0]
      if ($snippet.Length -gt 160) { $snippet = $snippet.Substring(0, 160) + '...' }
      $issues.Add(("{0}: hot file appears to auto-load another instruction file: {1}" -f $RelPath, $snippet.Trim())) | Out-Null
    }
  }
  return @($issues)
}

function Get-SkillTriggerIssues {
  param([string]$RelPath, [string]$Description)
  $issues = [System.Collections.Generic.List[string]]::new()
  if ([string]::IsNullOrWhiteSpace($Description)) { return @($issues) }
  $broadPatterns = @(
    '(?i)\b(use|trigger|run|invoke|apply)\b.{0,80}\b(every|all|any)\s+(task|request|session|turn|work item|work)\b',
    '(?i)\b(always|by default)\b.{0,80}\b(use|trigger|run|invoke|apply)\b.{0,80}\b(skill\b|this skill\b)',
    '(?i)\b(use|trigger|run|invoke|apply)\b.{0,80}\b(skill\b|this skill\b).{0,80}\b(always|by default)\b'
  )
  foreach ($pattern in $broadPatterns) {
    if ($Description -match $pattern) {
      $snippet = $Matches[0]
      if ($snippet.Length -gt 160) { $snippet = $snippet.Substring(0, 160) + '...' }
      $issues.Add(("{0}: skill description has an always-on/broad trigger: {1}" -f $RelPath, $snippet.Trim())) | Out-Null
    }
  }
  return @($issues)
}

function Invoke-SelfTest {
  $failures = [System.Collections.Generic.List[string]]::new()

  $smallHot = "For UI work, read docs/design/DESIGN.md."
  if (@(Get-HotFileIssues -RelPath 'AGENTS.md' -Text $smallHot -MaxBytes 6000).Count -ne 0) {
    $failures.Add('conditional hot reference falsely failed') | Out-Null
  }

  $badHot = "Always read docs/design/DESIGN.md before any task."
  if (@(Get-HotFileIssues -RelPath 'AGENTS.md' -Text $badHot -MaxBytes 6000).Count -lt 1) {
    $failures.Add('always-read hot indirection was not detected') | Out-Null
  }

  $bigHot = ('x' * 6001)
  if (@(Get-HotFileIssues -RelPath 'AGENTS.md' -Text $bigHot -MaxBytes 6000).Count -lt 1) {
    $failures.Add('oversized hot file was not detected') | Out-Null
  }

  $narrowSkill = 'Use when debugging build failures. Trigger: "fix build".'
  if (@(Get-SkillTriggerIssues -RelPath 'skills/build/SKILL.md' -Description $narrowSkill).Count -ne 0) {
    $failures.Add('narrow skill trigger falsely failed') | Out-Null
  }

  $badSkill = 'Use this skill for every task and every request.'
  if (@(Get-SkillTriggerIssues -RelPath 'skills/all/SKILL.md' -Description $badSkill).Count -lt 1) {
    $failures.Add('broad skill trigger was not detected') | Out-Null
  }

  return [pscustomobject]@{
    passed = (@($failures).Count -eq 0)
    failures = @($failures)
  }
}

if ($SelfTest) {
  $st = Invoke-SelfTest
  if ($st.passed) {
    Write-Output 'RESULT: PASS (hot-context discipline self-test passed)'
    if ($Json) { [pscustomobject]@{ gate = 'hot-context-discipline'; mode = 'self-test'; overall = 'PASS' } | ConvertTo-Json -Depth 4 }
    exit 0
  }
  Write-Output 'RESULT: FAIL (hot-context discipline self-test failed)'
  foreach ($f in $st.failures) { Write-Output ("- {0}" -f $f) }
  if ($Json) { [pscustomobject]@{ gate = 'hot-context-discipline'; mode = 'self-test'; overall = 'FAIL'; failures = @($st.failures) } | ConvertTo-Json -Depth 4 }
  exit 1
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()
$files = Get-TrackedAndUntrackedFiles -RepoRoot $resolvedRoot

$hotIssues = [System.Collections.Generic.List[string]]::new()
$skillIssues = [System.Collections.Generic.List[string]]::new()

foreach ($rel in $files) {
  $normalized = $rel -replace '/', '\'
  $leaf = Split-Path -Leaf $normalized
  $full = Join-Path $resolvedRoot $normalized
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }

  if ($leaf -eq 'AGENTS.md' -or $leaf -eq 'CLAUDE.md') {
    $text = Read-Utf8 $full
    foreach ($issue in (Get-HotFileIssues -RelPath $normalized -Text $text -MaxBytes $MaxHotBytes)) {
      $hotIssues.Add($issue) | Out-Null
    }
  }

  if ($leaf -eq 'SKILL.md') {
    $lines = [System.IO.File]::ReadAllLines($full, [System.Text.Encoding]::UTF8)
    $desc = Get-FrontmatterDescription -Lines $lines
    foreach ($issue in (Get-SkillTriggerIssues -RelPath $normalized -Description $desc)) {
      $skillIssues.Add($issue) | Out-Null
    }
  }
}

$hotStatus = if ($hotIssues.Count -eq 0) { 'PASS' } else { 'FAIL' }
$hotEvidence = "hot_files=$(@($files | Where-Object { (Split-Path -Leaf ($_ -replace '/', '\')) -in @('AGENTS.md', 'CLAUDE.md') }).Count); issues=$($hotIssues.Count); max_hot_bytes=$MaxHotBytes"
if ($hotIssues.Count -gt 0) { $hotEvidence += '; ' + (@($hotIssues) -join ' | ') }
Add-Result $results 'Hot-rules files stay small and do not auto-load long docs' $hotStatus $true $hotEvidence 'Move long procedures to on-demand skills/docs, and keep hot files to short always-needed rules.'

$skillStatus = if ($skillIssues.Count -eq 0) { 'PASS' } else { 'FAIL' }
$skillEvidence = "skill_files=$(@($files | Where-Object { (Split-Path -Leaf ($_ -replace '/', '\')) -eq 'SKILL.md' }).Count); issues=$($skillIssues.Count)"
if ($skillIssues.Count -gt 0) { $skillEvidence += '; ' + (@($skillIssues) -join ' | ') }
Add-Result $results 'Skills do not declare every-task triggers' $skillStatus $true $skillEvidence 'Narrow the skill trigger to a task class, or promote a short always-needed rule to AGENTS.md/CLAUDE.md.'

$blockingFailures = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
$overall = if ($blockingFailures.Count -gt 0) { 'FAIL' } else { 'PASS' }

Write-Output '== Driftless hot-context discipline gate =='
foreach ($r in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
}
$pass = @($results | Where-Object { $_.status -eq 'PASS' }).Count
$fail = @($results | Where-Object { $_.status -eq 'FAIL' }).Count
Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $overall, $pass, $fail)

if ($Json) {
  [pscustomobject]@{
    command = $Command
    root = $resolvedRoot
    overall = $overall
    pass = $pass
    fail = $fail
    results = @($results)
  } | ConvertTo-Json -Depth 5
}

if ($overall -eq 'FAIL') { exit 1 } else { exit 0 }
