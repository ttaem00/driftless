#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Back-compat wrapper: Codex-named entrypoint for the tool-agnostic session
  claim helper (issue #137).

.DESCRIPTION
  The single claim implementation lives in New-SessionClaim.ps1 ("one purpose,
  one script" - the same rule Test-WorkSurfaceDuplication.ps1 enforces for
  skills). This wrapper only preserves the historical entrypoint name and its
  historical default store (.codex-work/session-claims.json) for existing
  callers and CI. New callers should use New-SessionClaim.ps1 directly.
  Runs under PowerShell 7 (pwsh), like the core.
#>
param(
    [ValidateSet("Check", "Acquire", "Release", "Show")]
    [string]$Mode = "Check",
    [string]$RepoPath = ".",
    [string]$Issue,
    [string]$TaskId,
    [string]$Branch,
    [string]$Worktree,
    [string[]]$OwnerSurface = @(),
    [string]$Owner = $env:USERNAME,
    [string]$ClaimId,
    [int]$StaleAfterHours = 24,
    [string]$StoreDirName = ".codex-work",
    [string]$StatePath,
    [string[]]$CrossStatePath,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$forward = @{}
foreach ($key in $PSBoundParameters.Keys) {
    $forward[$key] = $PSBoundParameters[$key]
}
if (-not $forward.ContainsKey("StoreDirName")) {
    $forward["StoreDirName"] = $StoreDirName
}

& (Join-Path $PSScriptRoot "New-SessionClaim.ps1") @forward
exit $LASTEXITCODE
