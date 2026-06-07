<#
.SYNOPSIS
  Build a repo-local compiled context wiki from trusted source files.

.DESCRIPTION
  Clean-room implementation of the useful compiled wiki pattern:
  source pointers -> compiled markdown wiki -> schema/search/graph artifacts.

  This script does not call an LLM, does not use paid APIs, does not copy
  third-party GPL code, and does not read host-global profiles. It only reads
  git-tracked files under the selected repository root and writes the generated
  wiki under a repo-local output path, defaulting to .runtime/context-wiki.

  The generated wiki is Obsidian-friendly markdown with [[wikilinks]],
  source-trace frontmatter, a search index, and a lightweight knowledge graph.
#>
param(
  [string]$Root = '.',
  [string]$OutputPath,
  [string[]]$SourcePath = @(),
  [switch]$Clean,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($Root -eq '.') { $Root = (Resolve-Path (Join-Path $scriptDir '..')).Path }

function Resolve-RepoRoot {
  param([string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  try {
    $top = (& git -C $resolved rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and $top) {
      return (Resolve-Path -LiteralPath $top.Trim()).Path
    }
  } catch { }
  return $resolved
}

function Test-UnderRoot {
  param([string]$Path, [string]$RootPath)
  $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
  $rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
  return ($full -eq $rootFull -or $full.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))
}

function Get-RelativePath {
  param([string]$BasePath, [string]$TargetPath)
  $baseUri = [System.Uri]::new(([System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar))
  $targetUri = [System.Uri]::new([System.IO.Path]::GetFullPath($TargetPath))
  return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function ConvertTo-Slug {
  param([string]$Text)
  $lower = $Text.ToLowerInvariant()
  $slug = [regex]::Replace($lower, '[^a-z0-9]+', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($slug)) {
    $slug = 'page-' + ([System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').Substring(0, 10).ToLowerInvariant())
  }
  return $slug
}

function Get-PageTitle {
  param([string]$RelativePath, [string[]]$Lines)
  foreach ($line in $Lines) {
    if ($line -match '^\s*#\s+(.+?)\s*$') { return $Matches[1].Trim() }
  }
  return ($RelativePath -replace '\\', '/')
}

function Get-Category {
  param([string]$RelativePath)
  $p = $RelativePath.Replace('\', '/')
  if ($p -match '^docs/codex/') { return 'Codex Learning' }
  if ($p -match '^docs/en/') { return 'English Docs' }
  if ($p -match '^docs/ko/') { return 'Korean Docs' }
  if ($p -match '^docs/') { return 'Project Docs' }
  if ($p -match '^profiles/codex/') { return 'Codex Profile' }
  if ($p -match '^profiles/claude/') { return 'Claude Profile' }
  if ($p -match '^profiles/shared/contract/') { return 'Shared Contract' }
  if ($p -match '^profiles/shared/schemas/') { return 'Shared Schemas' }
  if ($p -match '^profiles/shared/skills/') { return 'Shared Skills' }
  if ($p -match '^scripts/') { return 'Runtime Scripts' }
  if ($p -eq 'AGENTS.md' -or $p -eq 'README.md' -or $p -eq 'README.ko.md') { return 'Hot Entry Points' }
  return 'Repository Context'
}

function Get-TokenList {
  param([string]$Text)
  $stop = @{
    'the'=$true; 'and'=$true; 'for'=$true; 'with'=$true; 'that'=$true; 'this'=$true;
    'from'=$true; 'are'=$true; 'was'=$true; 'were'=$true; 'have'=$true; 'has'=$true;
    'not'=$true; 'you'=$true; 'your'=$true; 'into'=$true; 'when'=$true; 'then'=$true
  }
  $tokens = [regex]::Matches($Text.ToLowerInvariant(), '[a-z0-9][a-z0-9_-]{2,}') |
    ForEach-Object { $_.Value } |
    Where-Object { -not $stop.ContainsKey($_) }
  return @($tokens | Group-Object | Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Ascending = $true } | Select-Object -First 18 | ForEach-Object { $_.Name })
}

function Get-Headings {
  param([string[]]$Lines)
  return @($Lines | Where-Object { $_ -match '^\s{0,3}#{1,4}\s+\S' } | Select-Object -First 16 | ForEach-Object { ($_ -replace '^\s{0,3}#{1,4}\s+', '').Trim() })
}

function Get-SourceFiles {
  param([string]$RepoRoot, [string[]]$ExplicitSources)
  if ($ExplicitSources.Count -gt 0) {
    $files = foreach ($s in $ExplicitSources) {
      $candidate = if ([System.IO.Path]::IsPathRooted($s)) { $s } else { Join-Path $RepoRoot $s }
      if (Test-Path -LiteralPath $candidate -PathType Leaf) { (Resolve-Path -LiteralPath $candidate).Path }
    }
    return @($files | Sort-Object -Unique)
  }

  $tracked = @(& git -C $RepoRoot ls-files 2>$null)
  $allowExact = @(
    'AGENTS.md',
    'README.md',
    'README.ko.md',
    'CONTRIBUTING.md',
    'SECURITY.md',
    'MAINTAINERS.md',
    'CHANGELOG.md',
    'docs/README.md',
    'docs/en/quickstart.md',
    'docs/en/what-is-driftless.md',
    'docs/en/guardrails.md',
    'docs/en/compiled-context-wiki.md',
    'docs/en/how-driftless-learns.md',
    'docs/en/single-source-mirror.md',
    'docs/en/lesson-promotion-ladder.md',
    'docs/en/apply-to-your-agent.md',
    'docs/en/adopt-external-tools-safely.md',
    'docs/en/codex-and-claude.md',
    'docs/codex/LEARNING.md',
    'profiles/shared/README.md',
    'profiles/shared/contract/SHARED_DESIGN_CONTRACT.md',
    'profiles/codex/README.md',
    'profiles/codex/prompts/infinite-goal.md',
    'profiles/codex/skills/goal-mode/SKILL.md',
    'profiles/claude/README.md',
    'profiles/claude/prompts/infinite-workflow.md',
    'profiles/claude/skills/ultracode-orchestration/SKILL.md',
    'profiles/shared/skills/adopt-external-tool/SKILL.md',
    'profiles/shared/skills/finish-to-done/SKILL.md',
    'profiles/shared/skills/handoff-guard/SKILL.md',
    'profiles/shared/skills/work-ledger/SKILL.md',
    'profiles/shared/skills/root-goal-check/SKILL.md',
    'profiles/shared/skills/mission-control/SKILL.md',
    'profiles/shared/skills/learning-loop/SKILL.md',
    'profiles/shared/skills/parallel-ticket-planner/SKILL.md'
  )
  $allowPrefixes = @(
    'docs/ko/',
    'profiles/shared/schemas/'
  )
  $selected = foreach ($rel in $tracked) {
    $norm = $rel.Replace('\', '/')
    if ($allowExact -contains $norm) { $norm; continue }
    foreach ($prefix in $allowPrefixes) {
      if ($norm.StartsWith($prefix) -and ($norm.EndsWith('.md') -or $norm.EndsWith('.json'))) {
        $norm
        break
      }
    }
  }
  return @($selected | Sort-Object -Unique | ForEach-Object { Join-Path $RepoRoot $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
}

function Write-Utf8NoBom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Get-Sha256Hex {
  param([string]$Path)
  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
      return ([System.BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant())
    } finally {
      $sha.Dispose()
    }
  } finally {
    $stream.Dispose()
  }
}

$repoRoot = Resolve-RepoRoot -Path $Root
if (-not $OutputPath) { $OutputPath = Join-Path $repoRoot '.runtime/context-wiki' }
$outputFull = [System.IO.Path]::GetFullPath($OutputPath)
if (-not (Test-UnderRoot -Path $outputFull -RootPath $repoRoot)) {
  throw "OutputPath must stay under repo root: $outputFull"
}
if ($Clean -and (Test-Path -LiteralPath $outputFull)) {
  Remove-Item -LiteralPath $outputFull -Recurse -Force
}

$wikiDir = Join-Path $outputFull 'wiki'
$pagesDir = Join-Path $wikiDir 'pages'
$schemaDir = Join-Path $outputFull 'schema'
$indexDir = Join-Path $outputFull 'index'
foreach ($dir in @($wikiDir, $pagesDir, $schemaDir, $indexDir)) {
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

$sourceFiles = Get-SourceFiles -RepoRoot $repoRoot -ExplicitSources $SourcePath
$pages = New-Object System.Collections.ArrayList
$tokenBySlug = @{}

foreach ($file in $sourceFiles) {
  $full = (Resolve-Path -LiteralPath $file).Path
  if (-not (Test-UnderRoot -Path $full -RootPath $repoRoot)) { continue }
  $rel = Get-RelativePath -BasePath $repoRoot -TargetPath $full
  $relSlash = $rel.Replace('\', '/')
  $text = Get-Content -LiteralPath $full -Raw -Encoding UTF8
  $lines = @($text -split "`r?`n")
  $title = Get-PageTitle -RelativePath $relSlash -Lines $lines
  $slug = ConvertTo-Slug -Text $relSlash
  $category = Get-Category -RelativePath $relSlash
  $categorySlug = ConvertTo-Slug -Text $category
  $hash = Get-Sha256Hex -Path $full
  $tokens = Get-TokenList -Text ($title + "`n" + $relSlash + "`n" + $text)
  $tokenBySlug[$slug] = $tokens
  $headings = Get-Headings -Lines $lines
  $excerptLines = @($lines | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First 10)
  $pagePath = Join-Path $pagesDir ($slug + '.md')

  $frontmatter = @(
    '---',
    ('title: "' + ($title.Replace('"', '\"')) + '"'),
    'type: source',
    ('category: "' + $category + '"'),
    ('source: "' + $relSlash + '"'),
    ('sha256: "' + $hash + '"'),
    'links:',
    ('  - "[[' + $category + ']]"'),
    '---'
  ) -join "`n"

  $body = @()
  $body += "# $title"
  $body += ''
  $body += "- Source: ``$relSlash``"
  $body += "- Category: [[$category]]"
  $body += "- SHA256: ``$hash``"
  if ($tokens.Count -gt 0) {
    $body += "- Keywords: " + (($tokens | ForEach-Object { "``$_``" }) -join ', ')
  }
  $body += ''
  $body += '## Headings'
  if ($headings.Count -gt 0) {
    foreach ($h in $headings) { $body += "- $h" }
  } else {
    $body += '- No markdown headings found.'
  }
  $body += ''
  $body += '## Source Excerpt'
  $body += '```text'
  $body += $excerptLines
  $body += '```'
  Write-Utf8NoBom -Path $pagePath -Content ($frontmatter + "`n" + ($body -join "`n") + "`n")

  [void]$pages.Add([pscustomobject]@{
    slug = $slug
    title = $title
    type = 'source'
    category = $category
    categorySlug = $categorySlug
    source = $relSlash
    wikiPath = (Get-RelativePath -BasePath $outputFull -TargetPath $pagePath).Replace('\', '/')
    sha256 = $hash
    keywords = $tokens
    headings = $headings
  })
}

$categories = @($pages | Group-Object category | Sort-Object Name)
foreach ($group in $categories) {
  $category = [string]$group.Name
  $slug = ConvertTo-Slug -Text $category
  $catPath = Join-Path $pagesDir ($slug + '.md')
  $members = @($group.Group | Sort-Object title)
  $content = @(
    '---',
    ('title: "' + $category + '"'),
    'type: category',
    'source: "generated"',
    '---',
    '',
    "# $category",
    '',
    'Generated category page. It exists to make source clusters navigable without adding hot context.',
    '',
    '## Pages'
  )
  foreach ($p in $members) { $content += "- [[$($p.title)]] - ``$($p.source)``" }
  Write-Utf8NoBom -Path $catPath -Content (($content -join "`n") + "`n")
}

$edges = New-Object System.Collections.ArrayList
foreach ($p in $pages) {
  [void]$edges.Add([pscustomobject]@{
    from = $p.slug
    to = $p.categorySlug
    reason = 'direct_category_link'
    weight = 3.0
  })
}

$pageArray = @($pages)
for ($i = 0; $i -lt $pageArray.Count; $i++) {
  for ($j = $i + 1; $j -lt $pageArray.Count; $j++) {
    $a = $pageArray[$i]
    $b = $pageArray[$j]
    $shared = @($a.keywords | Where-Object { $b.keywords -contains $_ })
    $sameCategory = $a.category -eq $b.category
    $weight = 0.0
    $reasons = @()
    if ($sameCategory) { $weight += 1.0; $reasons += 'type_affinity' }
    if ($shared.Count -gt 0) { $weight += [Math]::Min(4.0, 1.0 + ($shared.Count * 0.5)); $reasons += 'keyword_overlap' }
    if ($weight -ge 2.5) {
      [void]$edges.Add([pscustomobject]@{
        from = $a.slug
        to = $b.slug
        reason = ($reasons -join '+')
        weight = [Math]::Round($weight, 2)
        sharedKeywords = @($shared | Select-Object -First 8)
      })
    }
  }
}

$nodes = @()
$nodes += @($pages | ForEach-Object {
  [pscustomobject]@{
    id = $_.slug
    title = $_.title
    type = 'source'
    category = $_.category
    path = $_.wikiPath
    source = $_.source
  }
})
$nodes += @($categories | ForEach-Object {
  $category = [string]$_.Name
  [pscustomobject]@{
    id = (ConvertTo-Slug -Text $category)
    title = $category
    type = 'category'
    category = $category
    path = 'wiki/pages/' + (ConvertTo-Slug -Text $category) + '.md'
    source = 'generated'
  }
})

$communities = @($categories | ForEach-Object {
  $category = [string]$_.Name
  $members = @($_.Group | ForEach-Object { $_.slug })
  $possible = [Math]::Max(1, ($members.Count * ($members.Count - 1)) / 2)
  $internal = @($edges | Where-Object { $members -contains $_.from -and $members -contains $_.to }).Count
  [pscustomobject]@{
    id = (ConvertTo-Slug -Text $category)
    label = $category
    members = $members
    memberCount = $members.Count
    cohesion = [Math]::Round(($internal / $possible), 3)
  }
})

$graph = [pscustomobject]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  generator = 'Build-RepoContextWiki.ps1'
  licenseBoundary = 'clean-room-no-third-party-code'
  nodes = $nodes
  edges = @($edges)
  communities = $communities
}

$searchRows = @($pages | ForEach-Object {
  [pscustomobject]@{
    title = $_.title
    slug = $_.slug
    source = $_.source
    wikiPath = $_.wikiPath
    category = $_.category
    keywords = $_.keywords
    headings = $_.headings
  }
})

$indexLines = @(
  '# Repo Context Wiki',
  '',
  'Compiled source map for recurring runtime context. Generated files are evidence helpers, not source of truth.',
  '',
  '- [[Purpose]]',
  '- [[Schema]]',
  '- [[Log]]',
  '',
  '## Categories'
)
foreach ($group in $categories) {
  $indexLines += "- [[$($group.Name)]] ($($group.Count) pages)"
}
$indexLines += ''
$indexLines += '## Source Pages'
foreach ($p in ($pages | Sort-Object source)) {
  $indexLines += "- [[$($p.title)]] - ``$($p.source)``"
}

$purpose = @(
  '# Purpose',
  '',
  'This repo-local context wiki reduces repeated cold-start reading by compiling trusted public source files into a small navigable index.',
  '',
  'Human-owned sources remain in the repository. The generated wiki only points back to them and summarizes headings, keywords, and graph relationships.',
  '',
  'Maintainer-only boundaries remain outside automation: credentials, billing, public release, destructive changes, host-global profile promotion, and user-data transfer.'
)

$schema = @(
  '# Schema',
  '',
  '## Layers',
  '- Raw sources: git-tracked repository files listed in `index/source-manifest.json`.',
  '- Wiki: generated markdown pages under `wiki/pages/` with source traceability.',
  '- Index/schema: `index/search-index.json`, `index/graph.json`, this schema page, and `wiki/log.md`.',
  '',
  '## Page Requirements',
  '- Every source page has YAML frontmatter with `title`, `type`, `category`, `source`, and `sha256`.',
  '- Generated category pages use `source: generated`.',
  '- Facts must cite the source path, not the generated page alone.',
  '',
  '## Boundaries',
  '- No paid API, no LLM call, no external desktop app dependency, no host-global profile access.',
  '- External GPL implementations may be studied for product ideas, but code is not copied into this repository.'
)

$log = @(
  '# Log',
  '',
  ("## " + (Get-Date).ToUniversalTime().ToString('o') + " | build"),
  '',
  "- Sources: $($pages.Count)",
  "- Categories: $($categories.Count)",
  "- Edges: $($edges.Count)",
  '- Mode: deterministic clean-room build'
)

Write-Utf8NoBom -Path (Join-Path $wikiDir 'index.md') -Content (($indexLines -join "`n") + "`n")
Write-Utf8NoBom -Path (Join-Path $wikiDir 'purpose.md') -Content (($purpose -join "`n") + "`n")
Write-Utf8NoBom -Path (Join-Path $wikiDir 'schema.md') -Content (($schema -join "`n") + "`n")
Write-Utf8NoBom -Path (Join-Path $wikiDir 'log.md') -Content (($log -join "`n") + "`n")
Write-Utf8NoBom -Path (Join-Path $indexDir 'source-manifest.json') -Content (([pscustomobject]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  root = $repoRoot
  sources = @($pages | Select-Object source, sha256, title, category, wikiPath)
} | ConvertTo-Json -Depth 8) + "`n")
Write-Utf8NoBom -Path (Join-Path $indexDir 'search-index.json') -Content (([pscustomobject]@{ rows = @($searchRows) } | ConvertTo-Json -Depth 8) + "`n")
Write-Utf8NoBom -Path (Join-Path $indexDir 'graph.json') -Content (($graph | ConvertTo-Json -Depth 10) + "`n")
Write-Utf8NoBom -Path (Join-Path $schemaDir 'README.md') -Content (($schema -join "`n") + "`n")

$summary = [pscustomobject]@{
  status = 'PASS'
  root = $repoRoot
  outputPath = $outputFull
  sources = $pages.Count
  categories = $categories.Count
  graphEdges = $edges.Count
  searchIndex = (Join-Path $indexDir 'search-index.json')
  wikiIndex = (Join-Path $wikiDir 'index.md')
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 6
} else {
  Write-Output ("CONTEXT_WIKI_BUILT sources={0} categories={1} edges={2}" -f $summary.sources, $summary.categories, $summary.graphEdges)
  Write-Output ("wiki={0}" -f $summary.wikiIndex)
  Write-Output ("search_index={0}" -f $summary.searchIndex)
}
