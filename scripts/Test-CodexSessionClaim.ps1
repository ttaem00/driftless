param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = "Stop"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-ClaimHelperJson([string[]]$Arguments, [int[]]$ExpectedExitCodes = @(0)) {
    $output = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $script:Helper @Arguments
    $exitCode = $LASTEXITCODE
    Assert-True ($ExpectedExitCodes -contains $exitCode) "Unexpected exit code $exitCode for args: $($Arguments -join ' ')`n$output"
    $jsonText = ($output -join "`n")
    Assert-True (-not [string]::IsNullOrWhiteSpace($jsonText)) "Helper returned no JSON for args: $($Arguments -join ' ')"
    return $jsonText | ConvertFrom-Json
}

$script:Helper = Join-Path $PSScriptRoot "New-CodexSessionClaim.ps1"
$repo = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path $repo (Join-Path ".codex-work\session-claim-tests" ([System.Guid]::NewGuid().ToString("N")))
$statePath = Join-Path $testRoot "session-claims.json"
$nonGitRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-session-claim-nongit-" + [System.Guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $nonGitRoot | Out-Null

    $nonGitStatePath = Join-Path $nonGitRoot "session-claims.json"
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $nonGitOutput = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $script:Helper `
            -Mode Check `
            -RepoPath $nonGitRoot `
            -OwnerSurface "scripts\alpha.ps1" `
            -StatePath $nonGitStatePath `
            -Json 2>&1
        $nonGitExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    Assert-True ($nonGitExitCode -ne 0) "Non-git RepoPath unexpectedly succeeded."
    Assert-True (($nonGitOutput -join "`n") -match "RepoPath must be inside a git worktree") "Non-git RepoPath error was not explicit.`n$nonGitOutput"
    Assert-True (-not (Test-Path -LiteralPath $nonGitStatePath)) "Non-git RepoPath wrote claim state."

    $commonA = @(
        "-RepoPath", $repo,
        "-Issue", "600",
        "-TaskId", "issue-600-a",
        "-Branch", "codex/issue-600-a",
        "-Worktree", ".runtime\worktrees\issue-600-a",
        "-OwnerSurface", "scripts\alpha.ps1",
        "-Owner", "claim-test-a",
        "-StatePath", $statePath,
        "-Json"
    )

    $check = Invoke-ClaimHelperJson (@("-Mode", "Check") + $commonA)
    Assert-True ($check.state -eq "OWNERSHIP_CLEAR_TO_START") "Disjoint Check did not return clear-to-start."
    Assert-True (-not (Test-Path -LiteralPath $statePath)) "Check created claim state even though it must be non-mutating."

    $forbidden = Invoke-ClaimHelperJson @(
        "-Mode", "Check",
        "-RepoPath", $repo,
        "-OwnerSurface", ("." + "env"),
        "-StatePath", $statePath,
        "-Json"
    ) @(4)
    Assert-True ($forbidden.state -eq "BLOCKED_NEEDS_MANAGER_DECISION") "Forbidden owner surface was not blocked."
    Assert-True (-not (Test-Path -LiteralPath $statePath)) "Forbidden Check wrote claim state."

    $acquireA = Invoke-ClaimHelperJson (@("-Mode", "Acquire") + $commonA)
    Assert-True ($acquireA.state -eq "OWNERSHIP_CLEAR_TO_START") "Acquire A did not return clear-to-start."
    Assert-True (Test-Path -LiteralPath $statePath) "Acquire did not write claim state."

    $branchConflict = Invoke-ClaimHelperJson @(
        "-Mode", "Acquire",
        "-RepoPath", $repo,
        "-Issue", "601",
        "-TaskId", "issue-601-branch",
        "-Branch", "codex/issue-600-a",
        "-Worktree", ".runtime\worktrees\issue-601-branch",
        "-OwnerSurface", "scripts\branch.ps1",
        "-Owner", "claim-test-branch",
        "-StatePath", $statePath,
        "-Json"
    ) @(2)
    Assert-True ($branchConflict.state -eq "DUPLICATE_WORK_DETECTED") "Branch overlap did not return duplicate-work."
    Assert-True (($branchConflict.conflicts[0].reasons -contains "branch")) "Branch conflict reason missing."

    $issueConflict = Invoke-ClaimHelperJson @(
        "-Mode", "Acquire",
        "-RepoPath", $repo,
        "-Issue", "600",
        "-TaskId", "issue-600-other",
        "-Branch", "codex/issue-600-other",
        "-Worktree", ".runtime\worktrees\issue-600-other",
        "-OwnerSurface", "scripts\issue.ps1",
        "-Owner", "claim-test-issue",
        "-StatePath", $statePath,
        "-Json"
    ) @(2)
    Assert-True ($issueConflict.state -eq "DUPLICATE_WORK_DETECTED") "Issue overlap did not return duplicate-work."
    Assert-True (($issueConflict.conflicts[0].reasons -contains "issue")) "Issue conflict reason missing."

    $worktreeConflict = Invoke-ClaimHelperJson @(
        "-Mode", "Acquire",
        "-RepoPath", $repo,
        "-Issue", "602",
        "-TaskId", "issue-602-worktree",
        "-Branch", "codex/issue-602-worktree",
        "-Worktree", ".runtime\worktrees\issue-600-a",
        "-OwnerSurface", "scripts\worktree.ps1",
        "-Owner", "claim-test-worktree",
        "-StatePath", $statePath,
        "-Json"
    ) @(2)
    Assert-True ($worktreeConflict.state -eq "DUPLICATE_WORK_DETECTED") "Worktree overlap did not return duplicate-work."
    Assert-True (($worktreeConflict.conflicts[0].reasons -contains "worktree")) "Worktree conflict reason missing."

    $surfaceConflict = Invoke-ClaimHelperJson @(
        "-Mode", "Acquire",
        "-RepoPath", $repo,
        "-Issue", "603",
        "-TaskId", "issue-603-surface",
        "-Branch", "codex/issue-603-surface",
        "-Worktree", ".runtime\worktrees\issue-603-surface",
        "-OwnerSurface", "scripts\alpha.ps1",
        "-Owner", "claim-test-surface",
        "-StatePath", $statePath,
        "-Json"
    ) @(2)
    Assert-True ($surfaceConflict.state -eq "WAIT_FOR_OTHER_SESSION") "Owner surface overlap did not return wait state."
    Assert-True (($surfaceConflict.conflicts[0].reasons -contains "ownerSurface")) "Owner surface conflict reason missing."

    $commonB = @(
        "-RepoPath", $repo,
        "-Issue", "604",
        "-TaskId", "issue-604-b",
        "-Branch", "codex/issue-604-b",
        "-Worktree", ".runtime\worktrees\issue-604-b",
        "-OwnerSurface", "scripts\beta.ps1",
        "-Owner", "claim-test-b",
        "-StatePath", $statePath,
        "-Json"
    )
    $acquireB = Invoke-ClaimHelperJson (@("-Mode", "Acquire") + $commonB)
    Assert-True ($acquireB.state -eq "OWNERSHIP_CLEAR_TO_START") "Disjoint Acquire B did not return clear-to-start."

    $showBeforeRelease = Invoke-ClaimHelperJson @("-Mode", "Show", "-RepoPath", $repo, "-StatePath", $statePath, "-Json")
    Assert-True ($showBeforeRelease.claimCount -eq 2) "Show before release did not report two claims."

    $releaseA = Invoke-ClaimHelperJson (@("-Mode", "Release") + $commonA)
    Assert-True ($releaseA.state -eq "OWNERSHIP_CLEAR_TO_START") "Release A did not return clear-to-start."
    Assert-True ($releaseA.releasedCount -eq 1) "Release A did not release exactly one claim."
    Assert-True ($releaseA.claimCount -eq 1) "Release A did not leave exactly one unrelated claim."

    $showAfterRelease = Invoke-ClaimHelperJson @("-Mode", "Show", "-RepoPath", $repo, "-StatePath", $statePath, "-Json")
    Assert-True ($showAfterRelease.claimCount -eq 1) "Show after release did not report one claim."
    Assert-True ($showAfterRelease.claims[0].taskId -eq "issue-604-b") "Release removed or changed unrelated claim."

    $releaseB = Invoke-ClaimHelperJson (@("-Mode", "Release") + $commonB)
    Assert-True ($releaseB.releasedCount -eq 1) "Release B did not release exactly one claim."

    $finalShow = Invoke-ClaimHelperJson @("-Mode", "Show", "-RepoPath", $repo, "-StatePath", $statePath, "-Json")
    Assert-True ($finalShow.claimCount -eq 0) "Final Show did not report zero claims."

    $staleStatePath = Join-Path $testRoot "stale-session-claims.json"
    $staleCommon = @(
        "-RepoPath", $repo,
        "-Issue", "605",
        "-TaskId", "issue-605-stale",
        "-Branch", "codex/issue-605-stale",
        "-Worktree", ".runtime\worktrees\issue-605-stale",
        "-OwnerSurface", "scripts\stale.ps1",
        "-Owner", "claim-test-stale",
        "-StatePath", $staleStatePath,
        "-StaleAfterHours", "1",
        "-Json"
    )
    $staleAcquire = Invoke-ClaimHelperJson (@("-Mode", "Acquire") + $staleCommon)
    Assert-True ($staleAcquire.state -eq "OWNERSHIP_CLEAR_TO_START") "Stale fixture acquire did not return clear-to-start."

    $staleState = Get-Content -Raw -Encoding UTF8 -LiteralPath $staleStatePath | ConvertFrom-Json
    $oldStamp = (Get-Date).ToUniversalTime().AddHours(-2).ToString("o")
    $staleState.claims[0].updatedAt = $oldStamp
    $staleState.claims[0].createdAt = $oldStamp
    $staleState | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $staleStatePath -Encoding UTF8

    $staleConflict = Invoke-ClaimHelperJson @(
        "-Mode", "Acquire",
        "-RepoPath", $repo,
        "-Issue", "605",
        "-TaskId", "issue-605-stale-other",
        "-Branch", "codex/issue-605-stale-other",
        "-Worktree", ".runtime\worktrees\issue-605-stale-other",
        "-OwnerSurface", "scripts\stale-other.ps1",
        "-Owner", "claim-test-stale-other",
        "-StatePath", $staleStatePath,
        "-StaleAfterHours", "1",
        "-Json"
    ) @(3)
    Assert-True ($staleConflict.state -eq "PARENT_REVIEW_NEEDED") "Stale overlap did not return parent-review state."

    Write-Host "Codex session claim helper tests PASS"
    $global:LASTEXITCODE = 0
}
finally {
    if (-not $KeepArtifacts -and (Test-Path -LiteralPath $testRoot)) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
    if (-not $KeepArtifacts -and (Test-Path -LiteralPath $nonGitRoot)) {
        Remove-Item -LiteralPath $nonGitRoot -Recurse -Force
    }
}
