#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Tool-agnostic session-claim helper (issue #137). One implementation for every
  agent runtime (Claude, Codex, or any future tool) to Check / Acquire / Release
  ownership of an issue, branch, worktree, or file surface before mutating it.

.DESCRIPTION
  Two agent sessions working the same repository at the same time must not
  silently duplicate work or fight over the same files. A session claim is a
  small JSON record (issue, taskId, branch, worktree, owner surfaces, owner,
  timestamps) in a repo-local store. Before starting non-trivial work a session
  runs Check (read-only) or Acquire (writes a claim); on finishing it runs
  Release. Overlap on issue/taskId/branch/worktree is DUPLICATE_WORK_DETECTED;
  overlap on an owner surface alone is WAIT_FOR_OTHER_SESSION; a stale claim
  (default 24h without update) downgrades to PARENT_REVIEW_NEEDED instead of
  silently blocking forever.

  Cross-store comparison (arbitration rule R3, docs/cross-agent-work-arbitration.md):
  different tools may keep their own stores (.claude-work/, .codex-work/, and
  the tool-agnostic default .agent-work/). Comparing only one store cannot see a
  cross-agent conflict, so when no explicit -StatePath is given the conflict
  scan reads ALL default stores that exist, while mutations (Acquire/Release)
  only ever touch the primary store. An explicit -StatePath limits the scan to
  exactly that store (test isolation / legacy behavior) unless -CrossStatePath
  adds more. An unreadable cross store stops the run with an explicit error -
  it is never silently skipped, because a skipped store could hide a conflict.

  This file is the single implementation. New-CodexSessionClaim.ps1 is a thin
  back-compat wrapper that delegates here with -StoreDirName .codex-work.
  Runs under PowerShell 7 (pwsh), the repo's default agent shell.

.PARAMETER Mode
  Check (read-only scan), Acquire (scan then write a claim), Release (remove
  matching claims from the primary store), Show (list claims).

.PARAMETER StoreDirName
  Directory (under the primary worktree root) holding the primary claim store.
  Default ".agent-work" - the tool-agnostic store.

.PARAMETER StatePath
  Explicit path to the primary claim store file. When set, the conflict scan is
  limited to this store unless -CrossStatePath is also given.

.PARAMETER CrossStatePath
  Extra store files to scan read-only for conflicts (never mutated). Additive:
  the default stores are still scanned unless -StatePath narrows the run.

.OUTPUTS
  Key=value lines, or JSON with -Json. Exit codes: 0 clear / 1 missing selector
  / 2 duplicate-or-wait conflict / 3 stale conflict needs parent review /
  4 forbidden surface needs manager decision.
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
    [string]$StoreDirName = ".agent-work",
    [string]$StatePath,
    [string[]]$CrossStatePath,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$StateClear = "OWNERSHIP_CLEAR_TO_START"
$StateWait = "WAIT_FOR_OTHER_SESSION"
$StateDuplicate = "DUPLICATE_WORK_DETECTED"
$StateParent = "PARENT_REVIEW_NEEDED"
$StateManager = "BLOCKED_NEEDS_MANAGER_DECISION"

# Default store directories that any agent tool may use in this repo. The
# conflict scan covers all of them (rule R3) unless -StatePath narrows it.
$DefaultStoreDirNames = @(".agent-work", ".claude-work", ".codex-work")

