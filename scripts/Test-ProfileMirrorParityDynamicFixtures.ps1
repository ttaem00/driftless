#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Fixture tests for dynamic same-name skill discovery in
  Test-ProfileMirrorParity.ps1.

.DESCRIPTION
  Builds three temporary fixture repos and runs the real mirror-parity gate:
  - same-name profile-local skill classified as sharedAsset -> PASS
  - same-name profile-local skill unclassified -> FAIL
  - same-name profile-local skill explicitly exempted with why -> PASS

  This proves sharedness is discovered from profile consumers instead of relying
  only on a manually remembered allowlist.
#>
param()

$ErrorActionPreference = 'Stop'
$sut = Join-Path $PSScriptRoot 'Test-ProfileMirrorParity.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("driftless-mirror-fixtures-" + [guid]::NewGuid().ToString('n'))

function Write-Utf8NoBom {
  param([string]$Path, [string]$Text)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function New-Fixture {
  param(
    [string]$Name,
    [string]$SkillName,
    [switch]$DeclareShared,
    [switch]$DeclareExempt
  )
  $root = Join-Path $tempRoot $Name
  New-Item -ItemType Directory -Path $root -Force | Out-Null
  Write-Utf8NoBom -Path (Join-Path $root 'profiles/claude/README.md') -Text 'Consumes ../shared/schemas/forbidden-paths.json'
  Write-Utf8NoBom -Path (Join-Path $root 'profiles/codex/README.md') -Text 'Consumes ../shared/schemas/forbidden-paths.json'
  Write-Utf8NoBom -Path (Join-Path $root 'profiles/shared/contract/SHARED_DESIGN_CONTRACT.md') -Text '# Shared contract'
  Write-Utf8NoBom -Path (Join-Path $root 'profiles/shared/schemas/forbidden-paths.json') -Text '{}'
  Write-Utf8NoBom -Path (Join-Path $root "profiles/claude/skills/$SkillName/SKILL.md") -Text "---`nname: $SkillName`n---`n"
  Write-Utf8NoBom -Path (Join-Path $root "profiles/codex/skills/$SkillName/SKILL.md") -Text "---`nname: $SkillName`n---`n"

  $sharedAssets = @(
    [ordered]@{
      name = 'forbidden-paths'
      file = 'schemas/forbidden-paths.json'
      consumedBy = @('claude', 'codex')
      why = 'fixture consumer proof'
    }
  )
  if ($DeclareShared) {
    Write-Utf8NoBom -Path (Join-Path $root "profiles/shared/skills/$SkillName/SKILL.md") -Text "---`nname: $SkillName`n---`n"
    $sharedAssets += [ordered]@{
      name = "skill-$SkillName"
      file = "skills/$SkillName/SKILL.md"
      consumedBy = @('claude', 'codex')
      why = 'fixture shared skill'
    }
  }

  $manifest = [ordered]@{
    '$comment' = 'temporary fixture allowlist'
    sharedRoot = 'profiles/shared'
    claudeProfileRoot = 'profiles/claude'
    codexProfileRoot = 'profiles/codex'
    sharedAssets = $sharedAssets
    profileConsumerProof = [ordered]@{
      claude = [ordered]@{ consumerFile = 'profiles/claude/README.md'; mustReference = '../shared/schemas/forbidden-paths.json' }
      codex = [ordered]@{ consumerFile = 'profiles/codex/README.md'; mustReference = '../shared/schemas/forbidden-paths.json' }
    }
    toolSpecificExempt = @()
    profileLocalSameNameExempt = @()
  }
  if ($DeclareExempt) {
    $manifest.profileLocalSameNameExempt = @(
      [ordered]@{
        name = $SkillName
        why = 'fixture tool-shaped implementation differs while the public contract remains equivalent'
      }
    )
  }
  Write-Utf8NoBom -Path (Join-Path $root 'profiles/shared/schemas/mirror-parity-allowlist.json') -Text (($manifest | ConvertTo-Json -Depth 8) + "`n")
  return $root
}

function Invoke-Fixture {
  param([string]$Name, [string]$Root, [int]$ExpectedExit)
  $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $sut -Root $Root -SkipGitDiff -Json 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne $ExpectedExit) {
    Write-Output ($output -join "`n")
    throw "Fixture '$Name' expected exit $ExpectedExit but got $exitCode"
  }
  Write-Output ("[PASS] {0} expected_exit={1}" -f $Name, $ExpectedExit)
}

try {
  $classified = New-Fixture -Name 'classified-pass' -SkillName 'shared-control' -DeclareShared
  $unclassified = New-Fixture -Name 'unclassified-fail' -SkillName 'shared-control'
  $exempt = New-Fixture -Name 'exempt-pass' -SkillName 'tool-shaped-control' -DeclareExempt

  Invoke-Fixture -Name 'classified same-name sharedAsset passes' -Root $classified -ExpectedExit 0
  Invoke-Fixture -Name 'unclassified same-name fails' -Root $unclassified -ExpectedExit 1
  Invoke-Fixture -Name 'explicit same-name exemption passes' -Root $exempt -ExpectedExit 0
  Write-Output 'RESULT: PASS'
} finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}
