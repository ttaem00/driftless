#requires -Version 7.0
#requires -PSEdition Core

[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Copy-JsonObject {
  param([Parameter(Mandatory = $true)][object]$InputObject)
  return ($InputObject | ConvertTo-Json -Depth 40 | ConvertFrom-Json)
}

function Add-Check {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Checks,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][bool]$Pass,
    [Parameter(Mandatory = $true)][string]$Detail
  )
  $Checks.Add([pscustomobject]@{
    name = $Name
    status = $(if ($Pass) { 'PASS' } else { 'FAIL' })
    detail = $Detail
  }) | Out-Null
}

function New-ChildIdentity {
  param(
    [Parameter(Mandatory = $true)][object]$Template,
    [Parameter(Mandatory = $true)][object]$Child
  )

  $identity = Copy-JsonObject $Template
  $identity.ownerKey = [string]$Child.ownerKey
  $identity.nativeIdentity.ownerId = 'native-' + [string]$Child.ownerKey
  $identity.nativeIdentity.ownerUri = 'runtime://owner/' + [string]$Child.ownerKey
  $identity.nativeIdentity.readback.evidence = 'fixture://native-readback/' + [string]$Child.ownerKey
  $identity.workspace.cwdEvidence = 'repo://sample/worktree/' + [string]$Child.ownerKey
  $identity.workspace.worktreeEvidence = 'fixture://worktree-readback/' + [string]$Child.ownerKey
  $identity.task.proofId = [string]$Child.proofId
  $identity.task.taskCardId = 'task-card-' + [string]$Child.sliceKey
  $identity.task.readback.evidence = 'fixture://task-readback/' + [string]$Child.sliceKey
  return $identity
}

$modulePath = Join-Path $Root 'profiles\shared\modules\orphanless-control\OrphanlessControl.psm1'
$fixtureRoot = Join-Path $Root 'tests\fixtures\orphanless-control'
$inputSchemaPath = Join-Path $Root 'profiles\shared\schemas\orphanless-control-envelope.schema.json'
$receiptSchemaPath = Join-Path $Root 'profiles\shared\schemas\orphanless-reconcile-receipt.schema.json'
$docPath = Join-Path $Root 'docs\en\orphanless-control-module.md'
$checks = [System.Collections.Generic.List[object]]::new()

foreach ($path in @($modulePath, $inputSchemaPath, $receiptSchemaPath, $docPath)) {
  Add-Check $checks ('exists ' + [System.IO.Path]::GetFileName($path)) (Test-Path -LiteralPath $path -PathType Leaf) $path
}

Import-Module $modulePath -Force
$running = Get-Content -LiteralPath (Join-Path $fixtureRoot 'running-materialized.json') -Raw | ConvertFrom-Json
$pending = Get-Content -LiteralPath (Join-Path $fixtureRoot 'running-pending.json') -Raw | ConvertFrom-Json
$blocked = Get-Content -LiteralPath (Join-Path $fixtureRoot 'blocked-fission.json') -Raw | ConvertFrom-Json
$at = '2030-01-01T00:05:00Z'

$pendingIdentity = $pending.actual.identities[0]
$pendingCheck = Test-OrphanlessIdentityEnvelope -Envelope $pendingIdentity
$pendingReceipt = Invoke-OrphanlessReconcile -InputObject $pending -At $at
Add-Check $checks 'pending identity is valid but not materialized' ($pendingCheck.valid -and $pendingCheck.state -eq 'WAITING_NATIVE_THREAD_MATERIALIZATION') ('state=' + $pendingCheck.state)
Add-Check $checks 'pending owner cannot become active' ($pendingReceipt.normalizedState -eq 'WAITING_NATIVE_THREAD_MATERIALIZATION' -and $pendingReceipt.decision -eq 'READBACK_NATIVE_OWNER' -and -not $pendingReceipt.adoptionAllowed) ('state=' + $pendingReceipt.normalizedState + '; decision=' + $pendingReceipt.decision)
Add-Check $checks 'pending owner emits structured readback action' (@($pendingReceipt.actions).Count -eq 1 -and $pendingReceipt.actions[0].type -eq 'READBACK_NATIVE_OWNER' -and $pendingReceipt.actions[0].proofId -eq $pending.desired.proofId -and $pendingReceipt.actions[0].gate -eq 'MATERIALIZED_IDENTITY_WITH_READBACK') ('actions=' + @($pendingReceipt.actions).Count)