function Get-FullPath([string]$Path, [string]$BasePath) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Get-RepoInfo([string]$Path) {
    $requested = Get-FullPath $Path (Get-Location).Path
    if (-not (Test-Path -LiteralPath $requested -PathType Container)) {
        throw "RepoPath does not exist: $requested"
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $top = & git -C $requested rev-parse --show-toplevel 2>$null
        $revParseExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($revParseExitCode -ne 0 -or [string]::IsNullOrWhiteSpace(($top -join "`n"))) {
        throw "RepoPath must be inside a git worktree: $requested"
    }
    $workRoot = [System.IO.Path]::GetFullPath(($top | Select-Object -First 1).Trim())

    $claimRoot = $workRoot
    $worktrees = & git -C $workRoot worktree list --porcelain 2>$null
    if ($LASTEXITCODE -eq 0) {
        foreach ($line in $worktrees) {
            if ($line -match '^worktree\s+(.+)$') {
                $claimRoot = [System.IO.Path]::GetFullPath($Matches[1].Trim())
                break
            }
        }
    }

    return [pscustomobject]@{
        RequestedPath = $requested
        WorkRoot = $workRoot
        ClaimRoot = $claimRoot
    }
}

function Convert-ToTextKey([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }
    return $Value.Trim().TrimStart("#").ToLowerInvariant()
}

function Convert-ToPathKey([string]$Path, [string]$BasePath) {
    $full = Get-FullPath $Path $BasePath
    if ($null -eq $full) {
        return $null
    }
    return $full.TrimEnd("\").ToLowerInvariant()
}

function Convert-ToSurface([string]$Surface, [string]$BasePath) {
    if ([string]::IsNullOrWhiteSpace($Surface)) {
        return $null
    }

    $display = $Surface.Trim() -replace "/", "\"
    if ($display.StartsWith(".\")) {
        $display = $display.Substring(2)
    }

    if ([System.IO.Path]::IsPathRooted($display)) {
        $full = [System.IO.Path]::GetFullPath($display)
        $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\") + "\"
        if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
            $display = $full.Substring($base.Length)
        }
        else {
            $display = $full
        }
    }

    return [pscustomobject]@{
        Display = $display
        Key = $display.TrimStart("\").ToLowerInvariant()
    }
}

function Test-ForbiddenSurface([string]$SurfaceKey) {
    if ([string]::IsNullOrWhiteSpace($SurfaceKey)) {
        return $false
    }

    $value = $SurfaceKey -replace "/", "\"
    $dot = "\."
    if ($value -match ('(^|\\)' + $dot + 'env(\..*)?$')) { return $true }
    if ($value -match '(^|\\)(secrets|work|output|site|data)(\\|$)') { return $true }
    if ($value -match '(^|\\)pipeline_config\.json$') { return $true }
    if ($value -match ('(^|\\)' + $dot + 'ssh(\\|$)')) { return $true }
    if ($value -match ('(^|\\)' + $dot + 'codex(\\|$)')) { return $true }
    if ($value -match ('(^|\\)' + $dot + 'claude(\\|$)')) { return $true }
    if ($value -match 'browser profiles?' -or $value -match 'cookies?') { return $true }
    return $false
}

function Get-StorePath([pscustomobject]$Repo, [string]$OverridePath) {
    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        return Get-FullPath $OverridePath $Repo.WorkRoot
    }
    return Join-Path $Repo.ClaimRoot (Join-Path $StoreDirName "session-claims.json")
}

function Get-CrossStorePaths([pscustomobject]$Repo, [string]$PrimaryPath) {
    # The two sources are ADDITIVE, never exclusive: explicit -CrossStatePath
    # entries extend the scan, and the default stores are always included
    # whenever no explicit -StatePath narrows the run. Making them exclusive
    # would let a -CrossStatePath-only call silently skip a live default-store
    # claim (a false all-clear, violating arbitration rule R3).
    $paths = @()
    if ($null -ne $CrossStatePath) {
        foreach ($candidate in @($CrossStatePath)) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $paths += (Get-FullPath $candidate $Repo.WorkRoot)
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($StatePath)) {
        foreach ($dirName in $DefaultStoreDirNames) {
            $paths += (Join-Path $Repo.ClaimRoot (Join-Path $dirName "session-claims.json"))
        }
    }

    $primaryKey = $PrimaryPath.TrimEnd("\").ToLowerInvariant()
    $unique = @()
    $seen = @{}
    foreach ($path in $paths) {
        $key = $path.TrimEnd("\").ToLowerInvariant()
        if ($key -eq $primaryKey -or $seen.ContainsKey($key)) {
            continue
        }
        $seen[$key] = $true
        $unique += $path
    }
    return @($unique)
}

function Read-State([string]$Path, [string]$RepoRoot) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            schemaVersion = 1
            repoRoot = $RepoRoot
            updatedAt = $null
            claims = @()
        }
    }

    $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Claim state file is empty: $Path"
    }
    $state = $raw | ConvertFrom-Json
    if ($null -eq $state.claims) {
        $state | Add-Member -NotePropertyName claims -NotePropertyValue @()
    }
    return $state
}

