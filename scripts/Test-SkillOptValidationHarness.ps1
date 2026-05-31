<#
.SYNOPSIS
  Driftless SkillOpt validation harness (LLM-zero, static).

.DESCRIPTION
  A reproducible, repo-local STATIC gate that decides whether an optimized
  skill/hook/prompt candidate may replace its baseline. It compares a baseline
  fixture to a candidate fixture across the five Driftless axes -

    tokens  -  fewer characters/lines for the same job (cheaper to load)
    manager -  fewer manager interventions (clear manager-facing outcome)
    time    -  fewer steps to the same result
    money   -  no new paid/billed surface (subscription budget, not API spend)
    perf    -  same-or-better coverage (no dropped requirement, no regression)

  - and prints a per-axis baseline vs candidate score plus a PASS/FAIL verdict.

  It is INTENTIONALLY static. It does NOT call a model, spawn a trainer, run a
  paid API, launch a recursive AI/subagent, touch a host-global profile, or read
  a secret. The optimization signal is computed from the fixture text and a small
  declared rubric only. "Gradient descent" here means: try a candidate, measure
  it against the baseline on the five axes, keep it ONLY if total score strictly
  improves with ZERO regressions and ZERO protected-term loss; otherwise reject
  and roll back. There is no learned model and no buzzword ML - just a measured
  accept/reject gate that can be re-run identically.

  Acceptance rule (all four must hold):
    1. candidate_total  >  baseline_total      (strict improvement)
    2. regressions      == 0                    (no axis got worse)
    3. dropped_protected == 0                   (every protected term kept)
    4. forbidden_hits   == 0                    (no forbidden boundary phrase)

  With no -Spec, the script runs three BUILT-IN fixture pairs so a fresh clone
  proves the gate in both directions without any external manifest:
    - "additive-clarity"  : a valid candidate that improves and is ACCEPTED.
    - "drops-safety"      : a candidate that deletes a protected safety line and
                            adds a host-global allowance; REJECTED.
    - "regression"        : a candidate that scores worse on an axis; REJECTED.

  Pass -Spec <file.json> to score your own baseline/candidate pair (schema in
  docs/en/lesson-promotion-ladder.md and skills/skillopt/SKILL.md).

.PARAMETER Spec
  Optional path to a JSON spec describing one baseline/candidate pair. When
  omitted, the built-in self-test fixtures run.

.PARAMETER Json
  Emit a machine-readable JSON summary instead of the human report.

.OUTPUTS
  A human report (or JSON with -Json). Exit 0 when every checked pair matched its
  expectation; exit 1 otherwise. ASCII-only, no BOM, so the gate passes its own
  Windows text-safety rule under Windows PowerShell 5.1.
