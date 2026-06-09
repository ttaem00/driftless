#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Driftless improvement-principle discipline gate.

.DESCRIPTION
  Verifies that the shared root-cause / principle-based / no-overfit rule stays
  on the public surfaces that both profiles consume:

    1. profiles/shared/contract/SHARED_DESIGN_CONTRACT.md carries the canonical
       public improvement principle.
    2. AGENTS.md points agents at that shared principle.

  This is structural evidence, not behavioral proof. It prevents later prompt
  compression, profile porting, or doc cleanup from silently dropping the rule.
  It also checks the behavior-shaping public surfaces that make the rule fire:
  shipped skills, learning-loop promotion, finish-to-done closeout, CI, docs,
  and the pull request template. Behavioral improvement claims still need real
  workflow evidence.

  Read-only. No network, no secrets, no peer AI, no host-global access.
  ASCII-only so the gate parses under PowerShell 7.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$SelfTest,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$Command = 'Test-ImprovementPrincipleDiscipline.ps1'

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
    if ($Text -notlike ('*' + $anchor + '*')) { $missing.Add($anchor) | Out-Null }
  }
  return @($missing)
}

function Invoke-SelfTest {
  $failures = [System.Collections.Generic.List[string]]::new()
  $anchors = @('root-cause fixes', 'principle-based', 'spec overfitting', 'special-casing')
  $cleanText = 'Prefer root-cause fixes expressed as principle-based guidance. Avoid spec overfitting and special-casing.'
  $cleanMissing = Test-Anchors -Text $cleanText -Anchors $anchors
  if ($cleanMissing.Count -ne 0) {
    $failures.Add('positive fixture unexpectedly missed anchors') | Out-Null
  }
  $brokenText = 'Prefer root-cause fixes.'
  $brokenMissing = Test-Anchors -Text $brokenText -Anchors $anchors
  if ($brokenMissing.Count -lt 1) {
    $failures.Add('negative fixture did not report missing principle anchors') | Out-Null
  }
  return [pscustomobject]@{
    passed = ($failures.Count -eq 0)
    failures = @($failures)
    detail = ("clean_missing={0}; broken_missing={1}" -f $cleanMissing.Count, $brokenMissing.Count)
  }
}

function Get-ShippedSkillFiles {
  param([string]$RepoRoot)
  $roots = @(
    'profiles/shared/skills',
    'profiles/codex/skills',
    'profiles/claude/skills'
  )
  $files = [System.Collections.Generic.List[object]]::new()
  foreach ($relRoot in $roots) {
    $absRoot = Join-Path $RepoRoot ($relRoot -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $absRoot -PathType Container)) { continue }
    foreach ($f in Get-ChildItem -LiteralPath $absRoot -Recurse -Filter 'SKILL.md' -File) {
      $files.Add($f) | Out-Null
    }
  }
  return @($files)
}

