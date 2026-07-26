#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Verifies full Claude/Codex homes and the bounded Hermes Aemeth adapter home.

.DESCRIPTION
  The profiles keep shared skills once under profiles/shared/skills, but the
  generated Claude/Codex homes must expose shared skills under their active
  skills/ directory. The Hermes adapter must expose the exact Starrail skill,
  contract, bundle, and protected aliases without becoming a full third profile.
#>
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

$repoRoot = (Resolve-Path -LiteralPath $Root).Path
$installer = Join-Path $repoRoot 'install.ps1'
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
  throw "Missing installer: $installer"
}

function Get-SkillNames {
  param([string[]]$Roots)

  $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($root in $Roots) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
      Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf } |
      ForEach-Object { [void]$names.Add($_.Name) }
  }
  return [string[]]$names
}

function Invoke-Installer {
  param([string]$Tool)

  $saved = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $installer -Tool $Tool -Yes 2>&1
    $exit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $saved
  }

  [pscustomobject]@{
    tool = $Tool
    exit = $exit
    output = @($output | ForEach-Object { [string]$_ })
  }
}

$sharedSkills = Join-Path $repoRoot 'profiles\shared\skills'
$tools = @(
  @{ tool = 'claude'; profile = 'profiles\claude\skills'; home = '.runtime\claude-home\skills'; adapter = 'CLAUDE.md' },
  @{ tool = 'codex'; profile = 'profiles\codex\skills'; home = '.runtime\codex-home\skills'; adapter = 'AGENTS.md' }
)

$rows = [System.Collections.Generic.List[object]]::new()
$requiredExactTriggerSkills = @('wuther-codemap', 'finish-to-done', 'starrail-sprint')
$leafCloseoutSkills = @('bounded-sprint-close', 'manager-blindspot-audit', 'durable-evidence-audit', 'closeout-skill-evolution')