$identity = $running.actual.identities[0]
$identityCheck = Test-OrphanlessIdentityEnvelope -Envelope $identity
Add-Check $checks 'materialized identity passes full evidence gate' ($identityCheck.valid -and $identityCheck.state -eq 'MATERIALIZED') ('state=' + $identityCheck.state)
$wrongVersionIdentity = Copy-JsonObject $identity
$wrongVersionIdentity.contractVersion = '2.0'
$wrongVersionIdentityCheck = Test-OrphanlessIdentityEnvelope -Envelope $wrongVersionIdentity
Add-Check $checks 'unsupported identity contract version fails closed' (-not $wrongVersionIdentityCheck.valid) ('state=' + $wrongVersionIdentityCheck.state)

$wrongControllerContract = Copy-JsonObject $running
$wrongControllerContract.contractVersion = '2.0'
$wrongControllerRejected = $false
try {
  $null = Invoke-OrphanlessReconcile -InputObject $wrongControllerContract -At $at
} catch {
  $wrongControllerRejected = $_.Exception.Message -match 'contractVersion'
}
Add-Check $checks 'unsupported reconcile contract version fails closed' $wrongControllerRejected 'controller contract version enforced'

$lease = New-OrphanlessOwnerLease -Identity $identity -ProofId $running.desired.proofId -LeaseId 'lease-demo-1' -IssuedAt '2030-01-01T00:00:00Z' -ExpiresAt '2030-01-01T00:10:00Z'
$mismatchedIdentity = Copy-JsonObject $identity
$mismatchedIdentity.task.proofId = 'PROOF-DIFFERENT'
$mismatchRejected = $false
try {
  $null = New-OrphanlessOwnerLease -Identity $mismatchedIdentity -ProofId $running.desired.proofId -LeaseId 'lease-mismatch' -IssuedAt '2030-01-01T00:00:00Z' -ExpiresAt '2030-01-01T00:10:00Z'
} catch {
  $mismatchRejected = $_.Exception.Message -match 'identity.task.proofId'
}
Add-Check $checks 'lease rejects identity from a different proof' $mismatchRejected 'task proof binding enforced'
$mismatchedRunning = Copy-JsonObject $running
$mismatchedRunning.actual.identities[0] = $mismatchedIdentity
$mismatchedRunningReceipt = Invoke-OrphanlessReconcile -InputObject $mismatchedRunning -At $at
Add-Check $checks 'reconcile routes a different-proof identity to evidence repair' ($mismatchedRunningReceipt.normalizedState -eq 'BLOCKED_OWNER_EVIDENCE' -and $mismatchedRunningReceipt.decision -eq 'REPAIR_OWNER_EVIDENCE' -and $mismatchedRunningReceipt.actions[0].gate -eq 'IDENTITY_TASK_PROOF_MATCH') ('state=' + $mismatchedRunningReceipt.normalizedState)
$futureIdentityRunning = Copy-JsonObject $running
$futureIdentityRunning.actual.identities[0].observedAt = '2030-01-01T00:06:00Z'
$futureIdentityReceipt = Invoke-OrphanlessReconcile -InputObject $futureIdentityRunning -At $at
Add-Check $checks 'future identity evidence fails closed' ($futureIdentityReceipt.normalizedState -eq 'BLOCKED_OWNER_EVIDENCE' -and $futureIdentityReceipt.actions[0].gate -eq 'IDENTITY_OBSERVED_AT_NOT_FUTURE') ('state=' + $futureIdentityReceipt.normalizedState)
$duplicateIdentityRunning = Copy-JsonObject $running
$duplicateIdentityRunning.actual.identities = @($identity, (Copy-JsonObject $identity))
$duplicateIdentityReceipt = Invoke-OrphanlessReconcile -InputObject $duplicateIdentityRunning -At $at
Add-Check $checks 'duplicate owner identity fails closed' ($duplicateIdentityReceipt.normalizedState -eq 'BLOCKED_OWNER_EVIDENCE' -and $duplicateIdentityReceipt.actions[0].gate -eq 'UNIQUE_OWNER_IDENTITY') ('state=' + $duplicateIdentityReceipt.normalizedState)
$running.actual.leases = @($lease)
$activeReceiptA = Invoke-OrphanlessReconcile -InputObject $running -At $at
$activeReceiptB = Invoke-OrphanlessReconcile -InputObject $running -At $at
Add-Check $checks 'materialized owner plus current lease becomes active without parent adoption' ($activeReceiptA.normalizedState -eq 'ACTIVE' -and $activeReceiptA.decision -eq 'KEEP_OWNER_ACTIVE' -and -not $activeReceiptA.adoptionAllowed) ('state=' + $activeReceiptA.normalizedState + '; adoptionAllowed=' + $activeReceiptA.adoptionAllowed)
Add-Check $checks 'reconcile receipt is deterministic' ($activeReceiptA.inputDigest -eq $activeReceiptB.inputDigest -and $activeReceiptA.receiptDigest -eq $activeReceiptB.receiptDigest -and (ConvertTo-OrphanlessCanonicalJson $activeReceiptA) -eq (ConvertTo-OrphanlessCanonicalJson $activeReceiptB)) ('receiptDigest=' + $activeReceiptA.receiptDigest)

