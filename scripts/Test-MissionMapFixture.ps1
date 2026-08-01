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

function ConvertTo-CanonicalValue {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) {
    return $null
  }
  if ($Value -is [pscustomobject]) {
    $ordered = [ordered]@{}
    foreach ($property in @($Value.PSObject.Properties | Sort-Object -Property Name)) {
      $ordered[$property.Name] = ConvertTo-CanonicalValue -Value $property.Value
    }
    return [pscustomobject]$ordered
  }
  if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
    $items = @()
    foreach ($item in $Value) {
      $items += ,(ConvertTo-CanonicalValue -Value $item)
    }
    return ,$items
  }
  return $Value
}

function Get-CanonicalDigest16 {
  param([Parameter(Mandatory = $true)][object]$Value)

  $canonical = ConvertTo-CanonicalValue -Value $Value
  $json = $canonical | ConvertTo-Json -Depth 50 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hash = $sha.ComputeHash($bytes)
  } finally {
    $sha.Dispose()
  }
  return ([System.Convert]::ToHexString($hash).ToLowerInvariant().Substring(0, 16))
}

function Get-ScopedProjection {
  param(
    [Parameter(Mandatory = $true)][object]$Source,
    [Parameter(Mandatory = $true)][string[]]$Scope
  )

  $projection = [ordered]@{}
  foreach ($field in @($Scope | Sort-Object -Unique)) {
    if (-not ($Source.PSObject.Properties.Name -contains $field)) {
      throw "digest scope field missing: $field"
    }
    $projection[$field] = $Source.$field
  }
  return [pscustomobject]$projection
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
$starrailContractPath = Join-Path $Root 'profiles\shared\contract\STARRAIL_SPRINT_CONTRACT.json'

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

  if ($doc -match 'Runtime cards' -and $doc -match 'optional node graph' -and $doc -match 'projection, not execution authority') {
    $results.Add((New-Result 'Mission Map card/graph vocabulary' 'PASS' 'doc defines runtime cards, optional node graph, and projection-only authority'))
  } else {
    $results.Add((New-Result 'Mission Map card/graph vocabulary' 'FAIL' 'doc must define public-safe runtime cards, optional node graph vocabulary, and state that graph/card UI is a projection, not execution authority'))
  }

  if ($doc -match 'Starrail Atlas' -and $doc -match 'StarrailTopology' -and $doc -match 'Mission Map' -and $doc -match 'Wuther Codemap' -and $doc -match 'never adds a pipeline step' -and $doc -match 'never.*runs `Trailblazer`' -and $doc -match 'freshness-labelled') {
    $results.Add((New-Result 'Starrail Atlas map distinction' 'PASS' 'doc separates live observation, executable topology, generic UI pattern, and repository map'))
  } else {
    $results.Add((New-Result 'Starrail Atlas map distinction' 'FAIL' 'doc must distinguish Starrail Atlas, StarrailTopology, Mission Map, and Wuther Codemap with an explicit no-execution boundary'))
  }

  if ($doc -match 'stable semantic rail' -and $doc -match 'direct one-hop neighbors' -and $doc -match 'Relation labels appear only on focused edges' -and $doc -match 'Only a topology change may recompute' -and $doc -match '`brief` first' -and $doc -match 'changed: false' -and $doc -match '`contextRevision`' -and $doc -match '`topologyRevision`' -and $doc -match 'canonical, key-sorted JSON' -and $doc -match 'share `rank`') {
    $results.Add((New-Result 'Starrail Atlas stable rail and bounded context' 'PASS' 'doc separates topology and context digests, stable layered lanes, focused labels, and progressive no-change context'))
  } else {
    $results.Add((New-Result 'Starrail Atlas stable rail and bounded context' 'FAIL' 'doc must define separate canonical topology/context digests, stable layered lanes, focused labels, and brief/current/full no-change context'))
  }
}

