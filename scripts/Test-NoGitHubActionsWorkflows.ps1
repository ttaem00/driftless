#Requires -Version 7.2
#Requires -PSEdition Core
<#
.SYNOPSIS
  Fail when tracked GitHub Actions workflow files are present.

.DESCRIPTION
  This repo uses local PowerShell validation as the merge authority. Hosted
  GitHub Actions workflows must not be reintroduced by stale branches because
  account, billing, or hosted runner state is not a manager-safe completion gate.
#>
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
  [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TrackedWorkflowFiles {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $output = & git -C $RepoRoot ls-files -- '.github/workflows/*.yml' '.github/workflows/*.yaml'
  if ($LASTEXITCODE -ne 0) {
    throw "git ls-files failed for $RepoRoot"
  }

  return @($output | Where-Object { $_ })
}

function Invoke-Check {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $files = @(Get-TrackedWorkflowFiles -RepoRoot $RepoRoot)
  if ($files.Count -gt 0) {
    [Console]::Out.WriteLine(("[FAIL] no tracked GitHub Actions workflows - count={0}; files={1}" -f $files.Count, ($files -join ',')))
    return $false
  }

  [Console]::Out.WriteLine('[PASS] no tracked GitHub Actions workflows - count=0')
  return $true
}

if ($SelfTest) {
  $repo = (Resolve-Path -LiteralPath $Root).Path
  $tmp = Join-Path $repo '.runtime\test-no-actions-workflows'
  $tmpFull = [System.IO.Path]::GetFullPath($tmp)
  $repoFull = [System.IO.Path]::GetFullPath($repo)

  if (-not $tmpFull.StartsWith($repoFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing temp path outside repo: $tmpFull"
  }

  if (Test-Path -LiteralPath $tmpFull) {
    Remove-Item -LiteralPath $tmpFull -Recurse -Force
  }

  New-Item -ItemType Directory -Path (Join-Path $tmpFull '.github\workflows') -Force | Out-Null
  git -C $tmpFull init *> $null
  Set-Content -LiteralPath (Join-Path $tmpFull '.github\workflows\bad.yml') -Value 'name: bad' -Encoding ASCII
  git -C $tmpFull add . *> $null
  $negative = Invoke-Check -RepoRoot $tmpFull

  git -C $tmpFull rm -f -q '.github/workflows/bad.yml'
  $positive = Invoke-Check -RepoRoot $tmpFull

  Remove-Item -LiteralPath $tmpFull -Recurse -Force

  if ($negative -or -not $positive) {
    Write-Output 'RESULT: FAIL self-test did not prove both fail/pass directions'
    exit 1
  }
}

$rootPath = (Resolve-Path -LiteralPath $Root).Path
$ok = Invoke-Check -RepoRoot $rootPath

if ($ok) {
  Write-Output 'RESULT: PASS'
  exit 0
}

Write-Output 'RESULT: FAIL'
exit 1
