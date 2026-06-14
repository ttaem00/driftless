#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Driftless context-engineering discipline gate.

.DESCRIPTION
  Verifies that Driftless keeps public, shared context-management guidance in a
  single contract and wires that guidance into normal gates. This prevents a
  common failure mode: compressing or pruning skills/docs until load-bearing
  constraints disappear, or adding more hot text instead of keeping context
  small and verifiable.

  The gate is structural evidence. It does not claim a workflow behaved well; it
  proves the shared public contract still contains the four context disciplines
  and that this gate is documented as a local closeout gate.

  Read-only. No network, no secrets, no peer AI, no host-global access.
  ASCII-only so the gate parses under PowerShell 7.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$SelfTest,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$Command = 'Test-ContextEngineeringDiscipline.ps1'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$List,
    [string]$Check,
    [string]$Status,
    [bool]$Blocking,
    [string]$Evidence,
    [string]$NextAction = ''
  )
  $List.Add([pscustomobject]@{
      check = $Check
      status = $Status
      blocking = $Blocking
      evidence = $Evidence
      next_action = $NextAction
    }) | Out-Null
}

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Test-Anchors {
  param([string]$Text, [string[]]$Anchors)
  $missing = [System.Collections.Generic.List[string]]::new()
  foreach ($anchor in $Anchors) {
    if ($Text -notlike ('*' + $anchor + '*')) {
      $missing.Add($anchor) | Out-Null
    }
  }
  return @($missing)
}

function Invoke-SelfTest {
  $failures = [System.Collections.Generic.List[string]]::new()
  $anchors = @(
    'Context budget',
    'Compressed reference integrity',
    'Repo map freshness',
    'Action/evidence ledger',
    'UNVERIFIED',
    'stale map'
  )

  $clean = @'
Context budget
Compressed reference integrity
Repo map freshness
Action/evidence ledger
Mark missing proof UNVERIFIED.
Do not trust a stale map.
'@
  $cleanMissing = Test-Anchors -Text $clean -Anchors $anchors
  if ($cleanMissing.Count -ne 0) {
    $failures.Add('positive fixture unexpectedly missed context anchors') | Out-Null
  }

  $broken = @'
Context budget
Repo map freshness
'@
  $brokenMissing = Test-Anchors -Text $broken -Anchors $anchors
  if ($brokenMissing.Count -lt 1) {
    $failures.Add('negative fixture did not report missing context anchors') | Out-Null
  }

  return [pscustomobject]@{
    passed = ($failures.Count -eq 0)
    failures = @($failures)
    detail = ("clean_missing={0}; broken_missing={1}" -f $cleanMissing.Count, $brokenMissing.Count)
  }
}

