#requires -Version 7.0
#requires -PSEdition Core
param(
  [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$Results,
    [string]$Check,
    [string]$Path,
    [bool]$Pass,
    [string]$Needle
  )

  $Results.Add([pscustomobject]@{
    check = $Check
    path = $Path
    status = $(if ($Pass) { 'PASS' } else { 'FAIL' })
    needle = $Needle
  }) | Out-Null
}

function Get-MissingNeedles {
  param(
    [string]$Text,
    [string[]]$Needles
  )

  return @($Needles | Where-Object { -not $Text.Contains($_) })
}

$results = [System.Collections.Generic.List[object]]::new()

$commonNeedles = @(
  'worker_recovery_inventory',
  'MODEL_CAPACITY_RETRY',
  'CONTEXT_ROLLOVER_RETRY',
  'PARTIAL_RETRY_REQUIRED'
)

$writerHandoffNeedles = @(
  'Writer Handoff: Make Before Break',
  'prepare -> dispatch -> commit-or-abort',
  'successor_started_receipt',
  'task identity',
  'writable surface',
  'expected revision',
  'live run',
  'card, session id, heartbeat, or running status alone',
  'not write authority',
  'plan-only capability',
  'retain or restore the authorized fallback writer',
  'zero active writers'
)

$requirements = @(
  @{
    path = 'profiles\shared\skills\mission-control\SKILL.md'
    needles = @('Worker Failure Recovery', 'COMPLETE', 'FAILED', 'BLOCKED', 'reversible work') + $commonNeedles + $writerHandoffNeedles
  },
  @{
    path = 'profiles\shared\skills\parallel-ticket-planner\SKILL.md'
    needles = @('Worker capacity/context/partial failures', 'COMPLETE', 'FAILED', 'BLOCKED', 'context/fallback route') + $commonNeedles
  },
  @{
    path = 'profiles\shared\skills\finish-to-done\SKILL.md'
    needles = @('Worker-assisted', 'not-Done tracker') + $commonNeedles
  },
  @{
    path = 'profiles\shared\skills\goal-pair-guardian\SKILL.md'
    needles = @('worker model-capacity/context/partial failures') + $commonNeedles
  },
  @{
    path = 'profiles\shared\skills\adopt-external-tool\SKILL.md'
    needles = @('candidate-review workers', 'missing closeout', 'final adopt/watch/reject/block') + $commonNeedles
  },
  @{
    path = 'profiles\shared\skills\handoff-guard\SKILL.md'
    needles = @('worker_recovery_inventory', 'reversible-safety status', 'retry route') + $commonNeedles
  },
  @{
    path = 'profiles\codex\skills\goal-mode\SKILL.md'
    needles = @('worker GOAL', 'fresh GOAL/fallback route') + $commonNeedles
  }
)

$completeFixture = $writerHandoffNeedles -join "`n"
$positiveDetected = @(Get-MissingNeedles -Text $completeFixture -Needles $writerHandoffNeedles).Count -eq 0
$missingTermsCaught = 0
foreach ($needle in $writerHandoffNeedles) {
  $incompleteFixture = $completeFixture.Replace($needle, '')
  $missing = @(Get-MissingNeedles -Text $incompleteFixture -Needles $writerHandoffNeedles)
  if ($missing.Count -eq 1 -and $missing[0] -eq $needle) {
    $missingTermsCaught += 1
  }
}

Add-Result `
  -Results $results `
  -Check 'writer handoff detector self-test' `
  -Path '<built-in>' `
  -Pass ($positiveDetected -and $missingTermsCaught -eq $writerHandoffNeedles.Count) `
  -Needle ("positive={0}; missing_terms_caught={1}/{2}" -f $positiveDetected, $missingTermsCaught, $writerHandoffNeedles.Count)

foreach ($requirement in $requirements) {
  $path = Join-Path $Root $requirement.path
  $exists = Test-Path -LiteralPath $path -PathType Leaf
  Add-Result -Results $results -Check 'file exists' -Path $requirement.path -Pass $exists -Needle ''
  if (-not $exists) { continue }

  $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $missing = @(Get-MissingNeedles -Text $text -Needles $requirement.needles)
  foreach ($needle in $requirement.needles) {
    Add-Result -Results $results -Check "contains $needle" -Path $requirement.path -Pass ($missing -notcontains $needle) -Needle $needle
  }
}

Write-Output '== Driftless worker failure recovery contract gate =='
$results | Format-Table -AutoSize | Out-String | Write-Output

$failed = @($results | Where-Object { $_.status -ne 'PASS' })
if ($failed.Count -gt 0) {
  Write-Output "DRIFTLESS_WORKER_FAILURE_RECOVERY_CONTRACT_FAIL count=$($failed.Count)"
  exit 1
}

Write-Output 'DRIFTLESS_WORKER_FAILURE_RECOVERY_CONTRACT_PASS'
