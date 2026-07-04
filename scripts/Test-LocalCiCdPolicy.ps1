#Requires -Version 7.2
#Requires -PSEdition Core
<#
.SYNOPSIS
  Verify Driftless local CI/CD authority policy is present and wired.

.DESCRIPTION
  Driftless routine agent work uses repo-local validation as the completion
  authority. GitHub Actions/workflow CI/CD, hosted checks, and workflow scope are
  exceptional maintainer-approved surfaces, not routine Done proof.
#>
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
  [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$Rows,
    [string]$Name,
    [string]$Status,
    [string]$Evidence,
    [string]$NextAction
  )
  $Rows.Add([pscustomobject]@{
      name = $Name
      status = $Status
      evidence = $Evidence
      next_action = $NextAction
    }) | Out-Null
}

function Test-PolicyText {
  param([string]$Text)
  $hasLocalAuthority = (
    $Text -match '(?is)local workflow CI/CD.{0,240}(authority|policy|default|completion proof)' -or
    $Text -match '(?is)repo-local.{0,160}(gates|scripts|harnesses).{0,160}(completion|authority|proof)'
  )
  $hasRemoteDenial = (
    $Text -match '(?is)(do not|must not|not routine|no ).{0,180}(GitHub Actions|workflow CI/CD|hosted checks|workflow scope)' -or
    $Text -match '(?is)(GitHub remote workflow CI/CD|GitHub Actions/workflow CI/CD).{0,180}(exceptional|maintainer-approved)'
  )
  return ($hasLocalAuthority -and $hasRemoteDenial)
}

if ($SelfTest) {
  $good = @'
Local workflow CI/CD is the default authority. Use repo-local gates, scripts,
harnesses, and local merge-ref validation as completion proof. Do not create or
wait on GitHub Actions/workflow CI/CD, hosted checks, or workflow scope.
'@
  $bad = 'Hosted checks are required before Done.'
  if (-not (Test-PolicyText -Text $good)) { throw 'SelfTest good fixture failed.' }
  if (Test-PolicyText -Text $bad) { throw 'SelfTest bad fixture passed.' }
  Write-Output 'RESULT: PASS self-test'
  exit 0
}

$repo = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

$surfaces = @(
  @{ name = 'agent guidance'; rel = 'AGENTS.md' },
  @{ name = 'shared design contract'; rel = 'profiles/shared/contract/SHARED_DESIGN_CONTRACT.md' }
)

foreach ($surface in $surfaces) {
  $path = Join-Path $repo $surface.rel
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Result $results $surface.name 'FAIL' "missing=$($surface.rel)" 'Restore the policy surface.'
    continue
  }
  $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  $ok = Test-PolicyText -Text $text
  Add-Result $results $surface.name ($(if ($ok) { 'PASS' } else { 'FAIL' })) $surface.rel 'Add local CI/CD authority and GitHub remote workflow denial wording.'
}

$noActions = Join-Path $repo 'scripts/Test-NoGitHubActionsWorkflows.ps1'
$noActionsOk = Test-Path -LiteralPath $noActions -PathType Leaf
Add-Result $results 'tracked workflow-file guard exists' ($(if ($noActionsOk) { 'PASS' } else { 'FAIL' })) 'scripts/Test-NoGitHubActionsWorkflows.ps1' 'Restore the no GitHub Actions workflow gate.'

$prGatePath = Join-Path $repo 'scripts/Test-PrValidationGate.ps1'
$prGateText = if (Test-Path -LiteralPath $prGatePath -PathType Leaf) { Get-Content -LiteralPath $prGatePath -Raw -Encoding UTF8 } else { '' }
$prGateOk = $prGateText -match 'Local CI/CD policy' -and $prGateText -match 'Test-LocalCiCdPolicy.ps1'
Add-Result $results 'aggregate PR validation includes local CI/CD policy gate' ($(if ($prGateOk) { 'PASS' } else { 'FAIL' })) 'scripts/Test-PrValidationGate.ps1' 'Wire Test-LocalCiCdPolicy.ps1 into aggregate PR validation.'

foreach ($result in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $result.status, $result.name, $result.evidence)
}

$fail = @($results | Where-Object { $_.status -ne 'PASS' })
$passCount = @($results | Where-Object { $_.status -eq 'PASS' }).Count
Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $(if ($fail.Count -eq 0) { 'PASS' } else { 'FAIL' }), $passCount, $fail.Count)
if ($fail.Count -gt 0) { exit 1 }
exit 0
