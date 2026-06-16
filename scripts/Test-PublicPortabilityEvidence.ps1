#requires -Version 7.2
#requires -PSEdition Core
<#
.SYNOPSIS
  Check public-safe portability evidence for Driftless.

.DESCRIPTION
  Driftless is public OSS. This gate keeps public evidence honest after hosted
  GitHub Actions are intentionally absent and keeps machine-specific private
  paths out of public surfaces except explicit fixture needles.
#>
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$Rows,
    [string]$Check,
    [string]$Status,
    [string]$Evidence,
    [string]$NextAction
  )
  $Rows.Add([pscustomobject]@{
      check = $Check
      status = $Status
      evidence = $Evidence
      next_action = $NextAction
    }) | Out-Null
}

function Get-TrackedFiles {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)
  $output = & git -C $RepoRoot ls-files
  if ($LASTEXITCODE -ne 0) {
    throw "git ls-files failed for $RepoRoot"
  }
  return @($output | Where-Object { $_ })
}

function Test-TextLikeFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  $name = [System.IO.Path]::GetFileName($Path)
  if ($name -in @('.gitignore', '.gitattributes')) { return $true }
  $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
  return $ext -in @(
    '.bat', '.cmd', '.css', '.html', '.js', '.json', '.md', '.ps1', '.psd1',
    '.sh', '.txt', '.ts', '.yaml', '.yml'
  )
}

function Read-TextFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

$repoRoot = (Resolve-Path -LiteralPath $Root).Path
$rows = [System.Collections.Generic.List[object]]::new()
$trackedFiles = @(Get-TrackedFiles -RepoRoot $repoRoot)

$workflowFiles = @($trackedFiles | Where-Object { $_ -match '^\.github/workflows/.*\.(yml|yaml)$' })
if ($workflowFiles.Count -eq 0) {
  Add-Result $rows 'no tracked hosted workflow files' 'PASS' 'count=0' 'Keep merge authority on repo-local validation unless a manager approves hosted CI as a product decision.'
} else {
  Add-Result $rows 'no tracked hosted workflow files' 'FAIL' ("files={0}" -f ($workflowFiles -join ',')) 'Remove stale hosted workflow files or update the repo strategy with manager-approved hosted CI.'
}

$currentEvidenceDocs = @(
  'evidence/loop-log.md',
  'evidence/real-use-verification.md',
  'docs/en/host-evidence-matrix.md'
)
$staleHostedCiPatterns = @(
  'Every PR, issue, and CI run',
  'CI proves',
  '.github/workflows/gates.yml'
)
$staleHits = [System.Collections.Generic.List[string]]::new()
if ($workflowFiles.Count -eq 0) {
  foreach ($rel in $currentEvidenceDocs) {
    $full = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
    $text = Read-TextFile -Path $full
    foreach ($needle in $staleHostedCiPatterns) {
      if ($text.Contains($needle)) {
        $staleHits.Add(("{0}: {1}" -f $rel, $needle)) | Out-Null
      }
    }
  }
}
if ($staleHits.Count -eq 0) {
  Add-Result $rows 'current evidence does not cite absent hosted CI as live proof' 'PASS' ("docs={0}" -f ($currentEvidenceDocs -join ',')) 'Keep hosted CI references historical or UNVERIFIED while workflows are absent.'
} else {
  Add-Result $rows 'current evidence does not cite absent hosted CI as live proof' 'FAIL' (($staleHits | Select-Object -First 10) -join '; ') 'Rewrite current evidence docs to cite local validation or mark hosted CI proof as historical/retired.'
}

$privateRootNames = @(
  ('c-c' + '-isolated-runtime'),
  ('codex' + '-isolated-runtime'),
  'driftless'
)
$machinePathRegex = [regex]("(?i)\b[A-Z]:[\\/](?:[^`r`n]*[\\/])?(?:" + (($privateRootNames | ForEach-Object { [regex]::Escape($_) }) -join '|') + ")(?:[\\/][^`r`n]*)?")
$allowedMachinePathFiles = @{
  'scripts/Test-UiUxDesignGuidanceFallback.ps1' = 'fixture-only machine-path needles'
}
$machinePathHits = [System.Collections.Generic.List[string]]::new()
foreach ($rel in $trackedFiles) {
  $normalized = $rel -replace '\\', '/'
  $full = Join-Path $repoRoot $rel
  if (-not (Test-TextLikeFile -Path $full)) { continue }
  $text = Read-TextFile -Path $full
  $matches = @($machinePathRegex.Matches($text))
  if ($matches.Count -eq 0) { continue }

  if ($allowedMachinePathFiles.ContainsKey($normalized) -and $text.Contains($allowedMachinePathFiles[$normalized])) {
    continue
  }

  $sample = (($matches | Select-Object -First 3 | ForEach-Object { $_.Value }) -join ',')
  $machinePathHits.Add(("{0}: {1}" -f $normalized, $sample)) | Out-Null
}
if ($machinePathHits.Count -eq 0) {
  Add-Result $rows 'machine-specific paths are fixture-only' 'PASS' ("tracked_text_files={0}" -f $trackedFiles.Count) 'Keep public guidance repo-relative; mark any deliberate machine-path test needles as fixtures.'
} else {
  Add-Result $rows 'machine-specific paths are fixture-only' 'FAIL' (($machinePathHits | Select-Object -First 10) -join '; ') 'Remove machine-specific paths from public docs/code, or move deliberate needles into an explicitly marked fixture gate.'
}

$failures = @($rows | Where-Object { $_.status -ne 'PASS' })
$summary = [pscustomobject]@{
  gate = 'Public portability evidence'
  root = $repoRoot
  overall = $(if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' })
  pass = @($rows | Where-Object { $_.status -eq 'PASS' }).Count
  fail = $failures.Count
  results = @($rows)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} else {
  Write-Output '== Public portability evidence gate =='
  foreach ($row in $rows) {
    Write-Output ("[{0}] {1} - {2}" -f $row.status, $row.check, $row.evidence)
  }
  Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $summary.overall, $summary.pass, $summary.fail)
}

if ($failures.Count -gt 0) { exit 1 }
exit 0
