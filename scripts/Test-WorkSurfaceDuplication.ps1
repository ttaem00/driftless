#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Work-surface duplication gate (issue #137): FAILs when the SAME skill name or
  the SAME script file name exists on MORE THAN ONE declared surface, unless the
  pair is explicitly allowlisted with a reason.

.DESCRIPTION
  Root cause (proven in a private deployment, 2026-06-12): two agent sessions
  worked the same repo in parallel; one merged a skill into the shared tier
  while the other independently created a near-identical same-name twin on a
  tool-specific surface. No gate compared the surfaces by NAME, so the duplicate
  could only be caught by a human. The session-claim helper
  (New-SessionClaim.ps1) compares issue/branch/worktree/surface PATHS, not asset
  NAMES across surfaces, so it cannot see this class either.

  This gate encodes the deterministic arbitration rule "one name, one shipping
  surface" (docs/cross-agent-work-arbitration.md rule R4). In Driftless the
  shared tier (profiles/shared/) is consumed in place by BOTH profiles, so a
  same-name twin under profiles/claude/, profiles/codex/, or the repo-level
  skills/ root is redundant by construction and a merge-conflict / drift magnet.
  The same rule generalizes to scripts: one script basename, one home - either
  scripts/ or exactly one skill-embedded scripts/ folder. A genuinely
  intentional pair must carry an explicit allowedDuplicates entry with a reason
  (full-port-no-partial decision pattern).

  Scope notes:
    * Which surfaces exist is declared in
      profiles/shared/schemas/work-surface-duplication-allowlist.json
      (skillRoots + scriptRoots + allowedDuplicates).
    * A skill = a directory bearing SKILL.md directly under a declared skill
      root. A twin DIRECTORY without SKILL.md is not a live skill and is out of
      scope by design; it trips the moment its SKILL.md lands.
    * Script surfaces are the declared scriptRoots (top-level *.ps1 only,
      non-recursive) plus every skill-embedded <skill>/scripts folder derived
      from the declared skill roots. Subdirectories of a script root are
      deliberately NOT surfaces: a dedicated legacy-shell compatibility folder
      (if present) holds runtime variants of a task, not duplicate work.
    * A skills-bearing root that exists on disk but is NOT declared FAILs
      (undeclared-root discovery), so a layout rename cannot silently shrink
      coverage. Missing allowlist, unparseable allowlist, or a scan with fewer
      than two resolvable surfaces in every dimension = BLOCKED, never a
      vacuous PASS.
    * A built-in negative self-test runs on EVERY invocation: a planted
      synthetic duplicate must be detected and a planted allowlisted duplicate
      must be accepted, proving the detector is not a no-op.

  Read-only. No network, no secrets, no peer AI, no host-global access.
  ASCII-only source so the gate cannot fail the Windows text-safety rule.

.PARAMETER Root
  Repo root. Defaults to git rev-parse, then the parent of this script's folder.

.PARAMETER Allowlist
  Override path to the allowlist JSON. Default:
  <Root>/profiles/shared/schemas/work-surface-duplication-allowlist.json.

.PARAMETER Json
  Also emit a machine-readable JSON summary.

.OUTPUTS
  Human PASS/FAIL/BLOCKED lines then a RESULT line. Exit 0 PASS / 1 FAIL /
  2 BLOCKED.