$expiredReceipt = Invoke-OrphanlessReconcile -InputObject $running -At '2030-01-01T00:20:00Z'
Add-Check $checks 'expired lease fails closed' ($expiredReceipt.normalizedState -eq 'LEASE_EXPIRED' -and $expiredReceipt.decision -eq 'RENEW_OWNER_LEASE' -and -not $expiredReceipt.adoptionAllowed) ('state=' + $expiredReceipt.normalizedState)

$unsafeIdentity = Copy-JsonObject $identity
$unsafeIdentity.workspace.cwdEvidence = 'X:/absolute/example'
$unsafeCheck = Test-OrphanlessIdentityEnvelope -Envelope $unsafeIdentity
Add-Check $checks 'absolute workspace evidence is rejected' (-not $unsafeCheck.valid -and $unsafeCheck.state -eq 'INVALID') ('state=' + $unsafeCheck.state)

$fissionReceipt = Invoke-OrphanlessReconcile -InputObject $blocked -At $at
$childIds = @($fissionReceipt.childProofs | ForEach-Object { [string]$_.proofId })
$issueActions = @($fissionReceipt.actions | Where-Object { $_.type -eq 'ISSUE_NATIVE_OWNER' })
Add-Check $checks 'agent blocker is automatically split into child proofs' ($fissionReceipt.normalizedState -eq 'BLOCKED_FISSION_IN_PROGRESS' -and $childIds.Count -eq 2 -and @($childIds | Select-Object -Unique).Count -eq 2) ('children=' + ($childIds -join ','))
Add-Check $checks 'every unowned child receives issuance action and gate' ($issueActions.Count -eq 2 -and @($issueActions | Where-Object { -not $_.ownerKey -or -not $_.ownerMode -or $_.gate -ne 'MATERIALIZED_IDENTITY_WITH_READBACK' }).Count -eq 0) ('issueActions=' + $issueActions.Count)

