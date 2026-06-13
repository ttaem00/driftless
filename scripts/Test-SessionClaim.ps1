#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Behavioral tests for the tool-agnostic session-claim helper (issue #137):
  New-SessionClaim.ps1 core semantics, cross-store conflict detection (rule R3
  in docs/cross-agent-work-arbitration.md), default store resolution, and the
  New-CodexSessionClaim.ps1 back-compat wrapper delegation.

.DESCRIPTION
  Complements Test-CodexSessionClaim.ps1 (which exercises the wrapper's full
  legacy behavior). This gate drives the core under pwsh and focuses on what is
  NEW in the tool-agnostic helper:

    * explicit-StatePath isolation (old behavior preserved exactly),
    * -CrossStatePath read-only conflict scanning across a second store,
    * stale cross-store claims downgrade to PARENT_REVIEW_NEEDED (exit 3),
    * Release mutates only the primary store,
    * default store resolution (.agent-work primary, .claude-work/.codex-work
      scanned) proven inside an isolated temp git fixture,
    * the Codex wrapper delegates to the core and propagates exit codes.

  All artifacts live in unique temp/gitignored folders and are removed in the
  finally block.
#>
param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-ClaimJson([string]$HelperPath, [string[]]$Arguments, [int[]]$ExpectedExitCodes = @(0)) {
    $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $HelperPath @Arguments
    $exitCode = $LASTEXITCODE
    Assert-True ($ExpectedExitCodes -contains $exitCode) "Unexpected exit code $exitCode for args: $($Arguments -join ' ')`n$output"
    $jsonText = ($output -join "`n")
    Assert-True (-not [string]::IsNullOrWhiteSpace($jsonText)) "Helper returned no JSON for args: $($Arguments -join ' ')"
    return $jsonText | ConvertFrom-Json
}

