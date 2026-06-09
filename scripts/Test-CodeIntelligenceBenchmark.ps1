#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Public-safe code-intelligence benchmark for Driftless.

.DESCRIPTION
  Measures whether the repo-local compiled context wiki helps find relevant
  Driftless source files with less context than a broad baseline scan. This is
  a bounded benchmark gate, not a dependency install.

  It does not install MCP servers, mutate agent config, call an LLM, read
  credentials, or touch host-global profiles.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$Rows,
    [string]$Check,
    [string]$Status,
    [string]$Evidence,
    [string]$NextAction = ''
  )
  $Rows.Add([pscustomobject]@{
    check = $Check
    status = $Status
    evidence = $Evidence
    next_action = $NextAction
  }) | Out-Null
}

function Resolve-RepoRoot {
  param([string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  try {
    $top = (& git -C $resolved rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and $top) { return (Resolve-Path -LiteralPath $top.Trim()).Path }
  } catch { }
  return $resolved
}

function Get-TrackedFiles {
  param([string]$RepoRoot)
  $raw = & git -C $RepoRoot -c core.quotepath=false ls-files 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $raw) { throw 'git ls-files failed' }
  return @($raw | ForEach-Object { $_.Replace('\', '/') } | Where-Object { $_ })
}

function Get-Text {
  param([string]$Path)
  try { return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) } catch { return '' }
}

function Get-Tokens {
  param([string]$Text)
  return @([regex]::Matches($Text.ToLowerInvariant(), '[a-z0-9][a-z0-9_-]{2,}') | ForEach-Object { $_.Value } | Select-Object -Unique)
}

function Estimate-Tokens {
  param([string]$Text)
  if (-not $Text) { return 0 }
  return [int][Math]::Ceiling($Text.Length / 4.0)
}

function Get-OverlapStats {
  param([string[]]$Expected, [string[]]$Actual)
  $expectedSet = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($e in $Expected) { [void]$expectedSet.Add($e.Replace('\', '/')) }
  $actualSet = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($a in $Actual) { [void]$actualSet.Add($a.Replace('\', '/')) }
  $hits = @($actualSet | Where-Object { $expectedSet.Contains($_) })
  $recall = if ($expectedSet.Count -eq 0) { 0.0 } else { [Math]::Round(($hits.Count / $expectedSet.Count), 3) }
  $precision = if ($actualSet.Count -eq 0) { 0.0 } else { [Math]::Round(($hits.Count / $actualSet.Count), 3) }
  return [pscustomobject]@{ hits = @($hits | Sort-Object); recall = $recall; precision = $precision }
}

function Get-BaselineCandidates {
  param([string]$RepoRoot, [string[]]$Tracked, [string[]]$Terms)
  $scores = @{}
  foreach ($rel in $Tracked) {
    $ext = [System.IO.Path]::GetExtension($rel).ToLowerInvariant()
    if ($ext -notin @('.md', '.ps1', '.json')) { continue }
    $text = Get-Text -Path (Join-Path $RepoRoot $rel)
    $hay = ($rel + "`n" + $text).ToLowerInvariant()
    $score = 0
    foreach ($term in $Terms) {
      $t = $term.ToLowerInvariant()
      if ($rel.ToLowerInvariant().Contains($t)) { $score += 8 }
      if ($hay.Contains($t)) { $score += 1 }
    }
    if ($score -gt 0) { $scores[$rel] = $score }
  }
  return @($scores.GetEnumerator() |
    Sort-Object @{ Expression = 'Value'; Descending = $true }, @{ Expression = 'Key'; Ascending = $true } |
    Select-Object -First 10 |
    ForEach-Object { [string]$_.Key })
}

function Get-WikiCandidates {
  param([object[]]$Rows, [string]$Query)
  $tokens = Get-Tokens -Text $Query
  $scores = @{}
  $snippets = [System.Collections.Generic.List[string]]::new()
  foreach ($row in $Rows) {
    $hay = (($row.title, $row.source, $row.category, @($row.keywords), @($row.headings)) -join ' ').ToLowerInvariant()
    $score = 0
    foreach ($tok in $tokens) {
      if ($hay.Contains($tok)) { $score += 1 }
      if ($row.source -and ([string]$row.source).ToLowerInvariant().Contains($tok)) { $score += 6 }
    }
    if ($score -gt 0 -and $row.source) {
      $source = [string]$row.source
      if (-not $scores.ContainsKey($source)) { $scores[$source] = 0 }
      $scores[$source] += $score
      $snippets.Add((($row.title, $row.source, $row.category, (@($row.keywords) -join ',')) -join ' | ')) | Out-Null
    }
  }
  $ranked = @($scores.GetEnumerator() |
    Sort-Object @{ Expression = 'Value'; Descending = $true }, @{ Expression = 'Key'; Ascending = $true } |
    Select-Object -First 10 |
    ForEach-Object { [string]$_.Key })
  return [pscustomobject]@{ candidates = $ranked; contextText = (($snippets | Select-Object -First 16) -join "`n") }
}

$repoRoot = Resolve-RepoRoot -Path $Root
$out = Join-Path $repoRoot '.runtime/test-code-intelligence-benchmark/context-wiki'
$builder = Join-Path $repoRoot 'scripts/Build-RepoContextWiki.ps1'
$wikiGate = Join-Path $repoRoot 'scripts/Test-RepoContextWiki.ps1'
$tracked = Get-TrackedFiles -RepoRoot $repoRoot

$buildJson = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $builder -Root $repoRoot -OutputPath $out -Clean -Json
$build = $buildJson | ConvertFrom-Json
$rows = @((Get-Content -LiteralPath (Join-Path $out 'index/search-index.json') -Raw -Encoding UTF8 | ConvertFrom-Json).rows)

$tasks = @(
  [pscustomobject]@{
    id = 'external-adoption-safety'
    query = 'adopt external tools safely adoption gate closeout'
    terms = @('adopt-external', 'external adoption', 'closeout', 'safety gate')
    expected = @('docs/en/adopt-external-tools-safely.md', 'profiles/shared/skills/adopt-external-tool/SKILL.md')
  },
  [pscustomobject]@{
    id = 'compiled-context-wiki'
    query = 'compiled context wiki source traceability search graph'
    terms = @('compiled context wiki', 'source traceability', 'search graph')
    expected = @('docs/en/compiled-context-wiki.md', 'scripts/Build-RepoContextWiki.ps1')
  },
  [pscustomobject]@{
    id = 'context-engineering-discipline'
    query = 'context budget compressed references repo map freshness action evidence ledger'
    terms = @('context budget', 'compressed reference', 'repo map freshness', 'Action/Evidence Ledger')
    expected = @('profiles/shared/contract/SHARED_DESIGN_CONTRACT.md', 'profiles/shared/skills/handoff-guard/SKILL.md', 'profiles/shared/skills/work-ledger/SKILL.md')
  },
  [pscustomobject]@{
    id = 'finish-to-done-workflow'
    query = 'finish to done mission control root goal validation blocker'
    terms = @('finish-to-done', 'mission-control', 'root-goal', 'blocker')
    expected = @('profiles/shared/skills/finish-to-done/SKILL.md', 'profiles/shared/skills/mission-control/SKILL.md', 'profiles/shared/skills/root-goal-check/SKILL.md')
  }
)

$taskResults = foreach ($task in $tasks) {
  $baseline = Get-BaselineCandidates -RepoRoot $repoRoot -Tracked $tracked -Terms $task.terms
  $wiki = Get-WikiCandidates -Rows $rows -Query $task.query
  $baselineText = ''
  foreach ($rel in $baseline) { $baselineText += (Get-Text -Path (Join-Path $repoRoot $rel)) }
  $wikiText = $wiki.contextText
  $baselineStats = Get-OverlapStats -Expected $task.expected -Actual $baseline
  $wikiStats = Get-OverlapStats -Expected $task.expected -Actual $wiki.candidates
  $baselineTokens = Estimate-Tokens -Text $baselineText
  $wikiTokens = Estimate-Tokens -Text $wikiText
  $reduction = if ($baselineTokens -le 0) { 0.0 } else { [Math]::Round((1.0 - ($wikiTokens / [double]$baselineTokens)), 3) }
  [pscustomobject]@{
    id = $task.id
    baseline = [pscustomobject]@{ candidates = $baseline; estimatedTokens = $baselineTokens; recall = $baselineStats.recall; precision = $baselineStats.precision; hits = $baselineStats.hits }
    wiki = [pscustomobject]@{ candidates = $wiki.candidates; estimatedTokens = $wikiTokens; recall = $wikiStats.recall; precision = $wikiStats.precision; hits = $wikiStats.hits }
    tokenReduction = $reduction
  }
}

$wikiGateOutput = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $wikiGate -Root $repoRoot 2>&1
$wikiGateExit = $LASTEXITCODE
$avgRecall = [Math]::Round((@($taskResults | ForEach-Object { $_.wiki.recall }) | Measure-Object -Average).Average, 3)
$avgReduction = [Math]::Round((@($taskResults | ForEach-Object { $_.tokenReduction }) | Measure-Object -Average).Average, 3)

$results = [System.Collections.Generic.List[object]]::new()
if ($build.status -eq 'PASS' -and $build.sources -ge 12) {
  Add-Result $results 'wiki build' 'PASS' "sources=$($build.sources); edges=$($build.graphEdges)"
} else {
  Add-Result $results 'wiki build' 'FAIL' ($buildJson -join ' ') 'Compiled wiki must build enough public source context.'
}
if ($avgRecall -ge 0.5) {
  Add-Result $results 'wiki usefulness floor' 'PASS' "averageRecall=$avgRecall"
} else {
  Add-Result $results 'wiki usefulness floor' 'FAIL' "averageRecall=$avgRecall" 'Improve source selection or benchmark tasks before dependency adoption.'
}
if ($avgReduction -gt 0.0) {
  Add-Result $results 'token estimate direction' 'PASS' "averageTokenReduction=$avgReduction"
} else {
  Add-Result $results 'token estimate direction' 'FAIL' "averageTokenReduction=$avgReduction" 'The wiki result path should be smaller than broad baseline reads.'
}
if ($wikiGateExit -eq 0) {
  Add-Result $results 'stale/source traceability gate' 'PASS' 'Test-RepoContextWiki.ps1 passed'
} else {
  Add-Result $results 'stale/source traceability gate' 'FAIL' (($wikiGateOutput | ForEach-Object { [string]$_ }) -join ' ') 'Restore source manifest, graph, search, and wikilink validation.'
}

$failures = @($results | Where-Object { $_.status -eq 'FAIL' })
$overall = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$report = [pscustomobject]@{
  gate = 'driftless-code-intelligence-benchmark'
  status = $overall
  root = $repoRoot
  candidateDecision = if ($overall -eq 'PASS') { 'ADOPT_BENCHMARK_AND_KEEP_LOCAL_WIKI' } else { 'REJECT_DEPENDENCY_UNTIL_LOCAL_BENCHMARK_PASSES' }
  aggregate = [pscustomobject]@{ tasks = @($tasks).Count; averageWikiRecall = $avgRecall; averageTokenReduction = $avgReduction }
  results = @($results)
  tasks = @($taskResults)
}

if ($Json) {
  $report | ConvertTo-Json -Depth 10
} else {
  Write-Output '== Driftless code-intelligence benchmark =='
  foreach ($r in $results) {
    Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
  }
  Write-Output ("RESULT: {0} (averageWikiRecall={1} averageTokenReduction={2})" -f $overall, $avgRecall, $avgReduction)
}

if ($overall -ne 'PASS') { exit 1 }
exit 0