if ($SelfTest) {
  $st = Invoke-SelfTest
  Write-Output '== Driftless improvement-principle discipline gate: built-in self-test =='
  Write-Output ("detector: {0}" -f $st.detail)
  if ($st.passed) {
    Write-Output 'RESULT: PASS (anchor detector PASSes clean and FAILs planted missing anchors)'
    if ($Json) {
      [pscustomobject]@{ gate = 'improvement-principle'; mode = 'self-test'; overall = 'PASS'; detail = $st.detail } | ConvertTo-Json -Depth 4
    }
    exit 0
  }
  Write-Output ('RESULT: FAIL - ' + (@($st.failures) -join '; '))
  if ($Json) {
    [pscustomobject]@{ gate = 'improvement-principle'; mode = 'self-test'; overall = 'FAIL'; failures = @($st.failures); detail = $st.detail } | ConvertTo-Json -Depth 4
  }
  exit 1
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

$sharedAnchors = @(
  '## 8. Improvement principle',
  'root-cause fixes',
  'principle-based',
  'spec overfitting',
  'case overfitting',
  'special-casing',
  'user effort',
  'maintainer effort',
  'maintainability'
)

$agentAnchors = @(
  'SHARED_DESIGN_CONTRACT.md',
  'root cause first',
  'principle-based guidance',
  'spec/case overfitting',
  'special-casing'
)

$skillAnchors = @(
  '## Improvement Principle',
  'root-cause analysis',
  'root-cause fixes',
  'principle-based guidance',
  'spec/case overfitting',
  'special-casing'
)

$learningLoopAnchors = @(
  'Promotion Gate',
  'Enforcement Workflow',
  'root-cause',
  'principle-based',
  'special-casing',
  'smallest',
  'validation'
)

$finishToDoneAnchors = @(
  'Autonomous Blocker Resolution',
  'No Substitute Done',
  'root-cause',
  'same session',
  'original',
  'validation'
)

$ciAnchors = @(
  'Test-ImprovementPrincipleDiscipline.ps1',
  'Improvement-principle'
)

$prTemplateAnchors = @(
  'root-cause',
  'principle-based',
  'overfitting',
  'special-casing'
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

$sharedPath = Join-Path $resolvedRoot 'profiles\shared\contract\SHARED_DESIGN_CONTRACT.md'
if (-not (Test-Path -LiteralPath $sharedPath -PathType Leaf)) {
  Add-Result $results 'Shared improvement principle' 'FAIL' $true "missing=$sharedPath" 'Restore profiles/shared/contract/SHARED_DESIGN_CONTRACT.md with section 8 Improvement principle.'
} else {
  $missing = Test-Anchors -Text (Read-Utf8 $sharedPath) -Anchors $sharedAnchors
  $status = if ($missing.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "anchors=$($sharedAnchors.Count); missing=$($missing.Count)"
  if ($missing.Count -gt 0) { $evidence += '; missing_anchors=' + ($missing -join ', ') }
  Add-Result $results 'Shared improvement principle' $status $true $evidence 'Restore section 8 so both profiles consume the same root-cause/no-overfit rule.'
}

$agentsPath = Join-Path $resolvedRoot 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agentsPath -PathType Leaf)) {
  Add-Result $results 'Agent guidance pointer' 'FAIL' $true "missing=$agentsPath" 'Restore AGENTS.md with a pointer to the shared improvement principle.'
} else {
  $missing = Test-Anchors -Text (Read-Utf8 $agentsPath) -Anchors $agentAnchors
  $status = if ($missing.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "anchors=$($agentAnchors.Count); missing=$($missing.Count)"
  if ($missing.Count -gt 0) { $evidence += '; missing_anchors=' + ($missing -join ', ') }
  Add-Result $results 'Agent guidance pointer' $status $true $evidence 'Point AGENTS.md to profiles/shared/contract/SHARED_DESIGN_CONTRACT.md section 8.'
}

$skillFiles = Get-ShippedSkillFiles -RepoRoot $resolvedRoot
if ($skillFiles.Count -eq 0) {
  Add-Result $results 'Shipped skills enumerated' 'FAIL' $true 'count=0' 'No public SKILL.md files found; scope or repo layout is wrong.'
} else {
  Add-Result $results 'Shipped skills enumerated' 'PASS' $true "count=$($skillFiles.Count)" ''
}

$missingSkills = [System.Collections.Generic.List[string]]::new()
foreach ($skill in $skillFiles) {
  $missing = Test-Anchors -Text (Read-Utf8 $skill.FullName) -Anchors $skillAnchors
  if ($missing.Count -gt 0) {
    $rel = $skill.FullName.Substring($resolvedRoot.Length + 1) -replace '\\', '/'
    $missingSkills.Add(("{0} missing [{1}]" -f $rel, ($missing -join ', '))) | Out-Null
  }
}

if ($missingSkills.Count -eq 0) {
  Add-Result $results 'Every shipped skill carries Improvement Principle' 'PASS' $true "checked=$($skillFiles.Count)" ''
} else {
  $sample = @($missingSkills | Select-Object -First 20) -join ' | '
  Add-Result $results 'Every shipped skill carries Improvement Principle' 'FAIL' $true "missing=$($missingSkills.Count); sample=$sample" 'Add the compact Improvement Principle section to every shipped SKILL.md; do not patch only the observed failing skill.'
}

Add-FileAnchorCheck `
  -Check 'Learning loop promotes reusable root-cause fixes' `
  -RelPath 'profiles/shared/skills/learning-loop/SKILL.md' `
  -Anchors $learningLoopAnchors `
  -NextAction 'Restore promotion/enforcement workflow so recurring lessons move to the smallest public-safe rule surface.'

Add-FileAnchorCheck `
  -Check 'Finish-to-done prevents substitute Done' `
  -RelPath 'profiles/shared/skills/finish-to-done/SKILL.md' `
  -Anchors $finishToDoneAnchors `
  -NextAction 'Restore autonomous blocker resolution and No Substitute Done so recording a limitation cannot be reported as completion.'

Add-FileAnchorCheck `
  -Check 'CI invokes improvement-principle gate' `
  -RelPath '.github/workflows/gates.yml' `
  -Anchors $ciAnchors `
  -NextAction 'Run Test-ImprovementPrincipleDiscipline.ps1 in CI so the rule is not only documented.'

Add-FileAnchorCheck `
  -Check 'PR template asks for principle evidence on rule/skill changes' `
  -RelPath '.github/PULL_REQUEST_TEMPLATE.md' `
  -Anchors $prTemplateAnchors `
  -NextAction 'Add a concise PR checklist item for root-cause, principle-based, no-overfit evidence when changing rules or skills.'

Add-FileAnchorCheck `
  -Check 'Scripts README documents strengthened gate' `
  -RelPath 'scripts/README.md' `
  -Anchors @('shipped SKILL.md', 'learning-loop', 'finish-to-done', 'CI') `
  -NextAction 'Document what the strengthened improvement-principle gate checks.'

$blockingFailures = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
$overall = if ($blockingFailures.Count -gt 0) { 'FAIL' } else { 'PASS' }

Write-Output '== Driftless improvement-principle discipline gate =='
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