function Save-State([string]$Path, [pscustomobject]$State, [object[]]$Claims) {
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $State.updatedAt = (Get-Date).ToUniversalTime().ToString("o")
    $State.claims = @($Claims)
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-Request([pscustomobject]$Repo) {
    $surfaces = @()
    foreach ($surface in @($OwnerSurface)) {
        foreach ($part in ([string]$surface -split ",")) {
            $converted = Convert-ToSurface $part $Repo.ClaimRoot
            if ($null -ne $converted) {
                $surfaces += $converted
            }
        }
    }

    return [pscustomobject]@{
        issue = $Issue
        issueKey = Convert-ToTextKey $Issue
        taskId = $TaskId
        taskKey = Convert-ToTextKey $TaskId
        branch = $Branch
        branchKey = Convert-ToTextKey $Branch
        worktree = $Worktree
        worktreeKey = Convert-ToPathKey $Worktree $Repo.ClaimRoot
        ownerSurfaces = @($surfaces | ForEach-Object { $_.Display } | Sort-Object -Unique)
        ownerSurfaceKeys = @($surfaces | ForEach-Object { $_.Key } | Sort-Object -Unique)
        owner = if ([string]::IsNullOrWhiteSpace($Owner)) { "unknown" } else { $Owner.Trim() }
    }
}

function Test-HasSelector([pscustomobject]$Request, [string]$RequestedClaimId) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedClaimId)) {
        return $true
    }
    return -not (
        [string]::IsNullOrWhiteSpace($Request.issueKey) -and
        [string]::IsNullOrWhiteSpace($Request.taskKey) -and
        [string]::IsNullOrWhiteSpace($Request.branchKey) -and
        [string]::IsNullOrWhiteSpace($Request.worktreeKey) -and
        @($Request.ownerSurfaceKeys).Count -eq 0
    )
}

function Get-ClaimKey([object]$Claim, [string]$Name) {
    $property = $Claim.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        return $null
    }
    return ([string]$property.Value).Trim().TrimStart("#").ToLowerInvariant()
}

function Get-ClaimSurfaceKeys([object]$Claim) {
    $property = $Claim.PSObject.Properties["ownerSurfaceKeys"]
    if ($null -eq $property -or $null -eq $property.Value) {
        return @()
    }
    return @($property.Value | ForEach-Object { ([string]$_).ToLowerInvariant() })
}

function Test-ClaimStale([object]$Claim, [int]$Hours) {
    if ($Hours -lt 1) {
        return $false
    }

    $stamp = $Claim.updatedAt
    if ($null -eq $stamp) {
        $stamp = $Claim.createdAt
    }
    if ($null -eq $stamp) {
        return $true
    }

    # pwsh 7 ConvertFrom-Json materializes ISO timestamps as [datetime] with
    # Kind=Utc; casting that to [string] and re-parsing without RoundtripKind
    # re-interprets the value as LOCAL time and shifts it by the host UTC
    # offset, misclassifying fresh claims as stale (and vice versa) on any
    # non-UTC host. Handle both shapes Kind-aware.
    try {
        if ($stamp -is [datetime]) {
            $updated = $stamp.ToUniversalTime()
        }
        else {
            $updated = [datetime]::Parse([string]$stamp, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
        }
    }
    catch {
        return $true
    }
    return $updated -lt (Get-Date).ToUniversalTime().AddHours(-1 * $Hours)
}

function Get-ConflictState([object[]]$Conflicts) {
    if (@($Conflicts | Where-Object { $_.staleReviewNeeded }).Count -gt 0) {
        return $StateParent
    }
    foreach ($conflict in @($Conflicts)) {
        if (@($conflict.reasons | Where-Object { $_ -in @("issue", "taskId", "branch", "worktree") }).Count -gt 0) {
            return $StateDuplicate
        }
    }
    return $StateWait
}

function Test-ClaimMatchesRequest([object]$Claim, [pscustomobject]$Request, [string]$RequestedClaimId) {
    if (-not [string]::IsNullOrWhiteSpace($RequestedClaimId)) {
        return ((Get-ClaimKey $Claim "claimId") -eq (Convert-ToTextKey $RequestedClaimId))
    }
    if ($Request.issueKey -and $Request.issueKey -ne (Get-ClaimKey $Claim "issue")) { return $false }
    if ($Request.taskKey -and $Request.taskKey -ne (Get-ClaimKey $Claim "taskId")) { return $false }
    if ($Request.branchKey -and $Request.branchKey -ne (Get-ClaimKey $Claim "branch")) { return $false }
    if ($Request.worktreeKey -and $Request.worktreeKey -ne (Get-ClaimKey $Claim "worktreeKey")) { return $false }

    $claimSurfaces = Get-ClaimSurfaceKeys $Claim
    foreach ($surface in @($Request.ownerSurfaceKeys)) {
        if (-not ($claimSurfaces -contains $surface)) {
            return $false
        }
    }
    return $true
}

function Write-Result([pscustomobject]$Result) {
    if ($Json) {
        $Result | ConvertTo-Json -Depth 8
        return
    }

    Write-Host "state=$($Result.state)"
    Write-Host "mode=$($Result.mode)"
    if ($Result.message) { Write-Host "message=$($Result.message)" }
    if ($null -ne $Result.claimCount) { Write-Host "claim_count=$($Result.claimCount)" }
    if ($Result.claimId) { Write-Host "claim_id=$($Result.claimId)" }
    if ($Result.statePath) { Write-Host "state_path=$($Result.statePath)" }
    foreach ($conflict in @($Result.conflicts)) {
        Write-Host ("conflict claim_id={0} reasons={1} owner={2} branch={3} task={4} store={5}" -f $conflict.claimId, (($conflict.reasons) -join ","), $conflict.owner, $conflict.branch, $conflict.taskId, $conflict.store)
    }
}

function New-BlockedResult([string]$ModeName, [string]$State, [string]$Message, [pscustomobject]$Repo, [string]$StorePath) {
    return [pscustomobject]@{
        mode = $ModeName
        state = $State
        message = $Message
        repoRoot = $Repo.ClaimRoot
        statePath = $StorePath
        claimCount = $null
        claims = @()
        conflicts = @()
    }
}

function Invoke-WithLock([string]$Path, [scriptblock]$Body) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(([System.IO.Path]::GetFullPath($Path)).ToLowerInvariant())
    $hash = ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace "-", "").Substring(0, 32)
    $mutex = [System.Threading.Mutex]::new($false, "Local\DriftlessSessionClaim_$hash")
    $locked = $false
    try {
        $locked = $mutex.WaitOne([TimeSpan]::FromSeconds(30))
        if (-not $locked) {
            throw "Timed out waiting for claim store lock: $Path"
        }
        & $Body
    }
    finally {
        if ($locked) {
            $mutex.ReleaseMutex()
        }
        $mutex.Dispose()
        $sha.Dispose()
    }
}

