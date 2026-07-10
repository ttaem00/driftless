#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Verifies that Driftless installers materialize shared skills into active agent homes.

.DESCRIPTION
  The profiles keep shared skills once under profiles/shared/skills, but the
  generated Claude/Codex homes must expose those skills under their active
  skills/ directory. A recursive SKILL.md count is not enough: agents load from
  their home skills directory.
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
  @{ tool = 'claude'; profile = 'profiles\claude\skills'; home = '.runtime\claude-home\skills' },
  @{ tool = 'codex'; profile = 'profiles\codex\skills'; home = '.runtime\codex-home\skills' }
)

$rows = [System.Collections.Generic.List[object]]::new()
$requiredExactTriggerSkills = @('wuther-codemap')

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
