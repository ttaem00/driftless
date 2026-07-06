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
    path = 'profiles\shared\skills\mission-control\SKILL.md'
    needles = @(
      'Parent Closeout Boundary',
      'parent_closeout_inventory',
      'Long or quiet commands',
      'long_command_evidence',
      '180 seconds',
      'atomic validation lanes',
      'does not start a competing validation loop',
      'missing log tail is `UNVERIFIED`'
    )
  },
  @{
    path = 'profiles\shared\skills\finish-to-done\SKILL.md'
    needles = @(
      'parent_closeout_inventory',
      'long_command_evidence',
      '180 seconds',
      'atomic validation lanes',
      'Do not convert child completion into parent Done',
      'caller timeout'
    )
  },
  @{
    path = 'scripts\Test-PrValidationGate.ps1'
    needles = @(
      'Mission-control closeout boundary',
      'Test-MissionControlCloseoutBoundary.ps1'
    )
  },
  @{
    path = 'scripts\README.md'
    needles = @(
      'Test-MissionControlCloseoutBoundary.ps1',
      'parent closeout inventory',
      'long command evidence'
    )
  }
)

foreach ($requirement in $requirements) {
  $path = Join-Path $Root $requirement.path
  $exists = Test-Path -LiteralPath $path -PathType Leaf
  Add-Result -Results $results -Check 'file exists' -Path $requirement.path -Pass $exists -Needle ''
  if (-not $exists) { continue }

  $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  foreach ($needle in $requirement.needles) {
    Add-Result -Results $results -Check "contains $needle" -Path $requirement.path -Pass $text.Contains($needle) -Needle $needle
  }
}

Write-Output '== Driftless mission-control closeout boundary gate =='
$results | Format-Table -AutoSize | Out-String | Write-Output

$failed = @($results | Where-Object { $_.status -ne 'PASS' })
if ($failed.Count -gt 0) {
  Write-Output "DRIFTLESS_MISSION_CONTROL_CLOSEOUT_BOUNDARY_FAIL count=$($failed.Count)"
  exit 1
}

Write-Output 'DRIFTLESS_MISSION_CONTROL_CLOSEOUT_BOUNDARY_PASS'