$missingSlices = Copy-JsonObject $blocked
$missingSlices.desired.blocker.fissionSlices = @()
$missingSlicesReceipt = Invoke-OrphanlessReconcile -InputObject $missingSlices -At $at
Add-Check $checks 'invalid fission input stays structured and not Done' ($missingSlicesReceipt.normalizedState -eq 'BLOCKED_FISSION_REQUIRED' -and $missingSlicesReceipt.decision -eq 'REPAIR_FISSION_INPUT' -and @($missingSlicesReceipt.actions).Count -eq 1 -and $missingSlicesReceipt.actions[0].proofId -eq $blocked.desired.proofId -and $missingSlicesReceipt.actions[0].gate -eq 'NONEMPTY_ATOMIC_FISSION_SLICES') ('state=' + $missingSlicesReceipt.normalizedState)
$missingClassification = Copy-JsonObject $blocked
$missingClassification.desired.blocker.PSObject.Properties.Remove('agentSolvable')
$missingClassificationReceipt = Invoke-OrphanlessReconcile -InputObject $missingClassification -At $at
Add-Check $checks 'missing blocker classification cannot silently become human-only' ($missingClassificationReceipt.normalizedState -eq 'BLOCKED_FISSION_REQUIRED' -and $missingClassificationReceipt.actions[0].gate -eq 'VALID_BLOCKER_CLASSIFICATION') ('state=' + $missingClassificationReceipt.normalizedState)
$stringClassification = Copy-JsonObject $blocked
$stringClassification.desired.blocker.agentSolvable = 'false'
$stringClassificationReceipt = Invoke-OrphanlessReconcile -InputObject $stringClassification -At $at
Add-Check $checks 'non-boolean blocker classification fails closed' ($stringClassificationReceipt.normalizedState -eq 'BLOCKED_FISSION_REQUIRED' -and $stringClassificationReceipt.actions[0].gate -eq 'VALID_BLOCKER_CLASSIFICATION') ('state=' + $stringClassificationReceipt.normalizedState)

$reordered = Copy-JsonObject $blocked
$reordered.desired.blocker.fissionSlices = @($reordered.desired.blocker.fissionSlices | Sort-Object key -Descending)
$reorderedReceipt = Invoke-OrphanlessReconcile -InputObject $reordered -At $at
$reorderedIds = @($reorderedReceipt.childProofs | ForEach-Object { [string]$_.proofId })
Add-Check $checks 'fission child ids are stable across slice order' (($childIds -join "`n") -eq ($reorderedIds -join "`n")) ('children=' + ($reorderedIds -join ','))

$completed = Copy-JsonObject $blocked
$completedIdentities = [System.Collections.Generic.List[object]]::new()
$completedLeases = [System.Collections.Generic.List[object]]::new()
$completedProofs = [System.Collections.Generic.List[object]]::new()
foreach ($child in @($fissionReceipt.childProofs)) {
  $childIdentity = New-ChildIdentity -Template $identity -Child $child
  $completedIdentities.Add($childIdentity) | Out-Null
  $completedLeases.Add((New-OrphanlessOwnerLease -Identity $childIdentity -ProofId $child.proofId -LeaseId ('lease-' + $child.sliceKey) -IssuedAt '2030-01-01T00:00:00Z' -ExpiresAt '2030-01-01T00:10:00Z')) | Out-Null
  $completedProofs.Add([pscustomobject]@{
    proofId = [string]$child.proofId
    state = 'PASS'
    evidenceStatus = 'PASS'
    evidence = 'fixture://child-proof/' + [string]$child.sliceKey
    observedAt = '2030-01-01T00:04:00Z'
  }) | Out-Null
}
$completed.actual.identities = @($completedIdentities)
$completed.actual.leases = @($completedLeases)
$completed.actual.childProofs = @($completedProofs)
$readyReceipt = Invoke-OrphanlessReconcile -InputObject $completed -At $at
Add-Check $checks 'passing children are not parent Done without adoption' ($readyReceipt.normalizedState -eq 'READY_FOR_PARENT_ADOPTION' -and $readyReceipt.decision -eq 'RECORD_PARENT_ADOPTION' -and -not $readyReceipt.adoptionAllowed -and @($readyReceipt.actions | Where-Object type -eq 'RECORD_PARENT_ADOPTION').Count -eq 1) ('state=' + $readyReceipt.normalizedState)

