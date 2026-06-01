<#
.SYNOPSIS
  Driftless skill-audit gate. Mechanically checks that every shipped SKILL.md is
  structurally sound before it lands - it has a name and a non-empty description
  with trigger signal, and its name matches its own folder so the skill router
  can actually find it. Containment already forbids inlined secrets and
  host-global paths, so this gate deliberately does NOT re-check those: it covers
  only the skill-hygiene surface that no other gate does.

.DESCRIPTION
  driftless ships a starter kit of agent skills and makes "skill gradient
  descent" (skillopt) a headline. The skillopt harness scores skill *changes* on
  five axes; the containment gate forbids forbidden paths and leaked secrets. But
  nothing checked, at commit time, that a NEW SKILL.md is even well-formed. A
  skill whose name does not match its folder, or whose description is an empty
  shell, silently fails to fire - the worst kind of bug, because it looks shipped
  but never triggers. Prose in a contributing guide cannot stop that from
  recurring, so this gate turns it into a blocking check.

  Every tracked SKILL.md under profiles/ and the top-level skills/ is held to:

    BLOCKING - Check 1: the file has YAML frontmatter with a 'name:' and a
               'description:' (single-line or block scalar).
    BLOCKING - Check 2: 'name' matches the skill's own folder name (the segment
               immediately above SKILL.md), so the router resolves it.
    BLOCKING - Check 3: the description body is non-empty and carries at least
               one trigger signal (a 'Trigger' marker, OR a quoted phrase, OR a
               'Use when' intent line) so the skill is discoverable rather than
               a blank stub.

  Honest fairness. Check 3 accepts ANY of the three discoverability signals, so a
  description written purely as a plain "Use when ..." intent line (the
  front-loaded style this repo adopted) passes without a literal "Trigger:"
  block. This gate's own source is ASCII-only and read-only.

  To prove the checks have teeth, a built-in self-test (-SelfTest) asserts the
  auditor FAILs on planted-bad in-memory fixtures (missing name, name/folder
  mismatch, empty description) and PASSes on a clean fixture - no temp files, no
  git mutation.

  Read-only. No network, no secrets, no peer AI, no host-global access. ASCII
  only so the gate cannot fail its own text-safety rule under PowerShell 5.1.

.PARAMETER Root
  Repo root. Defaults to the parent of this script's folder.

.PARAMETER SelfTest
  Run only the built-in self-test of the auditor and exit. Used by CI to prove
  the gate has teeth without planting anything in the tree.

.PARAMETER Json
  Also emit a machine-readable JSON summary.

.OUTPUTS
  A header, one line per audited skill issue, then a RESULT line. Exit 0 when no
  blocking check FAILed; exit 1 otherwise.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$SelfTest,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

# Decode git stdout as UTF-8 so non-ASCII tracked paths (with core.quotepath=false)
# are read correctly under Windows PowerShell 5.1, and keep our own output UTF-8.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------------------
# Frontmatter parsing. A SKILL.md opens with a YAML block delimited by '---'.
# We only need 'name' (scalar) and 'description' (scalar OR block '>' / '|').
# Hand-rolled rather than pulling a YAML module so the gate has zero deps and
# parses identically under PS 5.1.
# ---------------------------------------------------------------------------
function Get-Frontmatter {
  param([string[]]$Lines)
  $result = [pscustomobject]@{ hasFrontmatter = $false; name = $null; description = $null }
  if (@($Lines).Count -eq 0) { return $result }
  # First non-empty line must be the opening '---'.
  $i = 0
  while ($i -lt $Lines.Count -and [string]::IsNullOrWhiteSpace($Lines[$i])) { $i++ }
  if ($i -ge $Lines.Count -or $Lines[$i].Trim() -ne '---') { return $result }
  $result.hasFrontmatter = $true
  $i++
  $descLines = [System.Collections.Generic.List[string]]::new()
  while ($i -lt $Lines.Count) {
    $line = $Lines[$i]
    if ($line.Trim() -eq '---') { break }
    if ($line -match '^name:\s*(.+?)\s*$') {
      $result.name = $Matches[1].Trim().Trim('"').Trim("'")
    } elseif ($line -match '^description:\s*(.*)$') {
      $rest = $Matches[1].Trim()
      if ($rest -eq '>' -or $rest -eq '|' -or $rest -eq '>-' -or $rest -eq '|-') {
        # Block scalar: collect the following indented lines.
        $i++
        while ($i -lt $Lines.Count) {
          $bl = $Lines[$i]
          if ($bl.Trim() -eq '---') { $i--; break }
          # A new top-level key (no leading whitespace, 'key:') ends the block.
          if ($bl -match '^[A-Za-z0-9_-]+:\s') { $i--; break }
          if (-not [string]::IsNullOrWhiteSpace($bl)) { $descLines.Add($bl.Trim()) | Out-Null }
          $i++
        }
      } elseif ($rest.Length -gt 0) {
        $descLines.Add($rest.Trim('"').Trim("'")) | Out-Null
      }
    }
    $i++
  }
  if ($descLines.Count -gt 0) { $result.description = ($descLines -join ' ').Trim() }
  return $result
}

