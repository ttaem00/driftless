#requires -Version 7.0
#requires -PSEdition Core
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function New-Result {
  param(
    [string]$Name,
    [string]$Status,
    [string]$Detail
  )
  [pscustomobject]@{
    name = $Name
    status = $Status
    detail = $Detail
  }
}

function Test-ControlPlaneState {
  param([object]$ControlPlane)

  $failures = New-Object System.Collections.Generic.List[string]
  if (-not $ControlPlane) {
    $failures.Add('controlPlane missing') | Out-Null
    return $failures
  }

  $allowedNormalizedStates = @('ACTIVE', 'BLOCKED', 'DONE', 'UNVERIFIED', 'WATCHING')
  $state = [string]$ControlPlane.normalizedState
  if ($allowedNormalizedStates -notcontains $state) {
    $failures.Add("normalizedState unsupported: $state") | Out-Null
  }

  $workspaceStatus = [string]$ControlPlane.workspaceRoot.status
  $heartbeatStatus = [string]$ControlPlane.heartbeat.status
  $adoptionStatus = [string]$ControlPlane.adoption.status
  $driverStatus = [string]$ControlPlane.runtimeDriver.status
  $evidenceStatuses = @($workspaceStatus, $heartbeatStatus, $adoptionStatus, $driverStatus)
  $allowedEvidenceStatuses = @('PASS', 'FAIL', 'BLOCKED', 'UNVERIFIED', 'PARTIAL')
  foreach ($status in $evidenceStatuses) {
    if ($allowedEvidenceStatuses -notcontains $status) {
      $failures.Add("control-plane evidence status unsupported: $status") | Out-Null
    }
  }

  $expectedRootKind = [string]$ControlPlane.workspaceRoot.expectedRootKind
  $observedRootKind = [string]$ControlPlane.workspaceRoot.observedRootKind
  if ($expectedRootKind -and $observedRootKind -and $expectedRootKind -ne $observedRootKind -and $state -eq 'ACTIVE') {
    $failures.Add('ACTIVE requires matching workspace root evidence') | Out-Null
  }

  $hasNativeWorkId = -not [string]::IsNullOrWhiteSpace([string]$ControlPlane.nativeWorkId)
  $hasPendingWorkId = -not [string]::IsNullOrWhiteSpace([string]$ControlPlane.pendingWorkId)
  $driverLifecycle = [string]$ControlPlane.runtimeDriver.lifecycle
  $driverStdinDelivery = [string]$ControlPlane.runtimeDriver.stdinDelivery
  $driverInFlightWake = [string]$ControlPlane.runtimeDriver.inFlightWake
  $realProgressEvents = @($ControlPlane.runtimeDriver.realProgressEvents)
  if ($state -eq 'ACTIVE') {
    if (-not $hasNativeWorkId) {
      $failures.Add('ACTIVE requires nativeWorkId') | Out-Null
    }
    if ($workspaceStatus -ne 'PASS') {
      $failures.Add('ACTIVE requires workspaceRoot.status PASS') | Out-Null
    }
    if ($heartbeatStatus -ne 'PASS') {
      $failures.Add('ACTIVE requires heartbeat.status PASS') | Out-Null
    }
    if ($adoptionStatus -ne 'PASS') {
      $failures.Add('ACTIVE requires adoption.status PASS') | Out-Null
    }
    if ($driverStatus -ne 'PASS') {
      $failures.Add('ACTIVE requires runtimeDriver.status PASS') | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($driverLifecycle) -or [string]::IsNullOrWhiteSpace($driverStdinDelivery) -or [string]::IsNullOrWhiteSpace($driverInFlightWake) -or $realProgressEvents.Count -eq 0) {
      $failures.Add('ACTIVE requires runtime driver lifecycle/stdin/wake/progress semantics') | Out-Null
    }
    if ($hasPendingWorkId -and -not $hasNativeWorkId) {
      $failures.Add('pendingWorkId alone cannot be ACTIVE') | Out-Null
    }
  }

  return $failures
}

$results = New-Object System.Collections.Generic.List[object]
$fixturePath = Join-Path $Root 'examples\mission-map-state.json'
$docPath = Join-Path $Root 'docs\en\mission-map.md'

