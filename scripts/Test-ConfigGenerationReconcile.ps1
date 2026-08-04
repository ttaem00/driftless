#Requires -Version 7.2
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$modulePath = Join-Path $repoRoot 'profiles\shared\modules\config-generation-reconcile\ConfigGenerationReconcile.psm1'
$fixtureRoot = Join-Path $repoRoot '.runtime\test-config-generation-reconcile'

function Write-Utf8Text {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Text)
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Assert-True {
  param([Parameter(Mandatory = $true)][bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
  if (-not $Condition) { throw $Message }
}

if (Test-Path -LiteralPath $fixtureRoot) {
  Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}

try {
  Import-Module $modulePath -Force
  [System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null
  $caseRoot = Join-Path $fixtureRoot 'case with spaces'
  [System.IO.Directory]::CreateDirectory($caseRoot) | Out-Null
  $base = Join-Path $caseRoot 'base.txt'
  $user = Join-Path $caseRoot 'user.txt'
  $target = Join-Path $caseRoot 'target.txt'
  $candidate = Join-Path $caseRoot 'candidate.txt'
  $receipt = Join-Path $caseRoot 'receipt.json'
  $active = Join-Path $fixtureRoot 'active.txt'
  Write-Utf8Text -Path $active -Text "active-sentinel`n"

  Write-Utf8Text -Path $base -Text "first=base`nseparator=stable`nsecond=base`n"
  Write-Utf8Text -Path $user -Text "first=user`nseparator=stable`nsecond=base`n"
  Write-Utf8Text -Path $target -Text "first=base`nseparator=stable`nsecond=target`n"
  $merged = Invoke-DriftlessConfigGenerationReconcile -BasePath $base -UserPath $user -TargetPath $target -CandidatePath $candidate -ReceiptPath $receipt -GenerationId 'clean-merge'
  Assert-True ($merged.status -eq 'AUTO_MERGED') 'Expected a clean three-way merge.'
  $candidateText = Get-Content -LiteralPath $candidate -Raw
  Assert-True ($candidateText.Contains('first=user') -and $candidateText.Contains('second=target')) 'Candidate did not retain both independent changes.'
  Assert-True ((Get-Content -LiteralPath $active -Raw) -eq "active-sentinel`n") 'Reconcile mutated the active sentinel.'

  Write-Utf8Text -Path $base -Text "setting=base`n"
  Write-Utf8Text -Path $user -Text "setting=user`n"
  Write-Utf8Text -Path $target -Text "setting=target`n"
  $held = Invoke-DriftlessConfigGenerationReconcile -BasePath $base -UserPath $user -TargetPath $target -CandidatePath $candidate -ReceiptPath $receipt -GenerationId 'held-conflict'
  Assert-True ($held.status -eq 'HELD_CONFLICT') 'Expected same-line divergence to be held.'
  Assert-True (-not (Test-Path -LiteralPath $candidate)) 'A held conflict must not leave a candidate.'

  Write-Utf8Text -Path $user -Text "setting=base`n"
  $official = Invoke-DriftlessConfigGenerationReconcile -BasePath $base -UserPath $user -TargetPath $target -CandidatePath $candidate -ReceiptPath $receipt -GenerationId 'target-applied'
  Assert-True ($official.status -eq 'TARGET_APPLIED') 'Expected unchanged user state to accept target.'
  Assert-True ((Get-Content -LiteralPath $candidate -Raw) -eq "setting=target`n") 'Target candidate mismatch.'

  Write-Utf8Text -Path $user -Text "setting=user`n"
  Write-Utf8Text -Path $target -Text "setting=base`n"
  $preserved = Invoke-DriftlessConfigGenerationReconcile -BasePath $base -UserPath $user -TargetPath $target -CandidatePath $candidate -ReceiptPath $receipt -GenerationId 'user-preserved'
  Assert-True ($preserved.status -eq 'USER_PRESERVED') 'Expected unchanged target to preserve user state.'
  Assert-True ((Get-Content -LiteralPath $candidate -Raw) -eq "setting=user`n") 'User candidate mismatch.'

  [System.IO.File]::WriteAllBytes($user, [byte[]](1, 0, 2))
  [System.IO.File]::WriteAllBytes($target, [byte[]](1, 0, 3))
  [System.IO.File]::WriteAllBytes($base, [byte[]](1, 0, 4))
  $binary = Invoke-DriftlessConfigGenerationReconcile -BasePath $base -UserPath $user -TargetPath $target -CandidatePath $candidate -ReceiptPath $receipt -GenerationId 'binary-held'
  Assert-True ($binary.status -eq 'HELD_BINARY_CONFLICT') 'Expected divergent binary state to be held.'
  Assert-True (-not (Test-Path -LiteralPath $candidate)) 'A held binary conflict must not leave a candidate.'

  $aliasRejected = $false
  try {
    Invoke-DriftlessConfigGenerationReconcile -BasePath $base -UserPath $user -TargetPath $target -CandidatePath $user -ReceiptPath $receipt -GenerationId 'alias-rejected' | Out-Null
  } catch {
    $aliasRejected = $_.Exception.Message.Contains('must not overwrite an input')
  }
  Assert-True $aliasRejected 'Expected an output/input path collision to be rejected.'

  Write-Output '{"result":"PASS","clean_merge":true,"space_path":true,"conflict_held":true,"binary_held":true,"path_alias_rejected":true,"active_unchanged":true,"temporary_fixture_removed":true}'
} finally {
  if (Test-Path -LiteralPath $fixtureRoot) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}