#>
[CmdletBinding()]
param(
  [string]$Root,
  [string]$Allowlist,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$OutputEncoding = [System.Text.Encoding]::UTF8

$Command = 'Test-WorkSurfaceDuplication.ps1'

function Resolve-RepoRoot {
  param([string]$Start)
  if ($Start) { return (Resolve-Path -LiteralPath $Start).Path }
  try {
    $top = (& git -C (Split-Path -Parent $PSCommandPath) rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -eq 0 -and $top) { return (Resolve-Path -LiteralPath $top.Trim()).Path }
  } catch { }
  return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
}

# ---------------------------------------------------------------------------
# Pure detection core: takes name sets per surface, returns findings. It is
# filesystem-free so the built-in self-test can prove the detector on synthetic
# data with no fixtures. A finding is any normalized name that appears on two
# or more distinct surfaces.
# ---------------------------------------------------------------------------
function Find-SurfaceDuplicate {
  param(
    [hashtable]$NamesBySurface,   # surface label (rel path string) -> string[] of names
    [hashtable]$AllowSet          # lowercased name -> reason
  )
  $byKey = @{}
  foreach ($surface in ($NamesBySurface.Keys | Sort-Object)) {
    foreach ($name in @($NamesBySurface[$surface])) {
      if (-not $name) { continue }
      # Trim + lowercase keys so a case-variant or trailing-space twin still
      # matches its sibling.
      $key = ([string]$name).Trim().ToLowerInvariant()
      if (-not $key) { continue }
      if (-not $byKey.ContainsKey($key)) {
        $byKey[$key] = [pscustomobject]@{
          Display = ([string]$name).Trim()
          Surfaces = [System.Collections.Generic.List[string]]::new()
        }
      }
      if (-not $byKey[$key].Surfaces.Contains([string]$surface)) {
        $byKey[$key].Surfaces.Add([string]$surface) | Out-Null
      }
    }
  }

  $findings = [System.Collections.Generic.List[object]]::new()
  foreach ($key in ($byKey.Keys | Sort-Object)) {
    $entry = $byKey[$key]
    if ($entry.Surfaces.Count -lt 2) { continue }
    if ($AllowSet.ContainsKey($key)) {
      $findings.Add([pscustomobject]@{ kind = 'allowed'; name = $entry.Display; surfaces = @($entry.Surfaces | Sort-Object); reason = [string]$AllowSet[$key] }) | Out-Null
    } else {
      $findings.Add([pscustomobject]@{ kind = 'duplicate'; name = $entry.Display; surfaces = @($entry.Surfaces | Sort-Object); reason = '' }) | Out-Null
    }
  }
  return @($findings)
}

function Get-SkillDirNames {
  param([string]$AbsRoot)
  if (-not (Test-Path -LiteralPath $AbsRoot -PathType Container)) { return @() }
  $names = @()
  foreach ($d in Get-ChildItem -LiteralPath $AbsRoot -Directory -ErrorAction SilentlyContinue) {
    if (Test-Path -LiteralPath (Join-Path $d.FullName 'SKILL.md') -PathType Leaf) { $names += $d.Name }
  }
  return @($names)
}

function Get-ScriptFileNames {
  param([string]$AbsRoot)
  if (-not (Test-Path -LiteralPath $AbsRoot -PathType Container)) { return @() }
  $names = @()
  foreach ($f in Get-ChildItem -LiteralPath $AbsRoot -File -Filter '*.ps1' -ErrorAction SilentlyContinue) {
    $names += $f.Name
  }
  return @($names)
}

$results = [System.Collections.Generic.List[object]]::new()
function Add-Row {
  param([string]$Check, [string]$Status, [bool]$Blocking, [string]$Evidence, [string]$Next = '')
  $results.Add([pscustomobject]@{ check = $Check; status = $Status; blocking = $Blocking; evidence = $Evidence; next_action = $Next }) | Out-Null
}

function Write-Report {
  param([string]$Overall, [int]$ExitCode, [hashtable]$Extra)
  Write-Output '== Work-surface duplication gate =='
  foreach ($r in $results) {
    Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
  }
  $pass = @($results | Where-Object { $_.status -eq 'PASS' }).Count
  $fail = @($results | Where-Object { $_.status -eq 'FAIL' }).Count
  $blocked = @($results | Where-Object { $_.status -eq 'BLOCKED' }).Count
  Write-Output ("RESULT: {0} (pass={1} fail={2} blocked={3})" -f $Overall, $pass, $fail, $blocked)
  if ($Json) {
    $summary = [ordered]@{
      command = $Command; overall = $Overall; pass = $pass; fail = $fail; blocked = $blocked
      results = @($results)
    }
    foreach ($k in $Extra.Keys) { $summary[$k] = $Extra[$k] }
    [pscustomobject]$summary | ConvertTo-Json -Depth 6
  }
  exit $ExitCode
}

$repoRoot = Resolve-RepoRoot -Start $Root
if (-not $Allowlist) { $Allowlist = Join-Path $repoRoot 'profiles\shared\schemas\work-surface-duplication-allowlist.json' }

# ---------------------------------------------------------------------------
# Built-in negative self-test (always runs; pure data, no fixtures on disk).
# A planted duplicate with an empty allowlist MUST be found; the same duplicate
# with an allowlist entry MUST be accepted. A detector missing either is a
# no-op and the gate FAILs itself before scanning anything.
# ---------------------------------------------------------------------------
$plantedSurfaces = @{
  'surface-a' = @('planted-dup-skill', 'unique-skill', 'Trail-Skill ')
  'surface-b' = @('planted-dup-skill', 'trail-skill')
}
$mustFind = Find-SurfaceDuplicate -NamesBySurface $plantedSurfaces -AllowSet @{}
$mustAllow = Find-SurfaceDuplicate -NamesBySurface @{
  'surface-a' = @('planted-dup-skill')
  'surface-b' = @('planted-dup-skill', 'unique-skill')
} -AllowSet @{ 'planted-dup-skill' = 'self-test allow' }
# Two planted duplicates must surface: the exact-name pair AND the
# case+trailing-space variant pair (Trim+lowercase matching).
$foundPlanted = @($mustFind | Where-Object { $_.kind -eq 'duplicate' }).Count -eq 2
$allowedPlanted = (@($mustAllow | Where-Object { $_.kind -eq 'duplicate' }).Count -eq 0) -and (@($mustAllow | Where-Object { $_.kind -eq 'allowed' }).Count -eq 1)
if ($foundPlanted -and $allowedPlanted) {
  Add-Row 'Negative self-test (planted duplicate detected; allowlisted pair accepted)' 'PASS' $true 'detector proves both directions on synthetic data'
} else {
  Add-Row 'Negative self-test (planted duplicate detected; allowlisted pair accepted)' 'FAIL' $true ("detector no-op: foundPlanted={0} allowedPlanted={1}" -f $foundPlanted, $allowedPlanted) 'Fix Find-SurfaceDuplicate before trusting this gate.'
  Write-Report -Overall 'FAIL' -ExitCode 1 -Extra @{ allowlist = $Allowlist }
}

# ---------------------------------------------------------------------------
# Load the allowlist. Missing / unparseable = BLOCKED (never a vacuous PASS).
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Allowlist -PathType Leaf)) {
  Add-Row 'Allowlist present' 'BLOCKED' $true ("missing=" + $Allowlist) 'Create profiles/shared/schemas/work-surface-duplication-allowlist.json (skillRoots + scriptRoots + allowedDuplicates). NO_DATA is BLOCKED, never PASS.'
  Write-Report -Overall 'BLOCKED' -ExitCode 2 -Extra @{ allowlist = $Allowlist }
}
try {
  $manifest = Get-Content -LiteralPath $Allowlist -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
  Add-Row 'Allowlist parse' 'BLOCKED' $true ("unparseable=" + $Allowlist + '; ' + $_.Exception.Message) 'Fix the JSON syntax in the allowlist.'
  Write-Report -Overall 'BLOCKED' -ExitCode 2 -Extra @{ allowlist = $Allowlist }
}

