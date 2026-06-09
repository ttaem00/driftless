#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Validate compressed handoff/protocol summaries keep load-bearing context.

.DESCRIPTION
  A compressed handoff is useful only if the next worker can recover the source,
  scope, exclusions, manager-only gates, validation evidence, stale-map status,
  and the next executable action. This gate checks a tiny fixture and includes a
  negative self-test proving missing required fields fail.

  Read-only except -SelfTest temp fixtures. ASCII-only for PowerShell 7.
#>
[CmdletBinding()]
param(
  [string]$Root,
  [string]$Fixture,
  [switch]$SelfTest,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$Results,
    [string]$Check,
    [string]$Status,
    [string]$Evidence,
    [string]$NextAction
  )
  $Results.Add([pscustomobject]@{
    check = $Check
    status = $Status
    evidence = $Evidence
    next_action = $NextAction
  }) | Out-Null
}

function Test-RequiredProperty {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $false }
  return $null -ne $Object.PSObject.Properties[$Name]
}

function Test-NonEmptyString {
  param([object]$Value)
  return ($null -ne $Value -and -not [string]::IsNullOrWhiteSpace([string]$Value))
}

function Test-NonEmptyArray {
  param([object]$Value)
  if ($null -eq $Value) { return $false }
  return @($Value).Count -gt 0
}

function Test-RepoRelativePath {
  param([string]$Path)
  if (-not (Test-NonEmptyString $Path)) { return $false }
  if ([System.IO.Path]::IsPathRooted($Path)) { return $false }
  if ($Path -match '^[A-Za-z]:') { return $false }
  if ($Path -match '^(~|%USERPROFILE%|\$HOME)') { return $false }
  if ($Path -match '(^|[\\/])\.\.([\\/]|$)') { return $false }
  return $true
}

function Test-CompressedSummary {
  param(
    [string]$RepoRoot,
    [string]$Label,
    [object]$Summary,
    [System.Collections.Generic.List[object]]$Results
  )

  $requiredTop = @(
    'summaryKind',
    'sourcePointer',
    'scope',
    'exclusions',
    'managerOnlyGates',
    'validationEvidence',
    'staleMapStatus',
    'nextExecutableAction'
  )

  $missingTop = @()
  foreach ($name in $requiredTop) {
    if (-not (Test-RequiredProperty $Summary $name)) {
      $missingTop += $name
    }
  }
  if ($missingTop.Count -gt 0) {
    Add-Result $Results $Label 'FAIL' ('missing_top_level=' + ($missingTop -join ', ')) 'Restore every load-bearing compressed-summary field.'
    return
  }

  $failures = [System.Collections.Generic.List[string]]::new()
  $allowedKinds = @('handoff', 'skill-reference', 'reference', 'repo-map', 'protocol')
  if ($allowedKinds -notcontains [string]$Summary.summaryKind) {
    $failures.Add('summaryKind must be one of: ' + ($allowedKinds -join ', ')) | Out-Null
  }

  $sourcePath = [string]$Summary.sourcePointer.repoRelativePath
  if (-not (Test-RepoRelativePath $sourcePath)) {
    $failures.Add('sourcePointer.repoRelativePath must be repo-relative and non-empty') | Out-Null
  } else {
    $sourceFull = Join-Path $RepoRoot $sourcePath
    if (-not (Test-Path -LiteralPath $sourceFull -PathType Leaf)) {
      $failures.Add('sourcePointer.repoRelativePath missing in repo: ' + $sourcePath) | Out-Null
    }
  }
  if (-not (Test-NonEmptyString $Summary.sourcePointer.anchor)) {
    $failures.Add('sourcePointer.anchor missing') | Out-Null
  }
  if (-not (Test-NonEmptyArray $Summary.scope.in)) {
    $failures.Add('scope.in must list included work') | Out-Null
  }
  if (-not (Test-NonEmptyArray $Summary.scope.out)) {
    $failures.Add('scope.out must list excluded work') | Out-Null
  }
  if (-not (Test-NonEmptyArray $Summary.exclusions)) {
    $failures.Add('exclusions must be non-empty') | Out-Null
  }
  if (-not (Test-NonEmptyArray $Summary.managerOnlyGates)) {
    $failures.Add('managerOnlyGates must be non-empty') | Out-Null
  }

  $validEvidenceStatuses = @('PASS', 'FAIL', 'BLOCKED', 'UNVERIFIED', 'PARTIAL')
  $evidenceRows = @($Summary.validationEvidence)
  if ($evidenceRows.Count -eq 0) {
    $failures.Add('validationEvidence must contain at least one evidence row') | Out-Null
  } else {
    for ($i = 0; $i -lt $evidenceRows.Count; $i++) {
      $row = $evidenceRows[$i]
      if (-not (Test-NonEmptyString $row.command)) {
        $failures.Add("validationEvidence[$i].command missing") | Out-Null
      }
      if ($validEvidenceStatuses -notcontains [string]$row.status) {
        $failures.Add("validationEvidence[$i].status invalid") | Out-Null
      }
      if (-not (Test-NonEmptyString $row.result)) {
        $failures.Add("validationEvidence[$i].result missing") | Out-Null
      }
    }
  }

  $validStaleStatuses = @('current', 'stale', 'unknown', 'blocked')
  if ($validStaleStatuses -notcontains [string]$Summary.staleMapStatus.status) {
    $failures.Add('staleMapStatus.status must be current, stale, unknown, or blocked') | Out-Null
  }
  if (-not (Test-NonEmptyString $Summary.staleMapStatus.evidence)) {
    $failures.Add('staleMapStatus.evidence missing') | Out-Null
  }
  if (-not (Test-NonEmptyString $Summary.staleMapStatus.nextRefreshAction)) {
    $failures.Add('staleMapStatus.nextRefreshAction missing') | Out-Null
  }

  $next = $Summary.nextExecutableAction
  if (-not (Test-NonEmptyString $next.actor)) {
    $failures.Add('nextExecutableAction.actor missing') | Out-Null
  }
  if (-not (Test-NonEmptyString $next.command)) {
    $failures.Add('nextExecutableAction.command missing') | Out-Null
  }
  if (-not (Test-NonEmptyString $next.successSignal)) {
    $failures.Add('nextExecutableAction.successSignal missing') | Out-Null
  }

  if ($failures.Count -gt 0) {
    Add-Result $Results $Label 'FAIL' (($failures | Select-Object -First 8) -join '; ') 'Repair the compressed summary fixture/protocol before trusting it as continuation context.'
  } else {
    Add-Result $Results $Label 'PASS' "kind=$($Summary.summaryKind); source=$sourcePath; evidence_rows=$($evidenceRows.Count)" ''
  }
}

