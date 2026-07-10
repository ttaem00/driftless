#requires -Version 7.0
#requires -PSEdition Core

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-OrphanlessField {
  param(
    [AllowNull()][object]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($property) { return $property.Value }
  return $null
}

function ConvertTo-OrphanlessCanonicalValue {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) { return $null }
  if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString('o') }
  if ($Value -is [datetimeoffset]) { return $Value.UtcDateTime.ToString('o') }
  if ($Value -is [string] -or $Value -is [char] -or $Value -is [bool] -or
      $Value -is [byte] -or $Value -is [sbyte] -or $Value -is [short] -or
      $Value -is [ushort] -or $Value -is [int] -or $Value -is [uint] -or
      $Value -is [long] -or $Value -is [ulong] -or $Value -is [float] -or
      $Value -is [double] -or $Value -is [decimal]) {
    return $Value
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $ordered = [ordered]@{}
    foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) {
      $ordered[$key] = ConvertTo-OrphanlessCanonicalValue -Value $Value[$key]
    }
    return $ordered
  }

  if ($Value -is [System.Collections.IEnumerable]) {
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Value) {
      $items.Add((ConvertTo-OrphanlessCanonicalValue -Value $item)) | Out-Null
    }
    return @($items)
  }

  $properties = @($Value.PSObject.Properties | Sort-Object Name -CaseSensitive)
  if ($properties.Count -gt 0) {
    $ordered = [ordered]@{}
    foreach ($property in $properties) {
      $ordered[$property.Name] = ConvertTo-OrphanlessCanonicalValue -Value $property.Value
    }
    return $ordered
  }

  return [string]$Value
}

function ConvertTo-OrphanlessCanonicalJson {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object]$InputObject)

  $canonical = ConvertTo-OrphanlessCanonicalValue -Value $InputObject
  return ($canonical | ConvertTo-Json -Depth 40 -Compress)
}

function Get-OrphanlessSha256 {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
  return ([System.Convert]::ToHexString($hash)).ToLowerInvariant()
}

function ConvertTo-OrphanlessUtcStamp {
  param([Parameter(Mandatory = $true)][string]$Value)

  try {
    $parsed = [datetimeoffset]::Parse(
      $Value,
      [System.Globalization.CultureInfo]::InvariantCulture,
      [System.Globalization.DateTimeStyles]::RoundtripKind
    )
    return $parsed.UtcDateTime.ToString('o')
  } catch {
    throw "Invalid timestamp: $Value"
  }
}

function Test-OrphanlessOpaqueValue {
  param([AllowNull()][object]$Value)

  if ($null -eq $Value) { return $false }
  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) { return $false }
  if ($text.Length -gt 512) { return $false }
  if ($text -match '[\r\n]') { return $false }
  if ($text -match '^[A-Za-z]:[\\/]') { return $false }
  if ($text -match '^[/\\]{1,2}') { return $false }
  if ($text -match '^(?i:file):') { return $false }
  return $true
}

function Add-OrphanlessFailure {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Failures,
    [Parameter(Mandatory = $true)][string]$Message
  )
  $Failures.Add($Message) | Out-Null
}