# Null-filter BEFORE the count check: @($null) has Count 1, and Join-Path with
# an empty child can silently resolve to the parent, so a null/missing roots
# key would otherwise become a vacuous PASS. Empty AFTER filtering on BOTH
# dimensions = BLOCKED.
$skillRels = @(@($manifest.skillRoots) | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_.Trim() })
$scriptRels = @(@($manifest.scriptRoots) | ForEach-Object { [string]$_ } | Where-Object { $_ -and $_.Trim() })
if ($skillRels.Count -eq 0 -and $scriptRels.Count -eq 0) {
  Add-Row 'Surface roots declared' 'BLOCKED' $true 'both skillRoots and scriptRoots are empty, null, or whitespace-only; nothing to compare' 'Populate skillRoots and scriptRoots in the allowlist.'
  Write-Report -Overall 'BLOCKED' -ExitCode 2 -Extra @{ allowlist = $Allowlist }
}

$allowSkill = @{}
$allowScript = @{}
foreach ($a in @($manifest.allowedDuplicates)) {
  if (-not $a -or -not $a.name) { continue }
  $kind = 'skill'
  if ($a.kind) { $kind = ([string]$a.kind).Trim().ToLowerInvariant() }
  $key = ([string]$a.name).Trim().ToLowerInvariant()
  # The reason is the audit artifact that makes an intentional pair reviewable.
  # A reason-less entry must not be able to silence a duplicate - that would be
  # a quiet bypass of exactly the class this gate exists to catch.
  if ([string]::IsNullOrWhiteSpace([string]$a.reason)) {
    Add-Row ("Allowlist entry missing reason: " + $key) 'FAIL' $true 'allowedDuplicates entries must carry a non-empty reason; the entry was ignored, so any duplicate it meant to allow still FAILs' 'Add a reason explaining why the pair is intentional, or remove the entry.'
    continue
  }
  if ($kind -eq 'script') { $allowScript[$key] = [string]$a.reason }
  else { $allowSkill[$key] = [string]$a.reason }
}

