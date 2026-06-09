#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Write a compact checkpoint for a long Codex goal-pair pass.

.DESCRIPTION
  Records the current goal, evidence summary, remaining work, and goal-pair
  decision under .runtime/goal-runs/<RunId>/goal-pair/checkpoints/. This script
  is static and local: it does not call a model, read secrets, inspect
  host-global profiles, mutate git, or access the network.
#>
param(
  [string]$TargetRepo = (Get-Location).Path,
  [string]$RunId = '',
  [string]$Goal = '',
  [string]$SuccessCriteria = '',
  [string]$Scope = '',
  [string]$Observed = '',
  [string]$Remaining = '',
  [ValidateSet('CONTINUE_CURRENT_GOAL','REPLAN_WITH_PARALLEL_OR_OVERNIGHT','START_FRESH_GOAL','BLOCKED_TRUE_MANAGER')]
  [string]$Decision = 'CONTINUE_CURRENT_GOAL',
  [string]$Reason = ''
)

$ErrorActionPreference = 'Stop'

function Test-UnderPath {
  param(
    [string]$Child,
    [string]$Parent
  )
  $childFull = [System.IO.Path]::GetFullPath($Child).TrimEnd([char[]]@('\','/'))
  $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd([char[]]@('\','/'))
  return $childFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase) -or
    $childFull.StartsWith("$parentFull\", [System.StringComparison]::OrdinalIgnoreCase) -or
    $childFull.StartsWith("$parentFull/", [System.StringComparison]::OrdinalIgnoreCase)
}

$repoFull = [System.IO.Path]::GetFullPath($TargetRepo)
if (-not (Test-Path -LiteralPath $repoFull -PathType Container)) {
  throw "TargetRepo does not exist: $TargetRepo"
}

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-goal'
}

if ($RunId -notmatch '^[A-Za-z0-9._-]+$') {
  throw "RunId may contain only letters, digits, dot, underscore, and dash: $RunId"
}

$runtimeRoot = Join-Path $repoFull '.runtime'
$runRoot = Join-Path (Join-Path $runtimeRoot 'goal-runs') $RunId
$checkpointRoot = Join-Path (Join-Path $runRoot 'goal-pair') 'checkpoints'
$checkpointFull = [System.IO.Path]::GetFullPath($checkpointRoot)

if (-not (Test-UnderPath -Child $checkpointFull -Parent $repoFull)) {
  throw "Checkpoint path escaped TargetRepo."
}

New-Item -ItemType Directory -Path $checkpointFull -Force | Out-Null

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$jsonPath = Join-Path $checkpointFull "$stamp-checkpoint.json"
$mdPath = Join-Path $checkpointFull "$stamp-checkpoint.md"

$record = [pscustomobject]@{
  schema_version = 1
  created_utc = (Get-Date).ToUniversalTime().ToString('o')
  target_repo = $repoFull
  run_id = $RunId
  goal = $Goal
  success_criteria = $SuccessCriteria
  scope = $Scope
  observed = $Observed
  remaining = $Remaining
  decision = $Decision
  reason = $Reason
}

$json = $record | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($jsonPath, $json, [System.Text.UTF8Encoding]::new($false))

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Goal Pair Checkpoint') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("- created_utc: $($record.created_utc)") | Out-Null
$lines.Add("- target_repo: $repoFull") | Out-Null
$lines.Add("- run_id: $RunId") | Out-Null
$lines.Add("- decision: $Decision") | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Goal') | Out-Null
$lines.Add($Goal) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Success Criteria') | Out-Null
$lines.Add($SuccessCriteria) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Scope') | Out-Null
$lines.Add($Scope) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Observed') | Out-Null
$lines.Add($Observed) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Remaining') | Out-Null
$lines.Add($Remaining) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Reason') | Out-Null
$lines.Add($Reason) | Out-Null
[System.IO.File]::WriteAllText($mdPath, ($lines -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))

[pscustomobject]@{
  status = 'PASS'
  json_path = $jsonPath
  markdown_path = $mdPath
  decision = $Decision
} | ConvertTo-Json -Depth 4
