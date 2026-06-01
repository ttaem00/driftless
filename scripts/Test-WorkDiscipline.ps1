<#
.SYNOPSIS
  Driftless work-discipline gate. Mechanically enforces that no unresolved
  placeholder ships inside a real rule, and (advisory) that the current branch
  follows the agent/issue-<n>-<slug> naming convention.

.DESCRIPTION
  Two disciplines are stated as prose across the skills and docs:

    1. Evidence-first / no-false-rule. A rule, guardrail, or instruction must be
       real before it ships - never an unresolved stub left for "later". A
       placeholder marker (TODO, FIXME, XXX, TBD, FILL-IN, or an angle-bracket
       <PLACEHOLDER> token) sitting in a tracked rule file means an unfinished
       rule was shipped as if it were authoritative. Prose alone cannot stop
       that from recurring, so this gate turns it into a blocking check:

         BLOCKING - Check 1: no unresolved placeholder in a tracked *.md / *.ps1.

       The gate flags the placeholder by a deterministic token match. It never
       deletes or rewrites the prose around it - it only FAILs so a human or the
       agent resolves the stub before the change is called done.

    2. Issue-before-edit. Non-trivial repo work runs on a branch named
       agent/issue-<n>-<slug> (or the tool-specific claude/issue-... /
       codex/issue-... forms) so the change is tied to a tracked issue. The
       branch name is reported as an ADVISORY check (never blocking): a
       detached HEAD, the default branch, or a clean release cut should not
       mechanically fail, but a clearly off-pattern working branch is surfaced.

  Honest fairness (so the gate does not falsely fail). The placeholder check
  exempts (a) this gate's own source, which must NAME the placeholder tokens in
  order to hunt for them, and (b) the documentation that DESCRIBES this gate
  (any *.md whose text declares it is the work-discipline guardrail), exactly
  the way the containment and text-safety gates let their own docs name the
  thing they forbid. Every other tracked rule file is held to the rule. To prove
  the check has teeth, a built-in negative self-test plants a placeholder in an
  in-memory rule fixture and asserts the detector FAILs on it, then asserts a
  clean fixture PASSes - no temp files, no git mutation, ASCII-only.

  Read-only. No network, no secrets, no peer AI, no host-global access. ASCII
  only so the gate cannot fail its own text-safety rule under PowerShell 5.1.

.PARAMETER Root
  Repo root. Defaults to the parent of this script's folder.

.PARAMETER SelfTest
  Run only the built-in negative+positive self-test of the detector and exit.
  Used by CI to prove the gate has teeth without planting anything in the tree.

.PARAMETER Json
  Also emit a machine-readable JSON summary.

.OUTPUTS
  A header, one line per check, then a RESULT line. Exit 0 when no blocking
  check FAILed; exit 1 otherwise.
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

# This gate's own file name. Its source legitimately names the placeholder tokens
# (to hunt for them), so it is never flagged against itself - the same self-exempt
# pattern the text-safety gate uses for Get-FileHash.
$script:SelfFileName = 'test-workdiscipline.ps1'

# Extensions that carry shipped rules/instructions in this repo.
$script:RuleExt = @('.md', '.ps1')

# A marker that, sitting in a shipped rule file, means an UNRESOLVED stub - as
# opposed to prose that merely NAMES the word "TODO" as a concept. The signal of
# a genuine leftover stub is narrow on purpose, to avoid false positives on docs
# that describe the workflow (e.g. "Scan TODO / backlog signals", or a `TODO`
# token cited inside backticks):
#
#   1. A code span (`...`) is a deliberate citation of the token, not a live
#      stub, so inline-code is stripped before testing - the same spirit as the
#      text-safety gate stripping comments before it hunts cmdlets.
#   2. A classic marker counts only in STUB FORM: TODO:/FIXME:/XXX:/TBD: with a
#      trailing colon or '(', i.e. introducing unfinished content, OR a marker
#      that is the FIRST non-whitespace token of the line / list item (a leftover
#      placeholder), not one buried mid-sentence or in a comma list of nouns.
#   3. An angle-bracket template token (<PLACEHOLDER>, <FILL-IN>, <TBD>,
#      <REPLACE-ME>) is always an unfilled slot.
# Case-sensitive (cmatch) so lower-case prose like "to-do later" is not a hit.
function Remove-InlineCode {
  param([string]$Line)
  # Drop `...` code spans so a deliberately cited `TODO` token is not a stub hit.
  return ([regex]::Replace($Line, '`[^`]*`', ' '))
}

