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

$results = [System.Collections.Generic.List[object]]::new()

$requirements = @(
  @{
    path = 'profiles\shared\skills\goal-pair-guardian\SKILL.md'
    needles = @('Session visibility and rollover gate', 'User interaction boundary', 'split_gate=single_lane', 'uncommitted changes', 'early-stop closeout work', 'one meaning-level question', 'Verify the supervision loop', 'UNVERIFIED_HEARTBEAT_TARGET', 'parent implementation thread', 'lookup hints, not liveness proof', 'readable materialized state', 'UNVERIFIED_OWNER_READBACK')
  },
  @{
    path = 'profiles\shared\skills\mission-control\SKILL.md'
    needles = @('Split And Closeout Gates', 'User Interaction Boundary', 'coordinator-cleanup', 'split_gate=single_lane', 'uncommitted changes', 'Do not ask the user to choose worker prompts', 'lookup hints, not liveness proof', 'readable materialized state', 'UNVERIFIED_OWNER_READBACK')
  },
  @{
    path = 'profiles\shared\skills\parallel-ticket-planner\SKILL.md'
    needles = @('Native Dispatch Mode', 'project-scoped', 'Wrong-workspace', 'Idle/completed plus uncommitted changes', 'User interaction is intentionally narrow')
  }
)

foreach ($requirement in $requirements) {
  $path = Join-Path $Root $requirement.path
  $exists = Test-Path -LiteralPath $path -PathType Leaf
  Add-Result -Results $results -Check 'file exists' -Path $requirement.path -Pass $exists -Needle ''
  if (-not $exists) { continue }
  $text = Get-Content -LiteralPath $path -Raw
  foreach ($needle in $requirement.needles) {
    Add-Result -Results $results -Check "contains $needle" -Path $requirement.path -Pass $text.Contains($needle) -Needle $needle
  }
}

Write-Output '== Driftless goal-pair operating contract gate =='
$results | Format-Table -AutoSize | Out-String | Write-Output

$failed = @($results | Where-Object { $_.status -ne 'PASS' })
if ($failed.Count -gt 0) {
  Write-Output "DRIFTLESS_GOAL_PAIR_OPERATING_CONTRACT_FAIL count=$($failed.Count)"
  exit 1
}

Write-Output 'DRIFTLESS_GOAL_PAIR_OPERATING_CONTRACT_PASS'