# A description carries a discoverability signal if ANY of: a Trigger marker, a
# quoted phrase, or a 'Use when'/'Use this skill' intent line. Accepting any one
# keeps the gate fair to the front-loaded plain-intent style this repo adopted.
# Source stays ASCII-only (PS 5.1 reads this file as CP1252): the bilingual
# "Trigger / <Korean>:" form in every SKILL.md always carries the ASCII word
# "Trigger" alongside the Korean, so matching the ASCII token is sufficient - we
# never embed any Korean literal in this gate's source.
function Test-HasTriggerSignal {
  param([string]$Description)
  if ([string]::IsNullOrWhiteSpace($Description)) { return $false }
  if ($Description -match 'Trigger') { return $true }
  if ($Description -match '"[^"]+"') { return $true }
  if ($Description -match 'Use when' -or $Description -match 'Use this skill') { return $true }
  return $false
}

# Audit a single skill (folder + parsed frontmatter) into a list of issue
# strings. An empty list means the skill is clean.
function Get-SkillIssues {
  param([string]$RelPath, [string]$FolderName, $Front)
  $issues = [System.Collections.Generic.List[string]]::new()
  if (-not $Front.hasFrontmatter) {
    $issues.Add(("{0}: no YAML frontmatter (must open with '---' ... 'name:' ... 'description:' ... '---')" -f $RelPath)) | Out-Null
    return $issues
  }
  if ([string]::IsNullOrWhiteSpace($Front.name)) {
    $issues.Add(("{0}: missing 'name:' in frontmatter" -f $RelPath)) | Out-Null
  } elseif ($Front.name -ne $FolderName) {
    $issues.Add(("{0}: name '{1}' does not match its folder '{2}' (router would not resolve it)" -f $RelPath, $Front.name, $FolderName)) | Out-Null
  }
  if ([string]::IsNullOrWhiteSpace($Front.description)) {
    $issues.Add(("{0}: missing or empty 'description:' (a blank skill never fires)" -f $RelPath)) | Out-Null
  } elseif (-not (Test-HasTriggerSignal -Description $Front.description)) {
    $issues.Add(("{0}: description has no trigger signal (need a Trigger/trigger marker, a quoted phrase, or a 'Use when' intent line so the skill is discoverable)" -f $RelPath)) | Out-Null
  }
  return $issues
}

