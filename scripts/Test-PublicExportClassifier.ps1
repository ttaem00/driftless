#requires -Version 7.2
#requires -PSEdition Core
<#
.SYNOPSIS
  Classify candidate text before copying it into a public Driftless surface.

.DESCRIPTION
  This is a small, public-safe pre-publication classifier. It does not read
  credentials, browser profiles, private agent homes, or forbidden files. It
  scans only explicit -Text input or a bounded local -Path and classifies the
  candidate as public-safe, shared-internal, sanitize-first, private-only, or
  manager-only-decision.

  Classification is a routing decision, not permission to publish. Only
  public-safe exits 0. Every other class exits 1 and names the next action.
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
  [Parameter(ParameterSetName = 'Path')]
  [string]$Path = '',

  [Parameter(ParameterSetName = 'Text')]
  [string]$Text = '',

  [int]$MaxFiles = 50,
  [switch]$SelfTest,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

function Get-RepoRoot {
  try {
    $root = (& git rev-parse --show-toplevel 2>$null).Trim()
    if ($root) { return $root }
  } catch { }
  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

function Read-TextLinesIfSafe {
  param([Parameter(Mandatory = $true)][string]$File)
  try {
    $item = Get-Item -LiteralPath $File -ErrorAction Stop
    if ($item.Length -gt 1MB) { return $null }
    $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
    if ($bytes -contains 0) { return $null }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return @($text -split "`r?`n")
  } catch {
    return $null
  }
}

function Get-CandidateTexts {
  param([string]$CandidatePath, [string]$CandidateText, [int]$Limit)
  $rows = [System.Collections.Generic.List[object]]::new()
  $truncated = $false

  if ($CandidateText) {
    $rows.Add([pscustomobject]@{ source = '<text>'; line = 1; text = $CandidateText }) | Out-Null
    return [pscustomobject]@{ rows = @($rows); truncated = $false }
  }

  if (-not $CandidatePath) {
    return [pscustomobject]@{ rows = @(); truncated = $false }
  }
  if (-not (Test-Path -LiteralPath $CandidatePath)) {
    throw "Path not found: $CandidatePath"
  }

  $targetExts = @('.md', '.txt', '.json', '.yaml', '.yml', '.ps1', '.psm1')
  if (Test-Path -LiteralPath $CandidatePath -PathType Leaf) {
    $files = @((Resolve-Path -LiteralPath $CandidatePath).Path)
  } else {
    $items = @(Get-ChildItem -LiteralPath $CandidatePath -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $targetExts -contains $_.Extension.ToLowerInvariant() } |
      Select-Object -First ($Limit + 1))
    if ($items.Count -gt $Limit) {
      $truncated = $true
      $items = @($items | Select-Object -First $Limit)
    }
    $files = @($items | ForEach-Object { $_.FullName })
  }

  foreach ($file in $files) {
    $lines = Read-TextLinesIfSafe -File $file
    if ($null -eq $lines) { continue }
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $rows.Add([pscustomobject]@{ source = $file; line = ($i + 1); text = [string]$lines[$i] }) | Out-Null
    }
  }
  return [pscustomobject]@{ rows = @($rows); truncated = $truncated }
}

function Get-ForbiddenRules {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)
  $rulesPath = Join-Path $RepoRoot 'profiles/shared/schemas/forbidden-paths.json'
  if (-not (Test-Path -LiteralPath $rulesPath -PathType Leaf)) { return @() }
  try {
    $parsed = Get-Content -LiteralPath $rulesPath -Raw -Encoding UTF8 | ConvertFrom-Json
    return @($parsed.rules | Where-Object { $_.refRegex })
  } catch {
    return @()
  }
}

function Add-Finding {
  param(
    [System.Collections.Generic.List[object]]$Findings,
    [string]$Class,
    [string]$Id,
    [string]$Reason,
    [string]$Source,
    [int]$Line
  )
  $Findings.Add([pscustomobject]@{
      class = $Class
      id = $Id
      reason = $Reason
      source = $Source
      line = $Line
      sample = '[REDACTED]'
    }) | Out-Null
}