$completed.actual | Add-Member -NotePropertyName adoption -NotePropertyValue ([pscustomobject]@{
  status = 'PASS'
  parentProofId = [string]$completed.desired.proofId
  childProofIds = @($childIds)
  adoptedBy = 'fixture-parent-controller'
  adoptedAt = '2030-01-01T00:15:00Z'
  evidence = 'fixture://parent-adoption/demo'
})
$adoptedReceipt = Invoke-OrphanlessReconcile -InputObject $completed -At '2030-01-01T00:20:00Z'
Add-Check $checks 'exact child set adoption reaches adopted state' ($adoptedReceipt.normalizedState -eq 'ADOPTED' -and $adoptedReceipt.decision -eq 'ACCEPT_ADOPTED_CHILD_EVIDENCE' -and $adoptedReceipt.adoptionAllowed -and @($adoptedReceipt.actions).Count -eq 0) ('state=' + $adoptedReceipt.normalizedState)
Add-Check $checks 'delayed adoption uses lease validity at child evidence time' ($adoptedReceipt.normalizedState -eq 'ADOPTED') 'child completed before lease expiry; parent adopted later'

$completed.actual.adoption.adoptedAt = '2030-01-01T00:03:00Z'
$earlyAdoptionReceipt = Invoke-OrphanlessReconcile -InputObject $completed -At '2030-01-01T00:20:00Z'
Add-Check $checks 'parent adoption before child evidence is rejected' ($earlyAdoptionReceipt.normalizedState -eq 'READY_FOR_PARENT_ADOPTION' -and -not $earlyAdoptionReceipt.adoptionAllowed) ('state=' + $earlyAdoptionReceipt.normalizedState)
$completed.actual.adoption.adoptedAt = '2030-01-01T00:15:00Z'

$completed.actual.adoption.childProofIds = @($childIds | Select-Object -First 1)
$mismatchReceipt = Invoke-OrphanlessReconcile -InputObject $completed -At '2030-01-01T00:20:00Z'
Add-Check $checks 'partial adoption set is rejected' ($mismatchReceipt.normalizedState -eq 'READY_FOR_PARENT_ADOPTION' -and -not $mismatchReceipt.adoptionAllowed) ('state=' + $mismatchReceipt.normalizedState)

$schemaChecks = @(
  @{ path = $inputSchemaPath; needles = @('identityEnvelope', 'ownerLease', 'reconcileInput', 'fissionSlices') },
  @{ path = $receiptSchemaPath; needles = @('WAITING_NATIVE_THREAD_MATERIALIZATION', 'BLOCKED_FISSION_IN_PROGRESS', 'READY_FOR_PARENT_ADOPTION', 'ADOPTED', 'receiptDigest') }
)
foreach ($schemaCheck in $schemaChecks) {
  try {
    $raw = Get-Content -LiteralPath $schemaCheck.path -Raw
    $null = $raw | ConvertFrom-Json
    $missing = @($schemaCheck.needles | Where-Object { -not $raw.Contains($_) })
    Add-Check $checks ('schema parses and carries contract ' + [System.IO.Path]::GetFileName($schemaCheck.path)) ($missing.Count -eq 0) $(if ($missing.Count -eq 0) { 'anchors present' } else { 'missing=' + ($missing -join ',') })
  } catch {
    Add-Check $checks ('schema parses ' + [System.IO.Path]::GetFileName($schemaCheck.path)) $false $_.Exception.Message
  }
}