# ---------------------------------------------------------------------------
# Built-in self-test: prove the auditor FAILs on planted-bad fixtures and PASSes
# clean. In-memory only - no temp files, no git mutation.
# ---------------------------------------------------------------------------
function Invoke-SelfTest {
  $failures = [System.Collections.Generic.List[string]]::new()

  # Clean fixture: well-formed skill that must NOT be flagged.
  $cleanFront = Get-Frontmatter -Lines @(
    '---',
    'name: my-skill',
    'description: >',
    '  Use when the manager asks to do the thing. Trigger: "do the thing".',
    '---',
    '# body'
  )
  $cleanIssues = Get-SkillIssues -RelPath 'skills/my-skill/SKILL.md' -FolderName 'my-skill' -Front $cleanFront
  if (@($cleanIssues).Count -ne 0) {
    $failures.Add('clean fixture falsely flagged: ' + (@($cleanIssues) -join '; ')) | Out-Null
  }

  # Negative A: missing name.
  $noNameFront = Get-Frontmatter -Lines @(
    '---',
    'description: Use when something. "trigger"',
    '---'
  )
  $noNameIssues = Get-SkillIssues -RelPath 'skills/x/SKILL.md' -FolderName 'x' -Front $noNameFront
  if (@($noNameIssues).Count -lt 1) { $failures.Add('negative(missing name) NOT detected') | Out-Null }

  # Negative B: name/folder mismatch.
  $mismatchFront = Get-Frontmatter -Lines @(
    '---',
    'name: wrong-name',
    'description: Use when something. "trigger"',
    '---'
  )
  $mismatchIssues = Get-SkillIssues -RelPath 'skills/right-folder/SKILL.md' -FolderName 'right-folder' -Front $mismatchFront
  if (@($mismatchIssues).Count -lt 1) { $failures.Add('negative(name/folder mismatch) NOT detected') | Out-Null }

  # Negative C: empty description.
  $emptyDescFront = Get-Frontmatter -Lines @(
    '---',
    'name: y',
    'description:',
    '---'
  )
  $emptyDescIssues = Get-SkillIssues -RelPath 'skills/y/SKILL.md' -FolderName 'y' -Front $emptyDescFront
  if (@($emptyDescIssues).Count -lt 1) { $failures.Add('negative(empty description) NOT detected') | Out-Null }

  # Negative D: no frontmatter at all.
  $noFmFront = Get-Frontmatter -Lines @('# just a heading', 'no frontmatter here')
  $noFmIssues = Get-SkillIssues -RelPath 'skills/z/SKILL.md' -FolderName 'z' -Front $noFmFront
  if (@($noFmIssues).Count -lt 1) { $failures.Add('negative(no frontmatter) NOT detected') | Out-Null }

  return [pscustomobject]@{
    passed   = (@($failures).Count -eq 0)
    failures = @($failures)
    detail   = ("clean_issues={0}; neg_name={1}; neg_mismatch={2}; neg_emptydesc={3}; neg_nofm={4}" -f `
        @($cleanIssues).Count, @($noNameIssues).Count, @($mismatchIssues).Count, @($emptyDescIssues).Count, @($noFmIssues).Count)
  }
}

# Find every tracked SKILL.md (profiles/ and top-level skills/), falling back to
# a filesystem walk if git is unavailable.
function Get-SkillFiles {
  param([string]$RepoRoot)
  $rels = $null
  $git = (Get-Command git -ErrorAction SilentlyContinue)
  if ($git) {
    $saved = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $tracked = & git -C $RepoRoot -c core.quotepath=false ls-files 2>$null
      if ($LASTEXITCODE -eq 0 -and $tracked) {
        $rels = @($tracked | Where-Object { $_ -match '(^|/)SKILL\.md$' })
      }
    } finally {
      $ErrorActionPreference = $saved
    }
  }
  if ($null -eq $rels) {
    $rels = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter 'SKILL.md' -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' } |
      ForEach-Object { ($_.FullName.Substring($RepoRoot.Length).TrimStart('\', '/') -replace '\\', '/') }
  }
  return @($rels)
}

# ===========================================================================
# Run
# ===========================================================================
if ($SelfTest) {
  $st = Invoke-SelfTest
  Write-Output '== Skill-audit gate: built-in self-test =='
  Write-Output ("auditor: {0}" -f $st.detail)
  if ($st.passed) {
    Write-Output 'RESULT: PASS (auditor FAILs on missing-name / name-folder-mismatch / empty-description / no-frontmatter, PASSes clean)'
    if ($Json) {
      [pscustomobject]@{ gate = 'skill-audit'; mode = 'self-test'; overall = 'PASS'; detail = $st.detail } | ConvertTo-Json -Depth 4
    }
    exit 0
  } else {
    foreach ($f in $st.failures) { Write-Output ("  - " + $f) }
    Write-Output 'RESULT: FAIL (the auditor did not behave as specified)'
    if ($Json) {
      [pscustomobject]@{ gate = 'skill-audit'; mode = 'self-test'; overall = 'FAIL'; failures = @($st.failures); detail = $st.detail } | ConvertTo-Json -Depth 4
    }
    exit 1
  }
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

# Always run the self-test inline so a live run also proves the auditor has
# teeth; a broken auditor is a blocking failure. (Name avoids the $SelfTest
# switch parameter to prevent PowerShell coercing the object onto the switch.)
$auditorCheck = Invoke-SelfTest
$results.Add([pscustomobject]@{
    check       = 'Auditor self-test (FAILs on bad fixtures, PASSes clean)'
    status      = if ($auditorCheck.passed) { 'PASS' } else { 'FAIL' }
    blocking    = $true
    evidence    = $auditorCheck.detail
    next_action = if ($auditorCheck.passed) { '' } else { ('Auditor regressed: ' + (@($auditorCheck.failures) -join '; ')) }
  }) | Out-Null

# ---------------------------------------------------------------------------
# Check (BLOCKING): every shipped SKILL.md is structurally sound.
# ---------------------------------------------------------------------------
$skillRels = Get-SkillFiles -RepoRoot $resolvedRoot
$allIssues = [System.Collections.Generic.List[string]]::new()
$scanned = 0
foreach ($rel in $skillRels) {
  $full = Join-Path $resolvedRoot $rel
  if (-not (Test-Path -LiteralPath $full)) { continue }
  $scanned++
  $lines = @(Get-Content -LiteralPath $full -ErrorAction SilentlyContinue)
  $front = Get-Frontmatter -Lines $lines
  # Folder name = the path segment immediately above SKILL.md.
  $parts = $rel.Split('/')
  $folderName = if ($parts.Count -ge 2) { $parts[$parts.Count - 2] } else { '' }
  foreach ($iss in (Get-SkillIssues -RelPath $rel -FolderName $folderName -Front $front)) {
    $allIssues.Add($iss) | Out-Null
  }
}
if ($scanned -eq 0) {
  $results.Add([pscustomobject]@{ check = 'Every SKILL.md is structurally sound (name+description+trigger, name matches folder)'; status = 'SKIP'; blocking = $false; evidence = 'no tracked SKILL.md found'; next_action = '' }) | Out-Null
} else {
  $status = if ($allIssues.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "scanned=$scanned; issues=$($allIssues.Count)"
  if ($allIssues.Count -gt 0) { $evidence += '; ' + ($allIssues -join '; ') }
  $results.Add([pscustomobject]@{ check = 'Every SKILL.md is structurally sound (name+description+trigger, name matches folder)'; status = $status; blocking = $true; evidence = $evidence; next_action = 'Fix the flagged SKILL.md: add the missing name/description, make name match its folder, or add a trigger signal, so the skill actually fires.' }) | Out-Null
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
Write-Output '== Driftless skill-audit gate =='
$anyBlockingFail = $false
foreach ($r in $results) {
  Write-Output ("[{0}] {1}" -f $r.status, $r.check)
  if ($r.evidence) { Write-Output ("       {0}" -f $r.evidence) }
  if ($r.status -eq 'FAIL' -and $r.next_action) { Write-Output ("       -> {0}" -f $r.next_action) }
  if ($r.blocking -and $r.status -eq 'FAIL') { $anyBlockingFail = $true }
}

if ($anyBlockingFail) {
  Write-Output 'RESULT: FAIL (a blocking skill-audit check did not pass)'
  if ($Json) { [pscustomobject]@{ gate = 'skill-audit'; overall = 'FAIL'; checks = $results } | ConvertTo-Json -Depth 6 }
  exit 1
} else {
  Write-Output 'RESULT: PASS (all shipped skills are structurally sound)'
  if ($Json) { [pscustomobject]@{ gate = 'skill-audit'; overall = 'PASS'; checks = $results } | ConvertTo-Json -Depth 6 }
  exit 0
}