function Test-OrphanlessIdentityEnvelope {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][object]$Envelope)

  $failures = [System.Collections.Generic.List[string]]::new()
  if ([string](Get-OrphanlessField $Envelope 'contractVersion') -ne '1.0') {
    Add-OrphanlessFailure $failures 'identity.contractVersion must be 1.0'
  }
  foreach ($field in @('ownerKey', 'runtimeKind', 'observedAt')) {
    if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $Envelope $field))) {
      Add-OrphanlessFailure $failures "identity.$field is required and must be public-safe"
    }
  }

  try {
    $null = ConvertTo-OrphanlessUtcStamp -Value ([string](Get-OrphanlessField $Envelope 'observedAt'))
  } catch {
    Add-OrphanlessFailure $failures 'identity.observedAt must be an ISO-8601 timestamp'
  }

  $native = Get-OrphanlessField $Envelope 'nativeIdentity'
  $nativeStatus = [string](Get-OrphanlessField $native 'status')
  if ($nativeStatus -notin @('PENDING', 'MATERIALIZED')) {
    Add-OrphanlessFailure $failures 'identity.nativeIdentity.status must be PENDING or MATERIALIZED'
  }

  $workspace = Get-OrphanlessField $Envelope 'workspace'
  foreach ($field in @('cwdEvidence', 'worktreeEvidence')) {
    if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $workspace $field))) {
      Add-OrphanlessFailure $failures "identity.workspace.$field is required and must be public-safe"
    }
  }

  $task = Get-OrphanlessField $Envelope 'task'
  foreach ($field in @('proofId', 'taskCardId')) {
    if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $task $field))) {
      Add-OrphanlessFailure $failures "identity.task.$field is required and must be public-safe"
    }
  }
  $taskReadback = Get-OrphanlessField $task 'readback'
  if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $taskReadback 'evidence'))) {
    Add-OrphanlessFailure $failures 'identity.task.readback.evidence is required and must be public-safe'
  }

  if ($nativeStatus -eq 'PENDING') {
    if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $native 'pendingHandle'))) {
      Add-OrphanlessFailure $failures 'identity.nativeIdentity.pendingHandle is required and must be public-safe'
    }
    if ([string](Get-OrphanlessField $workspace 'status') -notin @('PASS', 'UNVERIFIED')) {
      Add-OrphanlessFailure $failures 'pending identity workspace status must be PASS or UNVERIFIED'
    }
    if ([string](Get-OrphanlessField $taskReadback 'status') -notin @('PASS', 'UNVERIFIED')) {
      Add-OrphanlessFailure $failures 'pending identity task readback status must be PASS or UNVERIFIED'
    }
    return [pscustomobject]@{
      valid = ($failures.Count -eq 0)
      state = $(if ($failures.Count -eq 0) { 'WAITING_NATIVE_THREAD_MATERIALIZATION' } else { 'INVALID' })
      failures = @($failures)
    }
  }

  foreach ($field in @('ownerId', 'ownerUri')) {
    if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $native $field))) {
      Add-OrphanlessFailure $failures "identity.nativeIdentity.$field is required and must be public-safe"
    }
  }
  $nativeReadback = Get-OrphanlessField $native 'readback'
  if ([string](Get-OrphanlessField $nativeReadback 'status') -ne 'PASS') {
    Add-OrphanlessFailure $failures 'identity.nativeIdentity.readback.status must be PASS'
  }
  if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $nativeReadback 'evidence'))) {
    Add-OrphanlessFailure $failures 'identity.nativeIdentity.readback.evidence is required and must be public-safe'
  }

  if ([string](Get-OrphanlessField $workspace 'status') -ne 'PASS') {
    Add-OrphanlessFailure $failures 'identity.workspace.status must be PASS'
  }

  if ([string](Get-OrphanlessField $taskReadback 'status') -ne 'PASS') {
    Add-OrphanlessFailure $failures 'identity.task.readback.status must be PASS'
  }

  return [pscustomobject]@{
    valid = ($failures.Count -eq 0)
    state = $(if ($failures.Count -eq 0) { 'MATERIALIZED' } else { 'INVALID' })
    failures = @($failures)
  }
}

function Get-OrphanlessIdentityDigest {
  [CmdletBinding()]
  param([Parameter(Mandatory = $true)][object]$Envelope)

  $validation = Test-OrphanlessIdentityEnvelope -Envelope $Envelope
  if (-not $validation.valid -or $validation.state -ne 'MATERIALIZED') {
    throw ('Identity is not materialized: ' + (@($validation.failures) -join '; '))
  }
  return Get-OrphanlessSha256 -Text (ConvertTo-OrphanlessCanonicalJson -InputObject $Envelope)
}

function New-OrphanlessOwnerLease {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][object]$Identity,
    [Parameter(Mandatory = $true)][string]$ProofId,
    [Parameter(Mandatory = $true)][string]$LeaseId,
    [Parameter(Mandatory = $true)][string]$IssuedAt,
    [Parameter(Mandatory = $true)][string]$ExpiresAt,
    [ValidateRange(1, [long]::MaxValue)][long]$Revision = 1
  )

  foreach ($value in @($ProofId, $LeaseId)) {
    if (-not (Test-OrphanlessOpaqueValue $value)) { throw 'Lease ids must be public-safe non-empty values.' }
  }
  if ([string](Get-OrphanlessField (Get-OrphanlessField $Identity 'task') 'proofId') -ne $ProofId) {
    throw 'Lease proofId must match identity.task.proofId.'
  }
  $issued = ConvertTo-OrphanlessUtcStamp -Value $IssuedAt
  $expires = ConvertTo-OrphanlessUtcStamp -Value $ExpiresAt
  if ([datetimeoffset]::Parse($expires) -le [datetimeoffset]::Parse($issued)) {
    throw 'Lease expiresAt must be later than issuedAt.'
  }

  return [pscustomobject][ordered]@{
    contractVersion = '1.0'
    leaseId = $LeaseId
    ownerKey = [string](Get-OrphanlessField $Identity 'ownerKey')
    proofId = $ProofId
    issuedAt = $issued
    expiresAt = $expires
    revision = $Revision
    identityDigest = Get-OrphanlessIdentityDigest -Envelope $Identity
  }
}

