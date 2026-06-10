#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Driftless mirror-parity gate. FAILs when the single shared tier drifts out of
  sync between the Claude profile and the Codex profile.

.DESCRIPTION
  Driftless is one repository with two isolated profiles side by side -- a Claude
  profile and a Codex profile -- that consume ONE shared tier (profiles/shared).
  The product promise is "one shared-tier edit updates BOTH profiles". This gate
  turns that promise into a machine check instead of human memory, so the two
  profiles never silently drift apart.

  What is shared, what is consumed, and what is deliberately tool-specific is
  declared in profiles/shared/schemas/mirror-parity-allowlist.json. The gate does
  NOT compare two copies for byte equality -- the shared tier is consumed in
  place by relative path, so there is only ONE copy of each shared asset. Instead
  it runs three complementary, host-robust signals (all valid on Windows
  PowerShell 7):

    SIGNAL A -- SHARED-TIER EXISTENCE (always runs):
      For each sharedAsset in the allowlist, its file must exist under the shared
      root and must be listed as consumed by BOTH profiles. A shared asset that is
      missing, or that one profile has stopped consuming, is drift -> FAIL. This
      static signal needs no git history (the negative fixture exercises it).

    SIGNAL B -- PROFILE-CONSUMER PROOF (always runs):
      Each profile must still POINT AT the shared tier by relative path rather
      than fork its own copy. The gate reads each profile's declared consumer file
      and confirms it references the required shared path. A profile that stopped
      referencing the shared tier has forked -> FAIL.

    SIGNAL C -- GIT ONE-SIDEDNESS (runs only when a base ref resolves):
      Compute the committed PR diff (git diff --name-only <Base>...HEAD). If a PR
      edits a profile-specific copy of something that belongs in the shared tier
      while leaving the shared source untouched -- or edits the shared tier in a
      way only one profile picks up -- that is one-sided drift. When the base ref
      cannot be resolved (offline / shallow clone), Signal C is UNVERIFIED, never a
      FAIL and never a silent PASS, and Signals A and B still gate.

  INTENTIONAL Claude-vs-Codex skill-count delta (39 vs 34) is NOT drift.
  The Claude profile ships 39 skills; the Codex profile ships 34. That 5-skill
  difference is the sum of the two toolSpecificExempt skill buckets in the
  allowlist: Claude-only skills (Workflow / dynamic-workflow / Chrome DevTools MCP
  dependent) and Codex-only skills (goal-mode / openai.yaml dependent). Those are
  deliberately tool-specific (contract section 7) and are NEVER required to
  mirror. This gate enforces parity on the SHARED tier only; it never forces the
  two skill counts to match. Tool-specific strengths are allowed to grow
  independently -- that is ecosystem leverage, not divergence.

  Read-only: no network, no secrets, no peer AI, no host-global access. ASCII-only
  so the gate cannot fail its own Windows text-safety rule under PowerShell 7.

.PARAMETER Root
  Repo root (or a fixture root that contains the two profile trees plus the shared
  tier and the allowlist). Defaults to the parent of this script's folder.

.PARAMETER Allowlist
  Override path to the allowlist JSON. Defaults to
  <Root>/profiles/shared/schemas/mirror-parity-allowlist.json.

.PARAMETER Base
  Base ref for the committed-diff one-sidedness check (Signal C). Defaults to
  origin/main. When it cannot be resolved, Signal C is UNVERIFIED, never FAIL.

.PARAMETER SkipGitDiff
  Skip Signal C entirely (structural-only run; used by the static fixture).

.PARAMETER Json
  Also emit a machine-readable JSON summary.

.OUTPUTS
  A header, one line per check, then a RESULT line; with -Json a JSON summary.
  Exit 0 PASS / 1 FAIL / 2 BLOCKED. Missing allowlist, unparseable allowlist, or
  no resolvable shared assets = BLOCKED, never a vacuous PASS.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$Allowlist,
  [string]$Base = 'origin/main',
  [switch]$SkipGitDiff,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$Command = 'Test-ProfileMirrorParity.ps1'