if ($SelfTest) {
  $st = Invoke-SelfTest
  Write-Output '== Driftless context-engineering discipline gate: built-in self-test =='
  Write-Output ("detector: {0}" -f $st.detail)
  if ($st.passed) {
    Write-Output 'RESULT: PASS (anchor detector PASSes clean and FAILs planted missing anchors)'
    if ($Json) {
      [pscustomobject]@{ gate = 'context-engineering-discipline'; mode = 'self-test'; overall = 'PASS'; detail = $st.detail } | ConvertTo-Json -Depth 4
    }
    exit 0
  }
  Write-Output ('RESULT: FAIL - ' + (@($st.failures) -join '; '))
  if ($Json) {
    [pscustomobject]@{ gate = 'context-engineering-discipline'; mode = 'self-test'; overall = 'FAIL'; failures = @($st.failures); detail = $st.detail } | ConvertTo-Json -Depth 4
  }
  exit 1
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

$contractAnchors = @(
  '## 9. Context engineering discipline',
  'Context budget',
  'Compressed reference integrity',
  'Repo map freshness',
  'Action/evidence ledger',
  'always-loaded instructions short',
  'source pointer',
  'important exclusions',
  'UNVERIFIED',
  'stale',
  'current command or tool evidence'
)

$readmeAnchors = @(
  'Test-ContextEngineeringDiscipline.ps1',
  'context budget',
  'compressed reference integrity',
  'repo map freshness',
  'action/evidence ledger'
)

$handoffGuardAnchors = @(
  'Compressed references',
  'source pointer',
  'scope',
  'exclusions',
  'verification evidence',
  'repo map',
  'refresh trigger',
  'mark it stale'
)

$workLedgerAnchors = @(
  'Action/Evidence Ledger',
  'Action',
  'Evidence',
  'Next action',
  'latest action',
  'next executable action'
)

function Add-FileAnchorCheck {
  param(
    [string]$Check,
    [string]$RelPath,
    [string[]]$Anchors,
    [string]$NextAction
  )
  $path = Join-Path $resolvedRoot ($RelPath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Result $results $Check 'FAIL' $true "missing=$RelPath" $NextAction
    return
  }
  $missing = Test-Anchors -Text (Read-Utf8 $path) -Anchors $Anchors
  $status = if ($missing.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "anchors=$($Anchors.Count); missing=$($missing.Count)"
  if ($missing.Count -gt 0) { $evidence += '; missing_anchors=' + ($missing -join ', ') }
  Add-Result $results $Check $status $true $evidence $NextAction
}

function Add-ChildGateCheck {
  param(
    [string]$Check,
    [string]$RelPath,
    [string[]]$Arguments,
    [string]$NextAction
  )
  $path = Join-Path $resolvedRoot ($RelPath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Add-Result $results $Check 'FAIL' $true "missing=$RelPath" $NextAction
    return
  }
  $powershell = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
  if (-not $powershell) { $powershell = (Get-Command pwsh -ErrorAction Stop).Source }
  $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $path @Arguments 2>&1
  $exit = $LASTEXITCODE
  $status = if ($exit -eq 0) { 'PASS' } else { 'FAIL' }
  $detail = (@($output) | ForEach-Object { [string]$_ } | Where-Object { $_ -match '^\[(FAIL|PASS)\]|^RESULT:' } | Select-Object -First 5) -join ' | '
  $evidence = "exit=$exit"
  if ($detail) { $evidence += "; $detail" }
  Add-Result $results $Check $status $true $evidence $NextAction
}

$st = Invoke-SelfTest
$selfTestStatus = if ($st.passed) { 'PASS' } else { 'FAIL' }
Add-Result $results 'Detector self-test' $selfTestStatus $true $st.detail 'Fix the built-in positive/negative fixtures before trusting this gate.'

Add-FileAnchorCheck `
  -Check 'Shared context-engineering contract' `
  -RelPath 'profiles/shared/contract/SHARED_DESIGN_CONTRACT.md' `
  -Anchors $contractAnchors `
  -NextAction 'Restore section 9 so compressed context preserves source, scope, exclusions, freshness, and evidence.'

Add-FileAnchorCheck `
  -Check 'Scripts README documents the context-engineering gate' `
  -RelPath 'scripts/README.md' `
  -Anchors $readmeAnchors `
  -NextAction 'Document how maintainers run Test-ContextEngineeringDiscipline.ps1 and what it protects.'

Add-FileAnchorCheck `
  -Check 'Handoff guard preserves compressed references and repo-map freshness' `
  -RelPath 'profiles/shared/skills/handoff-guard/SKILL.md' `
  -Anchors $handoffGuardAnchors `
  -NextAction 'Restore handoff guidance for compressed reference integrity and repo-map freshness.'

Add-FileAnchorCheck `
  -Check 'Work ledger carries current action/evidence state' `
  -RelPath 'profiles/shared/skills/work-ledger/SKILL.md' `
  -Anchors $workLedgerAnchors `
  -NextAction 'Restore the Action/Evidence Ledger shape for long, resumed, or multi-issue work.'

Add-ChildGateCheck `
  -Check 'Compressed handoff summary protocol fixture' `
  -RelPath 'scripts/Test-CompressedHandoffSummaryProtocol.ps1' `
  -Arguments @('-Root', $resolvedRoot) `
  -NextAction 'Restore the compressed handoff fixture/protocol so summaries keep source, scope, exclusions, manager-only gates, validation evidence, stale-map status, and next executable action.'

$blockingFailures = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
$overall = if ($blockingFailures.Count -gt 0) { 'FAIL' } else { 'PASS' }

Write-Output '== Driftless context-engineering discipline gate =='
foreach ($r in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
}
$pass = @($results | Where-Object { $_.status -eq 'PASS' }).Count
$fail = @($results | Where-Object { $_.status -eq 'FAIL' }).Count
Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $overall, $pass, $fail)

if ($Json) {
  [pscustomobject]@{
    command = $Command
    root = $resolvedRoot
    overall = $overall
    pass = $pass
    fail = $fail
    results = @($results)
  } | ConvertTo-Json -Depth 5
}

if ($overall -eq 'FAIL') { exit 1 } else { exit 0 }