function Test-OrphanlessOwnerLease {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][object]$Lease,
    [Parameter(Mandatory = $true)][object]$Identity,
    [Parameter(Mandatory = $true)][string]$ProofId,
    [Parameter(Mandatory = $true)][string]$At
  )

  $failures = [System.Collections.Generic.List[string]]::new()
  if ([string](Get-OrphanlessField $Lease 'contractVersion') -ne '1.0') {
    Add-OrphanlessFailure $failures 'lease.contractVersion must be 1.0'
  }
  if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $Lease 'leaseId'))) {
    Add-OrphanlessFailure $failures 'lease.leaseId is required and must be public-safe'
  }
  $identityValidation = Test-OrphanlessIdentityEnvelope -Envelope $Identity
  if (-not $identityValidation.valid -or $identityValidation.state -ne 'MATERIALIZED') {
    Add-OrphanlessFailure $failures 'lease requires a materialized identity'
  }
  if ([string](Get-OrphanlessField $Lease 'ownerKey') -ne [string](Get-OrphanlessField $Identity 'ownerKey')) {
    Add-OrphanlessFailure $failures 'lease.ownerKey does not match identity.ownerKey'
  }
  if ([string](Get-OrphanlessField $Lease 'proofId') -ne $ProofId) {
    Add-OrphanlessFailure $failures 'lease.proofId does not match the reconciled proof'
  }
  if ([string](Get-OrphanlessField (Get-OrphanlessField $Identity 'task') 'proofId') -ne $ProofId) {
    Add-OrphanlessFailure $failures 'identity.task.proofId does not match the reconciled proof'
  }
  if ([long](Get-OrphanlessField $Lease 'revision') -lt 1) {
    Add-OrphanlessFailure $failures 'lease.revision must be at least 1'
  }

  try {
    $expectedDigest = Get-OrphanlessIdentityDigest -Envelope $Identity
    if ([string](Get-OrphanlessField $Lease 'identityDigest') -ne $expectedDigest) {
      Add-OrphanlessFailure $failures 'lease.identityDigest does not match the materialized identity'
    }
  } catch {
    Add-OrphanlessFailure $failures 'lease identity digest could not be verified'
  }

  $state = 'INVALID'
  try {
    $issued = [datetimeoffset]::Parse((ConvertTo-OrphanlessUtcStamp -Value ([string](Get-OrphanlessField $Lease 'issuedAt'))))
    $expires = [datetimeoffset]::Parse((ConvertTo-OrphanlessUtcStamp -Value ([string](Get-OrphanlessField $Lease 'expiresAt'))))
    $observed = [datetimeoffset]::Parse((ConvertTo-OrphanlessUtcStamp -Value $At))
    if ($expires -le $issued) {
      Add-OrphanlessFailure $failures 'lease expiration must be later than issuance'
    } elseif ($observed -lt $issued) {
      Add-OrphanlessFailure $failures 'lease is not active before issuedAt'
    } elseif ($observed -ge $expires) {
      $state = 'EXPIRED'
    } else {
      $state = 'ACTIVE'
    }
  } catch {
    Add-OrphanlessFailure $failures 'lease timestamps must be ISO-8601 values'
  }

  if ($failures.Count -gt 0) { $state = 'INVALID' }
  return [pscustomobject]@{
    valid = ($failures.Count -eq 0)
    state = $state
    failures = @($failures)
  }
}

function New-OrphanlessFissionPlan {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$ParentProofId,
    [Parameter(Mandatory = $true)][string]$BlockerClass,
    [Parameter(Mandatory = $true)][string]$ProofGap,
    [Parameter(Mandatory = $true)][object[]]$Slices
  )

  if (-not (Test-OrphanlessOpaqueValue $ParentProofId) -or
      -not (Test-OrphanlessOpaqueValue $BlockerClass) -or
      -not (Test-OrphanlessOpaqueValue $ProofGap)) {
    throw 'Fission parent proof, blocker class, and proof gap must be public-safe values.'
  }
  if ($Slices.Count -eq 0) { throw 'Agent-solvable blockers require at least one fission slice.' }

  $seen = @{}
  $children = [System.Collections.Generic.List[object]]::new()
  foreach ($slice in @($Slices | Sort-Object { [string](Get-OrphanlessField $_ 'key') } -CaseSensitive)) {
    $key = [string](Get-OrphanlessField $slice 'key')
    $acceptance = [string](Get-OrphanlessField $slice 'acceptance')
    $ownerKey = [string](Get-OrphanlessField $slice 'ownerKey')
    $ownerMode = [string](Get-OrphanlessField $slice 'ownerMode')
    foreach ($value in @($key, $acceptance, $ownerKey, $ownerMode)) {
      if (-not (Test-OrphanlessOpaqueValue $value)) { throw 'Every fission slice requires public-safe key, acceptance, ownerKey, and ownerMode values.' }
    }
    if ($seen.ContainsKey($key)) { throw "Duplicate fission slice key: $key" }
    $seen[$key] = $true
    $seed = "$ParentProofId|$BlockerClass|$ProofGap|$key"
    $suffix = (Get-OrphanlessSha256 -Text $seed).Substring(0, 12).ToUpperInvariant()
    $children.Add([pscustomobject][ordered]@{
      proofId = "$ParentProofId-CHILD-$suffix"
      sliceKey = $key
      acceptance = $acceptance
      ownerKey = $ownerKey
      ownerMode = $ownerMode
    }) | Out-Null
  }
  return @($children)
}

