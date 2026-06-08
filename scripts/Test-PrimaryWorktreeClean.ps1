param(
    [string]$Root = ".",
    [switch]$SelfTest,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
    param(
        [string]$Cwd,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )
    $savedEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & git -C $Cwd @Arguments 2>&1
        $exit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $savedEap
    }
    if (-not $AllowFailure -and $exit -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit=$exit`: $($output -join ' ')"
    }
    return [pscustomobject]@{
        ExitCode = $exit
        Output = @($output | ForEach-Object { [string]$_ })
    }
}

function Get-RepoRoot {
    param([string]$Path)
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $result = Invoke-Git -Cwd $resolved -Arguments @("rev-parse", "--show-toplevel")
    return [System.IO.Path]::GetFullPath(($result.Output | Select-Object -First 1).Trim())
}

function Get-PrimaryWorktree {
    param([string]$RepoRoot)
    $result = Invoke-Git -Cwd $RepoRoot -Arguments @("worktree", "list", "--porcelain")
    foreach ($line in $result.Output) {
        if ($line -match "^worktree\s+(.+)$") {
            return [System.IO.Path]::GetFullPath($Matches[1].Trim())
        }
    }
    return $RepoRoot
}

function Get-CurrentBranch {
    param([string]$RepoRoot)
    $result = Invoke-Git -Cwd $RepoRoot -Arguments @("branch", "--show-current") -AllowFailure
    if ($result.ExitCode -ne 0) {
        return ""
    }
    return (($result.Output | Select-Object -First 1) -as [string]).Trim()
}

function Test-HeadEqualsRef {
    param(
        [string]$RepoRoot,
        [string]$Ref
    )
    $head = Invoke-Git -Cwd $RepoRoot -Arguments @("rev-parse", "--verify", "HEAD") -AllowFailure
    $target = Invoke-Git -Cwd $RepoRoot -Arguments @("rev-parse", "--verify", $Ref) -AllowFailure
    if ($head.ExitCode -ne 0 -or $target.ExitCode -ne 0) {
        return $false
    }
    return (($head.Output | Select-Object -First 1).Trim() -eq ($target.Output | Select-Object -First 1).Trim())
}

function Test-DefaultEquivalent {
    param(
        [string]$RepoRoot,
        [string]$Branch
    )
    if ($Branch -in @("main", "master")) {
        return $true
    }
    foreach ($ref in @("origin/main", "refs/heads/main", "origin/master", "refs/heads/master")) {
        if (Test-HeadEqualsRef -RepoRoot $RepoRoot -Ref $ref) {
            return $true
        }
    }
    return $false
}

function Invoke-PrimaryWorktreeCheck {
    param([string]$Path)
    $repoRoot = Get-RepoRoot -Path $Path
    $primary = Get-PrimaryWorktree -RepoRoot $repoRoot
    $current = [System.IO.Path]::GetFullPath($repoRoot)
    $isPrimary = $current.TrimEnd("\") -ieq $primary.TrimEnd("\")
    $branch = Get-CurrentBranch -RepoRoot $current
    $isDefaultEquivalent = Test-DefaultEquivalent -RepoRoot $current -Branch $branch
    $statusResult = Invoke-Git -Cwd $current -Arguments @("status", "--porcelain=v1", "--untracked-files=all")
    $dirtyRows = @($statusResult.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $isDirty = $dirtyRows.Count -gt 0
    $state = "PASS"
    $nextAction = "Continue in this issue-scoped branch/worktree."
    if ($isPrimary -and $isDirty) {
        $state = "FAIL"
        $nextAction = "Stop before new work. Move existing dirty root changes to a named issue/rescue branch or manager-approved cleanup path; do not keep editing the primary checkout."
    }
    return [pscustomobject]@{
        status = $state
        repo = $current
        primaryWorktree = $primary
        isPrimaryWorktree = $isPrimary
        branch = $branch
        defaultEquivalent = $isDefaultEquivalent
        dirty = $isDirty
        dirtyRows = $dirtyRows.Count
        next_action = $nextAction
    }
}

function Invoke-SelfTest {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("primary-worktree-clean-" + [System.Guid]::NewGuid().ToString("N"))
    $repo = Join-Path $tempRoot "repo"
    $worktree = Join-Path $tempRoot "worktree"
    try {
        New-Item -ItemType Directory -Force -Path $repo | Out-Null
        & git -C $repo init -b main | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git init fixture failed" }
        & git -C $repo config user.email "codex@example.invalid" | Out-Null
        & git -C $repo config user.name "Codex Test" | Out-Null
        Set-Content -LiteralPath (Join-Path $repo "README.md") -Value "fixture" -Encoding UTF8
        & git -C $repo add README.md | Out-Null
        & git -C $repo commit -m "fixture" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "fixture commit failed" }
        & git -C $repo worktree add -b codex/issue-1-fixture $worktree | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "fixture worktree add failed" }

        Set-Content -LiteralPath (Join-Path $repo "dirty.txt") -Value "dirty" -Encoding UTF8
        $dirtyPrimary = Invoke-PrimaryWorktreeCheck -Path $repo
        if ($dirtyPrimary.status -ne "FAIL") {
            throw "SelfTest expected dirty primary checkout to FAIL."
        }
        $cleanIssueWorktree = Invoke-PrimaryWorktreeCheck -Path $worktree
        if ($cleanIssueWorktree.status -ne "PASS" -or $cleanIssueWorktree.isPrimaryWorktree) {
            throw "SelfTest expected issue worktree to PASS."
        }
        return [pscustomobject]@{
            status = "PASS"
            dirtyPrimary = $dirtyPrimary.status
            issueWorktree = $cleanIssueWorktree.status
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

if ($SelfTest) {
    $result = Invoke-SelfTest
}
else {
    $result = Invoke-PrimaryWorktreeCheck -Path $Root
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
}
else {
    Write-Host ("PRIMARY_WORKTREE_CLEAN_{0}" -f $result.status)
    if ($result.PSObject.Properties["repo"]) {
        Write-Host ("repo={0}" -f $result.repo)
        Write-Host ("primary={0}" -f $result.primaryWorktree)
        Write-Host ("is_primary={0}; branch={1}; default_equivalent={2}; dirty_rows={3}" -f $result.isPrimaryWorktree, $result.branch, $result.defaultEquivalent, $result.dirtyRows)
        Write-Host ("next_action={0}" -f $result.next_action)
    }
    elseif ($result.PSObject.Properties["dirtyPrimary"]) {
        Write-Host ("dirty_primary_fixture={0}" -f $result.dirtyPrimary)
        Write-Host ("issue_worktree_fixture={0}" -f $result.issueWorktree)
    }
}

if ($result.status -eq "FAIL") {
    exit 1
}
exit 0