function Invoke-SelfTest {
  $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('compressed-handoff-' + [System.IO.Path]::GetRandomFileName())
  try {
    New-Item -ItemType Directory -Force -Path (Join-Path $tmpRoot 'docs') | Out-Null
    Set-Content -LiteralPath (Join-Path $tmpRoot 'docs/source.md') -Encoding ASCII -Value '# Source'
    $valid = [pscustomobject]@{
      summaryKind = 'handoff'
      sourcePointer = [pscustomobject]@{ repoRelativePath = 'docs/source.md'; anchor = 'Source' }
      scope = [pscustomobject]@{ in = @('compress handoff'); out = @('credentials') }
      exclusions = @('no host-global mutation')
      managerOnlyGates = @('credentials')
      validationEvidence = @([pscustomobject]@{ command = 'test command'; status = 'PASS'; result = 'passed' })
      staleMapStatus = [pscustomobject]@{ status = 'current'; evidence = 'source exists'; nextRefreshAction = 'rerun gate' }
      nextExecutableAction = [pscustomobject]@{ actor = 'agent'; command = 'next command'; successSignal = 'PASS' }
    }

    $positive = [System.Collections.Generic.List[object]]::new()
    Test-CompressedSummary -RepoRoot $tmpRoot -Label 'self-test positive fixture' -Summary $valid -Results $positive
    if (@($positive | Where-Object { $_.status -eq 'PASS' }).Count -ne 1) {
      Write-Output '[FAIL] self-test expected valid compressed handoff to pass'
      exit 1
    }

    $required = @('sourcePointer', 'scope', 'exclusions', 'managerOnlyGates', 'validationEvidence', 'staleMapStatus', 'nextExecutableAction')
    $missesCaught = 0
    foreach ($field in $required) {
      $clone = ($valid | ConvertTo-Json -Depth 8) | ConvertFrom-Json
      $clone.PSObject.Properties.Remove($field)
      $results = [System.Collections.Generic.List[object]]::new()
      Test-CompressedSummary -RepoRoot $tmpRoot -Label "self-test missing $field" -Summary $clone -Results $results
      if (@($results | Where-Object { $_.status -eq 'FAIL' -and $_.evidence -match [regex]::Escape($field) }).Count -eq 1) {
        $missesCaught++
      }
    }
    if ($missesCaught -ne $required.Count) {
      Write-Output ("[FAIL] self-test expected {0} missing-field failures, caught {1}" -f $required.Count, $missesCaught)
      exit 1
    }

    Write-Output ("[PASS] self-test detected all missing load-bearing fields (caught={0})" -f $missesCaught)
    Write-Output 'RESULT: PASS (pass=2 fail=0)'
    exit 0
  } finally {
    if (Test-Path -LiteralPath $tmpRoot) {
      Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

if ($SelfTest) {
  Invoke-SelfTest
}

if (-not $Root) {
  $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
  $Root = Join-Path $scriptDir '..'
}
$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
if (-not $Fixture) {
  $Fixture = Join-Path $resolvedRoot 'tests/fixtures/context-engineering/compressed-handoff-summary.valid.json'
} elseif (-not [System.IO.Path]::IsPathRooted($Fixture)) {
  $Fixture = Join-Path $resolvedRoot $Fixture
}

$results = [System.Collections.Generic.List[object]]::new()
if (-not (Test-Path -LiteralPath $Fixture -PathType Leaf)) {
  Add-Result $results 'compressed handoff fixture present' 'FAIL' "missing=$Fixture" 'Restore the compressed handoff fixture or pass -Fixture to a replacement summary.'
} else {
  $summary = (Get-Content -LiteralPath $Fixture -Raw -Encoding UTF8) | ConvertFrom-Json
  Test-CompressedSummary -RepoRoot $resolvedRoot -Label 'compressed handoff summary protocol' -Summary $summary -Results $results
}

$failures = @($results | Where-Object { $_.status -eq 'FAIL' })
$overall = if ($failures.Count -gt 0) { 'FAIL' } else { 'PASS' }
$pass = @($results | Where-Object { $_.status -eq 'PASS' }).Count
$fail = $failures.Count

Write-Output '== Compressed handoff summary protocol =='
foreach ($result in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $result.status, $result.check, $result.evidence)
}
Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $overall, $pass, $fail)

if ($Json) {
  [pscustomobject]@{
    gate = 'compressed-handoff-summary-protocol'
    root = $resolvedRoot
    fixture = $Fixture
    overall = $overall
    pass = $pass
    fail = $fail
    results = @($results)
  } | ConvertTo-Json -Depth 8
}

if ($fail -gt 0) { exit 1 }
exit 0