if (-not (Test-Path -LiteralPath $starrailContractPath -PathType Leaf)) {
  $results.Add((New-Result 'Starrail Atlas shared contract' 'FAIL' 'shared Starrail contract is missing'))
} else {
  $starrailContract = Get-Content -LiteralPath $starrailContractPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
  $atlasProjection = $starrailContract.companion_projections.StarrailAtlas
  $atlasAliases = @($atlasProjection.aliases | ForEach-Object { [string]$_ })
  $atlasIsNonExecutable = (
    $atlasProjection.mode -ceq 'read-only' -and
    $atlasProjection.authority -ceq 'projection-only' -and
    $atlasAliases.Count -eq 2 -and
    -not [bool]$atlasProjection.may_execute -and
    -not [bool]$atlasProjection.may_schedule -and
    -not [bool]$atlasProjection.may_mutate -and
    -not [bool]$atlasProjection.may_run_trailblazer -and
    -not [bool]$atlasProjection.may_emit_receipt -and
    -not ($starrailContract.session_aliases.psobject.Properties.Name -contains 'StarrailAtlas') -and
    -not ($starrailContract.executable_identifiers.psobject.Properties.Name -contains 'StarrailAtlas')
  )
  if ($atlasIsNonExecutable) {
    $results.Add((New-Result 'Starrail Atlas shared contract' 'PASS' 'contract keeps Atlas read-only, projection-only, and outside execution aliases'))
  } else {
    $results.Add((New-Result 'Starrail Atlas shared contract' 'FAIL' 'Atlas must stay outside execution aliases and must not schedule, mutate, run Trailblazer, or emit a receipt'))
  }
}

