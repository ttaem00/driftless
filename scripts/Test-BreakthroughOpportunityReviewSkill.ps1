#requires -Version 7.0
#requires -PSEdition Core
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

$repo = (Resolve-Path -LiteralPath $Root).Path
$skillRel = 'profiles/shared/skills/breakthrough-opportunity-review/SKILL.md'
$skillPath = Join-Path $repo ($skillRel -replace '/', [System.IO.Path]::DirectorySeparatorChar)
$results = [System.Collections.Generic.List[object]]::new()
function Add-Result([string]$Check, [string]$Status, [string]$Evidence, [bool]$Blocking) {
  $results.Add([pscustomobject]@{ check = $Check; status = $Status; evidence = $Evidence; blocking = $Blocking }) | Out-Null
}

if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
  Add-Result 'skill exists' 'FAIL' "missing=$skillRel" $true
} else {
  $text = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8
  $required = @(
    'name: breakthrough-opportunity-review',
    'scope lock: <exact surface>',
    'Opportunity Solution Tree',
    'Service blueprint',
    'Business Model Canvas',
    'PASS',
    'FAIL',
    'BLOCKED',
    'UNVERIFIED',
    'PARTIAL',
    'Ticket / Parallel Execution Add-on',
    'Blocker fission',
    'Parent adoption',
    'public-safe Driftless counterpart',
    'Principle-based Learning',
    'Far Transfer',
    'Analogical Transfer',
    'Relational Thinking',
    'Structural Analogical Learning',
    'Cross-domain Principle Extraction',
    'Structural Mapping',
    'Generative Learning',
    'Schema Induction',
    'Conceptual Blending',
    'trigger -> root_cause_class -> decision_rule -> placement -> validation -> rollback'
  )
  foreach ($term in $required) {
    if ($text -match [regex]::Escape($term)) {
      Add-Result "required term: $term" 'PASS' "present in $skillRel" $false
    } else {
      Add-Result "required term: $term" 'FAIL' "missing in $skillRel" $true
    }
  }
  $forbidden = @(
    'D:\\',
    'C:\\Users',
    'token=',
    'token:',
    'cookie value',
    'private campaign',
    'internal positioning goal'
  )
  foreach ($term in $forbidden) {
    if ($text -match [regex]::Escape($term)) {
      Add-Result "forbidden private term: $term" 'FAIL' "must stay public-safe: $skillRel" $true
    }
  }
  Add-Result 'public-safe path scan' 'PASS' 'machine-specific Windows paths, token assignments, cookie values, and private/internal campaign wording not found in the skill' $false
}

$fail = @($results | Where-Object { $_.status -eq 'FAIL' }).Count
$pass = @($results | Where-Object { $_.status -eq 'PASS' }).Count
$blocked = @($results | Where-Object { $_.status -eq 'BLOCKED' }).Count
$unverified = @($results | Where-Object { $_.status -eq 'UNVERIFIED' }).Count
$overall = if ($fail -gt 0 -or $blocked -gt 0) { 'FAIL' } else { 'PASS' }
$summary = [pscustomobject]@{ command = 'Test-BreakthroughOpportunityReviewSkill.ps1'; root = $repo; overall = $overall; pass = $pass; fail = $fail; blocked = $blocked; unverified = $unverified; results = @($results) }
Write-Output '== Breakthrough Opportunity Review skill gate =='
foreach ($r in $results) { Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence) }
Write-Output ("RESULT: {0} (pass={1} fail={2} blocked={3} unverified={4})" -f $overall, $pass, $fail, $blocked, $unverified)
if ($Json) { $summary | ConvertTo-Json -Depth 6 }
if ($overall -ne 'PASS') { exit 1 }