$inputSchema = Get-Content -LiteralPath $inputSchemaPath -Raw
$receiptSchema = Get-Content -LiteralPath $receiptSchemaPath -Raw
$fixtureSchemaFailures = [System.Collections.Generic.List[string]]::new()
foreach ($fixturePath in @(Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.json')) {
  $validFixture = Get-Content -LiteralPath $fixturePath.FullName -Raw |
    Test-Json -Schema $inputSchema -ErrorAction SilentlyContinue
  if (-not $validFixture) { $fixtureSchemaFailures.Add($fixturePath.Name) | Out-Null }
}
Add-Check $checks 'input fixtures validate against the published schema' ($fixtureSchemaFailures.Count -eq 0) $(if ($fixtureSchemaFailures.Count -eq 0) { 'fixtures=3' } else { 'invalid=' + ($fixtureSchemaFailures -join ',') })

$receiptSchemaFailures = [System.Collections.Generic.List[string]]::new()
foreach ($receiptCase in @($pendingReceipt, $activeReceiptA, $fissionReceipt, $readyReceipt, $adoptedReceipt)) {
  $validReceipt = ($receiptCase | ConvertTo-Json -Depth 40) |
    Test-Json -Schema $receiptSchema -ErrorAction SilentlyContinue
  if (-not $validReceipt) { $receiptSchemaFailures.Add([string]$receiptCase.normalizedState) | Out-Null }
}
Add-Check $checks 'representative receipts validate against the published schema' ($receiptSchemaFailures.Count -eq 0) $(if ($receiptSchemaFailures.Count -eq 0) { 'states=5' } else { 'invalid=' + ($receiptSchemaFailures -join ',') })

$invalidActiveReceipt = Copy-JsonObject $activeReceiptA
$invalidActiveReceipt.adoptionAllowed = $true
$invalidActiveSchemaResult = ($invalidActiveReceipt | ConvertTo-Json -Depth 40) |
  Test-Json -Schema $receiptSchema -ErrorAction SilentlyContinue
Add-Check $checks 'receipt schema rejects adoption permission outside ADOPTED' (-not $invalidActiveSchemaResult) 'ACTIVE plus adoptionAllowed=true rejected'

$doc = Get-Content -LiteralPath $docPath -Raw
$docAnchors = @('private registry', 'WAITING_NATIVE_THREAD_MATERIALIZATION', 'Proof-scoped leases', 'Blocked Atom Fission', 'Deterministic receipts', '`ADOPTED` is deliberately not root Done', '`adoptionAllowed`', 'issue, ticket, or task reference', 'end-to-end test')
$missingDocAnchors = @($docAnchors | Where-Object { -not $doc.Contains($_) })
Add-Check $checks 'documentation keeps adapter and root Done boundaries explicit' ($missingDocAnchors.Count -eq 0) $(if ($missingDocAnchors.Count -eq 0) { 'anchors present' } else { 'missing=' + ($missingDocAnchors -join ',') })

$fixtureText = Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }
$privateFixturePatterns = @(
  '^[A-Za-z]:[\\/]',
  'file://',
  'thread:',
  ([string]::Concat('to', 'ken=')),
  ([string]::Concat('pass', 'word='))
)
$fixtureHits = [System.Collections.Generic.List[string]]::new()
foreach ($text in @($fixtureText)) {
  foreach ($pattern in $privateFixturePatterns) {
    if ($text -match $pattern) { $fixtureHits.Add($pattern) | Out-Null }
  }
}
Add-Check $checks 'fixtures are public-safe and adapter-neutral' ($fixtureHits.Count -eq 0) $(if ($fixtureHits.Count -eq 0) { 'no private fixture markers' } else { 'hits=' + ($fixtureHits -join ',') })

$failed = @($checks | Where-Object status -ne 'PASS')
$overall = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
$result = [pscustomobject]@{
  gate = 'Driftless detachable Orphanless control module'
  overall = $overall
  proofId = 'POD-1563-DRIFTLESS-007'
  checks = @($checks)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  Write-Output '== Detachable Orphanless control module gate =='
  foreach ($check in $checks) {
    Write-Output ('[' + $check.status + '] ' + $check.name + ' - ' + $check.detail)
  }
  Write-Output ('RESULT: ' + $overall)
}

if ($overall -ne 'PASS') { exit 1 }
exit 0