function Test-PlaceholderLine {
  param([string]$Line)
  $stripped = Remove-InlineCode -Line $Line
  # Stub form: marker immediately followed by ':' or '(' (TODO:, FIXME(...)).
  if ($stripped -cmatch '(^|[^A-Za-z0-9_])(TODO|FIXME|XXX|TBD|FILL-IN|FILLIN)\s*[:(]') { return $true }
  # Leftover form: marker is the first non-whitespace token, optionally after a
  # list bullet / heading marker / code-comment hash (- * # 1. //).
  if ($stripped -cmatch '^\s*(#+\s*|[-*]\s+|[0-9]+\.\s+|//\s*)?(TODO|FIXME|XXX|TBD|FILL-IN|FILLIN)([^A-Za-z0-9_]|$)') { return $true }
  # Angle-bracket template token: an unfilled slot. Upper-case word inside to
  # avoid matching ordinary HTML/markup.
  if ($stripped -cmatch '<\s*(PLACEHOLDER|FILL[ _-]?IN|TBD|REPLACE[ _-]?ME)\s*>') { return $true }
  return $false
}

# Decide whether a tracked rule file is exempt from the placeholder check:
#   - this gate's own source (names the tokens to hunt them), and
#   - the *.md that DESCRIBES this gate (declares it is the work-discipline gate).
function Test-PlaceholderExempt {
  param([string]$RelPath, [string[]]$Lines)
  $lower = $RelPath.ToLowerInvariant()
  if ($lower.EndsWith($script:SelfFileName)) { return $true }
  if ($lower.EndsWith('.md')) {
    # A doc that self-declares it documents this gate is allowed to name the
    # tokens (mirrors the text-safety/containment doc exemption). Match on a
    # stable phrase the gate's own doc section uses.
    foreach ($l in $Lines) {
      if ($l -match 'work-discipline gate' -or $l -match 'Test-WorkDiscipline') { return $true }
    }
  }
  return $false
}

function Get-TrackedRuleFiles {
  param([string]$RepoRoot)
  $files = $null
  $git = (Get-Command git -ErrorAction SilentlyContinue)
  if ($git) {
    $saved = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $tracked = & git -C $RepoRoot -c core.quotepath=false ls-files 2>$null
      if ($LASTEXITCODE -eq 0 -and $tracked) {
        $files = foreach ($rel in $tracked) {
          $ext = [System.IO.Path]::GetExtension($rel).ToLowerInvariant()
          if ($script:RuleExt -contains $ext) { Join-Path $RepoRoot $rel }
        }
      }
    } finally {
      $ErrorActionPreference = $saved
    }
  }
  if ($null -eq $files) {
    $files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object {
        $script:RuleExt -contains $_.Extension.ToLowerInvariant() -and
        $_.FullName -notmatch '[\\/]node_modules[\\/]'
      } | ForEach-Object { $_.FullName }
  }
  return @($files | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
}

# Scan one file's lines for placeholder hits, honoring the exemption.
function Get-FilePlaceholderHits {
  param([string]$RelPath, [string[]]$Lines)
  $hits = [System.Collections.Generic.List[string]]::new()
  if (Test-PlaceholderExempt -RelPath $RelPath -Lines $Lines) { return $hits }
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if (Test-PlaceholderLine -Line $Lines[$i]) {
      $token = $Lines[$i].Trim()
      if ($token.Length -gt 80) { $token = $token.Substring(0, 80) + '...' }
      $hits.Add(("{0}:{1}: {2}" -f $RelPath, ($i + 1), $token)) | Out-Null
    }
  }
  return $hits
}

