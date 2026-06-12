#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Public-safety gate for the Driftless insight-inbox starter.

.DESCRIPTION
  Ensures the public Driftless surface remains a pattern/starter and does not
  drift into shipping or claiming the private companion service. Read-only,
  no network, no secrets, no host-global access. ASCII-only.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

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

function Read-Text {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8)
}

function New-CodePointText {
  param([int[]]$CodePoints)
  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

$skillRel = 'profiles/shared/skills/insight-inbox-starter/SKILL.md'
$exampleRel = 'examples/insight-inbox-starter/README.md'
$enDocRel = 'docs/en/insight-inbox-pattern.md'
$koDocRel = 'docs/ko/' + (New-CodePointText @(51064,49324,51060,53944,51064,48149,49828,54056,53556)) + '.md'

$required = @($skillRel, $exampleRel, $enDocRel, $koDocRel)
$missing = [System.Collections.Generic.List[string]]::new()
foreach ($rel in $required) {
  $path = Join-Path $resolvedRoot ($rel -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $missing.Add($rel) | Out-Null }
}
if ($missing.Count -eq 0) {
  Add-Result $results 'Starter public files exist' 'PASS' $true ("files={0}" -f $required.Count)
} else {
  Add-Result $results 'Starter public files exist' 'FAIL' $true ("missing=" + ($missing -join ', ')) 'Restore the public starter skill, example README, and EN/KO pattern docs.'
}

$scanRels = @(
  'profiles/shared/skills/insight-inbox-starter/SKILL.md',
  'examples/insight-inbox-starter/README.md',
  'examples/insight-inbox-starter/queue/sample-links.md',
  'examples/insight-inbox-starter/prompts/review-contract.md',
  'examples/insight-inbox-starter/ledger/DECISIONS.md',
  'docs/en/insight-inbox-pattern.md',
  $koDocRel
)

$badPatterns = @(
  @{ id = 'private_repo_url'; rx = 'github\.com/mizan0515/insight-inbox'; reason = 'Private app repo URL must not be advertised from the public starter.' },
  @{ id = 'windows_machine_path'; rx = '(?i)\b[A-Z]:\\'; reason = 'Public starter must not encode local machine paths.' },
  @{ id = 'loopback_service'; rx = '(?i)(127\.0\.0\.1|localhost):48653'; reason = 'Public starter must not imply the private local service is shipped.' },
  @{ id = 'real_webhook_shape'; rx = '(?i)discord(?:app)?\.com/api/webhooks|webhook/[A-Za-z0-9_-]'; reason = 'Do not include real credential endpoint shapes.' },
  @{ id = 'token_shape'; rx = '(?i)(bot\s+[A-Za-z0-9._-]{12,}|mfa\.[A-Za-z0-9_-]+|sk-[A-Za-z0-9_-]{12,})'; reason = 'No token-like examples in the public starter.' },
  @{ id = 'private_extension_claim'; rx = '(?i)(chrome-extension://|chrome extension folder)'; reason = 'Public starter must not claim private runtime UX is included.' }
)

$violations = [System.Collections.Generic.List[string]]::new()
foreach ($rel in $scanRels) {
  $path = Join-Path $resolvedRoot ($rel -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  $text = Read-Text -Path $path
  if ($null -eq $text) { continue }
  foreach ($pat in $badPatterns) {
    if ($text -match $pat.rx) {
      $violations.Add(("{0}: {1} ({2})" -f $rel, $pat.id, $pat.reason)) | Out-Null
    }
  }
}
if ($violations.Count -eq 0) {
  Add-Result $results 'Public starter has no private-service leakage' 'PASS' $true ("scanned={0}; violations=0" -f $scanRels.Count)
} else {
  Add-Result $results 'Public starter has no private-service leakage' 'FAIL' $true (($violations | Select-Object -First 12) -join '; ') 'Remove private repo URLs, machine paths, live service references, token shapes, and private integration claims.'
}

$skillText = Read-Text -Path (Join-Path $resolvedRoot ($skillRel -replace '/', [System.IO.Path]::DirectorySeparatorChar))
$exampleText = Read-Text -Path (Join-Path $resolvedRoot ($exampleRel -replace '/', [System.IO.Path]::DirectorySeparatorChar))
$enText = Read-Text -Path (Join-Path $resolvedRoot ($enDocRel -replace '/', [System.IO.Path]::DirectorySeparatorChar))
$koText = Read-Text -Path (Join-Path $resolvedRoot ($koDocRel -replace '/', [System.IO.Path]::DirectorySeparatorChar))

$contractMisses = [System.Collections.Generic.List[string]]::new()
if ($skillText -notmatch 'Driftless\s+does\s+not\s+ship\s+the\s+private\s+app') { $contractMisses.Add('skill missing private-app boundary') | Out-Null }
if ($exampleText -notmatch 'does\s+not\s+ship\s+the\s+private\s+app') { $contractMisses.Add('example missing private-app boundary') | Out-Null }
if ($enText -notmatch 'Public starter vs private companion service') { $contractMisses.Add('EN doc missing public/private boundary heading') | Out-Null }
if ($enText -notmatch 'does\s+not\s+ship\s+the\s+private\s+app') { $contractMisses.Add('EN doc missing private-app boundary') | Out-Null }
if ($enText -notmatch 'starter') { $contractMisses.Add('EN doc missing starter language') | Out-Null }
if ($koText -notmatch 'public starter vs private companion service') { $contractMisses.Add('KO doc missing ASCII public/private boundary marker') | Out-Null }
if ($koText -notmatch 'private app') { $contractMisses.Add('KO doc missing ASCII private-app marker') | Out-Null }
if ($koText -notmatch 'starter') { $contractMisses.Add('KO doc missing starter marker') | Out-Null }
if ($exampleText -notmatch 'excluded from future review by default') { $contractMisses.Add('example missing active-list exclusion recovery wording') | Out-Null }
if ($skillText -notmatch 'future-processing exclusion') { $contractMisses.Add('skill missing removal-as-processing-exclusion wording') | Out-Null }

if ($contractMisses.Count -eq 0) {
  Add-Result $results 'Manager-safe UX contract is explicit' 'PASS' $true 'private/public boundary, starter language, ledger, and recovery wording present'
} else {
  Add-Result $results 'Manager-safe UX contract is explicit' 'FAIL' $true (($contractMisses | Select-Object -First 12) -join '; ') 'Make the public/private boundary, starter scope, and recovery semantics explicit.'
}

Write-Output '== Insight-inbox starter public-safety gate =='
foreach ($r in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
}
$fail = @($results | Where-Object { $_.blocking -and $_.status -eq 'FAIL' }).Count
$overall = if ($fail -gt 0) { 'FAIL' } else { 'PASS' }
Write-Output ("RESULT: {0} (checks={1} fail={2})" -f $overall, $results.Count, $fail)

if ($Json) {
  [pscustomobject]@{
    gate = 'insight-inbox-starter-public-safety'
    root = $resolvedRoot
    overall = $overall
    checks = @($results)
  } | ConvertTo-Json -Depth 6
}

if ($overall -eq 'FAIL') { exit 1 }
exit 0
