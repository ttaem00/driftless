<#
.SYNOPSIS
  Validate the repo-local compiled context wiki build.

.DESCRIPTION
  Builds a fresh test wiki under .runtime/test-context-wiki, validates generated
  JSON, source traceability, graph connectivity, and search behavior.
#>
param(
  [string]$Root = '.',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($Root -eq '.') { $Root = (Resolve-Path (Join-Path $scriptDir '..')).Path }

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

$repoRoot = (Resolve-Path -LiteralPath $Root).Path
$out = Join-Path $repoRoot '.runtime/test-context-wiki'
$builder = Join-Path $scriptDir 'Build-RepoContextWiki.ps1'
$search = Join-Path $scriptDir 'Search-RepoContextWiki.ps1'
$results = [System.Collections.Generic.List[object]]::new()

$buildJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder -Root $repoRoot -OutputPath $out -Clean -Json
$build = $buildJson | ConvertFrom-Json
if ($build.status -eq 'PASS' -and $build.sources -ge 8) {
  Add-Result $results 'fresh build' 'PASS' "sources=$($build.sources); edges=$($build.graphEdges)"
} else {
  Add-Result $results 'fresh build' 'FAIL' ($buildJson -join ' ') 'Build must produce at least the core source set.'
}

$manifestPath = Join-Path $out 'index/source-manifest.json'
$searchIndexPath = Join-Path $out 'index/search-index.json'
$graphPath = Join-Path $out 'index/graph.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$searchIndex = Get-Content -LiteralPath $searchIndexPath -Raw -Encoding UTF8 | ConvertFrom-Json
$searchRows = @($searchIndex.rows)
$graph = Get-Content -LiteralPath $graphPath -Raw -Encoding UTF8 | ConvertFrom-Json

$missingSource = @($manifest.sources | Where-Object { -not $_.source -or -not $_.sha256 -or -not $_.wikiPath })
if ($missingSource.Count -eq 0) {
  Add-Result $results 'source traceability' 'PASS' "sources=$(@($manifest.sources).Count)"
} else {
  Add-Result $results 'source traceability' 'FAIL' "missing=$($missingSource.Count)" 'Every source needs source, sha256, and wikiPath.'
}

if (@($graph.nodes).Count -ge @($manifest.sources).Count -and @($graph.edges).Count -gt 0 -and @($graph.communities).Count -gt 0) {
  Add-Result $results 'graph index' 'PASS' "nodes=$(@($graph.nodes).Count); edges=$(@($graph.edges).Count); communities=$(@($graph.communities).Count)"
} else {
  Add-Result $results 'graph index' 'FAIL' "nodes=$(@($graph.nodes).Count); edges=$(@($graph.edges).Count)" 'Graph needs nodes, edges, and community summaries.'
}

$searchJson = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $search -Root $repoRoot -WikiPath $out -Query 'Codex profile' -Json
$searchResult = $searchJson | ConvertFrom-Json
if ($searchResult.status -eq 'MATCH' -and @($searchResult.results).Count -gt 0) {
  Add-Result $results 'compiled search' 'PASS' "results=$(@($searchResult.results).Count)"
} else {
  Add-Result $results 'compiled search' 'FAIL' ($searchJson -join ' ') 'Search should find Codex profile context.'
}

$deadLinks = New-Object System.Collections.ArrayList
$pageFiles = @(Get-ChildItem -LiteralPath (Join-Path $out 'wiki') -Recurse -File -Filter *.md)
$pageText = @{}
foreach ($f in $pageFiles) {
  $pageText[$f.FullName] = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
}
$pageTitles = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $pageFiles) {
  $txt = $pageText[$f.FullName]
  foreach ($m in [regex]::Matches($txt, '(?m)^#\s+(.+)$')) { [void]$pageTitles.Add($m.Groups[1].Value.Trim()) }
}
foreach ($kv in $pageText.GetEnumerator()) {
  foreach ($m in [regex]::Matches($kv.Value, '\[\[([^\]|]+)(?:\|[^\]]+)?\]\]')) {
    $target = $m.Groups[1].Value.Trim()
    if (-not $pageTitles.Contains($target) -and $target -notin @('Purpose', 'Schema', 'Log')) {
      [void]$deadLinks.Add("$($kv.Key): $target")
    }
  }
}
if ($deadLinks.Count -eq 0) {
  Add-Result $results 'wikilinks' 'PASS' "pages=$($pageFiles.Count)"
} else {
  Add-Result $results 'wikilinks' 'FAIL' (($deadLinks | Select-Object -First 5) -join '; ') 'Fix generated wikilink targets.'
}

$failures = @($results | Where-Object { $_.status -eq 'FAIL' })
$summary = [pscustomobject]@{
  status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
  outputPath = $out
  results = @($results)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} else {
  foreach ($r in $results) {
    Write-Output ("{0}: {1} ({2})" -f $r.status, $r.check, $r.evidence)
  }
  Write-Output ("CONTEXT_WIKI_TEST_{0}" -f $summary.status)
}

if ($failures.Count -gt 0) { exit 1 }