foreach ($entry in $tools) {
  $install = Invoke-Installer -Tool $entry.tool
  $profileSkills = Join-Path $repoRoot $entry.profile
  $homeSkills = Join-Path $repoRoot $entry.home
  $expected = @(Get-SkillNames -Roots @($sharedSkills, $profileSkills) | Sort-Object)
  $actual = @(Get-SkillNames -Roots @($homeSkills) | Sort-Object)
  $missing = @($expected | Where-Object { $actual -notcontains $_ })
  $triggerFailures = [System.Collections.Generic.List[string]]::new()
  foreach ($skillName in $requiredExactTriggerSkills) {
    $installedSkill = Join-Path $homeSkills (Join-Path $skillName 'SKILL.md')
    if (-not (Test-Path -LiteralPath $installedSkill -PathType Leaf)) {
      $triggerFailures.Add("$skillName missing") | Out-Null
      continue
    }
    $skillText = Get-Content -LiteralPath $installedSkill -Raw -Encoding UTF8
    $frontmatter = @($skillText -split "`r?`n" | Select-Object -First 14)
    $nameMatch = $frontmatter -contains ("name: {0}" -f $skillName)
    $descriptionLines = [System.Collections.Generic.List[string]]::new()
    $inDescription = $false
    foreach ($line in $frontmatter) {
      if ($line -eq 'description: >') { $inDescription = $true; continue }
      if ($inDescription -and $line -eq '---') { break }
      if ($inDescription) { $descriptionLines.Add($line) | Out-Null }
    }
    $triggerMatch = ($descriptionLines -join ' ').Contains($skillName)
    if (-not ($nameMatch -and $triggerMatch)) {
      $triggerFailures.Add("$skillName frontmatter") | Out-Null
    }
  }

  $homeRoot = Split-Path -Parent $homeSkills
  $adapterPath = Join-Path $homeRoot $entry.adapter
  $policyPath = Join-Path $homeRoot 'shared\schemas\manager-closeout-routing-policy.json'
  $umbrellaRegistration = Join-Path $homeSkills 'finish-to-done\agents\openai.yaml'
  $starrailRegistration = Join-Path $homeSkills 'starrail-sprint\agents\openai.yaml'
  $starrailContract = Join-Path $homeRoot 'shared\contract\STARRAIL_SPRINT_CONTRACT.json'
  $obsoleteStarrailContract = Join-Path $homeRoot 'shared\contract\STARTRAIL_SPRINT_CONTRACT.json'
  if (-not (Test-Path -LiteralPath $adapterPath -PathType Leaf)) {
    $triggerFailures.Add("$($entry.adapter) missing") | Out-Null
  } else {
    $adapterText = Get-Content -LiteralPath $adapterPath -Raw -Encoding UTF8
    if (-not ($adapterText.Contains('finish-to-done') -and $adapterText.Contains('manager-closeout-routing-policy.json'))) {
      $triggerFailures.Add("$($entry.adapter) routing pointer") | Out-Null
    }
  }
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    $triggerFailures.Add('routing policy missing') | Out-Null
  } else {
    $policyData = Get-Content -LiteralPath $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($policyData.entrypoint -ne 'finish-to-done' -or -not $policyData.implicit_entrypoint -or $policyData.implicit_leaf_skills) {
      $triggerFailures.Add('routing policy semantics') | Out-Null
    }
  }
  if (-not (Test-Path -LiteralPath $umbrellaRegistration -PathType Leaf)) {
    $triggerFailures.Add('finish-to-done registration missing') | Out-Null
  } elseif (-not (Get-Content -LiteralPath $umbrellaRegistration -Raw -Encoding UTF8).Contains('allow_implicit_invocation: true')) {
    $triggerFailures.Add('finish-to-done is not implicit') | Out-Null
  }
  if (-not (Test-Path -LiteralPath $starrailRegistration -PathType Leaf) -or -not (Get-Content -LiteralPath $starrailRegistration -Raw -Encoding UTF8).Contains('allow_implicit_invocation: true')) {
    $triggerFailures.Add('starrail-sprint implicit registration') | Out-Null
  }
  if (-not (Test-Path -LiteralPath $starrailContract -PathType Leaf) -or (Test-Path -LiteralPath $obsoleteStarrailContract)) {
    $triggerFailures.Add('canonical Starrail contract materialization') | Out-Null
  }
  foreach ($leafName in $leafCloseoutSkills) {
    $leafRegistration = Join-Path $homeSkills "$leafName\agents\openai.yaml"
    if (-not (Test-Path -LiteralPath $leafRegistration -PathType Leaf)) {
      $triggerFailures.Add("$leafName registration missing") | Out-Null
    } elseif (-not (Get-Content -LiteralPath $leafRegistration -Raw -Encoding UTF8).Contains('allow_implicit_invocation: false')) {
      $triggerFailures.Add("$leafName must stay explicit") | Out-Null
    }
  }

  $status = if ($install.exit -eq 0 -and $missing.Count -eq 0 -and $triggerFailures.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "installer_exit=$($install.exit); expected_active_skills=$($expected.Count); actual_active_skills=$($actual.Count); exact_triggers=$($requiredExactTriggerSkills.Count)"
  if ($missing.Count -gt 0) {
    $evidence += "; missing=" + (($missing | Select-Object -First 8) -join ',')
  }
  if ($triggerFailures.Count -gt 0) {
    $evidence += "; trigger_failures=" + (($triggerFailures | Select-Object -First 8) -join ',')
  }

  $rows.Add([pscustomobject]@{
      tool = $entry.tool
      status = $status
      evidence = $evidence
      next_action = 'Copy shared profile skills into the active home skills directory before reporting setup complete.'
    }) | Out-Null
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [System.Convert]::ToHexString($sha.ComputeHash($stream)) }
    finally { $sha.Dispose() }
  } finally { $stream.Dispose() }
}

