#requires -Version 7.2
#requires -PSEdition Core
<#
.SYNOPSIS
  Validate the public-safe cross-agent work arbitration contract.

.DESCRIPTION
  Keeps docs/cross-agent-work-arbitration.md from blurring deterministic
  duplicate-work arbitration with advisory similar-work discovery. The gate is
  read-only and checks that history and semantic search cannot become hidden
  authority for routing or cleanup.
#>
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
  [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ContractText {
  param([string]$Text)

  $checks = [ordered]@{
    'advisory similar-work section exists' = ($Text -match '(?im)^## Advisory similar-work discovery\s*$')
    'exact arbitration is distinct from advisory discovery' = (
      $Text -match 'Exact duplicate-work arbitration' -and
      $Text -match 'advisory similar-work discovery' -and
      $Text -match 'different contracts'
    )
    'history is opt-in and not a default blocker' = (
      $Text -match 'Completed or archived' -and
      $Text -match 'active blockers' -and
      $Text -match '(?is)by\s+default' -and
      $Text -match 'include-history' -and
      $Text -match '(?is)advisory\s+background'
    )
    'semantic index input is sanitized and narrow' = (
      $Text -match 'sanitized' -and
      $Text -match '`purpose_summary`' -and
      $Text -match '`intent_tags`' -and
      $Text -match 'vector, embedding, or semantic index'
    )
    'semantic discovery cannot authorize mutation' = (
      $Text -match 'MUST NOT\s+authorize routing, deletion, merge,\s*messaging, cleanup' -and
      $Text -match 'claim release'
    )
    'work control-plane section exists' = ($Text -match '(?im)^## Work Control Plane\s*$')
    'issue tracker is not execution owner' = (
      $Text -match 'collaboration artifacts' -and
      $Text -match 'execution control plane' -and
      $Text -match 'GitHub issue alone is not an owner'
    )
    'ready is dependency-aware' = (
      $Text -match 'Dependency-aware ready' -and
      $Text -match '(?is)cannot become `ready`' -and
      $Text -match '(?is)dependency is\s+still running, blocked, stale, or unknown'
    )
    'claimed work needs owner and workspace' = (
      $Text -match 'Single owner claim' -and
      $Text -match '`claimed` and `running` work need one owner' -and
      $Text -match 'worktree/scratch lane'
    )
    'warnings require remediation and rollback or handoff' = (
      $Text -match 'Actionable warnings' -and
      $Text -match '(?is)dry-run or check\s+command' -and
      $Text -match '(?is)rollback or\s+handoff'
    )
  }

  return $checks
}

function Write-Report {
  param([System.Collections.Specialized.OrderedDictionary]$Checks)

  $failures = @($Checks.GetEnumerator() | Where-Object { -not $_.Value })
  foreach ($entry in $Checks.GetEnumerator()) {
    $status = if ($entry.Value) { 'PASS' } else { 'FAIL' }
    Write-Output ("[{0}] {1}" -f $status, $entry.Key)
  }
  $pass = @($Checks.GetEnumerator() | Where-Object { $_.Value }).Count
  $fail = $failures.Count
  Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $(if ($fail -eq 0) { 'PASS' } else { 'FAIL' }), $pass, $fail)
  if ($fail -gt 0) { exit 1 }
  exit 0
}

if ($SelfTest) {
  $good = @'
## Advisory similar-work discovery

Exact duplicate-work arbitration and advisory similar-work discovery are
different contracts.

Completed or archived sessions and tasks MUST NOT appear as active blockers by
default. Historical material is considered only with include-history mode and
stays advisory background.

Any vector, embedding, or semantic index MUST be derived from sanitized
`purpose_summary` and `intent_tags` fields. It is advisory only and MUST NOT
authorize routing, deletion, merge, messaging, cleanup, claim release, or any
other mutation.

## Work Control Plane

Issue trackers, PRs, and project boards are collaboration artifacts. The
repo-local claim store and gates are the execution control plane. Dependency-
aware ready means a task cannot become `ready` while a dependency is still
running, blocked, stale, or unknown. Single owner claim means `claimed` and
`running` work need one owner plus a worktree/scratch lane. A GitHub issue alone
is not an owner. Actionable warnings include a dry-run or check command plus a
rollback or handoff note.
'@
  $bad = @'
## Advisory similar-work discovery

Similar work may route stale sessions automatically.
'@
  $goodChecks = Test-ContractText -Text $good
  $badChecks = Test-ContractText -Text $bad
  $goodPass = @($goodChecks.GetEnumerator() | Where-Object { -not $_.Value }).Count -eq 0
  $badPass = @($badChecks.GetEnumerator() | Where-Object { -not $_.Value }).Count -eq 0
  if (-not $goodPass) {
    $missing = @($goodChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
    throw ('SelfTest good fixture failed: ' + ($missing -join '; '))
  }
  if ($badPass) { throw 'SelfTest bad fixture unexpectedly passed.' }
  Write-Output 'RESULT: PASS self-test'
  exit 0
}

$repo = (Resolve-Path -LiteralPath $Root).Path
$doc = Join-Path $repo 'docs\cross-agent-work-arbitration.md'
if (-not (Test-Path -LiteralPath $doc -PathType Leaf)) {
  Write-Output "[FAIL] arbitration doc exists - missing=$doc"
  Write-Output 'RESULT: FAIL (pass=0 fail=1)'
  exit 1
}

$text = Get-Content -LiteralPath $doc -Raw -Encoding UTF8
Write-Report -Checks (Test-ContractText -Text $text)