$script:Core = Join-Path $PSScriptRoot "New-SessionClaim.ps1"
$script:Wrapper = Join-Path $PSScriptRoot "New-CodexSessionClaim.ps1"
$repo = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $repo (Join-Path ".agent-work\session-claim-tests" ([System.Guid]::NewGuid().ToString("N")))
$storeA = Join-Path $testRoot "store-a.json"
$storeB = Join-Path $testRoot "store-b.json"
$nonGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("session-claim-nongit-" + [System.Guid]::NewGuid().ToString("N"))
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("session-claim-fixture-" + [System.Guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $nonGitRoot | Out-Null

    # --- Non-git RepoPath fails explicitly and writes nothing. ---------------
    $nonGitStatePath = Join-Path $nonGitRoot "session-claims.json"
    $savedEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $nonGitOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Core `
            -Mode Check `
            -RepoPath $nonGitRoot `
            -OwnerSurface "scripts\alpha.ps1" `
            -StatePath $nonGitStatePath `
            -Json 2>&1
        $nonGitExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $savedEap
    }
    Assert-True ($nonGitExitCode -ne 0) "Non-git RepoPath unexpectedly succeeded."
    Assert-True (($nonGitOutput -join "`n") -match "RepoPath must be inside a git worktree") "Non-git RepoPath error was not explicit.`n$nonGitOutput"
    Assert-True (-not (Test-Path -LiteralPath $nonGitStatePath)) "Non-git RepoPath wrote claim state."

    # --- Forbidden surface is BLOCKED (exit 4) and writes nothing. -----------
    $forbidden = Invoke-ClaimJson $script:Core @(
        "-Mode", "Check",
        "-RepoPath", $repo,
        "-OwnerSurface", ("." + "env"),
        "-StatePath", $storeA,
        "-Json"
    ) @(4)
    Assert-True ($forbidden.state -eq "BLOCKED_NEEDS_MANAGER_DECISION") "Forbidden owner surface was not blocked."
    Assert-True (-not (Test-Path -LiteralPath $storeA)) "Forbidden Check wrote claim state."

    # --- Explicit StatePath: Check is non-mutating, Acquire writes. ----------
    $commonA = @(
        "-RepoPath", $repo,
        "-Issue", "600",
        "-TaskId", "issue-600-a",
        "-Branch", "agent/issue-600-a",
        "-Worktree", ".runtime\worktrees\issue-600-a",
        "-OwnerSurface", "scripts\alpha.ps1",
        "-Owner", "claim-test-a",
        "-StatePath", $storeA,
        "-Json"
    )
    $check = Invoke-ClaimJson $script:Core (@("-Mode", "Check") + $commonA)
    Assert-True ($check.state -eq "OWNERSHIP_CLEAR_TO_START") "Disjoint Check did not return clear-to-start."
    Assert-True (@($check.crossStorePaths).Count -eq 0) "Explicit StatePath without CrossStatePath must scan only the primary store."
    Assert-True (-not (Test-Path -LiteralPath $storeA)) "Check created claim state even though it must be non-mutating."

    $acquireA = Invoke-ClaimJson $script:Core (@("-Mode", "Acquire") + $commonA)
    Assert-True ($acquireA.state -eq "OWNERSHIP_CLEAR_TO_START") "Acquire A did not return clear-to-start."
    Assert-True (Test-Path -LiteralPath $storeA) "Acquire did not write claim state."

    $branchConflict = Invoke-ClaimJson $script:Core @(
        "-Mode", "Acquire",
        "-RepoPath", $repo,
        "-Issue", "601",
        "-Branch", "agent/issue-600-a",
        "-OwnerSurface", "scripts\branch.ps1",
        "-StatePath", $storeA,
        "-Json"
    ) @(2)
    Assert-True ($branchConflict.state -eq "DUPLICATE_WORK_DETECTED") "Branch overlap did not return duplicate-work."
    Assert-True (($branchConflict.conflicts[0].reasons -contains "branch")) "Branch conflict reason missing."

    # --- Cross-store scan (rule R3): a claim in store B blocks via store A. --
    $acquireB = Invoke-ClaimJson $script:Core @(
        "-Mode", "Acquire",
        "-RepoPath", $repo,
        "-Issue", "700",
        "-TaskId", "issue-700-b",
        "-Branch", "agent/issue-700-b",
        "-OwnerSurface", "scripts\beta.ps1",
        "-Owner", "claim-test-b",
        "-StatePath", $storeB,
        "-Json"
    )
    Assert-True ($acquireB.state -eq "OWNERSHIP_CLEAR_TO_START") "Acquire B did not return clear-to-start."

    $crossConflict = Invoke-ClaimJson $script:Core @(
        "-Mode", "Check",
        "-RepoPath", $repo,
        "-Issue", "700",
        "-StatePath", $storeA,
        "-CrossStatePath", $storeB,
        "-Json"
    ) @(2)
    Assert-True ($crossConflict.state -eq "DUPLICATE_WORK_DETECTED") "Cross-store issue overlap was not detected."
    Assert-True (($crossConflict.conflicts[0].reasons -contains "issue")) "Cross-store conflict reason missing."
    Assert-True (([string]$crossConflict.conflicts[0].store) -eq $storeB) "Cross-store conflict did not name the source store."

    $crossClear = Invoke-ClaimJson $script:Core @(
        "-Mode", "Check",
        "-RepoPath", $repo,
        "-Issue", "800",
        "-StatePath", $storeA,
        "-CrossStatePath", $storeB,
        "-Json"
    )
    Assert-True ($crossClear.state -eq "OWNERSHIP_CLEAR_TO_START") "Disjoint cross-store Check did not return clear-to-start."

    # Timezone regression: a claim acquired seconds ago must classify as a live
    # DUPLICATE (exit 2), never as stale PARENT_REVIEW_NEEDED (exit 3), even
    # with the tightest threshold and on non-UTC hosts. Guards the Kind-aware
    # timestamp handling in Test-ClaimStale.
    $freshTight = Invoke-ClaimJson $script:Core @(
        "-Mode", "Check",
        "-RepoPath", $repo,
        "-Issue", "700",
        "-StatePath", $storeA,
        "-CrossStatePath", $storeB,
        "-StaleAfterHours", "1",
        "-Json"
    ) @(2)
    Assert-True ($freshTight.state -eq "DUPLICATE_WORK_DETECTED") "Fresh claim was misclassified as stale (timezone-sensitive timestamp handling regressed)."

    # --- Cross-store surface overlap stays a WAIT state. ---------------------
    $crossWait = Invoke-ClaimJson $script:Core @(
        "-Mode", "Check",
        "-RepoPath", $repo,
        "-Issue", "801",
        "-OwnerSurface", "scripts\beta.ps1",
        "-StatePath", $storeA,
        "-CrossStatePath", $storeB,
        "-Json"
    ) @(2)
    Assert-True ($crossWait.state -eq "WAIT_FOR_OTHER_SESSION") "Cross-store surface overlap did not return wait state."
    Assert-True (($crossWait.conflicts[0].reasons -contains "ownerSurface")) "Cross-store surface conflict reason missing."

    # --- Release mutates only the primary store. -----------------------------
    $releaseA = Invoke-ClaimJson $script:Core @(
        "-Mode", "Release",
        "-RepoPath", $repo,
        "-Issue", "600",
        "-StatePath", $storeA,
        "-CrossStatePath", $storeB,
        "-Json"
    )
    Assert-True ($releaseA.releasedCount -eq 1) "Release A did not release exactly one claim."
    $showB = Invoke-ClaimJson $script:Core @("-Mode", "Show", "-RepoPath", $repo, "-StatePath", $storeB, "-Json")
    Assert-True ($showB.claimCount -eq 1) "Release through store A touched store B."

    # --- Show surfaces cross-store claims read-only. --------------------------
    $showCross = Invoke-ClaimJson $script:Core @("-Mode", "Show", "-RepoPath", $repo, "-StatePath", $storeA, "-CrossStatePath", $storeB, "-Json")
    Assert-True ($showCross.crossClaimCount -eq 1) "Show did not surface the cross-store claim."

    # --- Stale cross-store claim downgrades to PARENT_REVIEW_NEEDED. ---------
    $staleState = Get-Content -Raw -Encoding UTF8 -LiteralPath $storeB | ConvertFrom-Json
    $oldStamp = (Get-Date).ToUniversalTime().AddHours(-2).ToString("o")
    $staleState.claims[0].updatedAt = $oldStamp
    $staleState.claims[0].createdAt = $oldStamp
    $staleState | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $storeB -Encoding UTF8

    $staleConflict = Invoke-ClaimJson $script:Core @(
        "-Mode", "Check",
        "-RepoPath", $repo,
        "-Issue", "700",
        "-StatePath", $storeA,
        "-CrossStatePath", $storeB,
        "-StaleAfterHours", "1",
        "-Json"
    ) @(3)
    Assert-True ($staleConflict.state -eq "PARENT_REVIEW_NEEDED") "Stale cross-store overlap did not return parent-review state."

    # --- Default store resolution + wrapper delegation, in a temp fixture. ---
    New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null
    & git -C $fixtureRoot init -b main | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "git init fixture failed."

    $fixtureCodexStore = Join-Path $fixtureRoot ".codex-work\session-claims.json"
    $fixtureAcquire = Invoke-ClaimJson $script:Core @(
        "-Mode", "Acquire",
        "-RepoPath", $fixtureRoot,
        "-Issue", "555",
        "-Branch", "agent/issue-555-fixture",
        "-Owner", "claim-test-fixture",
        "-StatePath", $fixtureCodexStore,
        "-Json"
    )
    Assert-True ($fixtureAcquire.state -eq "OWNERSHIP_CLEAR_TO_START") "Fixture acquire did not return clear-to-start."

    $defaultCheck = Invoke-ClaimJson $script:Core @(
        "-Mode", "Check",
        "-RepoPath", $fixtureRoot,
        "-Issue", "555",
        "-Json"
    ) @(2)
    Assert-True ($defaultCheck.state -eq "DUPLICATE_WORK_DETECTED") "Default-store Check did not cross-detect the .codex-work claim."
    Assert-True (([string]$defaultCheck.statePath).EndsWith(".agent-work\session-claims.json")) "Default primary store is not .agent-work."
    Assert-True (([string]$defaultCheck.conflicts[0].store) -eq ([System.IO.Path]::GetFullPath($fixtureCodexStore))) "Default cross-store scan did not name the .codex-work store."

    # -CrossStatePath is additive: passing it WITHOUT -StatePath must not turn
    # off the default-store scan (a false all-clear would break rule R3).
    $additiveCheck = Invoke-ClaimJson $script:Core @(
        "-Mode", "Check",
        "-RepoPath", $fixtureRoot,
        "-Issue", "555",
        "-CrossStatePath", (Join-Path $fixtureRoot "unrelated-store.json"),
        "-Json"
    ) @(2)
    Assert-True ($additiveCheck.state -eq "DUPLICATE_WORK_DETECTED") "Explicit -CrossStatePath disabled the default cross-store scan."

    $wrapperCheck = Invoke-ClaimJson $script:Wrapper @(
        "-Mode", "Check",
        "-RepoPath", $fixtureRoot,
        "-Issue", "555",
        "-Json"
    ) @(2)
    Assert-True ($wrapperCheck.state -eq "DUPLICATE_WORK_DETECTED") "Wrapper did not delegate to the core (conflict missed)."
    Assert-True (([string]$wrapperCheck.statePath).EndsWith(".codex-work\session-claims.json")) "Wrapper default primary store is not .codex-work."

    Write-Host "Session claim helper (tool-agnostic core + cross-store) tests PASS"
    $global:LASTEXITCODE = 0
}
finally {
    if (-not $KeepArtifacts) {
        foreach ($path in @($testRoot, $nonGitRoot, $fixtureRoot)) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }
    }
}