$hermesInstall = Invoke-Installer -Tool 'hermes'
$hermesHome = Join-Path $repoRoot '.runtime\hermes-home'
$hermesSkill = Join-Path $hermesHome 'skills\starrail-sprint\SKILL.md'
$hermesRegistration = Join-Path $hermesHome 'skills\starrail-sprint\agents\openai.yaml'
$hermesContract = Join-Path $hermesHome 'shared\contract\STARRAIL_SPRINT_CONTRACT.json'
$hermesObsoleteContract = Join-Path $hermesHome 'shared\contract\STARTRAIL_SPRINT_CONTRACT.json'
$hermesGuide = Join-Path $hermesHome 'HERMES.md'
$hermesConfig = Join-Path $hermesHome 'config.yaml'
$hermesBundle = Join-Path $hermesHome 'skill-bundles\starrail-sprint.yaml'
$sourceStarrailSkill = Join-Path $repoRoot 'profiles\shared\skills\starrail-sprint\SKILL.md'
$sourceStarrailRegistration = Join-Path $repoRoot 'profiles\shared\skills\starrail-sprint\agents\openai.yaml'
$sourceStarrailContract = Join-Path $repoRoot 'profiles\shared\contract\STARRAIL_SPRINT_CONTRACT.json'
$hermesFailures = [System.Collections.Generic.List[string]]::new()
$aliases = @()

foreach ($desktopEntryPoint in @(
  @{ name = 'PowerShell installer'; path = $installer },
  @{ name = 'POSIX installer'; path = (Join-Path $repoRoot 'install.sh') }
)) {
  if (-not (Test-Path -LiteralPath $desktopEntryPoint.path -PathType Leaf)) {
    $hermesFailures.Add("$($desktopEntryPoint.name) missing") | Out-Null
  } elseif (-not (Get-Content -LiteralPath $desktopEntryPoint.path -Raw -Encoding UTF8).Contains('hermes desktop --cwd')) {
    $hermesFailures.Add("$($desktopEntryPoint.name) missing Hermes Desktop entry point") | Out-Null
  }
}

$requiredHermesFiles = @($hermesSkill, $hermesRegistration, $hermesContract, $hermesGuide, $hermesConfig, $hermesBundle)
foreach ($requiredFile in $requiredHermesFiles) {
  if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
    $hermesFailures.Add("missing=$requiredFile") | Out-Null
  }
}
if (Test-Path -LiteralPath $hermesObsoleteContract -PathType Leaf) {
  $hermesFailures.Add('obsolete contract present') | Out-Null
}

if ($hermesFailures.Count -eq 0) {
  if ((Get-Sha256 -Path $sourceStarrailSkill) -cne (Get-Sha256 -Path $hermesSkill)) {
    $hermesFailures.Add('skill hash mismatch') | Out-Null
  }
  if ((Get-Sha256 -Path $sourceStarrailRegistration) -cne (Get-Sha256 -Path $hermesRegistration)) {
    $hermesFailures.Add('registration hash mismatch') | Out-Null
  }
  if ((Get-Sha256 -Path $sourceStarrailContract) -cne (Get-Sha256 -Path $hermesContract)) {
    $hermesFailures.Add('contract hash mismatch') | Out-Null
  }

  $contractData = Get-Content -LiteralPath $hermesContract -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
  $aliases = @($contractData.session_aliases.psobject.Properties | ForEach-Object { @($_.Value) } | ForEach-Object { [string]$_ })
  $skillText = Get-Content -LiteralPath $hermesSkill -Raw -Encoding UTF8
  $guideText = Get-Content -LiteralPath $hermesGuide -Raw -Encoding UTF8
  $configText = Get-Content -LiteralPath $hermesConfig -Raw -Encoding UTF8
  foreach ($alias in $aliases) {
    if (-not $skillText.Contains($alias)) {
      $hermesFailures.Add("skill alias missing=$alias") | Out-Null
    }
    $escapedAlias = [regex]::Escape($alias)
    $mappingPattern = "(?m)^  (?:'$escapedAlias'|$escapedAlias):\r?`n    type: alias\r?`n    target: /starrail-sprint\r?$"
    if (([regex]::Matches($configText, $mappingPattern)).Count -ne 1) {
      $hermesFailures.Add("quick alias invalid=$alias") | Out-Null
    }
  }
  foreach ($identifier in @('AemethExecutionLanguage', 'StelleStepContract', 'StarrailTopologyGraph', 'TrailblazerExecutor', 'New-AemethSprint', 'New-StelleStep', 'New-StarrailTopology', 'Invoke-Trailblazer')) {
    if (-not $guideText.Contains($identifier)) {
      $hermesFailures.Add("guide identifier missing=$identifier") | Out-Null
    }
  }
  foreach ($commandName in @('starrail-sprint', 'aemeth-sprint')) {
    $commandPattern = "(?m)^  ${commandName}:\r?`n    type: alias\r?`n    target: /starrail-sprint\r?$"
    if (([regex]::Matches($configText, $commandPattern)).Count -ne 1) {
      $hermesFailures.Add("command alias invalid=$commandName") | Out-Null
    }
  }
  if ($contractData.compatibility.hermes_adapter.kind -cne 'bounded-aemeth-home') {
    $hermesFailures.Add('Hermes adapter contract missing') | Out-Null
  }
}