function New-OrphanlessAction {
  param(
    [Parameter(Mandatory = $true)][string]$Type,
    [Parameter(Mandatory = $true)][string]$ProofId,
    [Parameter(Mandatory = $true)][string]$OwnerKey,
    [Parameter(Mandatory = $true)][string]$Gate,
    [string]$OwnerMode = ''
  )
  return [pscustomobject][ordered]@{
    type = $Type
    proofId = $ProofId
    ownerKey = $OwnerKey
    ownerMode = $OwnerMode
    gate = $Gate
  }
}

function Find-OrphanlessItem {
  param(
    [AllowNull()][object]$Items,
    [Parameter(Mandatory = $true)][string]$Field,
    [Parameter(Mandatory = $true)][string]$Value
  )
  foreach ($item in @($Items)) {
    if ([string](Get-OrphanlessField $item $Field) -eq $Value) { return $item }
  }
  return $null
}

function Find-OrphanlessItems {
  param(
    [AllowNull()][object]$Items,
    [Parameter(Mandatory = $true)][string]$Field,
    [Parameter(Mandatory = $true)][string]$Value
  )

  return @($Items | Where-Object { [string](Get-OrphanlessField $_ $Field) -eq $Value })
}

function Test-OrphanlessObservationNotFuture {
  param(
    [Parameter(Mandatory = $true)][object]$Evidence,
    [Parameter(Mandatory = $true)][string]$At
  )

  try {
    $evidenceAt = [datetimeoffset]::Parse((ConvertTo-OrphanlessUtcStamp -Value ([string](Get-OrphanlessField $Evidence 'observedAt'))))
    $controllerAt = [datetimeoffset]::Parse((ConvertTo-OrphanlessUtcStamp -Value $At))
    return ($evidenceAt -le $controllerAt)
  } catch {
    return $false
  }
}

function Find-OrphanlessOwnerLease {
  param(
    [AllowNull()][object]$Items,
    [Parameter(Mandatory = $true)][string]$ProofId,
    [Parameter(Mandatory = $true)][string]$OwnerKey
  )

  $matching = @($Items | Where-Object {
    [string](Get-OrphanlessField $_ 'proofId') -eq $ProofId -and
    [string](Get-OrphanlessField $_ 'ownerKey') -eq $OwnerKey
  } | Sort-Object @(
    @{ Expression = { [long](Get-OrphanlessField $_ 'revision') }; Descending = $true },
    @{ Expression = { [string](Get-OrphanlessField $_ 'leaseId') }; Descending = $false }
  ))
  if ($matching.Count -eq 0) { return $null }
  return $matching[0]
}