function ConvertTo-AbsPath {
  param([string]$Rel)
  return (Join-Path $repoRoot (($Rel -replace '/', [System.IO.Path]::DirectorySeparatorChar)))
}

# ---------------------------------------------------------------------------
# Resolve declared surfaces. A missing declared root is an advisory skip (not
# every branch carries every surface), but if NO dimension ends up with at
# least two resolvable surfaces the scan is structurally vacuous = BLOCKED.
# ---------------------------------------------------------------------------
$skillNamesBySurface = @{}
$missingSkillRoots = @()
foreach ($rel in $skillRels) {
  $abs = ConvertTo-AbsPath $rel
  if (Test-Path -LiteralPath $abs -PathType Container) {
    $skillNamesBySurface[[string]$rel] = Get-SkillDirNames -AbsRoot $abs
  } else {
    $missingSkillRoots += [string]$rel
  }
}

$scriptNamesBySurface = @{}
$missingScriptRoots = @()
foreach ($rel in $scriptRels) {
  $abs = ConvertTo-AbsPath $rel
  if (Test-Path -LiteralPath $abs -PathType Container) {
    $scriptNamesBySurface[[string]$rel] = Get-ScriptFileNames -AbsRoot $abs
  } else {
    $missingScriptRoots += [string]$rel
  }
}

# Derived script surfaces: every skill-embedded scripts/ folder under each
# resolved skill root. These count toward the script dimension.
foreach ($rel in @($skillNamesBySurface.Keys)) {
  $abs = ConvertTo-AbsPath $rel
  foreach ($skillName in @($skillNamesBySurface[$rel])) {
    $scriptsAbs = Join-Path (Join-Path $abs $skillName) 'scripts'
    $names = Get-ScriptFileNames -AbsRoot $scriptsAbs
    if (@($names).Count -gt 0) {
      $scriptNamesBySurface[($rel + '/' + $skillName + '/scripts')] = $names
    }
  }
}

if (($missingSkillRoots.Count + $missingScriptRoots.Count) -gt 0) {
  Add-Row 'Declared roots present' 'PASS' $false ("skipped missing root(s): " + (@($missingSkillRoots + $missingScriptRoots) -join ', ') + ' (not every branch carries every surface)')
}

# ---------------------------------------------------------------------------
# Undeclared-root discovery: a skills-bearing root that exists on disk but is
# NOT declared would silently escape the scan - exactly how a layout rename
# shrinks coverage while CI stays green. Candidates are the repo-level skills/
# root, every profiles/<name>/skills root, and the repo-level scripts/ root.
# This runs BEFORE the vacuous-surface check so an undeclared root is reported
# as the actionable root cause instead of being masked by a generic BLOCKED.
# ---------------------------------------------------------------------------
$declaredSkillSet = @{}
foreach ($rel in $skillRels) { $declaredSkillSet[((($rel) -replace '\\', '/').TrimEnd('/')).ToLowerInvariant()] = $true }
$declaredScriptSet = @{}
foreach ($rel in $scriptRels) { $declaredScriptSet[((($rel) -replace '\\', '/').TrimEnd('/')).ToLowerInvariant()] = $true }

