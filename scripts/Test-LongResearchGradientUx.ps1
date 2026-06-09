#requires -Version 7.0
#requires -PSEdition Core
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

function Convert-EscapedUnicode {
  param([string]$Text)
  return [System.Text.RegularExpressions.Regex]::Unescape($Text)
}

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$Results,
    [string]$Check,
    [string]$Status,
    [string]$Evidence,
    [string]$NextAction = ''
  )
  $Results.Add([pscustomobject]@{
      check = $Check
      status = $Status
      evidence = $Evidence
      next_action = $NextAction
    }) | Out-Null
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()
$skillRel = 'profiles\shared\skills\long-research-gradient\SKILL.md'
$exampleRel = 'profiles\shared\skills\long-research-gradient\references\student-fast-path.md'
$skillPath = Join-Path $resolvedRoot $skillRel
$examplePath = Join-Path $resolvedRoot $exampleRel
$gradientCloseout = Convert-EscapedUnicode '\uc774\ubc88 \uacbd\uc0ac\ud558\uac15'
$studentPrompt = Convert-EscapedUnicode '\uc7a5\uae30\uc5f0\uad6c:'

if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
  Add-Result $results 'shared skill exists' 'FAIL' "missing=$skillRel" 'Restore profiles/shared/skills/long-research-gradient/SKILL.md.'
} else {
  $skillText = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8
  Add-Result $results 'shared skill exists' 'PASS' "path=$skillRel"

  $checks = @(
    [pscustomobject]@{ label = 'student fast path'; value = '## Student Fast Path' },
    [pscustomobject]@{ label = 'one-line student prompt'; value = $studentPrompt },
    [pscustomobject]@{ label = 'gradient closeout'; value = $gradientCloseout },
    [pscustomobject]@{ label = 'kept field'; value = '`kept`' },
    [pscustomobject]@{ label = 'changed field'; value = '`changed now`' },
    [pscustomobject]@{ label = 'issue field'; value = '`issue/watch`' },
    [pscustomobject]@{ label = 'saving field'; value = '`saved tokens/time/intervention`' },
    [pscustomobject]@{ label = 'next sprint field'; value = '`next sprint`' },
    [pscustomobject]@{ label = 'example reference'; value = 'references/student-fast-path.md' }
  )
  foreach ($check in $checks) {
    $ok = $skillText.Contains($check.value)
    Add-Result $results "shared skill ux contract: $($check.label)" ($(if ($ok) { 'PASS' } else { 'FAIL' })) "needle=$($check.label)" 'Keep the public shared skill usable by a non-developer student.'
  }
}

if (-not (Test-Path -LiteralPath $examplePath -PathType Leaf)) {
  Add-Result $results 'student example exists' 'FAIL' "missing=$exampleRel" 'Add a compact public-safe example showing the one-line start and required closeout.'
} else {
  $exampleText = Get-Content -LiteralPath $examplePath -Raw -Encoding UTF8
  Add-Result $results 'student example exists' 'PASS' "path=$exampleRel"
  foreach ($needle in @($studentPrompt, $gradientCloseout, 'Observed', 'UNVERIFIED', 'next sprint')) {
    $ok = $exampleText.Contains($needle)
    Add-Result $results "student example contract: $needle" ($(if ($ok) { 'PASS' } else { 'FAIL' })) "needle=$needle" 'The example must show student-facing input, evidence honesty, and the gradient closeout.'
  }
}

$pass = @($results | Where-Object status -eq 'PASS').Count
$fail = @($results | Where-Object status -eq 'FAIL').Count
$summary = [pscustomobject]@{
  command = 'Test-LongResearchGradientUx.ps1'
  root = $resolvedRoot
  overall = $(if ($fail -eq 0) { 'PASS' } else { 'FAIL' })
  pass = $pass
  fail = $fail
  results = @($results)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 6
} else {
  Write-Output '== Driftless long research UX gate =='
  foreach ($r in $results) {
    Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
  }
  Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $summary.overall, $pass, $fail)
}

if ($fail -gt 0) { exit 1 }
