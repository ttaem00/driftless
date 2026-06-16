#requires -Version 7.2
#requires -PSEdition Core
<#
.SYNOPSIS
  Public-safe aggregate PR validation gate for Driftless.

.DESCRIPTION
  Runs the repo-local checks a manager-facing agent should use before PR_READY
  or merge. This is intentionally a thin wrapper over existing Driftless gates:
  no hosted Actions, no credentials, no host-global mutation, and no toolchain
  choice pushed to the manager.
#>
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
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

function Invoke-Gate {
  param(
    [string]$Name,
    [string]$Script,
    [string[]]$Arguments = @(),
    [string]$NextAction
  )
  $scriptPath = Join-Path $script:RepoRoot $Script
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    return [pscustomobject]@{
      name = $Name
      status = 'FAIL'
      evidence = "missing=$scriptPath"
      next_action = $NextAction
    }
  }

  $output = $null
  $code = $null
  $pushed = $false
  try {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $script:RepoRoot
    $pushed = $true
    $output = & pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
    $code = $LASTEXITCODE
  } finally {
    if ($pushed) { Pop-Location }
    $ErrorActionPreference = $saved
  }

  $lines = @($output | ForEach-Object { [string]$_ })
  $interesting = @($lines | Where-Object { $_ -match '^(RESULT:|PASS:|FAIL:|ALL PASS|\[PASS\]|\[FAIL\]|CLAUDE_CONTAINMENT_)' } | Select-Object -Last 4)
  if ($interesting.Count -eq 0) {
    $interesting = @($lines | Select-Object -Last 4)
  }
  $evidence = "exit=$code"
  if ($interesting.Count -gt 0) {
    $evidence += '; ' + (($interesting | ForEach-Object { $_.Trim() }) -join ' | ')
  }

  return [pscustomobject]@{
    name = $Name
    status = $(if ($code -eq 0) { 'PASS' } else { 'FAIL' })
    evidence = $evidence
    next_action = $NextAction
  }
}

$script:RepoRoot = (Resolve-Path -LiteralPath $Root).Path
$rows = [System.Collections.Generic.List[object]]::new()

$gates = @(
  @{ name = 'PowerShell 7 runtime'; script = 'scripts\check-pwsh7.ps1'; args = @(); next = 'Run with pwsh.exe 7+.' },
  @{ name = 'No legacy default launchers'; script = 'scripts\check-no-powershell51.ps1'; args = @(); next = 'Keep normal tasks on pwsh.exe and isolate legacy probes under scripts/winps51.' },
  @{ name = 'Default repo task test'; script = 'scripts\task.ps1'; args = @('test'); next = 'Fix the shell/no-Actions/text-safety task test.' },
  @{ name = 'Containment full scan'; script = 'scripts\Test-Containment.ps1'; args = @('-AllFiles'); next = 'Remove forbidden path or secret references before merge.' },
  @{ name = 'Primary checkout hygiene'; script = 'scripts\Test-PrimaryWorktreeClean.ps1'; args = @('-CheckPrimaryRoot'); next = 'Move issue work into an issue worktree or clean the primary checkout before PR_READY.' },
  @{ name = 'Work discipline'; script = 'scripts\Test-WorkDiscipline.ps1'; args = @(); next = 'Restore work-discipline gate coverage.' },
  @{ name = 'Public portability evidence'; script = 'scripts\Test-PublicPortabilityEvidence.ps1'; args = @('-Root', $script:RepoRoot); next = 'Keep public evidence repo-relative and do not cite absent hosted CI as current proof.' },
  @{ name = 'Public path safety'; script = 'scripts\Test-ProfileNoMachineAbsolutePaths.ps1'; args = @(); next = 'Remove machine-specific absolute paths from public profile surfaces.' },
  @{ name = 'Installer materialization'; script = 'scripts\Test-InstallerMaterialization.ps1'; args = @('-Root', $script:RepoRoot); next = 'Make install.ps1 materialize shared skills into each active isolated home skills directory.' },
  @{ name = 'Skill audit'; script = 'scripts\Test-SkillAudit.ps1'; args = @('-Root', $script:RepoRoot); next = 'Fix broken skill frontmatter or missing runnable command references.' },
  @{ name = 'Improvement principle discipline'; script = 'scripts\Test-ImprovementPrincipleDiscipline.ps1'; args = @('-Root', $script:RepoRoot); next = 'Restore root-cause / no-overfit guidance on shipped surfaces.' },
  @{ name = 'Hot context discipline'; script = 'scripts\Test-HotContextDiscipline.ps1'; args = @('-Root', $script:RepoRoot); next = 'Keep hot rules small and move conditional workflows into skills/docs.' },
  @{ name = 'Context engineering discipline'; script = 'scripts\Test-ContextEngineeringDiscipline.ps1'; args = @('-Root', $script:RepoRoot); next = 'Restore context budget, handoff, and evidence ledger anchors.' },
  @{ name = 'Mission-control closeout boundary'; script = 'scripts\Test-MissionControlCloseoutBoundary.ps1'; args = @('-Root', $script:RepoRoot); next = 'Restore parent closeout inventory and long-command evidence guidance before Done claims.' },
  @{ name = 'Code intelligence benchmark'; script = 'scripts\Test-CodeIntelligenceBenchmark.ps1'; args = @('-Root', $script:RepoRoot); next = 'Regenerate/fix the repo context wiki or benchmark evidence.' },
  @{ name = 'Compressed handoff protocol'; script = 'scripts\Test-CompressedHandoffSummaryProtocol.ps1'; args = @('-Root', $script:RepoRoot); next = 'Restore resumable handoff summary fields.' },
  @{ name = 'Mission map fixture'; script = 'scripts\Test-MissionMapFixture.ps1'; args = @(); next = 'Fix public-safe Mission Map fixture fields.' },
  @{ name = 'External adoption safety self-test'; script = 'scripts\Test-ExternalAdoptionSafetyGate.ps1'; args = @('-SelfTest'); next = 'Restore static adoption safety and lane closeout checks.' },
  @{ name = 'Public export classifier self-test'; script = 'scripts\Test-PublicExportClassifier.ps1'; args = @('-SelfTest'); next = 'Restore the pre-public classifier so private lessons are routed through public-safe, shared-internal, sanitize-first, private-only, or manager-only-decision before export.' }
)

foreach ($gate in $gates) {
  $result = Invoke-Gate -Name $gate.name -Script $gate.script -Arguments @($gate.args) -NextAction $gate.next
  Add-Result $rows $result.name $result.status $result.evidence $result.next_action
}

$failures = @($rows | Where-Object { $_.status -ne 'PASS' })
$summary = [pscustomobject]@{
  gate = 'Driftless PR validation'
  root = $script:RepoRoot
  overall = $(if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' })
  pass = @($rows | Where-Object { $_.status -eq 'PASS' }).Count
  fail = $failures.Count
  results = @($rows)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 8
} else {
  Write-Output '== Driftless PR validation gate =='
  foreach ($row in $rows) {
    Write-Output ("[{0}] {1} - {2}" -f $row.status, $row.name, $row.evidence)
  }
  Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $summary.overall, $summary.pass, $summary.fail)
}

if ($failures.Count -gt 0) {
  exit 1
}
exit 0