$skillRootCandidates = @('skills')
$profilesDir = Join-Path $repoRoot 'profiles'
if (Test-Path -LiteralPath $profilesDir -PathType Container) {
  foreach ($profDir in Get-ChildItem -LiteralPath $profilesDir -Directory -ErrorAction SilentlyContinue) {
    $skillRootCandidates += ('profiles/' + $profDir.Name + '/skills')
  }
}
foreach ($candRel in $skillRootCandidates) {
  $candAbs = ConvertTo-AbsPath $candRel
  if (-not (Test-Path -LiteralPath $candAbs -PathType Container)) { continue }
  if (@(Get-SkillDirNames -AbsRoot $candAbs).Count -eq 0) { continue }
  if (-not $declaredSkillSet.ContainsKey($candRel.ToLowerInvariant())) {
    Add-Row ("Undeclared skill root: " + $candRel) 'FAIL' $true 'skills-bearing root exists on disk but is NOT declared in skillRoots, so its twins would escape this gate' 'Add the root to skillRoots in profiles/shared/schemas/work-surface-duplication-allowlist.json (or remove the stale root).'
  }
}
$scriptsCandAbs = ConvertTo-AbsPath 'scripts'
if ((Test-Path -LiteralPath $scriptsCandAbs -PathType Container) -and (@(Get-ScriptFileNames -AbsRoot $scriptsCandAbs).Count -gt 0) -and (-not $declaredScriptSet.ContainsKey('scripts'))) {
  Add-Row 'Undeclared script root: scripts' 'FAIL' $true 'script-bearing root exists on disk but is NOT declared in scriptRoots, so its twins would escape this gate' 'Add "scripts" to scriptRoots in profiles/shared/schemas/work-surface-duplication-allowlist.json.'
}

# Vacuous-surface check: if NO dimension has at least two resolvable surfaces
# the scan would compare nothing - BLOCKED, never a vacuous PASS. When an
# undeclared-root FAIL was already recorded, fall through instead so the run
# ends FAIL with the actionable finding rather than masking it as BLOCKED.
$skillActive = ($skillNamesBySurface.Count -ge 2)
$scriptActive = ($scriptNamesBySurface.Count -ge 2)
$earlyBlockingFails = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
if (-not $skillActive -and -not $scriptActive -and $earlyBlockingFails.Count -eq 0) {
  Add-Row 'Surfaces resolve' 'BLOCKED' $true ("fewer than two resolvable surfaces in every dimension (skill={0} script={1}; missing: {2}) - the scan would compare nothing" -f $skillNamesBySurface.Count, $scriptNamesBySurface.Count, (@($missingSkillRoots + $missingScriptRoots) -join ', ')) 'Fix skillRoots/scriptRoots in the allowlist (or pass the correct -Root).'
  Write-Report -Overall 'BLOCKED' -ExitCode 2 -Extra @{ allowlist = $Allowlist }
}

# ---------------------------------------------------------------------------
# Real scan, one dimension at a time.
# ---------------------------------------------------------------------------
$totalDupes = 0
$totalAllowed = 0
$liveAllowedSkill = @{}
$liveAllowedScript = @{}