function Test-OrphanlessAdoption {
  param(
    [AllowNull()][object]$Adoption,
    [Parameter(Mandatory = $true)][string]$ParentProofId,
    [Parameter(Mandatory = $true)][string[]]$ChildProofIds,
    [Parameter(Mandatory = $true)][string[]]$ChildEvidenceObservedAt,
    [Parameter(Mandatory = $true)][string]$At
  )

  $failures = [System.Collections.Generic.List[string]]::new()
  if ($null -eq $Adoption) {
    Add-OrphanlessFailure $failures 'parent adoption record is missing'
  } else {
    if ([string](Get-OrphanlessField $Adoption 'status') -ne 'PASS') {
      Add-OrphanlessFailure $failures 'parent adoption status must be PASS'
    }
    if ([string](Get-OrphanlessField $Adoption 'parentProofId') -ne $ParentProofId) {
      Add-OrphanlessFailure $failures 'parent adoption must name the parent proof'
    }
    foreach ($field in @('adoptedBy', 'evidence')) {
      if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $Adoption $field))) {
        Add-OrphanlessFailure $failures "parent adoption $field is required and must be public-safe"
      }
    }
    $expected = @($ChildProofIds | Sort-Object -CaseSensitive)
    $actual = @(@(Get-OrphanlessField $Adoption 'childProofIds') | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)
    if (($expected -join "`n") -ne ($actual -join "`n")) {
      Add-OrphanlessFailure $failures 'parent adoption must reference the exact child proof set'
    }
    try {
      $adopted = [datetimeoffset]::Parse((ConvertTo-OrphanlessUtcStamp -Value ([string](Get-OrphanlessField $Adoption 'adoptedAt'))))
      $observed = [datetimeoffset]::Parse((ConvertTo-OrphanlessUtcStamp -Value $At))
      if ($adopted -gt $observed) { Add-OrphanlessFailure $failures 'parent adoption cannot occur after observedAt' }
      foreach ($childObservedAt in $ChildEvidenceObservedAt) {
        $childObserved = [datetimeoffset]::Parse((ConvertTo-OrphanlessUtcStamp -Value $childObservedAt))
        if ($adopted -lt $childObserved) {
          Add-OrphanlessFailure $failures 'parent adoption cannot occur before child evidence'
          break
        }
      }
    } catch {
      Add-OrphanlessFailure $failures 'parent adoption adoptedAt must be an ISO-8601 timestamp'
    }
  }

  return [pscustomobject]@{ valid = ($failures.Count -eq 0); failures = @($failures) }
}

function Complete-OrphanlessReceipt {
  param([Parameter(Mandatory = $true)][System.Collections.IDictionary]$Receipt)

  $digest = Get-OrphanlessSha256 -Text (ConvertTo-OrphanlessCanonicalJson -InputObject $Receipt)
  $completed = [ordered]@{}
  foreach ($key in $Receipt.Keys) { $completed[$key] = $Receipt[$key] }
  $completed.receiptDigest = $digest
  return [pscustomobject]$completed
}