if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
  $results.Add((New-Result 'Mission Map fixture exists' 'FAIL' 'examples/mission-map-state.json is missing'))
} else {
  $results.Add((New-Result 'Mission Map fixture exists' 'PASS' 'fixture found'))
}

if (-not (Test-Path -LiteralPath $docPath -PathType Leaf)) {
  $results.Add((New-Result 'Mission Map doc exists' 'FAIL' 'docs/en/mission-map.md is missing'))
} else {
  $doc = Get-Content -LiteralPath $docPath -Raw
  if ($doc -match 'do(es)? not prove a real\s+runtime' -and $doc -match 'private state files' -and $doc -match 'Control-plane status must fail closed' -and $doc -match 'runtime driver semantics') {
    $results.Add((New-Result 'Mission Map doc caveat' 'PASS' 'doc separates fixture proof from runtime behavior and requires fail-closed control-plane status'))
  } else {
    $results.Add((New-Result 'Mission Map doc caveat' 'FAIL' 'doc must state fixture/static proof does not prove runtime behavior, private adapters stay private, and control-plane status fails closed'))
  }
}

if (Test-Path -LiteralPath $fixturePath -PathType Leaf) {
  try {
    $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    $required = @(
      'activeGoal',
      'guardian',
      'controlPlane',
      'pr',
      'checks',
      'blockers',
      'evidence',
      'nextAction'
    )
    $missing = @()
    foreach ($field in $required) {
      if (-not ($fixture.PSObject.Properties.Name -contains $field)) {
        $missing += $field
      }
    }
    if ($missing.Count -eq 0) {
      $results.Add((New-Result 'Mission Map required fields' 'PASS' ('fields=' + ($required -join ','))))
    } else {
      $results.Add((New-Result 'Mission Map required fields' 'FAIL' ('missing=' + ($missing -join ','))))
    }

    $states = @(
      [string]$fixture.pr.state,
      [string]$fixture.checks.state,
      [string]$fixture.evidence[0].status
    )
    $allowed = @('PASS', 'FAIL', 'BLOCKED', 'UNVERIFIED', 'PARTIAL')
    $badStates = @($states | Where-Object { $allowed -notcontains $_ })
    if ($badStates.Count -eq 0) {
      $results.Add((New-Result 'Mission Map state labels' 'PASS' ('states=' + ($states -join ','))))
    } else {
      $results.Add((New-Result 'Mission Map state labels' 'FAIL' ('unsupported states=' + ($badStates -join ','))))
    }

    $controlPlaneFailures = @(Test-ControlPlaneState -ControlPlane $fixture.controlPlane)
    if ($controlPlaneFailures.Count -eq 0) {
      $results.Add((New-Result 'Mission Map control-plane status' 'PASS' ('normalizedState=' + [string]$fixture.controlPlane.normalizedState)))
    } else {
      $results.Add((New-Result 'Mission Map control-plane status' 'FAIL' ($controlPlaneFailures -join '; ')))
    }

    $badPendingActive = [pscustomobject]@{
      normalizedState = 'ACTIVE'
      pendingWorkId = 'pending-worktree-123'
      nativeWorkId = $null
      runtimeDriver = [pscustomobject]@{ status = 'PASS'; lifecycle = 'persistent'; stdinDelivery = 'direct'; inFlightWake = 'steer'; realProgressEvents = @('text') }
      workspaceRoot = [pscustomobject]@{ status = 'PASS'; expectedRootKind = 'repo-a'; observedRootKind = 'repo-a' }
      heartbeat = [pscustomobject]@{ status = 'PASS' }
      adoption = [pscustomobject]@{ status = 'PASS' }
    }
    $badWrongRootActive = [pscustomobject]@{
      normalizedState = 'ACTIVE'
      pendingWorkId = $null
      nativeWorkId = 'worker-123'
      runtimeDriver = [pscustomobject]@{ status = 'PASS'; lifecycle = 'persistent'; stdinDelivery = 'direct'; inFlightWake = 'steer'; realProgressEvents = @('text') }
      workspaceRoot = [pscustomobject]@{ status = 'PASS'; expectedRootKind = 'repo-a'; observedRootKind = 'repo-b' }
      heartbeat = [pscustomobject]@{ status = 'PASS' }
      adoption = [pscustomobject]@{ status = 'PASS' }
    }
    $badUnmonitoredActive = [pscustomobject]@{
      normalizedState = 'ACTIVE'
      pendingWorkId = $null
      nativeWorkId = 'worker-123'
      runtimeDriver = [pscustomobject]@{ status = 'PASS'; lifecycle = 'persistent'; stdinDelivery = 'direct'; inFlightWake = 'steer'; realProgressEvents = @('text') }
      workspaceRoot = [pscustomobject]@{ status = 'PASS'; expectedRootKind = 'repo-a'; observedRootKind = 'repo-a' }
      heartbeat = [pscustomobject]@{ status = 'UNVERIFIED' }
      adoption = [pscustomobject]@{ status = 'PASS' }
    }
    $badUnnormalized = [pscustomobject]@{
      normalizedState = 'waiting on worker slot'
      pendingWorkId = $null
      nativeWorkId = 'worker-123'
      runtimeDriver = [pscustomobject]@{ status = 'PASS'; lifecycle = 'persistent'; stdinDelivery = 'direct'; inFlightWake = 'steer'; realProgressEvents = @('text') }
      workspaceRoot = [pscustomobject]@{ status = 'PASS'; expectedRootKind = 'repo-a'; observedRootKind = 'repo-a' }
      heartbeat = [pscustomobject]@{ status = 'PASS' }
      adoption = [pscustomobject]@{ status = 'PASS' }
    }
    $badMissingDriverActive = [pscustomobject]@{
      normalizedState = 'ACTIVE'
      pendingWorkId = $null
      nativeWorkId = 'worker-123'
      runtimeDriver = [pscustomobject]@{ status = 'UNVERIFIED'; lifecycle = $null; stdinDelivery = $null; inFlightWake = $null; realProgressEvents = @() }
      workspaceRoot = [pscustomobject]@{ status = 'PASS'; expectedRootKind = 'repo-a'; observedRootKind = 'repo-a' }
      heartbeat = [pscustomobject]@{ status = 'PASS' }
      adoption = [pscustomobject]@{ status = 'PASS' }
    }
    $badCases = @($badPendingActive, $badWrongRootActive, $badUnmonitoredActive, $badUnnormalized, $badMissingDriverActive)
    $badCasePasses = @($badCases | Where-Object { @(Test-ControlPlaneState -ControlPlane $_).Count -eq 0 })
    if ($badCasePasses.Count -eq 0) {
      $results.Add((New-Result 'Mission Map control-plane fail-closed fixtures' 'PASS' 'pending-only, wrong-root, unmonitored, non-normalized, and missing-driver ACTIVE states are rejected'))
    } else {
      $results.Add((New-Result 'Mission Map control-plane fail-closed fixtures' 'FAIL' ('bad cases accepted=' + $badCasePasses.Count)))
    }

    $raw = Get-Content -LiteralPath $fixturePath -Raw
    $dot = [string][char]46
    $privateMarkers = @(
      'D:\\',
      'C:\\Users\\',
      ($dot + 'runtime\\codex-home'),
      ($dot + 'runtime\\claude-home'),
      'thread:',
      'cookie',
      'credential',
      'secret',
      ($dot + 'env'),
      ($dot + 'ssh')
    )
    $hits = @($privateMarkers | Where-Object { $raw.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if ($hits.Count -eq 0) {
      $results.Add((New-Result 'Mission Map public-safe fixture' 'PASS' 'no private path/session/credential markers'))
    } else {
      $results.Add((New-Result 'Mission Map public-safe fixture' 'FAIL' ('private markers=' + ($hits -join ','))))
    }
  } catch {
    $results.Add((New-Result 'Mission Map fixture parses' 'FAIL' $_.Exception.Message))
  }
}

$failed = @($results | Where-Object { $_.status -ne 'PASS' })
$overall = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }

if ($Json) {
  [pscustomobject]@{
    gate = 'Mission Map fixture'
    overall = $overall
    checks = $results
  } | ConvertTo-Json -Depth 5
} else {
  Write-Output '== Mission Map fixture gate =='
  foreach ($r in $results) {
    Write-Output ('[' + $r.status + '] ' + $r.name + ' - ' + $r.detail)
  }
  Write-Output ('RESULT: ' + $overall)
}

if ($overall -ne 'PASS') {
  exit 1
}