if ($skillActive) {
  $skillFindings = Find-SurfaceDuplicate -NamesBySurface $skillNamesBySurface -AllowSet $allowSkill
  $dupes = @($skillFindings | Where-Object { $_.kind -eq 'duplicate' })
  $allowed = @($skillFindings | Where-Object { $_.kind -eq 'allowed' })
  foreach ($f in $dupes) {
    Add-Row ("Skill surface duplicate: " + $f.name) 'FAIL' $true ("'" + $f.name + "' exists on " + ($f.surfaces -join ' AND ') + ' with no allowlist entry') 'A shared-tier skill already reaches BOTH profiles in place, so a same-name twin on another surface is redundant and drifts. Keep ONE surface (usually profiles/shared; see docs/cross-agent-work-arbitration.md rule R4) and delete the other, or add an allowedDuplicates entry with a reason.'
  }
  foreach ($f in $allowed) {
    Add-Row ("Allowlisted skill pair: " + $f.name) 'PASS' $false (($f.surfaces -join ' AND ') + ' (reason: ' + $f.reason + ')')
    $liveAllowedSkill[$f.name.ToLowerInvariant()] = $true
  }
  if ($dupes.Count -eq 0 -and $allowed.Count -eq 0) {
    Add-Row 'Skill surface intersection' 'PASS' $true ("no same-name skill across " + $skillNamesBySurface.Count + ' surfaces')
  }
  $totalDupes += $dupes.Count
  $totalAllowed += $allowed.Count
} else {
  Add-Row 'Skill dimension' 'PASS' $false ("inactive (only " + $skillNamesBySurface.Count + ' surface(s) resolved); script dimension still gates')
}

if ($scriptActive) {
  $scriptFindings = Find-SurfaceDuplicate -NamesBySurface $scriptNamesBySurface -AllowSet $allowScript
  $dupes = @($scriptFindings | Where-Object { $_.kind -eq 'duplicate' })
  $allowed = @($scriptFindings | Where-Object { $_.kind -eq 'allowed' })
  foreach ($f in $dupes) {
    Add-Row ("Script surface duplicate: " + $f.name) 'FAIL' $true ("'" + $f.name + "' exists on " + ($f.surfaces -join ' AND ') + ' with no allowlist entry') 'One script basename, one home. Keep ONE copy (and import/dot-source it from the other place if needed), or add an allowedDuplicates entry with kind "script" and a reason.'
  }
  foreach ($f in $allowed) {
    Add-Row ("Allowlisted script pair: " + $f.name) 'PASS' $false (($f.surfaces -join ' AND ') + ' (reason: ' + $f.reason + ')')
    $liveAllowedScript[$f.name.ToLowerInvariant()] = $true
  }
  if ($dupes.Count -eq 0 -and $allowed.Count -eq 0) {
    Add-Row 'Script surface intersection' 'PASS' $true ("no same-basename script across " + $scriptNamesBySurface.Count + ' surfaces')
  }
  $totalDupes += $dupes.Count
  $totalAllowed += $allowed.Count
} else {
  Add-Row 'Script dimension' 'PASS' $false ("inactive (only " + $scriptNamesBySurface.Count + ' surface(s) resolved); skill dimension still gates')
}

# Stale allowlist entries (entry exists but no live duplicate): advisory note so
# the allowlist shrinks back when a pair is resolved; never blocks.
foreach ($k in ($allowSkill.Keys | Sort-Object)) {
  if (-not $liveAllowedSkill.ContainsKey($k)) {
    Add-Row ("Stale allowlist entry (skill): " + $k) 'PASS' $false 'entry has no live cross-surface duplicate; consider removing it'
  }
}
foreach ($k in ($allowScript.Keys | Sort-Object)) {
  if (-not $liveAllowedScript.ContainsKey($k)) {
    Add-Row ("Stale allowlist entry (script): " + $k) 'PASS' $false 'entry has no live cross-surface duplicate; consider removing it'
  }
}

$blockingFails = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
$overall = if ($blockingFails.Count -gt 0) { 'FAIL' } else { 'PASS' }
$exit = if ($overall -eq 'FAIL') { 1 } else { 0 }
Write-Report -Overall $overall -ExitCode $exit -Extra @{
  allowlist = $Allowlist
  skill_surfaces = @($skillNamesBySurface.Keys | Sort-Object)
  script_surfaces = @($scriptNamesBySurface.Keys | Sort-Object)
  duplicate_count = $totalDupes
  allowed_count = $totalAllowed
}