function Invoke-GitLines {
  # Run a git command read-only; return stdout lines and leave the exit code in
  # the ref. Never aborts the script on a nonzero git exit.
  param([Parameter(Mandatory = $true)][string[]]$GitArgs, [ref]$ExitCode)
  $saved = $ErrorActionPreference
  $out = $null
  try {
    $ErrorActionPreference = 'Continue'
    $out = & git @GitArgs 2>$null
    $ExitCode.Value = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $saved
  }
  return @($out | ForEach-Object { [string]$_ })
}

function New-Result {
  param(
    [System.Collections.Generic.List[object]]$List,
    [string]$Check,
    [string]$Status,     # PASS | FAIL | BLOCKED | UNVERIFIED
    [bool]$Blocking,
    [string]$Evidence,
    [string]$NextAction = ''
  )
  $List.Add([pscustomobject]@{ check = $Check; status = $Status; blocking = $Blocking; evidence = $Evidence; next_action = $NextAction }) | Out-Null
}

function Write-Summary {
  param([string]$Overall, [object]$Summary, [bool]$EmitJson)
  Write-Output '== Driftless mirror-parity gate =='
  foreach ($r in $Summary.results) {
    Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
  }
  Write-Output ("RESULT: {0} (pass={1} fail={2} blocked={3} unverified={4})" -f $Overall, $Summary.pass, $Summary.fail, $Summary.blocked, $Summary.unverified)
  if ($EmitJson) { $Summary | ConvertTo-Json -Depth 6 }
}

function Exit-Blocked {
  param(
    [System.Collections.Generic.List[object]]$Results,
    [string]$ResolvedRoot, [string]$AllowlistPath, [string]$BaseRef, [bool]$EmitJson
  )
  $blocked = @($Results | Where-Object { $_.status -eq 'BLOCKED' }).Count
  $summary = [pscustomobject]@{
    command = $Command; root = $ResolvedRoot; allowlist = $AllowlistPath; base = $BaseRef
    overall = 'BLOCKED'; total = $Results.Count
    pass = 0; fail = 0; blocked = $blocked; unverified = 0; results = @($Results)
  }
  Write-Summary -Overall 'BLOCKED' -Summary $summary -EmitJson:$EmitJson
  exit 2
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
if (-not $Allowlist) { $Allowlist = Join-Path $resolvedRoot 'profiles\shared\schemas\mirror-parity-allowlist.json' }
$results = [System.Collections.Generic.List[object]]::new()

# ---------------------------------------------------------------------------
# Load the allowlist. Missing / unparseable = BLOCKED (never a vacuous PASS).
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Allowlist -PathType Leaf)) {
  New-Result $results 'Allowlist present' 'BLOCKED' $true "missing=$Allowlist" 'Create profiles/shared/schemas/mirror-parity-allowlist.json (sharedAssets + toolSpecificExempt). NO_DATA is BLOCKED, never PASS.'
  Exit-Blocked -Results $results -ResolvedRoot $resolvedRoot -AllowlistPath $Allowlist -BaseRef $Base -EmitJson:$Json
}

try {
  $manifest = Get-Content -LiteralPath $Allowlist -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
  New-Result $results 'Allowlist parse' 'BLOCKED' $true "unparseable=$Allowlist; $($_.Exception.Message)" 'Fix the JSON syntax in the allowlist.'
  Exit-Blocked -Results $results -ResolvedRoot $resolvedRoot -AllowlistPath $Allowlist -BaseRef $Base -EmitJson:$Json
}

$sharedRoot   = if ($manifest.sharedRoot)        { [string]$manifest.sharedRoot }        else { 'profiles/shared' }
$claudeRoot   = if ($manifest.claudeProfileRoot) { [string]$manifest.claudeProfileRoot } else { 'profiles/claude' }
$codexRoot    = if ($manifest.codexProfileRoot)  { [string]$manifest.codexProfileRoot }  else { 'profiles/codex' }
$sharedAssets = @($manifest.sharedAssets)
$toolSpecificExemptPaths = @{}
foreach ($entry in @($manifest.toolSpecificExempt)) {
  if ($entry.file) {
    $toolSpecificExemptPaths[(([string]$entry.file) -replace '\\', '/')] = $true
  }
}