function Invoke-OrphanlessReconcile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][object]$InputObject,
    [Parameter(Mandatory = $true)][string]$At
  )

  $observedAt = ConvertTo-OrphanlessUtcStamp -Value $At
  if ([string](Get-OrphanlessField $InputObject 'contractVersion') -ne '1.0') {
    throw 'contractVersion must be 1.0.'
  }
  if (-not (Test-OrphanlessOpaqueValue (Get-OrphanlessField $InputObject 'controllerKey'))) {
    throw 'controllerKey is required and must be public-safe.'
  }
  $desired = Get-OrphanlessField $InputObject 'desired'
  $actual = Get-OrphanlessField $InputObject 'actual'
  $proofId = [string](Get-OrphanlessField $desired 'proofId')
  $desiredState = [string](Get-OrphanlessField $desired 'state')
  if (-not (Test-OrphanlessOpaqueValue $proofId)) { throw 'desired.proofId is required and must be public-safe.' }
  if ($desiredState -notin @('RUNNING', 'BLOCKED')) { throw 'desired.state must be RUNNING or BLOCKED.' }

  $inputDigest = Get-OrphanlessSha256 -Text (ConvertTo-OrphanlessCanonicalJson -InputObject $InputObject)
  $actions = [System.Collections.Generic.List[object]]::new()
  $reasons = [System.Collections.Generic.List[string]]::new()
  $childProofs = @()
  $normalizedState = 'UNVERIFIED'
  $decision = 'REJECT_INVALID_INPUT'
  $adoptionAllowed = $false

  if ($desiredState -eq 'RUNNING') {
    $ownerKey = [string](Get-OrphanlessField $desired 'ownerKey')
    $ownerMode = [string](Get-OrphanlessField $desired 'ownerMode')
    if (-not (Test-OrphanlessOpaqueValue $ownerKey)) { throw 'RUNNING desired state requires a public-safe ownerKey.' }
    if (-not (Test-OrphanlessOpaqueValue $ownerMode)) { throw 'RUNNING desired state requires a public-safe ownerMode.' }
    $identities = @(Find-OrphanlessItems -Items (Get-OrphanlessField $actual 'identities') -Field 'ownerKey' -Value $ownerKey)
    if ($identities.Count -eq 0) {
      $normalizedState = 'WAITING_NATIVE_THREAD_MATERIALIZATION'
      $decision = 'ISSUE_NATIVE_OWNER'
      $reasons.Add('No identity envelope exists for the desired owner.') | Out-Null
      $actions.Add((New-OrphanlessAction -Type 'ISSUE_NATIVE_OWNER' -ProofId $proofId -OwnerKey $ownerKey -OwnerMode $ownerMode -Gate 'MATERIALIZED_IDENTITY_WITH_READBACK')) | Out-Null
    } elseif ($identities.Count -gt 1) {
      $normalizedState = 'BLOCKED_OWNER_EVIDENCE'
      $decision = 'REPAIR_OWNER_EVIDENCE'
      $reasons.Add('More than one identity envelope exists for the desired owner.') | Out-Null
      $actions.Add((New-OrphanlessAction -Type 'REPAIR_OWNER_EVIDENCE' -ProofId $proofId -OwnerKey $ownerKey -OwnerMode $ownerMode -Gate 'UNIQUE_OWNER_IDENTITY')) | Out-Null
    } else {
      $identity = $identities[0]
      $identityCheck = Test-OrphanlessIdentityEnvelope -Envelope $identity
      if ($identityCheck.state -eq 'WAITING_NATIVE_THREAD_MATERIALIZATION') {
        $normalizedState = 'WAITING_NATIVE_THREAD_MATERIALIZATION'
        $decision = 'READBACK_NATIVE_OWNER'
        $reasons.Add('A pending identity is not an active owner.') | Out-Null
        $actions.Add((New-OrphanlessAction -Type 'READBACK_NATIVE_OWNER' -ProofId $proofId -OwnerKey $ownerKey -OwnerMode $ownerMode -Gate 'MATERIALIZED_IDENTITY_WITH_READBACK')) | Out-Null
      } elseif (-not $identityCheck.valid) {
        $normalizedState = 'BLOCKED_OWNER_EVIDENCE'
        $decision = 'REPAIR_OWNER_EVIDENCE'
        foreach ($failure in @($identityCheck.failures)) { $reasons.Add([string]$failure) | Out-Null }
        $actions.Add((New-OrphanlessAction -Type 'REPAIR_OWNER_EVIDENCE' -ProofId $proofId -OwnerKey $ownerKey -Gate 'IDENTITY_ENVELOPE_PASS')) | Out-Null
      } elseif (-not (Test-OrphanlessObservationNotFuture -Evidence $identity -At $observedAt)) {
        $normalizedState = 'BLOCKED_OWNER_EVIDENCE'
        $decision = 'REPAIR_OWNER_EVIDENCE'
        $reasons.Add('The materialized identity observation is later than the controller observation.') | Out-Null
        $actions.Add((New-OrphanlessAction -Type 'REPAIR_OWNER_EVIDENCE' -ProofId $proofId -OwnerKey $ownerKey -Gate 'IDENTITY_OBSERVED_AT_NOT_FUTURE')) | Out-Null
      } elseif ([string](Get-OrphanlessField (Get-OrphanlessField $identity 'task') 'proofId') -ne $proofId) {
        $normalizedState = 'BLOCKED_OWNER_EVIDENCE'
        $decision = 'REPAIR_OWNER_EVIDENCE'
        $reasons.Add('The materialized identity is attached to a different proof.') | Out-Null
        $actions.Add((New-OrphanlessAction -Type 'REPAIR_OWNER_EVIDENCE' -ProofId $proofId -OwnerKey $ownerKey -Gate 'IDENTITY_TASK_PROOF_MATCH')) | Out-Null
      } else {
        $lease = Find-OrphanlessOwnerLease -Items (Get-OrphanlessField $actual 'leases') -ProofId $proofId -OwnerKey $ownerKey
        if ($null -eq $lease) {
          $normalizedState = 'LEASE_REQUIRED'
          $decision = 'ISSUE_OWNER_LEASE'
          $reasons.Add('A materialized owner requires a proof-scoped lease.') | Out-Null
          $actions.Add((New-OrphanlessAction -Type 'ISSUE_OWNER_LEASE' -ProofId $proofId -OwnerKey $ownerKey -Gate 'ACTIVE_PROOF_SCOPED_LEASE')) | Out-Null
        } else {
          $leaseCheck = Test-OrphanlessOwnerLease -Lease $lease -Identity $identity -ProofId $proofId -At $observedAt
          if ($leaseCheck.state -eq 'ACTIVE') {
            $normalizedState = 'ACTIVE'
            $decision = 'KEEP_OWNER_ACTIVE'
          } else {
            $normalizedState = $(if ($leaseCheck.state -eq 'EXPIRED') { 'LEASE_EXPIRED' } else { 'LEASE_REQUIRED' })
            $decision = 'RENEW_OWNER_LEASE'
            foreach ($failure in @($leaseCheck.failures)) { $reasons.Add([string]$failure) | Out-Null }
            if ($leaseCheck.state -eq 'EXPIRED') { $reasons.Add('The proof-scoped lease is expired.') | Out-Null }
            $actions.Add((New-OrphanlessAction -Type 'RENEW_OWNER_LEASE' -ProofId $proofId -OwnerKey $ownerKey -Gate 'ACTIVE_PROOF_SCOPED_LEASE')) | Out-Null
          }
        }
      }
    }
  } else {
    $blocker = Get-OrphanlessField $desired 'blocker'
    $blockerClass = [string](Get-OrphanlessField $blocker 'class')
    $proofGap = [string](Get-OrphanlessField $blocker 'proofGap')
    $agentSolvableValue = Get-OrphanlessField $blocker 'agentSolvable'
    $blockerInputValid = ((Test-OrphanlessOpaqueValue $blockerClass) -and
      (Test-OrphanlessOpaqueValue $proofGap) -and
      ($agentSolvableValue -is [bool]))
    if (-not $blockerInputValid) {
      $normalizedState = 'BLOCKED_FISSION_REQUIRED'
      $decision = 'REPAIR_FISSION_INPUT'
      $reasons.Add('BLOCKED desired state requires public-safe class/proofGap and a boolean agentSolvable value.') | Out-Null
      $actions.Add((New-OrphanlessAction -Type 'REPAIR_FISSION_INPUT' -ProofId $proofId -OwnerKey 'controller' -Gate 'VALID_BLOCKER_CLASSIFICATION')) | Out-Null
    } elseif (-not [bool]$agentSolvableValue) {
      $normalizedState = 'HUMAN_ONLY_BLOCKED'
      $decision = 'ESCALATE_HUMAN_ONLY_BLOCKER'
      $reasons.Add('The blocker is explicitly classified as human-only.') | Out-Null
    } else {
      $slices = @((Get-OrphanlessField $blocker 'fissionSlices'))
      try {
        $childProofs = @(New-OrphanlessFissionPlan -ParentProofId $proofId -BlockerClass $blockerClass -ProofGap $proofGap -Slices $slices)
      } catch {
        $normalizedState = 'BLOCKED_FISSION_REQUIRED'
        $decision = 'REPAIR_FISSION_INPUT'
        $reasons.Add($_.Exception.Message) | Out-Null
        $actions.Add((New-OrphanlessAction -Type 'REPAIR_FISSION_INPUT' -ProofId $proofId -OwnerKey 'controller' -Gate 'NONEMPTY_ATOMIC_FISSION_SLICES')) | Out-Null
      }

      if ($childProofs.Count -gt 0) {
        $completeCount = 0
        $completedEvidenceTimes = [System.Collections.Generic.List[string]]::new()
        foreach ($child in $childProofs) {
          $childId = [string]$child.proofId
          $ownerKey = [string]$child.ownerKey
          $identities = @(Find-OrphanlessItems -Items (Get-OrphanlessField $actual 'identities') -Field 'ownerKey' -Value $ownerKey)
          if ($identities.Count -eq 0) {
            $actions.Add((New-OrphanlessAction -Type 'ISSUE_NATIVE_OWNER' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'MATERIALIZED_IDENTITY_WITH_READBACK')) | Out-Null
            continue
          }
          if ($identities.Count -gt 1) {
            $actions.Add((New-OrphanlessAction -Type 'REPAIR_OWNER_EVIDENCE' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'UNIQUE_OWNER_IDENTITY')) | Out-Null
            continue
          }
          $identity = $identities[0]
          $identityCheck = Test-OrphanlessIdentityEnvelope -Envelope $identity
          if ($identityCheck.state -eq 'WAITING_NATIVE_THREAD_MATERIALIZATION') {
            $actions.Add((New-OrphanlessAction -Type 'READBACK_NATIVE_OWNER' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'MATERIALIZED_IDENTITY_WITH_READBACK')) | Out-Null
            continue
          }
          if (-not $identityCheck.valid) {
            $actions.Add((New-OrphanlessAction -Type 'REPAIR_OWNER_EVIDENCE' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'IDENTITY_ENVELOPE_PASS')) | Out-Null
            continue
          }
          if (-not (Test-OrphanlessObservationNotFuture -Evidence $identity -At $observedAt)) {
            $actions.Add((New-OrphanlessAction -Type 'REPAIR_OWNER_EVIDENCE' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'IDENTITY_OBSERVED_AT_NOT_FUTURE')) | Out-Null
            continue
          }
          if ([string](Get-OrphanlessField (Get-OrphanlessField $identity 'task') 'proofId') -ne $childId) {
            $actions.Add((New-OrphanlessAction -Type 'REPAIR_OWNER_EVIDENCE' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'IDENTITY_TASK_PROOF_MATCH')) | Out-Null
            continue
          }
          $lease = Find-OrphanlessOwnerLease -Items (Get-OrphanlessField $actual 'leases') -ProofId $childId -OwnerKey $ownerKey
          if ($null -eq $lease) {
            $actions.Add((New-OrphanlessAction -Type 'ISSUE_OWNER_LEASE' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'ACTIVE_PROOF_SCOPED_LEASE')) | Out-Null
            continue
          }
          $outcome = Find-OrphanlessItem -Items (Get-OrphanlessField $actual 'childProofs') -Field 'proofId' -Value $childId
          $outcomePass = ($null -ne $outcome -and
            [string](Get-OrphanlessField $outcome 'state') -eq 'PASS' -and
            [string](Get-OrphanlessField $outcome 'evidenceStatus') -eq 'PASS' -and
            (Test-OrphanlessOpaqueValue (Get-OrphanlessField $outcome 'evidence')))
          $leaseObservationAt = $observedAt
          if ($outcomePass) {
            try {
              $outcomeObservedAt = ConvertTo-OrphanlessUtcStamp -Value ([string](Get-OrphanlessField $outcome 'observedAt'))
              if ([datetimeoffset]::Parse($outcomeObservedAt) -gt [datetimeoffset]::Parse($observedAt)) {
                $outcomePass = $false
              } else {
                $leaseObservationAt = $outcomeObservedAt
              }
            } catch {
              $outcomePass = $false
            }
          }
          $leaseCheck = Test-OrphanlessOwnerLease -Lease $lease -Identity $identity -ProofId $childId -At $leaseObservationAt
          if ($leaseCheck.state -ne 'ACTIVE') {
            $actions.Add((New-OrphanlessAction -Type 'RENEW_OWNER_LEASE' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'ACTIVE_PROOF_SCOPED_LEASE')) | Out-Null
            continue
          }
          if (-not $outcomePass) {
            $actions.Add((New-OrphanlessAction -Type 'CONTINUE_CHILD_PROOF' -ProofId $childId -OwnerKey $ownerKey -OwnerMode ([string]$child.ownerMode) -Gate 'CHILD_PROOF_AND_EVIDENCE_PASS')) | Out-Null
            continue
          }
          $completeCount++
          $completedEvidenceTimes.Add($leaseObservationAt) | Out-Null
        }

        if ($completeCount -ne $childProofs.Count) {
          $normalizedState = 'BLOCKED_FISSION_IN_PROGRESS'
          $decision = 'DISPATCH_OR_CONTINUE_CHILD_PROOFS'
          $reasons.Add("Completed child proofs: $completeCount/$($childProofs.Count).") | Out-Null
        } else {
          $childIds = @($childProofs | ForEach-Object { [string]$_.proofId })
          $adoption = Test-OrphanlessAdoption -Adoption (Get-OrphanlessField $actual 'adoption') -ParentProofId $proofId -ChildProofIds $childIds -ChildEvidenceObservedAt @($completedEvidenceTimes) -At $observedAt
          if ($adoption.valid) {
            $normalizedState = 'ADOPTED'
            $decision = 'ACCEPT_ADOPTED_CHILD_EVIDENCE'
            $adoptionAllowed = $true
          } else {
            $normalizedState = 'READY_FOR_PARENT_ADOPTION'
            $decision = 'RECORD_PARENT_ADOPTION'
            foreach ($failure in @($adoption.failures)) { $reasons.Add([string]$failure) | Out-Null }
            $actions.Add((New-OrphanlessAction -Type 'RECORD_PARENT_ADOPTION' -ProofId $proofId -OwnerKey 'parent-controller' -Gate 'EXACT_CHILD_SET_ADOPTION_PASS')) | Out-Null
          }
        }
      }
    }
  }

  $receipt = [ordered]@{
    receiptVersion = '1.0'
    proofId = $proofId
    observedAt = $observedAt
    desiredState = $desiredState
    normalizedState = $normalizedState
    decision = $decision
    adoptionAllowed = $adoptionAllowed
    inputDigest = $inputDigest
    childProofs = @($childProofs)
    actions = @($actions)
    reasons = @($reasons)
  }
  return Complete-OrphanlessReceipt -Receipt $receipt
}

Export-ModuleMember -Function @(
  'ConvertTo-OrphanlessCanonicalJson',
  'Test-OrphanlessIdentityEnvelope',
  'Get-OrphanlessIdentityDigest',
  'New-OrphanlessOwnerLease',
  'Test-OrphanlessOwnerLease',
  'New-OrphanlessFissionPlan',
  'Invoke-OrphanlessReconcile'
)