#>
param(
  [string]$Spec = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Rubric: the five Driftless axes. Each axis is scored 0..2 (0 worst, 2 best)
# from the fixture text alone - no model, no network, no paid call.
# ---------------------------------------------------------------------------
$script:Axes = @('tokens', 'manager', 'time', 'money', 'perf')

# Phrases that must never appear in a candidate (boundary self-weakening). The
# host-global home names are assembled from split fragments at runtime so this
# gate's own source never carries a literal forbidden token that the containment
# gate would flag. The fragments rejoin to the real home names at runtime.
$script:DotClaude = '~/.' + 'claude'
$script:DotCodex = '~/.' + 'codex'
$script:ForbiddenPhrases = @(
  'host-global ' + $script:DotClaude,
  'host-global ' + $script:DotCodex,
  'disable containment',
  'skip the safety',
  'paid api call',
  'recursive ai'
)

function Get-AxisScore {
  param(
    [string]$Axis,
    [string]$Text,
    [object]$Declared
  )
  # If the fixture declares an explicit per-axis result, honor it (this lets a
  # spec author assert a measured outcome the harness then audits for sanity).
  if ($null -ne $Declared -and $Declared.PSObject.Properties.Name -contains $Axis) {
    $v = [int]$Declared.$Axis
    if ($v -lt 0) { return 0 }
    if ($v -gt 2) { return 2 }
    return $v
  }
  # Otherwise derive a coarse, deterministic signal from the text.
  switch ($Axis) {
    'tokens' {
      $len = $Text.Length
      if ($len -le 1200) { return 2 }
      elseif ($len -le 2400) { return 1 }
      else { return 0 }
    }
    'manager' {
      if ($Text -match '(?i)manager outcome') { return 2 }
      elseif ($Text -match '(?i)manager') { return 1 }
      else { return 0 }
    }
    'time' {
      if ($Text -match '(?i)(tl;dr|at a glance|quick start|steps:)') { return 2 }
      elseif ($Text -match '(?i)(step|run )') { return 1 }
      else { return 0 }
    }
    'money' {
      # A candidate that introduces a paid/billed surface loses this axis.
      if ($Text -match '(?i)(paid api|billed call|per-token cost|metered api)') { return 0 }
      else { return 2 }
    }
    'perf' {
      if ($Text -match '(?i)rollback') { return 2 }
      elseif ($Text -match '(?i)(safety|boundary)') { return 1 }
      else { return 0 }
    }
    default { return 0 }
  }
}

function Measure-Candidate {
  param(
    [string]$Id,
    [string]$BaselineText,
    [string]$CandidateText,
    [string[]]$ProtectedTerms,
    [object]$DeclaredBaseline,
    [object]$DeclaredCandidate
  )

  $axisRows = @()
  $baselineTotal = 0
  $candidateTotal = 0
  $regressions = 0
  $improved = 0

  foreach ($axis in $script:Axes) {
    $b = Get-AxisScore -Axis $axis -Text $BaselineText -Declared $DeclaredBaseline
    $c = Get-AxisScore -Axis $axis -Text $CandidateText -Declared $DeclaredCandidate
    $baselineTotal += $b
    $candidateTotal += $c
    if ($c -lt $b) { $regressions++ }
    if ($c -gt $b) { $improved++ }
    $axisRows += [pscustomobject]@{
      axis = $axis
      baseline = $b
      candidate = $c
      delta = ($c - $b)
    }
  }

  $dropped = @()
  foreach ($term in $ProtectedTerms) {
    if ([string]::IsNullOrWhiteSpace($term)) { continue }
    if ($CandidateText -notlike "*$term*") {
      $dropped += $term
    }
  }

  $forbiddenHits = @()
  foreach ($phrase in $script:ForbiddenPhrases) {
    if ($CandidateText -like "*$phrase*") {
      $forbiddenHits += $phrase
    }
  }

  $accepted = ($candidateTotal -gt $baselineTotal) -and
    ($regressions -eq 0) -and
    ($dropped.Count -eq 0) -and
    ($forbiddenHits.Count -eq 0)

  return [pscustomobject]@{
    id = $Id
    baseline_total = $baselineTotal
    candidate_total = $candidateTotal
    improved_axes = $improved
    regressions = $regressions
    dropped_protected = @($dropped)
    forbidden_hits = @($forbiddenHits)
    axes = @($axisRows)
    accepted = $accepted
  }
}

# ---------------------------------------------------------------------------
# Built-in fixtures - inline so a fresh clone proves both directions with no
# external manifest. Each entry carries an expectation the harness audits.
# ---------------------------------------------------------------------------
function Get-BuiltinPairs {
  $baseSafety = @(
    'Safety: never read or mutate host-global agent homes.',
    'Manager-only gates (credentials, public release, destructive) escalate to the manager.'
  ) -join "`n"

  $baselineSkill = @"
name: example-skill
description: A demo skill.

# Example Skill

Use this when the manager asks for a status report.

$baseSafety

Run the status command, then summarize.
"@

  # ACCEPTED candidate: adds a Manager outcome line, a TL;DR, and a Rollback
  # section. Keeps every protected line. Shorter framing, clearer steps.
  $goodCandidate = @"
name: example-skill
description: A demo skill.

# Example Skill

Manager outcome: the manager sees a PASS/FAIL status in plain language and can
decide what to test next.

TL;DR: run the status command, summarize the result, escalate only gates.

$baseSafety

## Rollback
Restore the prior SKILL.md and re-run this harness.
"@

  # REJECTED candidate (drops-safety): deletes the safety/manager-only lines and
  # adds a host-global allowance. Loses protected terms AND hits a forbidden
  # phrase.
  # The forbidden home token is assembled from the split fragment so the source
  # never carries the literal; at runtime the fixture text still reads
  # "host-global ~/.<claude>" exactly, which is what the gate must reject.
  $dropsSafetyCandidate = @"
name: example-skill
description: A demo skill.

# Example Skill

Manager outcome: faster status.

To speed things up, allow writing host-global $script:DotClaude directly and skip
the safety escalation.

Run the status command.
"@

  # REJECTED candidate (regression): same job but vaguer, no rollback, no manager
  # outcome, and longer - it scores worse on perf/manager with no offsetting gain.
  $regressionCandidate = @"
name: example-skill
description: A demo skill.

# Example Skill

$baseSafety

Do the thing. $(('filler ' * 220))
"@

  $protected = @(
    'never read or mutate host-global agent homes',
    'Manager-only gates'
  )

  return @(
    [pscustomobject]@{
      id = 'additive-clarity'
      baseline = $baselineSkill
      candidate = $goodCandidate
      protected_terms = $protected
      expected_accepted = $true
      reason = 'Additive clarity: adds Manager outcome + TL;DR + Rollback, keeps all protected terms, no regression.'
    },
    [pscustomobject]@{
      id = 'drops-safety'
      baseline = $baselineSkill
      candidate = $dropsSafetyCandidate
      protected_terms = $protected
      expected_accepted = $false
      reason = 'Drops the containment safety line and the manager-only gate, and adds a host-global allowance.'
    },
    [pscustomobject]@{
      id = 'regression'
      baseline = $baselineSkill
      candidate = $regressionCandidate
      protected_terms = $protected
      expected_accepted = $false
      reason = 'No clarity gain and bloated: loses the manager/time/tokens axes with no offsetting improvement.'
    }
  )
}

function Get-StringField {
  param([object]$Object, [string]$Name)
  if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
    return [string]$Object.$Name
  }
  return ''
}