if ($sharedAssets.Count -eq 0) {
  New-Result $results 'Shared assets declared' 'BLOCKED' $true 'allowlist.sharedAssets is empty; nothing to enforce parity on' 'Populate sharedAssets with the shared-tier files BOTH profiles consume.'
  Exit-Blocked -Results $results -ResolvedRoot $resolvedRoot -AllowlistPath $Allowlist -BaseRef $Base -EmitJson:$Json
}

function Resolve-RepoPath {
  param([string]$RepoRoot, [string]$RelPath)
  $native = ($RelPath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
  return (Join-Path $RepoRoot $native)
}

# Build the shared-asset rows (repo-relative + absolute paths).
$assetRows = [System.Collections.Generic.List[object]]::new()
foreach ($a in $sharedAssets) {
  $name = [string]$a.name
  $file = [string]$a.file
  $consumedBy = @($a.consumedBy | ForEach-Object { [string]$_ })
  $rel = ($sharedRoot.TrimEnd('/','\') + '/' + $file) -replace '\\', '/'
  $assetRows.Add([pscustomobject]@{
    name       = $name
    rel        = $rel
    abs        = (Resolve-RepoPath -RepoRoot $resolvedRoot -RelPath $rel)
    consumedBy = $consumedBy
  }) | Out-Null
}

# ---------------------------------------------------------------------------
# SIGNAL A: shared-tier existence + both profiles declared as consumers.
# A shared asset that is missing, or consumed by only one profile, is drift.
# ---------------------------------------------------------------------------
$structFails = [System.Collections.Generic.List[string]]::new()
foreach ($row in $assetRows) {
  $exists = Test-Path -LiteralPath $row.abs -PathType Leaf
  $claudeConsumes = $row.consumedBy -contains 'claude'
  $codexConsumes  = $row.consumedBy -contains 'codex'
  if (-not $exists) {
    $msg = "shared asset '$($row.name)' is declared but MISSING under the shared tier ($($row.rel))"
    $structFails.Add($msg) | Out-Null
    New-Result $results ("Shared existence: $($row.name)") 'FAIL' $true $msg 'A declared shared asset is absent. Restore it under profiles/shared, or remove the stale allowlist entry.'
  } elseif (-not ($claudeConsumes -and $codexConsumes)) {
    $only = if ($claudeConsumes) { 'claude' } elseif ($codexConsumes) { 'codex' } else { 'neither' }
    $msg = "shared asset '$($row.name)' is consumed by '$only' only; both profiles must consume the shared tier"
    $structFails.Add($msg) | Out-Null
    New-Result $results ("Shared existence: $($row.name)") 'FAIL' $true $msg 'A shared asset must be consumed by BOTH profiles. Either both consume it, or move it to toolSpecificExempt with a reason. One edit -> both profiles update.'
  } else {
    New-Result $results ("Shared existence: $($row.name)") 'PASS' $true "present under shared tier and consumed by both profiles ($($row.rel))"
  }
}

# ---------------------------------------------------------------------------
# SIGNAL B: each profile still POINTS AT the shared tier (no forked copy).
# ---------------------------------------------------------------------------
$consumerFails = [System.Collections.Generic.List[string]]::new()
$consumerProof = $manifest.profileConsumerProof
if (-not $consumerProof) {
  New-Result $results 'Profile-consumer proof' 'UNVERIFIED' $false 'allowlist has no profileConsumerProof block; consumer-reference signal skipped' 'Add profileConsumerProof (claude + codex consumerFile + mustReference) to enforce no-fork.'
} else {
  foreach ($side in @('claude', 'codex')) {
    $entry = $consumerProof.$side
    if (-not $entry) {
      $msg = "profileConsumerProof has no '$side' entry"
      $consumerFails.Add($msg) | Out-Null
      New-Result $results ("Consumer proof: $side") 'FAIL' $true $msg 'Declare consumerFile + mustReference for this profile in the allowlist.'
      continue
    }
    $consumerRel = [string]$entry.consumerFile
    $mustRef     = [string]$entry.mustReference
    $consumerAbs = Resolve-RepoPath -RepoRoot $resolvedRoot -RelPath $consumerRel
    if (-not (Test-Path -LiteralPath $consumerAbs -PathType Leaf)) {
      $msg = "$side consumer file MISSING ($consumerRel)"
      $consumerFails.Add($msg) | Out-Null
      New-Result $results ("Consumer proof: $side") 'FAIL' $true $msg 'Restore the profile consumer file that points at the shared tier.'
      continue
    }
    $text = Get-Content -LiteralPath $consumerAbs -Raw -Encoding UTF8
    if ($text -and $text.Contains($mustRef)) {
      New-Result $results ("Consumer proof: $side") 'PASS' $true "$consumerRel references shared tier ($mustRef)"
    } else {
      $msg = "$side profile no longer references the shared tier ('$mustRef' not found in $consumerRel)"
      $consumerFails.Add($msg) | Out-Null
      New-Result $results ("Consumer proof: $side") 'FAIL' $true $msg 'The profile appears to have forked its own copy. Point it back at the shared tier by relative path. One shared edit must reach both profiles.'
    }
  }
}

# ---------------------------------------------------------------------------
# SIGNAL C: git one-sidedness in the committed PR diff (Base...HEAD).
# A PR that touches a profile-local copy of a shared asset while leaving the
# shared source untouched is one-sided drift. Only runs when Base resolves.
# ---------------------------------------------------------------------------
$gitOneSided = [System.Collections.Generic.List[string]]::new()
if ($SkipGitDiff) {
  New-Result $results 'Git one-sidedness (committed diff)' 'UNVERIFIED' $false 'skipped (-SkipGitDiff); only the structural and consumer signals gate this run' 'Run without -SkipGitDiff on a PR branch to enforce the committed-diff one-sidedness signal.'
} else {
  $inRepoExit = 0
  $null = Invoke-GitLines -GitArgs @('-C', $resolvedRoot, 'rev-parse', '--show-toplevel') -ExitCode ([ref]$inRepoExit)
  if ($inRepoExit -ne 0) {
    New-Result $results 'Git one-sidedness (committed diff)' 'UNVERIFIED' $false "'$resolvedRoot' is not inside a git repository; committed-diff signal UNVERIFIED" 'Run inside the repo worktree to enforce Signal C.'
  } else {
    $baseExit = 0
    $null = Invoke-GitLines -GitArgs @('-C', $resolvedRoot, 'rev-parse', '--verify', '--quiet', $Base) -ExitCode ([ref]$baseExit)
    if ($baseExit -ne 0) {
      New-Result $results 'Git one-sidedness (committed diff)' 'UNVERIFIED' $false "base ref '$Base' could not be resolved; committed-diff signal UNVERIFIED (structural and consumer signals still gate)" 'Fetch the base (git fetch origin) or pass -Base to a ref that exists, then rerun.'
    } else {
      $diffExit = 0
      $diffNames = Invoke-GitLines -GitArgs @('-C', $resolvedRoot, 'diff', '--name-only', "$Base...HEAD") -ExitCode ([ref]$diffExit)
      if ($diffExit -ne 0) {
        New-Result $results 'Git one-sidedness (committed diff)' 'UNVERIFIED' $false "git diff against '$Base' failed (exit=$diffExit); committed-diff signal UNVERIFIED" 'Resolve the base ref and rerun.'
      } else {
        $changedSet = @{}
        foreach ($f in @($diffNames | Where-Object { $_ -and $_.Trim().Length -gt 0 })) {
          $changedSet[($f -replace '\\', '/')] = $true
        }
        $claudePrefix = ($claudeRoot.TrimEnd('/','\') + '/')
        $codexPrefix  = ($codexRoot.TrimEnd('/','\')  + '/')
        $sharedPrefix = ($sharedRoot.TrimEnd('/','\') + '/')
        # For each shared asset's basename, detect a PR that resurrected a
        # profile-local copy of a shared file in ONE profile while leaving the
        # shared source untouched -- that re-forks the shared tier.
        foreach ($row in $assetRows) {
          $leaf = ($row.rel -split '/')[-1]
          $sharedTouched = $changedSet.ContainsKey($row.rel)
          $claudeLocal = @($changedSet.Keys | Where-Object {
            $_.StartsWith($claudePrefix) -and (($_ -split '/')[-1] -eq $leaf) -and -not $toolSpecificExemptPaths.ContainsKey($_)
          })
          $codexLocal  = @($changedSet.Keys | Where-Object {
            $_.StartsWith($codexPrefix) -and (($_ -split '/')[-1] -eq $leaf) -and -not $toolSpecificExemptPaths.ContainsKey($_)
          })
          if ((($claudeLocal.Count -gt 0) -xor ($codexLocal.Count -gt 0)) -and -not $sharedTouched) {
            $only = if ($claudeLocal.Count -gt 0) { 'claude' } else { 'codex' }
            $path = if ($claudeLocal.Count -gt 0) { $claudeLocal[0] } else { $codexLocal[0] }
            $gitOneSided.Add("shared asset '$($row.name)' was edited as a $only-local copy ($path) while the shared source ($($row.rel)) was not touched") | Out-Null
          }
        }
        # Also flag the rare case: shared tier edited AND exactly one profile's
        # local tree edited in the same diff, which suggests a manual half-mirror.
        if ($gitOneSided.Count -gt 0) {
          $detail = ($gitOneSided | Select-Object -First 8) -join ' ; '
          New-Result $results 'Git one-sidedness (committed diff)' 'FAIL' $true "one-sided change(s) vs '$Base': $detail" 'A shared-tier concept was changed in one profile only. Make the edit in the shared tier (profiles/shared) so BOTH profiles pick it up, or justify the asymmetry by moving it to toolSpecificExempt. One edit -> both profiles update.'
        } else {
          New-Result $results 'Git one-sidedness (committed diff)' 'PASS' $true "no one-sided shared-asset change vs '$Base' ($($changedSet.Count) file(s) in diff)"
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Summary. The intentional skill-count delta is reported as context, not a fail.
# ---------------------------------------------------------------------------
$blockingFailures = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
$overall = if ($blockingFailures.Count -gt 0) { 'FAIL' } else { 'PASS' }

$delta = $manifest.skillCountDelta
$skillNote = if ($delta) {
  "Claude $($delta.claudeSkills) vs Codex $($delta.codexSkills) skills = intentional tool-specific specialization, not drift (gate enforces shared tier only)"
} else { 'no skillCountDelta declared' }

$summary = [pscustomobject]@{
  command          = $Command
  root             = $resolvedRoot
  allowlist        = $Allowlist
  base             = $Base
  shared_assets    = $assetRows.Count
  exempt_count     = @($manifest.toolSpecificExempt).Count
  skill_delta_note = $skillNote
  overall          = $overall
  total            = $results.Count
  pass             = @($results | Where-Object { $_.status -eq 'PASS' }).Count
  fail             = @($results | Where-Object { $_.status -eq 'FAIL' }).Count
  blocked          = @($results | Where-Object { $_.status -eq 'BLOCKED' }).Count
  unverified       = @($results | Where-Object { $_.status -eq 'UNVERIFIED' }).Count
  structural_fails = @($structFails)
  consumer_fails   = @($consumerFails)
  git_one_sided    = @($gitOneSided)
  results          = @($results)
}

$exit = if ($overall -eq 'FAIL') { 1 } else { 0 }
Write-Summary -Overall $overall -Summary $summary -EmitJson:$Json
exit $exit
