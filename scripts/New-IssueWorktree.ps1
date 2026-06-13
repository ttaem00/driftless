param(
    [Parameter(Mandatory = $true)][string]$Issue,
    [Parameter(Mandatory = $true)][string]$Slug,
    [string]$RepoPath = ".",
    [string]$Base = "main",
    [switch]$DryRun,
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

function Convert-ToSlug {
    param([string]$Value)
    $slug = $Value.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Slug must contain at least one ASCII letter or digit."
    }
    return $slug
}

$currentRepo = Get-RepoRoot -Path $RepoPath
$repo = Get-PrimaryWorktree -RepoRoot $currentRepo
$scriptPath = Join-Path $repo "scripts\Test-PrimaryWorktreeClean.ps1"
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing guard script: $scriptPath"
}

$guardOutput = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Root $repo 2>&1
$guardExit = $LASTEXITCODE
if ($guardExit -ne 0) {
    if ($Json) {
        [pscustomobject]@{
            status = "FAIL"
            reason = "primary_worktree_dirty"
            guard = @($guardOutput | ForEach-Object { [string]$_ })
            next_action = "Do not create a new worktree from a dirty primary checkout. Move or review the existing root changes first."
        } | ConvertTo-Json -Depth 5
    }
    else {
        Write-Host "ISSUE_WORKTREE_CREATE_FAIL"
        $guardOutput | ForEach-Object { Write-Host $_ }
        Write-Host "next_action=Move or review the existing root changes first; do not keep editing the primary checkout."
    }
    exit 1
}

$issueNumber = $Issue.Trim().TrimStart("#")
if ($issueNumber -notmatch "^[0-9]+$") {
    throw "Issue must be a GitHub issue number, for example 413."
}

$safeSlug = Convert-ToSlug -Value $Slug
$branch = "codex/issue-$issueNumber-$safeSlug"
$worktreeRel = ".runtime\worktrees\issue-$issueNumber-$safeSlug"
$worktree = Join-Path $repo $worktreeRel

if (Test-Path -LiteralPath $worktree) {
    throw "Worktree path already exists: $worktree"
}

$branchExists = Invoke-Git -Cwd $repo -Arguments @("rev-parse", "--verify", $branch) -AllowFailure
if ($branchExists.ExitCode -eq 0) {
    throw "Branch already exists: $branch"
}

$result = [pscustomobject]@{
    status = if ($DryRun) { "DRY_RUN" } else { "PASS" }
    repo = $repo
    issue = $issueNumber
    branch = $branch
    worktree = $worktree
    base = "origin/$Base"
    next_command = "cd `"$worktree`""
}

if (-not $DryRun) {
    Invoke-Git -Cwd $repo -Arguments @("fetch", "origin", $Base) | Out-Null
    Invoke-Git -Cwd $repo -Arguments @("worktree", "add", "-b", $branch, $worktree, "origin/$Base") | Out-Null

    $claimHelper = Join-Path $repo "scripts\New-CodexSessionClaim.ps1"
    if (Test-Path -LiteralPath $claimHelper) {
        $claim = & pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $claimHelper `
            -Mode Acquire `
            -RepoPath $worktree `
            -Issue $issueNumber `
            -TaskId "issue-$issueNumber-$safeSlug" `
            -Branch $branch `
            -Worktree $worktree `
            -Json 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Session claim failed after worktree creation: $($claim -join ' ')"
        }
        $result | Add-Member -NotePropertyName claim -NotePropertyValue (($claim -join "`n") | ConvertFrom-Json)
    }
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
}
else {
    Write-Host ("ISSUE_WORKTREE_CREATE_{0}" -f $result.status)
    Write-Host ("branch={0}" -f $result.branch)
    Write-Host ("worktree={0}" -f $result.worktree)
    Write-Host ("manager_next={0}" -f $result.next_command)
}
