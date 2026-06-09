#requires -Version 7.0
#requires -PSEdition Core
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Failure([System.Collections.Generic.List[string]]$Failures, [string]$Message) {
  $Failures.Add($Message) | Out-Null
}

$root = (Resolve-Path -LiteralPath $Root).Path
$missionPath = Join-Path $root "profiles\shared\skills\mission-control\SKILL.md"
$adoptPath = Join-Path $root "profiles\shared\skills\adopt-external-tool\SKILL.md"
$failures = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $missionPath)) {
  Add-Failure $failures "missing mission-control skill: $missionPath"
}
if (-not (Test-Path -LiteralPath $adoptPath)) {
  Add-Failure $failures "missing adopt-external-tool skill: $adoptPath"
}

if ($failures.Count -eq 0) {
  $mission = Get-Content -LiteralPath $missionPath -Raw -Encoding UTF8
  $adopt = Get-Content -LiteralPath $adoptPath -Raw -Encoding UTF8

  foreach ($pattern in @(
    "## Outcome Contract",
    "## Scope Preservation Gate",
    "outcome class",
    "parent-owned lane ledger",
    "value axes",
    "One safe subset applied is progress, not Done",
    "post-pilot decision",
    "Large agent harness",
    "hooks, scripts, skills, rules, commands/prompts",
    "multi-agent/workflow control",
    "dashboard/status UI",
    "credential/API/security",
    "technology/libraries",
    "star-reason and strong-feature gate",
    "strongest detailed features",
    "Popularity is discovery evidence, not adoption evidence",
    "star reason / strong features",
    "risky but plausibly valuable",
    "contained pilot"
  )) {
    if ($mission -notmatch [regex]::Escape($pattern)) {
      Add-Failure $failures "mission-control missing required scope-preservation text: $pattern"
    }
  }

  foreach ($pattern in @(
    "## Adoption Surface Ledger",
    "install vs reject",
    "final closeout state",
    "credential/security boundary",
    "multi-worker/process model",
    "public-safe propagation",
    "Risk is not a rejection by itself",
    "smallest contained pilot",
    "## Post-Pilot Decision Gate",
    "PILOT_ONLY is not Done",
    "post-pilot decision",
    "Large agent harness",
    "hooks, scripts, skills, rules, commands/prompts",
    "multi-agent/workflow control",
    "dashboard/status UI",
    "credential/API/security",
    "technology/libraries",
    "development process",
    "## Star Reason / Strong Feature Ledger",
    "Stars are discovery evidence",
    "adoption evidence",
    "pain point solved",
    "strongest detailed features",
    "why users would care",
    "local transform"
  )) {
    if ($adopt -notmatch [regex]::Escape($pattern)) {
      Add-Failure $failures "adopt-external-tool missing required adoption-ledger text: $pattern"
    }
  }
}

$result = [pscustomobject]@{
  check = "Test-MissionControlAdoptionScope"
  status = if ($failures.Count -eq 0) { "PASS" } else { "FAIL" }
  mission_control = $missionPath
  adopt_external_tool = $adoptPath
  failures = @($failures)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
}

if ($failures.Count -gt 0) {
  Write-Error ("FAIL Test-MissionControlAdoptionScope:`n" + ($failures -join "`n"))
  exit 1
}

Write-Output "PASS Test-MissionControlAdoptionScope"