function Test-Pattern {
  param([string]$Pattern, [string]$Text)
  try {
    return [regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  } catch {
    return $false
  }
}

function Invoke-Classifier {
  param([string]$CandidatePath, [string]$CandidateText, [int]$Limit)
  $repoRoot = Get-RepoRoot
  $candidate = Get-CandidateTexts -CandidatePath $CandidatePath -CandidateText $CandidateText -Limit $Limit
  $findings = [System.Collections.Generic.List[object]]::new()

  if (@($candidate.rows).Count -eq 0) {
    Add-Finding $findings 'blocked' 'empty_input' 'No text was provided to classify.' '<input>' 0
  }

  $rules = Get-ForbiddenRules -RepoRoot $repoRoot
  $machinePathPattern = '([A-Za-z]:[\\/][^\s]+|/(Users|home)/[A-Za-z0-9._-]+/[^\s]+)'
  $credentialLabelPattern = '(API[_ -]?KEY|SECRET|TOKEN|PASSWORD|PRIVATE[_ -]?KEY|CLIENT[_ -]?SECRET|ACCESS[_ -]?TOKEN|REFRESH[_ -]?TOKEN|DATABASE[_ -]?URL)'
  $rawLogPattern = '(raw chat transcript|raw session log|conversation history dump|debug log with user data|unredacted stack trace)'
  $customerDataPattern = '(customer data|student record|private user data|personal email|phone number|home address)'
  $privatePolicyPattern = '(private runtime note|internal campaign|nonpublic strategy|private manager directive)'
  $managerOnlyPattern = '(public release|publish publicly|copy to public repo|copy to driftless|announce publicly)'
  $sharedInternalPattern = '(shared-internal|internal rollout|maintainer-only note|team-only workflow)'

  foreach ($row in @($candidate.rows)) {
    $line = [string]$row.text
    if (-not $line) { continue }

    foreach ($rule in $rules) {
      if (Test-Pattern -Pattern ([string]$rule.refRegex) -Text $line) {
        $class = if ($rule.kind -eq 'secret') { 'private-only' } else { 'sanitize-first' }
        Add-Finding $findings $class ([string]$rule.id) ([string]$rule.reason) ([string]$row.source) ([int]$row.line)
      }
    }
    if (Test-Pattern -Pattern $machinePathPattern -Text $line) {
      Add-Finding $findings 'sanitize-first' 'machine_path' 'Machine-specific absolute path must be removed or generalized.' ([string]$row.source) ([int]$row.line)
    }
    if (Test-Pattern -Pattern $credentialLabelPattern -Text $line) {
      Add-Finding $findings 'sanitize-first' 'credential_label' 'Credential labels are allowed only after values and provider-specific details are removed.' ([string]$row.source) ([int]$row.line)
    }
    if (Test-Pattern -Pattern $rawLogPattern -Text $line) {
      Add-Finding $findings 'private-only' 'raw_log' 'Raw logs or transcripts should not be copied into a public repo.' ([string]$row.source) ([int]$row.line)
    }
    if (Test-Pattern -Pattern $customerDataPattern -Text $line) {
      Add-Finding $findings 'private-only' 'customer_data' 'Customer or student data is private-only.' ([string]$row.source) ([int]$row.line)
    }
    if (Test-Pattern -Pattern $privatePolicyPattern -Text $line) {
      Add-Finding $findings 'private-only' 'private_policy' 'Private operational policy is not public-safe.' ([string]$row.source) ([int]$row.line)
    }
    if (Test-Pattern -Pattern $managerOnlyPattern -Text $line) {
      Add-Finding $findings 'manager-only-decision' 'public_release' 'Publishing or copying to a public repo is a manager-only decision.' ([string]$row.source) ([int]$row.line)
    }
    if (Test-Pattern -Pattern $sharedInternalPattern -Text $line) {
      Add-Finding $findings 'shared-internal' 'internal_scope' 'Internal workflow material can be useful, but is not public-safe until rewritten for public users.' ([string]$row.source) ([int]$row.line)
    }
  }

  if ($candidate.truncated) {
    Add-Finding $findings 'blocked' 'truncated_scan' "Scan stopped at MaxFiles=$Limit." '<scan>' 0
  }

  $classes = @($findings | Select-Object -ExpandProperty class -Unique)
  $classification = 'public-safe'
  if ($classes -contains 'private-only') {
    $classification = 'private-only'
  } elseif ($classes -contains 'manager-only-decision') {
    $classification = 'manager-only-decision'
  } elseif ($classes -contains 'sanitize-first') {
    $classification = 'sanitize-first'
  } elseif ($classes -contains 'shared-internal') {
    $classification = 'shared-internal'
  } elseif ($classes -contains 'blocked') {
    $classification = 'blocked'
  }

  $next = switch ($classification) {
    'public-safe' { 'Candidate can be considered for public docs or examples after normal review.' }
    'shared-internal' { 'Rewrite for a public audience or keep it inside maintainer-only notes.' }
    'sanitize-first' { 'Remove paths, credential labels, private references, and rerun the classifier.' }
    'private-only' { 'Do not publish. Create a sanitized derivative instead.' }
    'manager-only-decision' { 'Ask the maintainer before publishing or copying to a public repo.' }
    default { 'Provide candidate text or a bounded path and rerun.' }
  }

  return [pscustomobject]@{
    gate = 'public-export-classifier'
    classification = $classification
    status = if ($classification -eq 'public-safe') { 'PASS' } else { 'BLOCKED' }
    checked_lines = @($candidate.rows).Count
    finding_count = $findings.Count
    findings = @($findings | Select-Object -First 50)
    next_action = $next
  }
}

function Assert-Class {
  param([string]$Name, [string]$TextValue, [string]$Expected)
  $result = Invoke-Classifier -CandidatePath '' -CandidateText $TextValue -Limit 50
  if ($result.classification -ne $Expected) {
    throw ("SelfTest {0} expected {1}, got {2}: {3}" -f $Name, $Expected, $result.classification, ($result | ConvertTo-Json -Compress -Depth 6))
  }
}

function Invoke-SelfTest {
  $slash = [char]92
  $machinePath = 'C:' + $slash + 'Users' + $slash + 'Student' + $slash + 'project'
  $credLabel = 'API' + '_KEY=' + '<redacted>'

  Assert-Class 'public-safe' 'Reusable validation pattern for public maintainers; no private details.' 'public-safe'
  Assert-Class 'shared-internal' 'shared-internal maintainer-only note for rollout sequencing.' 'shared-internal'
  Assert-Class 'sanitize-first' "Remove $machinePath and $credLabel before publishing." 'sanitize-first'
  Assert-Class 'private-only' 'raw chat transcript with customer data should never be copied.' 'private-only'
  Assert-Class 'manager-only-decision' 'Request to copy to public repo after approval.' 'manager-only-decision'
  $empty = Invoke-Classifier -CandidatePath '' -CandidateText '' -Limit 50
  if ($empty.classification -ne 'blocked') {
    throw "SelfTest empty input expected blocked, got $($empty.classification)"
  }

  Write-Output 'PASS Test-PublicExportClassifier self-test'
  exit 0
}

if ($SelfTest) {
  Invoke-SelfTest
}

$result = Invoke-Classifier -CandidatePath $Path -CandidateText $Text -Limit $MaxFiles
if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  Write-Output ("STATE: {0} ({1})" -f $result.classification, $result.status)
  Write-Output ("checked_lines={0}; findings={1}" -f $result.checked_lines, $result.finding_count)
  foreach ($finding in @($result.findings | Select-Object -First 10)) {
    Write-Output ("[{0}] {1}:{2} {3} - {4}" -f $finding.class, $finding.source, $finding.line, $finding.id, $finding.reason)
  }
  Write-Output ("next: {0}" -f $result.next_action)
}

if ($result.status -eq 'PASS') { exit 0 }
exit 1