$repo = Get-RepoInfo $RepoPath
$storePath = Get-StorePath $repo $StatePath
$crossStorePaths = Get-CrossStorePaths $repo $storePath
$request = New-Request $repo
$script:ExitCode = 0

$forbidden = @($request.ownerSurfaceKeys | Where-Object { Test-ForbiddenSurface $_ })
if ($forbidden.Count -gt 0) {
    Write-Result (New-BlockedResult $Mode $StateManager "Forbidden owner surface requested: $($forbidden -join ', ')" $repo $storePath)
    exit 4
}

Invoke-WithLock $storePath {
    $state = Read-State $storePath $repo.ClaimRoot
    $claims = @($state.claims)

    # Cross-store claims are scanned read-only for conflict detection (R3).
    # Reading them outside their own lock is a point-in-time advisory snapshot;
    # an unreadable store throws (never a silent skip).
    $taggedClaims = @()
    foreach ($claim in $claims) {
        $taggedClaims += [pscustomobject]@{ Claim = $claim; Store = $storePath }
    }
    foreach ($crossPath in $crossStorePaths) {
        if (-not (Test-Path -LiteralPath $crossPath -PathType Leaf)) {
            continue
        }
        $crossState = Read-State $crossPath $repo.ClaimRoot
        foreach ($claim in @($crossState.claims)) {
            $taggedClaims += [pscustomobject]@{ Claim = $claim; Store = $crossPath }
        }
    }

    if ($Mode -eq "Show") {
        $crossClaims = @($taggedClaims | Where-Object { $_.Store -ne $storePath } | ForEach-Object {
            $entry = $_.Claim | Select-Object *
            $entry | Add-Member -NotePropertyName store -NotePropertyValue $_.Store -Force
            $entry
        })
        Write-Result ([pscustomobject]@{
            mode = $Mode
            state = $StateClear
            message = "Claims loaded."
            repoRoot = $repo.ClaimRoot
            statePath = $storePath
            crossStorePaths = @($crossStorePaths)
            claimCount = $claims.Count
            crossClaimCount = $crossClaims.Count
            claims = @($claims)
            crossClaims = @($crossClaims)
            conflicts = @()
        })
        return
    }

    if (-not (Test-HasSelector $request $ClaimId)) {
        Write-Result (New-BlockedResult $Mode $StateParent "Provide at least one ownership selector: Issue, TaskId, Branch, Worktree, OwnerSurface, or ClaimId." $repo $storePath)
        $script:ExitCode = 1
        return
    }

    if ($Mode -eq "Release") {
        $remaining = @()
        $released = @()
        foreach ($claim in @($claims)) {
            if (Test-ClaimMatchesRequest $claim $request $ClaimId) {
                $released += $claim
            }
            else {
                $remaining += $claim
            }
        }

        if ($released.Count -gt 0) {
            Save-State $storePath $state @($remaining)
        }

        Write-Result ([pscustomobject]@{
            mode = $Mode
            state = $StateClear
            message = if ($released.Count -gt 0) { "Released matching claim(s)." } else { "No matching claim found." }
            repoRoot = $repo.ClaimRoot
            statePath = $storePath
            claimCount = $remaining.Count
            releasedCount = $released.Count
            releasedClaims = @($released)
            claims = @($remaining)
            conflicts = @()
        })
        return
    }

    $conflicts = @()
    foreach ($tagged in @($taggedClaims)) {
        $claim = $tagged.Claim
        if ((-not [string]::IsNullOrWhiteSpace([string]$claim.status)) -and ([string]$claim.status -ne "active")) {
            continue
        }

        $reasons = @()
        if ((-not [string]::IsNullOrWhiteSpace($request.issueKey)) -and ($request.issueKey -eq (Get-ClaimKey $claim "issue"))) {
            $reasons += "issue"
        }
        if ((-not [string]::IsNullOrWhiteSpace($request.taskKey)) -and ($request.taskKey -eq (Get-ClaimKey $claim "taskId"))) {
            $reasons += "taskId"
        }
        if ((-not [string]::IsNullOrWhiteSpace($request.branchKey)) -and ($request.branchKey -eq (Get-ClaimKey $claim "branch"))) {
            $reasons += "branch"
        }
        if ((-not [string]::IsNullOrWhiteSpace($request.worktreeKey)) -and ($request.worktreeKey -eq (Get-ClaimKey $claim "worktreeKey"))) {
            $reasons += "worktree"
        }

        $claimSurfaces = Get-ClaimSurfaceKeys $claim
        foreach ($surface in @($request.ownerSurfaceKeys)) {
            if ($claimSurfaces -contains $surface) {
                $reasons += "ownerSurface"
            }
        }

        if ($reasons.Count -gt 0) {
            $conflicts += [pscustomobject]@{
                claimId = $claim.claimId
                reasons = @($reasons | Sort-Object -Unique)
                issue = $claim.issue
                taskId = $claim.taskId
                branch = $claim.branch
                worktree = $claim.worktree
                ownerSurfaces = @($claim.ownerSurfaces)
                owner = $claim.owner
                store = $tagged.Store
                staleReviewNeeded = (Test-ClaimStale $claim $StaleAfterHours)
                updatedAt = $claim.updatedAt
            }
        }
    }

    if ($conflicts.Count -gt 0) {
        $stateName = Get-ConflictState $conflicts
        Write-Result ([pscustomobject]@{
            mode = $Mode
            state = $stateName
            message = "Overlapping active claim found."
            repoRoot = $repo.ClaimRoot
            statePath = $storePath
            crossStorePaths = @($crossStorePaths)
            claimCount = $claims.Count
            claims = @()
            conflicts = @($conflicts)
        })
        if ($stateName -eq $StateParent) {
            $script:ExitCode = 3
        }
        else {
            $script:ExitCode = 2
        }
        return
    }

    if ($Mode -eq "Check") {
        Write-Result ([pscustomobject]@{
            mode = $Mode
            state = $StateClear
            message = "No overlapping active claim found."
            repoRoot = $repo.ClaimRoot
            statePath = $storePath
            crossStorePaths = @($crossStorePaths)
            claimCount = $claims.Count
            claims = @()
            conflicts = @()
        })
        return
    }

    $now = (Get-Date).ToUniversalTime().ToString("o")
    $claim = [pscustomobject]@{
        claimId = [System.Guid]::NewGuid().ToString("N")
        status = "active"
        issue = $request.issue
        taskId = $request.taskId
        branch = $request.branch
        worktree = $request.worktree
        worktreeKey = $request.worktreeKey
        ownerSurfaces = @($request.ownerSurfaces)
        ownerSurfaceKeys = @($request.ownerSurfaceKeys)
        owner = $request.owner
        createdAt = $now
        updatedAt = $now
        staleAfterHours = $StaleAfterHours
    }

    Save-State $storePath $state @($claims + $claim)
    Write-Result ([pscustomobject]@{
        mode = $Mode
        state = $StateClear
        message = "Claim acquired."
        repoRoot = $repo.ClaimRoot
        statePath = $storePath
        crossStorePaths = @($crossStorePaths)
        claimCount = ($claims.Count + 1)
        claimId = $claim.claimId
        claim = $claim
        claims = @()
        conflicts = @()
    })
}

exit $script:ExitCode