if (Test-Path -LiteralPath $fixturePath -PathType Leaf) {
  try {
    $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    $required = @(
      'activeGoal',
      'guardian',
      'controlPlane',
      'runtimeCards',
      'nodeGraph',
      'agentContext',
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

    $cardFailures = New-Object System.Collections.Generic.List[string]
    $runtimeCards = @($fixture.runtimeCards)
    if ($runtimeCards.Count -eq 0) {
      $cardFailures.Add('runtimeCards must contain at least one public-safe card') | Out-Null
    }
    $allowedCardKinds = @('intent', 'runtime', 'evidence', 'blocker', 'next-action')
    $allowedCardStates = @('ACTIVE', 'BLOCKED', 'DONE', 'WATCHING', 'PASS', 'FAIL', 'UNVERIFIED', 'PARTIAL')
    foreach ($card in $runtimeCards) {
      foreach ($field in @('id', 'label', 'kind', 'normalizedState', 'authority', 'nextAction')) {
        if ([string]::IsNullOrWhiteSpace([string]$card.$field)) {
          $cardFailures.Add("runtimeCards item missing $field") | Out-Null
        }
      }
      if ($allowedCardKinds -notcontains [string]$card.kind) {
        $cardFailures.Add('runtimeCards kind must use public Mission Map vocabulary') | Out-Null
      }
      if ($allowedCardStates -notcontains [string]$card.normalizedState) {
        $cardFailures.Add('runtimeCards normalizedState is unsupported') | Out-Null
      }
      if ([string]$card.authority -ne 'projection-only') {
        $cardFailures.Add('runtimeCards authority must be projection-only') | Out-Null
      }
      if ([string]$card.normalizedState -eq 'ACTIVE' -and [string]$fixture.controlPlane.normalizedState -ne 'ACTIVE') {
        $cardFailures.Add('runtimeCards cannot claim ACTIVE when controlPlane is not ACTIVE') | Out-Null
      }
    }
    if ($cardFailures.Count -eq 0) {
      $results.Add((New-Result 'Mission Map runtime cards' 'PASS' ('cards=' + $runtimeCards.Count)))
    } else {
      $results.Add((New-Result 'Mission Map runtime cards' 'FAIL' ($cardFailures -join '; ')))
    }

    $graphFailures = New-Object System.Collections.Generic.List[string]
    if (-not $fixture.nodeGraph) {
      $graphFailures.Add('nodeGraph missing') | Out-Null
    } else {
      if ([string]$fixture.nodeGraph.mode -ne 'optional-projection') {
        $graphFailures.Add('nodeGraph.mode must be optional-projection') | Out-Null
      }
      if ([string]$fixture.nodeGraph.authority -ne 'projection-only') {
        $graphFailures.Add('nodeGraph.authority must be projection-only') | Out-Null
      }
      $cardIds = @($runtimeCards | ForEach-Object { [string]$_.id })
      $nodeIds = @($fixture.nodeGraph.nodes | ForEach-Object { [string]$_.id })
      if (@($fixture.nodeGraph.nodes).Count -eq 0) {
        $graphFailures.Add('nodeGraph.nodes must not be empty') | Out-Null
      }
      foreach ($node in @($fixture.nodeGraph.nodes)) {
        if ($cardIds -notcontains [string]$node.cardId) {
          $graphFailures.Add('nodeGraph nodes must reference runtimeCards by cardId') | Out-Null
        }
      }
      if (@($nodeIds | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($nodeIds | Select-Object -Unique).Count -ne $nodeIds.Count) {
        $graphFailures.Add('nodeGraph node ids must be unique non-empty strings') | Out-Null
      }
      $ranks = @($fixture.nodeGraph.nodes | ForEach-Object { $_.rank })
      $lanes = @($fixture.nodeGraph.nodes | ForEach-Object { $_.lane })
      if (@($ranks | Where-Object { ($_ -isnot [int] -and $_ -isnot [long]) -or $_ -lt 0 }).Count -gt 0 -or @($lanes | Where-Object { ($_ -isnot [int] -and $_ -isnot [long]) -or $_ -lt 0 }).Count -gt 0) {
        $graphFailures.Add('nodeGraph rank and lane must be non-negative integers') | Out-Null
      }
      $positions = @($fixture.nodeGraph.nodes | ForEach-Object { ([string]$_.rank + ':' + [string]$_.lane) })
      if (@($positions | Select-Object -Unique).Count -ne $positions.Count) {
        $graphFailures.Add('nodeGraph rank and lane pairs must be unique') | Out-Null
      }
      if ($nodeIds -notcontains [string]$fixture.nodeGraph.selectedNodeId) {
        $graphFailures.Add('nodeGraph selectedNodeId must reference an existing node') | Out-Null
      }
      $layout = $fixture.nodeGraph.layout
      if ([string]$layout.kind -ne 'stable-layered-rail' -or [string]$layout.positionKey -ne 'rank' -or [string]$layout.recomputeWhen -ne 'topology-change' -or [string]$layout.defaultFocus -ne 'selected-one-hop' -or [string]$layout.edgeLabelPolicy -ne 'focused-only' -or [string]$layout.feedbackRoute -ne 'outer-curve') {
        $graphFailures.Add('nodeGraph layout must keep stable ranks, one-hop focus, focused labels, and an outer feedback route') | Out-Null
      }
      $expectedTopologyScope = @('edges', 'layout', 'nodes')
      $topologyScope = @($fixture.nodeGraph.topologyRevisionScope | ForEach-Object { [string]$_ })
      if ([string]$fixture.nodeGraph.topologyRevisionAlgorithm -ne 'sha256-canonical-json-16' -or ($topologyScope | Sort-Object) -join '|' -cne ($expectedTopologyScope -join '|')) {
        $graphFailures.Add('nodeGraph topology revision must use the canonical layout/nodes/edges digest') | Out-Null
      } else {
        $expectedTopologyRevision = Get-CanonicalDigest16 -Value (Get-ScopedProjection -Source $fixture.nodeGraph -Scope $topologyScope)
        if ([string]$fixture.nodeGraph.topologyRevision -notmatch '^[a-f0-9]{16}$' -or [string]$fixture.nodeGraph.topologyRevision -cne $expectedTopologyRevision) {
          $graphFailures.Add("nodeGraph topology revision mismatch: expected=$expectedTopologyRevision") | Out-Null
        }
      }
      if (@($fixture.nodeGraph.edges).Count -eq 0) {
        $graphFailures.Add('nodeGraph.edges must not be empty') | Out-Null
      }
      foreach ($edge in @($fixture.nodeGraph.edges)) {
        if ($nodeIds -notcontains [string]$edge.from -or $nodeIds -notcontains [string]$edge.to) {
          $graphFailures.Add('nodeGraph edges must connect existing nodes') | Out-Null
        }
        if (@('flow', 'evidence', 'observation', 'feedback') -notcontains [string]$edge.kind) {
          $graphFailures.Add('nodeGraph edge kind is unsupported') | Out-Null
        }
      }
    }
    if ($graphFailures.Count -eq 0) {
      $results.Add((New-Result 'Mission Map optional node graph' 'PASS' ('nodes=' + @($fixture.nodeGraph.nodes).Count + '; edges=' + @($fixture.nodeGraph.edges).Count)))
    } else {
      $results.Add((New-Result 'Mission Map optional node graph' 'FAIL' ($graphFailures -join '; ')))
    }

    $contextFailures = New-Object System.Collections.Generic.List[string]
    $context = $fixture.agentContext
    if ([string]$context.schemaVersion -ne 'starrail-atlas-context.example.v1' -or [string]$context.authority -ne 'projection-only') {
      $contextFailures.Add('agentContext must use the public projection-only schema') | Out-Null
    }
    $derivedContextScope = New-Object System.Collections.Generic.List[string]
    $unsupportedViewIncludes = New-Object System.Collections.Generic.List[string]
    $viewIncludes = @($context.views.brief.includes) + @($context.views.current.includes) + @($context.views.full.includes)
    foreach ($include in @($viewIncludes | ForEach-Object { [string]$_ })) {
      if (@('brief', 'current') -contains $include) {
        continue
      }
      if (@('selectedNodeId', 'selected-one-hop') -contains $include) {
        $derivedContextScope.Add('nodeGraph') | Out-Null
      } elseif ($include -ne 'agentContext' -and $fixture.PSObject.Properties.Name -contains $include) {
        $derivedContextScope.Add($include) | Out-Null
      } else {
        $unsupportedViewIncludes.Add($include) | Out-Null
      }
    }
    $requiredContextScope = @($derivedContextScope | Sort-Object -Unique)
    $contextScope = @($context.contextRevisionScope | ForEach-Object { [string]$_ })
    if ($unsupportedViewIncludes.Count -gt 0 -or [string]$context.contextRevisionAlgorithm -ne 'sha256-canonical-json-16' -or ($contextScope | Sort-Object) -join '|' -cne ($requiredContextScope -join '|')) {
      $contextFailures.Add('agentContext revision must cover every source field emitted by brief/current/full') | Out-Null
    } else {
      $expectedContextRevision = Get-CanonicalDigest16 -Value (Get-ScopedProjection -Source $fixture -Scope $contextScope)
      if ([string]$context.contextRevision -notmatch '^[a-f0-9]{16}$' -or [string]$context.contextRevision -cne $expectedContextRevision) {
        $contextFailures.Add("agentContext revision mismatch: expected=$expectedContextRevision") | Out-Null
      }
    }
    $viewBytes = @([int]$context.views.brief.maxBytes, [int]$context.views.current.maxBytes, [int]$context.views.full.maxBytes)
    if ([string]$context.defaultView -ne 'brief' -or $viewBytes[0] -le 0 -or $viewBytes[0] -ge $viewBytes[1] -or $viewBytes[1] -ge $viewBytes[2] -or $viewBytes[2] -gt 16384) {
      $contextFailures.Add('agentContext must default to progressively bounded brief/current/full views') | Out-Null
    }
    $unchangedIncludes = @($context.unchangedResponse.includes | ForEach-Object { [string]$_ })
    $unchangedMaxBytes = [int]$context.unchangedResponse.maxBytes
    if ([bool]$context.unchangedResponse.changed -or $unchangedMaxBytes -lt 1 -or $unchangedMaxBytes -gt 256 -or $unchangedIncludes.Count -ne 2 -or $unchangedIncludes -notcontains 'contextRevision' -or $unchangedIncludes -notcontains 'changed') {
      $contextFailures.Add('agentContext unchanged response must contain only a 1..256 byte contextRevision and changed marker') | Out-Null
    }
    if ($contextFailures.Count -eq 0) {
      $results.Add((New-Result 'Starrail Atlas bounded agent context' 'PASS' ('contextRevision=' + [string]$context.contextRevision + '; bytes=' + ($viewBytes -join '/'))))
    } else {
      $results.Add((New-Result 'Starrail Atlas bounded agent context' 'FAIL' ($contextFailures -join '; ')))
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