# ---------------------------------------------------------------------------
# Built-in self-test: prove the detector FAILs on a planted placeholder and
# PASSes on a clean rule. In-memory only - no temp files, no git mutation.
# ---------------------------------------------------------------------------
function Invoke-SelfTest {
  $failures = [System.Collections.Generic.List[string]]::new()

  # Negative fixture: a rule file that ships an unresolved placeholder.
  $plantedRel = 'docs/en/__selftest_planted_rule.md'
  $plantedLines = @(
    '# A shipped rule',
    'The agent must always verify evidence before claiming PASS.',
    'TODO: fill in the exact verification command before shipping this rule.'
  )
  $plantedHits = Get-FilePlaceholderHits -RelPath $plantedRel -Lines $plantedLines
  if (@($plantedHits).Count -lt 1) {
    $failures.Add('negative fixture: a planted TODO placeholder was NOT detected') | Out-Null
  }

  # Clean fixture: a real, resolved rule with no stub - must NOT be flagged.
  $cleanRel = 'docs/en/__selftest_clean_rule.md'
  $cleanLines = @(
    '# A shipped rule',
    'The agent must run scripts/Test-Containment.ps1 and see PASS before done.',
    'No file fact or PASS claim is made without command evidence.'
  )
  $cleanHits = Get-FilePlaceholderHits -RelPath $cleanRel -Lines $cleanLines
  if (@($cleanHits).Count -ne 0) {
    $failures.Add(('clean fixture: a resolved rule was falsely flagged: ' + (@($cleanHits) -join '; '))) | Out-Null
  }

  # Exemption fixture: a doc that documents THIS gate may name the tokens.
  $docRel = 'docs/en/guardrails.md'
  $docLines = @(
    '## The work-discipline gate',
    'It flags a placeholder marker such as TODO, FIXME, or <PLACEHOLDER>.'
  )
  $docHits = Get-FilePlaceholderHits -RelPath $docRel -Lines $docLines
  if (@($docHits).Count -ne 0) {
    $failures.Add(('exemption fixture: the gate doc naming tokens was falsely flagged: ' + (@($docHits) -join '; '))) | Out-Null
  }

  return [pscustomobject]@{
    passed   = (@($failures).Count -eq 0)
    failures = @($failures)
    detail   = ("negative_hits={0}; clean_hits={1}; doc_hits={2}" -f `
        @($plantedHits).Count, @($cleanHits).Count, @($docHits).Count)
  }
}

# ---------------------------------------------------------------------------
# Branch-name advisory: agent/issue-<n>-<slug> and tool-specific forms.
# ---------------------------------------------------------------------------
function Get-CurrentBranch {
  param([string]$RepoRoot)
  $git = (Get-Command git -ErrorAction SilentlyContinue)
  if (-not $git) { return $null }
  $saved = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $b = & git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $b) { return ([string]$b).Trim() }
  } finally {
    $ErrorActionPreference = $saved
  }
  return $null
}

function Test-WorkBranchPattern {
  param([string]$Branch)
  # Accepted working-branch shapes: <prefix>/issue-<n>-<slug>
  # where <prefix> is agent | claude | codex.
  return ($Branch -match '^(agent|claude|codex)/issue-[0-9]+-[A-Za-z0-9._-]+$')
}

# ===========================================================================
# Run
# ===========================================================================
if ($SelfTest) {
  $st = Invoke-SelfTest
  Write-Output '== Work-discipline gate: built-in self-test =='
  Write-Output ("detector: {0}" -f $st.detail)
  if ($st.passed) {
    Write-Output 'RESULT: PASS (detector FAILs on a planted placeholder, PASSes clean, exempts its own doc)'
    if ($Json) {
      [pscustomobject]@{ gate = 'work-discipline'; mode = 'self-test'; overall = 'PASS'; detail = $st.detail } | ConvertTo-Json -Depth 4
    }
    exit 0
  } else {
    foreach ($f in $st.failures) { Write-Output ("  - " + $f) }
    Write-Output 'RESULT: FAIL (the detector did not behave as specified)'
    if ($Json) {
      [pscustomobject]@{ gate = 'work-discipline'; mode = 'self-test'; overall = 'FAIL'; failures = @($st.failures); detail = $st.detail } | ConvertTo-Json -Depth 4
    }
    exit 1
  }
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

# Always run the self-test inline so a live run also proves the detector has
# teeth; a broken detector is a blocking failure. (Name avoids the $SelfTest
# switch parameter - PowerShell variable names are case-insensitive, so reusing
# $selfTest would coerce a PSCustomObject onto the switch and throw.)
$detectorCheck = Invoke-SelfTest
$results.Add([pscustomobject]@{
    check       = 'Detector self-test (FAILs on planted placeholder, PASSes clean)'
    status      = if ($detectorCheck.passed) { 'PASS' } else { 'FAIL' }
    blocking    = $true
    evidence    = $detectorCheck.detail
    next_action = if ($detectorCheck.passed) { '' } else { ('Detector regressed: ' + (@($detectorCheck.failures) -join '; ')) }
  }) | Out-Null

# ---------------------------------------------------------------------------
# Check 1 (BLOCKING): no unresolved placeholder in a tracked *.md / *.ps1.
# ---------------------------------------------------------------------------
$ruleFiles = Get-TrackedRuleFiles -RepoRoot $resolvedRoot
$allHits = [System.Collections.Generic.List[string]]::new()
$scanned = 0
foreach ($f in $ruleFiles) {
  $rel = $f.Substring($resolvedRoot.Length).TrimStart('\', '/') -replace '\\', '/'
  $lines = @(Get-Content -LiteralPath $f -ErrorAction SilentlyContinue)
  $scanned++
  foreach ($h in (Get-FilePlaceholderHits -RelPath $rel -Lines $lines)) {
    $allHits.Add($h) | Out-Null
  }
}
if ($ruleFiles.Count -eq 0) {
  $results.Add([pscustomobject]@{ check = 'No unresolved placeholder in shipped rules (*.md/*.ps1)'; status = 'SKIP'; blocking = $false; evidence = 'no tracked rule files found'; next_action = '' }) | Out-Null
} else {
  $status = if ($allHits.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "scanned=$scanned; placeholder_hits=$($allHits.Count)"
  if ($allHits.Count -gt 0) { $evidence += '; ' + ($allHits -join '; ') }
  $results.Add([pscustomobject]@{ check = 'No unresolved placeholder in shipped rules (*.md/*.ps1)'; status = $status; blocking = $true; evidence = $evidence; next_action = 'Resolve the placeholder (TODO/FIXME/XXX/TBD/FILL-IN/<PLACEHOLDER>) into a real rule, or remove the stub, before shipping. A rule must be authoritative when it lands.' }) | Out-Null
}

# ---------------------------------------------------------------------------
# Check 2 (ADVISORY, non-blocking): working branch name convention.
# ---------------------------------------------------------------------------
$branch = Get-CurrentBranch -RepoRoot $resolvedRoot
if ([string]::IsNullOrWhiteSpace($branch)) {
  $results.Add([pscustomobject]@{ check = 'Branch name (advisory): agent/issue-<n>-<slug>'; status = 'SKIP'; blocking = $false; evidence = 'no git branch (not a repo or detached HEAD)'; next_action = '' }) | Out-Null
} elseif ($branch -eq 'main' -or $branch -eq 'master' -or $branch -eq 'HEAD') {
  $results.Add([pscustomobject]@{ check = 'Branch name (advisory): agent/issue-<n>-<slug>'; status = 'SKIP'; blocking = $false; evidence = ("on default/detached branch '{0}' - convention applies to working branches" -f $branch); next_action = '' }) | Out-Null
} elseif (Test-WorkBranchPattern -Branch $branch) {
  $results.Add([pscustomobject]@{ check = 'Branch name (advisory): agent/issue-<n>-<slug>'; status = 'PASS'; blocking = $false; evidence = ("branch '{0}' follows <prefix>/issue-<n>-<slug>" -f $branch); next_action = '' }) | Out-Null
} else {
  $results.Add([pscustomobject]@{ check = 'Branch name (advisory): agent/issue-<n>-<slug>'; status = 'ADVISORY'; blocking = $false; evidence = ("branch '{0}' is off-pattern" -f $branch); next_action = 'Non-trivial work should run on agent/issue-<n>-<slug> (or claude/codex/issue-...) so it ties to a tracked issue. Advisory only - not blocking.' }) | Out-Null
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$blockingFailures = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
$overall = if ($blockingFailures.Count -gt 0) { 'FAIL' } else { 'PASS' }

Write-Output '== Work-discipline gate =='
foreach ($r in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
}
$pass = @($results | Where-Object { $_.status -eq 'PASS' }).Count
$fail = @($results | Where-Object { $_.status -eq 'FAIL' }).Count
$skip = @($results | Where-Object { $_.status -eq 'SKIP' }).Count
$advisory = @($results | Where-Object { $_.status -eq 'ADVISORY' }).Count
Write-Output ("RESULT: {0} (pass={1} fail={2} skip={3} advisory={4})" -f $overall, $pass, $fail, $skip, $advisory)

if ($Json) {
  [pscustomobject]@{
    gate     = 'work-discipline'
    root     = $resolvedRoot
    overall  = $overall
    pass     = $pass
    fail     = $fail
    skip     = $skip
    advisory = $advisory
    results  = @($results)
  } | ConvertTo-Json -Depth 5
}

if ($overall -eq 'FAIL') { exit 1 } else { exit 0 }
