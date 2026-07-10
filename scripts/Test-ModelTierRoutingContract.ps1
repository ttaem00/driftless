#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Validates the public provider-detachable model-tier routing contract.

.DESCRIPTION
  Checks the real shared registry and runs isolated fixtures for the four
  failure modes that must never become a silent workflow default: frontier
  inheritance, stale provider-style literals, missing issuance provenance, and
  unjustified escalation. It is static by design: no model calls, credentials,
  billing, host-global homes, or vendor router are involved.
#>
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-Result {
  param([System.Collections.Generic.List[object]]$Rows, [string]$Check, [string]$Status, [string]$Evidence)
  $Rows.Add([pscustomobject]@{ check = $Check; status = $Status; evidence = $Evidence }) | Out-Null
}

function Test-Issuance {
  param([object]$Registry, [hashtable]$Record)
  foreach ($field in @($Registry.issuanceProvenance)) {
    if (-not $Record.ContainsKey([string]$field) -or [string]::IsNullOrWhiteSpace([string]$Record[[string]$field])) {
      return "missing provenance field: $field"
    }
  }
  $role = [string]$Record.routeRole
  if (-not $Registry.roles.PSObject.Properties.Name.Contains($role)) { return "unknown route role: $role" }
  $tier = [string]$Registry.roles.$role.tier
  $selectedModel = [string]$Record.selectedModel
  $tierAliases = @($Registry.tiers.$tier.modelAliases | ForEach-Object { [string]$_ })
  if ($selectedModel -notin $tierAliases) { return "selected model does not belong to role tier: role=$role; tier=$tier" }
  if ($tier -eq 'frontier') {
    $reason = [string]$Record.escalationReason
    if ($reason -eq 'not_escalated' -or $reason -notin @($Registry.escalation.allowedReasons)) { return 'frontier requires an allowed escalation reason' }
    if (-not $Record.ContainsKey('namedRisk') -or [string]::IsNullOrWhiteSpace([string]$Record.namedRisk)) { return 'frontier requires named risk evidence' }
    if (-not $Record.ContainsKey('qualityEvidence') -or [string]::IsNullOrWhiteSpace([string]$Record.qualityEvidence)) { return 'frontier requires quality evidence' }
  }
  return $null
}

$repoRoot = (Resolve-Path -LiteralPath $Root).Path
$registryPath = Join-Path $repoRoot 'profiles\shared\schemas\model-tier-routing.json'
$docPath = Join-Path $repoRoot 'docs\en\model-tier-routing.md'
$rows = [System.Collections.Generic.List[object]]::new()

if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) { throw "Missing registry: $registryPath" }
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json

$requiredTiers = @('fast', 'value', 'frontier')
$requiredRoles = @('scout', 'mechanical_worker', 'implementation_worker', 'reviewer', 'final_authority')
$tiersOk = @($requiredTiers | Where-Object { -not $registry.tiers.PSObject.Properties.Name.Contains($_) }).Count -eq 0
$rolesOk = @($requiredRoles | Where-Object { -not $registry.roles.PSObject.Properties.Name.Contains($_) }).Count -eq 0
$routingOk = $tiersOk -and $rolesOk -and $registry.roles.scout.tier -eq 'fast' -and $registry.roles.mechanical_worker.tier -eq 'fast' -and $registry.roles.implementation_worker.tier -eq 'value' -and $registry.roles.final_authority.tier -eq 'frontier'
Add-Result $rows 'Shared role defaults are provider-detachable' $(if ($routingOk) { 'PASS' } else { 'FAIL' }) 'required roles map to fast/value/frontier without provider IDs'

$fields = @($registry.issuanceProvenance)
$provenanceOk = @('routeRole', 'selectedModel', 'contextBudget', 'reasoningBudget', 'escalationReason' | Where-Object { $_ -notin $fields }).Count -eq 0
Add-Result $rows 'Issuance provenance contract' $(if ($provenanceOk) { 'PASS' } else { 'FAIL' }) ('fields=' + ($fields -join ','))

$docsOk = (Test-Path -LiteralPath $docPath -PathType Leaf) -and ((Get-Content -LiteralPath $docPath -Raw -Encoding UTF8) -match 'cost, quality, latency, cache, and availability')
Add-Result $rows 'Public trade-off and rollback documentation' $(if ($docsOk) { 'PASS' } else { 'FAIL' }) 'shared documentation names volatile inputs and role-mapping rollback'

$routingSurfaces = @(
  (Join-Path $repoRoot 'profiles\shared\skills\mission-control\SKILL.md'),
  (Join-Path $repoRoot 'profiles\claude\README.md'),
  (Join-Path $repoRoot 'profiles\codex\README.md')
)
$literalHits = @($routingSurfaces | Select-String -Pattern '(?i)\b(gpt-[a-z0-9._-]+|claude-[a-z0-9._-]+|gemini-[a-z0-9._-]+)\b' -ErrorAction SilentlyContinue)
Add-Result $rows 'No stale provider-style model literals in routing adapters' $(if ($literalHits.Count -eq 0) { 'PASS' } else { 'FAIL' }) $(if ($literalHits.Count -eq 0) { 'hits=0' } else { 'hits=' + (($literalHits | Select-Object -First 3 | ForEach-Object Path) -join ',') })

$fixtureRoot = Join-Path $repoRoot 'scripts\fixtures\model-tier-routing'
$fixturePaths = @(Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
if ($fixturePaths.Count -lt 5) {
  Add-Result $rows 'Executable routing fixtures present' 'FAIL' "expected_at_least=5; actual=$($fixturePaths.Count)"
}
foreach ($fixturePath in $fixturePaths) {
  $fixture = Get-Content -LiteralPath $fixturePath.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($fixture.PSObject.Properties['kind'] -and [string]$fixture.kind -eq 'stale_literal') {
    $staleCaught = [string]$fixture.literal -match '(?i)\b(gpt-[a-z0-9._-]+|claude-[a-z0-9._-]+|gemini-[a-z0-9._-]+)\b'
    $passed = if ([string]$fixture.expect -eq 'reject') { $staleCaught } else { -not $staleCaught }
    Add-Result $rows ('Fixture: ' + [string]$fixture.name) $(if ($passed) { 'PASS' } else { 'FAIL' }) 'provider-style stale literal detector evaluated fixture'
    continue
  }
  $record = @{}
  foreach ($property in $fixture.record.PSObject.Properties) { $record[$property.Name] = [string]$property.Value }
  $failure = Test-Issuance -Registry $registry -Record $record
  $expectsReject = [string]$fixture.expect -eq 'reject'
  $passed = if ($expectsReject) { $null -ne $failure } else { $null -eq $failure }
  Add-Result $rows ('Fixture: ' + [string]$fixture.name) $(if ($passed) { 'PASS' } else { 'FAIL' }) $(if ($failure) { $failure } else { 'accepted' })
}

$failures = @($rows | Where-Object { $_.status -ne 'PASS' })
$summary = [pscustomobject]@{ gate = 'Model tier routing contract'; root = $repoRoot; overall = $(if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }); results = @($rows) }
if ($Json) { $summary | ConvertTo-Json -Depth 6 } else { $rows | ForEach-Object { Write-Output ('[{0}] {1} - {2}' -f $_.status, $_.check, $_.evidence) }; Write-Output ('RESULT: ' + $summary.overall) }
if ($failures.Count -gt 0) { exit 1 }