$configHashBefore = if (Test-Path -LiteralPath $hermesConfig -PathType Leaf) { Get-Sha256 -Path $hermesConfig } else { '' }
$hermesRerun = Invoke-Installer -Tool 'hermes'
$configHashAfter = if (Test-Path -LiteralPath $hermesConfig -PathType Leaf) { Get-Sha256 -Path $hermesConfig } else { '' }
if ($hermesRerun.exit -ne 0 -or [string]::IsNullOrWhiteSpace($configHashBefore) -or $configHashBefore -cne $configHashAfter) {
  $hermesFailures.Add('idempotent rerun failed') | Out-Null
}
$customPreserved = $false
if (Test-Path -LiteralPath $hermesConfig -PathType Leaf) {
  $originalConfigBytes = [System.IO.File]::ReadAllBytes($hermesConfig)
  try {
    $customConfigText = (Get-Content -LiteralPath $hermesConfig -Raw -Encoding UTF8).TrimEnd() + "`nmanager_preserved_setting: true`n"
    [System.IO.File]::WriteAllText($hermesConfig, $customConfigText, [System.Text.UTF8Encoding]::new($false))
    $customHashBefore = Get-Sha256 -Path $hermesConfig
    $customRerun = Invoke-Installer -Tool 'hermes'
    $customHashAfter = Get-Sha256 -Path $hermesConfig
    $customPreserved = ($customRerun.exit -eq 0 -and $customHashBefore -ceq $customHashAfter)
  } finally {
    [System.IO.File]::WriteAllBytes($hermesConfig, $originalConfigBytes)
  }
}
if (-not $customPreserved) {
  $hermesFailures.Add('manager config preservation failed') | Out-Null
}
$hermesSkillCount = @(Get-SkillNames -Roots @((Join-Path $hermesHome 'skills'))).Count
if ($hermesSkillCount -ne 1) {
  $hermesFailures.Add("bounded skill count=$hermesSkillCount") | Out-Null
}

$hermesStatus = if ($hermesInstall.exit -eq 0 -and $hermesFailures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$hermesEvidence = "installer_exit=$($hermesInstall.exit); active_skills=$hermesSkillCount; aliases=$($aliases.Count); idempotent=$($configHashBefore -ceq $configHashAfter); manager_config_preserved=$customPreserved"
if ($hermesFailures.Count -gt 0) {
  $hermesEvidence += '; failures=' + (($hermesFailures | Select-Object -First 8) -join ',')
}
$rows.Add([pscustomobject]@{
    tool = 'hermes-aemeth-adapter'
    status = $hermesStatus
    evidence = $hermesEvidence
    next_action = 'Materialize the bounded Hermes Aemeth home and restart or reload skills before claiming recognition.'
  }) | Out-Null

$failures = @($rows | Where-Object { $_.status -ne 'PASS' })
$summary = [pscustomobject]@{
  gate = 'Driftless installer materialization'
  root = $repoRoot
  status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
  results = @($rows)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 6
} else {
  Write-Output '== Driftless installer materialization =='
  foreach ($row in $rows) {
    Write-Output ("[{0}] {1} - {2}" -f $row.status, $row.tool, $row.evidence)
  }
  Write-Output ("RESULT: {0}" -f $summary.status)
}

if ($failures.Count -gt 0) { exit 1 }
exit 0
