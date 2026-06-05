<#
.SYNOPSIS
  Driftless improvement-principle discipline gate.

.DESCRIPTION
  Verifies that the shared root-cause / principle-based / no-overfit rule stays
  on the public surfaces that both profiles consume:

    1. profiles/shared/contract/SHARED_DESIGN_CONTRACT.md carries the canonical
       public improvement principle.
    2. AGENTS.md points agents at that shared principle.

  This is structural evidence, not behavioral proof. It prevents later prompt
  compression, profile porting, or doc cleanup from silently dropping the rule.
  Behavioral improvement claims still need real workflow evidence.

  Read-only. No network, no secrets, no peer AI, no host-global access.
  ASCII-only so the gate parses under Windows PowerShell 5.1.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$Command = 'Test-ImprovementPrincipleDiscipline.ps1'

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

function Test-Anchors {
  param([string]$Text, [string[]]$Anchors)
  $missing = [System.Collections.Generic.List[string]]::new()
  foreach ($anchor in $Anchors) {
    if ($Text -notlike ('*' + $anchor + '*')) { $missing.Add($anchor) | Out-Null }
  }
  return @($missing)
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

$sharedAnchors = @(
  '## 8. Improvement principle',
  'root-cause fixes',
  'principle-based',
  'spec overfitting',
  'case overfitting',
  'special-casing',
  'user effort',
  'maintainer effort',
  'maintainability'
)

$agentAnchors = @(
  'SHARED_DESIGN_CONTRACT.md',
  'root cause first',
  'principle-based guidance',
  'spec/case overfitting',
  'special-casing'
)

$sharedPath = Join-Path $resolvedRoot 'profiles\shared\contract\SHARED_DESIGN_CONTRACT.md'
if (-not (Test-Path -LiteralPath $sharedPath -PathType Leaf)) {
  Add-Result $results 'Shared improvement principle' 'FAIL' $true "missing=$sharedPath" 'Restore profiles/shared/contract/SHARED_DESIGN_CONTRACT.md with section 8 Improvement principle.'
} else {
  $missing = Test-Anchors -Text (Read-Utf8 $sharedPath) -Anchors $sharedAnchors
  $status = if ($missing.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "anchors=$($sharedAnchors.Count); missing=$($missing.Count)"
  if ($missing.Count -gt 0) { $evidence += '; missing_anchors=' + ($missing -join ', ') }
  Add-Result $results 'Shared improvement principle' $status $true $evidence 'Restore section 8 so both profiles consume the same root-cause/no-overfit rule.'
}

$agentsPath = Join-Path $resolvedRoot 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agentsPath -PathType Leaf)) {
  Add-Result $results 'Agent guidance pointer' 'FAIL' $true "missing=$agentsPath" 'Restore AGENTS.md with a pointer to the shared improvement principle.'
} else {
  $missing = Test-Anchors -Text (Read-Utf8 $agentsPath) -Anchors $agentAnchors
  $status = if ($missing.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "anchors=$($agentAnchors.Count); missing=$($missing.Count)"
  if ($missing.Count -gt 0) { $evidence += '; missing_anchors=' + ($missing -join ', ') }
  Add-Result $results 'Agent guidance pointer' $status $true $evidence 'Point AGENTS.md to profiles/shared/contract/SHARED_DESIGN_CONTRACT.md section 8.'
}

$blockingFailures = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
$overall = if ($blockingFailures.Count -gt 0) { 'FAIL' } else { 'PASS' }

Write-Output '== Driftless improvement-principle discipline gate =='
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