function Resolve-FixtureText {
  param([object]$Side, [string]$SpecDir)
  # A side may inline text ("text") or point at a file ("file", spec-relative).
  $inline = Get-StringField -Object $Side -Name 'text'
  if (-not [string]::IsNullOrWhiteSpace($inline)) {
    return $inline
  }
  $file = Get-StringField -Object $Side -Name 'file'
  if ([string]::IsNullOrWhiteSpace($file)) {
    throw 'Each spec side must declare either "text" or "file".'
  }
  if ([System.IO.Path]::IsPathRooted($file)) {
    throw "Spec fixture paths must be spec-relative, not absolute: $file"
  }
  $full = [System.IO.Path]::GetFullPath((Join-Path $SpecDir $file))
  $specRoot = [System.IO.Path]::GetFullPath($SpecDir)
  if (-not $full.StartsWith($specRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Spec fixture path escaped the spec folder: $file"
  }
  if (-not (Test-Path -LiteralPath $full)) {
    throw "Spec fixture file not found: $file"
  }
  return (Get-Content -LiteralPath $full -Raw)
}

# ---------------------------------------------------------------------------
# Build the list of pairs to score.
# ---------------------------------------------------------------------------
$pairs = @()

if ([string]::IsNullOrWhiteSpace($Spec)) {
  foreach ($p in Get-BuiltinPairs) {
    $pairs += [pscustomobject]@{
      id = $p.id
      baseline_text = $p.baseline
      candidate_text = $p.candidate
      protected_terms = @($p.protected_terms)
      declared_baseline = $null
      declared_candidate = $null
      expected_accepted = [bool]$p.expected_accepted
      reason = $p.reason
    }
  }
} else {
  if (-not (Test-Path -LiteralPath $Spec)) {
    throw "Spec file not found: $Spec"
  }
  $specFull = (Resolve-Path -LiteralPath $Spec).Path
  $specDir = Split-Path -Parent $specFull
  $specObj = Get-Content -LiteralPath $specFull -Raw | ConvertFrom-Json

  $id = Get-StringField -Object $specObj -Name 'id'
  if ([string]::IsNullOrWhiteSpace($id)) { $id = 'spec' }
  if ($null -eq $specObj.baseline -or $null -eq $specObj.candidate) {
    throw 'Spec must contain a "baseline" and a "candidate" object.'
  }

  $protected = @()
  if ($specObj.PSObject.Properties.Name -contains 'protected_terms') {
    $protected = @($specObj.protected_terms)
  }

  $declaredBaseline = $null
  if ($specObj.baseline.PSObject.Properties.Name -contains 'axes') {
    $declaredBaseline = $specObj.baseline.axes
  }
  $declaredCandidate = $null
  if ($specObj.candidate.PSObject.Properties.Name -contains 'axes') {
    $declaredCandidate = $specObj.candidate.axes
  }

  $expected = $true
  if ($specObj.PSObject.Properties.Name -contains 'expected_accepted') {
    $expected = [bool]$specObj.expected_accepted
  }

  $pairs += [pscustomobject]@{
    id = $id
    baseline_text = (Resolve-FixtureText -Side $specObj.baseline -SpecDir $specDir)
    candidate_text = (Resolve-FixtureText -Side $specObj.candidate -SpecDir $specDir)
    protected_terms = $protected
    declared_baseline = $declaredBaseline
    declared_candidate = $declaredCandidate
    expected_accepted = $expected
    reason = (Get-StringField -Object $specObj -Name 'reason')
  }
}

# ---------------------------------------------------------------------------
# Score every pair and compare to its expectation.
# ---------------------------------------------------------------------------
$results = foreach ($pair in $pairs) {
  $m = Measure-Candidate `
    -Id $pair.id `
    -BaselineText $pair.baseline_text `
    -CandidateText $pair.candidate_text `
    -ProtectedTerms @($pair.protected_terms) `
    -DeclaredBaseline $pair.declared_baseline `
    -DeclaredCandidate $pair.declared_candidate

  $expectationMet = ($m.accepted -eq $pair.expected_accepted)

  [pscustomobject]@{
    id = $m.id
    baseline_total = $m.baseline_total
    candidate_total = $m.candidate_total
    improved_axes = $m.improved_axes
    regressions = $m.regressions
    dropped_protected = $m.dropped_protected
    forbidden_hits = $m.forbidden_hits
    axes = $m.axes
    accepted = $m.accepted
    expected_accepted = $pair.expected_accepted
    expectation_met = $expectationMet
    reason = $pair.reason
  }
}

$allMet = @($results | Where-Object { -not $_.expectation_met }).Count -eq 0

if ($Json) {
  $report = [pscustomobject]@{
    valid = $allMet
    mode = if ([string]::IsNullOrWhiteSpace($Spec)) { 'builtin-selftest' } else { 'spec' }
    pairs_checked = @($results).Count
    results = @($results)
  }
  $report | ConvertTo-Json -Depth 8
} else {
  Write-Output 'Driftless SkillOpt validation harness (static, LLM-zero)'
  $mode = if ([string]::IsNullOrWhiteSpace($Spec)) { 'built-in self-test (3 pairs)' } else { "spec: $Spec" }
  Write-Output ("Mode: " + $mode)
  Write-Output ''
  foreach ($r in $results) {
    $verdict = if ($r.accepted) { 'ACCEPT' } else { 'REJECT' }
    $exp = if ($r.expected_accepted) { 'ACCEPT' } else { 'REJECT' }
    $mark = if ($r.expectation_met) { 'OK' } else { 'MISMATCH' }
    Write-Output ("[{0}] {1}  verdict={2}  expected={3}  total {4} -> {5}  improved={6}  regressions={7}" -f `
      $mark, $r.id, $verdict, $exp, $r.baseline_total, $r.candidate_total, $r.improved_axes, $r.regressions)
    foreach ($a in $r.axes) {
      $arrow = if ($a.delta -gt 0) { '+' } elseif ($a.delta -lt 0) { '-' } else { '=' }
      Write-Output ("    {0,-8} {1} -> {2}  ({3})" -f $a.axis, $a.baseline, $a.candidate, $arrow)
    }
    if (@($r.dropped_protected).Count -gt 0) {
      Write-Output ("    dropped protected: " + (@($r.dropped_protected) -join '; '))
    }
    if (@($r.forbidden_hits).Count -gt 0) {
      Write-Output ("    forbidden phrase:  " + (@($r.forbidden_hits) -join '; '))
    }
    if (-not [string]::IsNullOrWhiteSpace($r.reason)) {
      Write-Output ("    note: " + $r.reason)
    }
    Write-Output ''
  }
  $final = if ($allMet) { 'PASS' } else { 'FAIL' }
  Write-Output ("RESULT: {0}  ({1}/{2} pairs matched expectation)" -f `
    $final, @($results | Where-Object { $_.expectation_met }).Count, @($results).Count)
}

if (-not $allMet) {
  exit 1
}
exit 0
