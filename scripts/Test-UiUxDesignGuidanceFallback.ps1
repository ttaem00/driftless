#requires -Version 7.0
#requires -PSEdition Core
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

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

function Read-IfPresent {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

$files = @(
  'docs\design\DESIGN.md',
  'profiles\shared\skills\ui-ux-design-guidance\SKILL.md',
  'profiles\shared\skills\ui-ux-design-guidance\agents\openai.yaml',
  'profiles\shared\skills\README.md',
  'profiles\shared\schemas\mirror-parity-allowlist.json'
)

$forbidden = @(
  # fixture-only machine-path needles: these strings prove the public shared
  # skill does not hardcode one maintainer's private checkout or local clone.
  'D:\c-c-isolated-runtime\docs\design\DESIGN.md',
  'D:\\c-c-isolated-runtime\\docs\\design\\DESIGN.md',
  'D:\codex-isolated-runtime\docs\design.md\DESGIN.md',
  'D:\\codex-isolated-runtime\\docs\\design.md\\DESGIN.md',
  'D:\driftless\docs\design\DESIGN.md',
  'D:\\driftless\\docs\\design\\DESIGN.md'
)

foreach ($rel in $files) {
  $path = Join-Path $resolvedRoot $rel
  $text = Read-IfPresent -Path $path
  Add-Result $results "file exists: $rel" ($(if ($null -ne $text) { 'PASS' } else { 'FAIL' })) "path=$path" 'Restore the Driftless UI/UX guidance asset.'
  if ($null -eq $text) { continue }

  foreach ($needle in $forbidden) {
    $hasForbidden = $text.Contains($needle)
    Add-Result $results "no machine absolute design fallback: $rel" ($(if (-not $hasForbidden) { 'PASS' } else { 'FAIL' })) "needle=$needle" 'Use repo-relative design paths and resolve the installed Driftless root from environment/current checkout.'
  }
}

$skillText = Read-IfPresent -Path (Join-Path $resolvedRoot 'profiles\shared\skills\ui-ux-design-guidance\SKILL.md')
$requiredSkillNeedles = @(
  'docs/design/DESIGN.md',
  'docs\design\DESIGN.md',
  'DRIFTLESS_REPO_ROOT',
  'CODEX_HOME',
  'CLAUDE_CONFIG_DIR',
  'PROFILE_DEFAULT_DESIGN_GUIDE_USED',
  'UNVERIFIED_REPO_DESIGN_GUIDE_MISSING',
  'UNVERIFIED_DESIGN_GUIDE_MISSING'
)

foreach ($needle in $requiredSkillNeedles) {
  $ok = $null -ne $skillText -and $skillText.Contains($needle)
  Add-Result $results "shared skill contract contains: $needle" ($(if ($ok) { 'PASS' } else { 'FAIL' })) "needle=$needle" 'The shared skill must prefer repo docs/design/DESIGN.md and resolve fallback from the installed Driftless root.'
}

$readmeText = Read-IfPresent -Path (Join-Path $resolvedRoot 'profiles\shared\skills\README.md')
$readmeOk = $null -ne $readmeText -and $readmeText.Contains('ui-ux-design-guidance')
Add-Result $results 'shared skill README lists ui-ux-design-guidance' ($(if ($readmeOk) { 'PASS' } else { 'FAIL' })) 'needle=ui-ux-design-guidance' 'Document the shared skill for both profiles.'

$allowlistText = Read-IfPresent -Path (Join-Path $resolvedRoot 'profiles\shared\schemas\mirror-parity-allowlist.json')
$allowlistOk = $null -ne $allowlistText -and $allowlistText.Contains('skill-ui-ux-design-guidance')
Add-Result $results 'mirror parity allowlist includes shared UI skill' ($(if ($allowlistOk) { 'PASS' } else { 'FAIL' })) 'needle=skill-ui-ux-design-guidance' 'Add the shared skill to the mirror parity allowlist.'

$pass = @($results | Where-Object status -eq 'PASS').Count
$fail = @($results | Where-Object status -eq 'FAIL').Count
$summary = [pscustomobject]@{
  command = 'Test-UiUxDesignGuidanceFallback.ps1'
  root = $resolvedRoot
  overall = $(if ($fail -eq 0) { 'PASS' } else { 'FAIL' })
  pass = $pass
  fail = $fail
  results = @($results)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 6
} else {
  Write-Output '== UI/UX design guidance fallback gate =='
  foreach ($r in $results) {
    Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
  }
  Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $summary.overall, $pass, $fail)
}

if ($fail -gt 0) { exit 1 }
