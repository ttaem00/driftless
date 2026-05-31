<#
.SYNOPSIS
  Driftless Windows text-safety gate. Keeps Windows-fragile scripts ASCII-only
  and free of a UTF-8 BOM.

.DESCRIPTION
  Guards against a recurring class of Windows shell/parse failures:

    1. Script text safety - every tracked *.ps1 / *.bat / *.cmd must be ASCII-only
       and have no UTF-8 BOM. Windows PowerShell 5.1 and cmd.exe read a BOM-less
       UTF-8 file as the legacy CP1252 codepage, so a stray em dash, curly quote,
       or non-Latin character corrupts the bytes and breaks the parse. A leading
       BOM upstream of param() has also broken 5.1 parsing, so .ps1 fails the BOM
       check too.

    2. PS 5.1-fragile cmdlets - some cmdlets are NOT reliably present in the
       constrained Windows PowerShell 5.1 host (for example Get-FileHash can be
       absent and throw CommandNotFoundException only at runtime). A LIVE use
       (not a comment) of such a cmdlet in any tracked *.ps1 is flagged so it
       cannot be reintroduced and silently fail later.

    3. Hook path safety - any tracked settings.json must declare hook 'command'
       paths as quoted forward-slash absolute paths, never backslash. Backslash
       hook paths collapse on Windows and can freeze the desktop agent host.

  Read-only. No network, no secrets, no peer AI, no host-global access. ASCII-only
  so the gate cannot fail its own rule under PowerShell 5.1.

.PARAMETER Root
  Repo root. Defaults to the parent of this script's folder.

.PARAMETER Json
  Also emit a machine-readable JSON summary.

.OUTPUTS
  A header, one line per check, then a RESULT line. Exit 0 when no blocking check
  FAILed; exit 1 otherwise.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

# Decode git stdout as UTF-8 so non-ASCII tracked paths (with core.quotepath=false)
# are read correctly under Windows PowerShell 5.1, and keep our own output UTF-8.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

# Extensions whose readers (PS 5.1, cmd.exe) are CP1252 on a BOM-less UTF-8 file.
$script:FragileExt = @('.ps1', '.bat', '.cmd')

function Get-TrackedFragileFiles {
  param([string]$RepoRoot)
  # Prefer git's tracked set so untracked scratch files do not block; fall back to
  # a recursive scan (skipping node_modules) when git is unavailable.
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
          if ($script:FragileExt -contains $ext) { Join-Path $RepoRoot $rel }
        }
      }
    } finally {
      $ErrorActionPreference = $saved
    }
  }
  if ($null -eq $files) {
    $files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object {
        $script:FragileExt -contains $_.Extension.ToLowerInvariant() -and
        $_.FullName -notmatch '[\\/]node_modules[\\/]'
      } | ForEach-Object { $_.FullName }
  }
  return @($files | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
}

function Test-TextSafe {
  param([string]$FilePath)
  # Read raw bytes: a BOM and any byte > 0x7F (non-ASCII) are both violations.
  $bytes = [System.IO.File]::ReadAllBytes($FilePath)
  $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
  $start = if ($hasBom) { 3 } else { 0 }
  $line = 1
  $firstNonAsciiLine = 0
  $nonAsciiCount = 0
  for ($i = $start; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 0x0A) { $line++ }
    elseif ($bytes[$i] -gt 0x7F) {
      $nonAsciiCount++
      if ($firstNonAsciiLine -eq 0) { $firstNonAsciiLine = $line }
    }
  }
  return [pscustomobject]@{
    safe              = (-not $hasBom -and $nonAsciiCount -eq 0)
    hasBom            = $hasBom
    nonAsciiCount     = $nonAsciiCount
    firstNonAsciiLine = $firstNonAsciiLine
  }
}

function Get-HookCommandPaths {
  param([string]$JsonText)
  # Extract every "command": "<value>" string without a JSON schema dependency.
  # A deterministic regex over the raw text is enough to catch backslash hook paths.
  $paths = [System.Collections.Generic.List[string]]::new()
  foreach ($m in [regex]::Matches($JsonText, '"command"\s*:\s*"((?:[^"\\]|\\.)*)"')) {
    $paths.Add($m.Groups[1].Value) | Out-Null
  }
  return $paths
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

# ---------------------------------------------------------------------------
# Check 1: ASCII-safe + BOM-free for *.ps1 / *.bat / *.cmd
# ---------------------------------------------------------------------------
$fragile = Get-TrackedFragileFiles -RepoRoot $resolvedRoot
$violations = [System.Collections.Generic.List[string]]::new()
foreach ($f in $fragile) {
  $check = Test-TextSafe -FilePath $f
  if (-not $check.safe) {
    $rel = $f.Substring($resolvedRoot.Length).TrimStart('\', '/')
    $why = @()
    if ($check.hasBom) { $why += 'BOM' }
    if ($check.nonAsciiCount -gt 0) { $why += ("non-ASCII x{0} (first line {1})" -f $check.nonAsciiCount, $check.firstNonAsciiLine) }
    $violations.Add(("{0}: {1}" -f $rel, ($why -join ', '))) | Out-Null
  }
}
if ($fragile.Count -eq 0) {
  $results.Add([pscustomobject]@{ check = 'Script text safety (.ps1/.bat/.cmd ASCII+noBOM)'; status = 'SKIP'; blocking = $false; evidence = 'no fragile scripts found'; next_action = '' }) | Out-Null
} else {
  $status = if ($violations.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "checked=$($fragile.Count); violations=$($violations.Count)"
  if ($violations.Count -gt 0) { $evidence += '; ' + ($violations -join '; ') }
  $results.Add([pscustomobject]@{ check = 'Script text safety (.ps1/.bat/.cmd ASCII+noBOM)'; status = $status; blocking = $true; evidence = $evidence; next_action = 'Replace non-ASCII (em dash, curly quote, non-Latin) with ASCII and strip the BOM; PS 5.1 and cmd.exe read these as CP1252 and corrupt the parse.' }) | Out-Null
}

# ---------------------------------------------------------------------------
# Check 1b: PS 5.1-fragile cmdlets. Flag a LIVE use (not a comment) of a cmdlet
# that is not reliably present in the constrained Windows PowerShell 5.1 host.
# Extend $fragileCmdlets if another absent cmdlet is found.
# ---------------------------------------------------------------------------
$fragileCmdlets = @('Get-FileHash')
$cmdletViolations = [System.Collections.Generic.List[string]]::new()
# This gate's own source legitimately NAMES the fragile cmdlet (in the list +
# the check label/next-action) to hunt for it; never flag it against itself.
$ps1Files = @($fragile | Where-Object { $_.ToLower().EndsWith('.ps1') -and -not ($_.ToLower().EndsWith('test-windowstextsafety.ps1')) })
foreach ($f in $ps1Files) {
  $lines = Get-Content -LiteralPath $f -ErrorAction SilentlyContinue
  $inBlockComment = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    # Skip <# ... #> block comments so an explanatory mention inside a docstring
    # does not false-positive.
    if ($inBlockComment) {
      if ($line -match '#>') { $inBlockComment = $false }
      continue
    }
    if ($line -match '<#') {
      if ($line -notmatch '#>') { $inBlockComment = $true }
      $line = ($line -split '<#')[0]
    }
    # Strip a trailing comment and skip whole-line comments.
    $code = $line
    $hashIdx = $code.IndexOf('#')
    if ($hashIdx -ge 0) { $code = $code.Substring(0, $hashIdx) }
    if ([string]::IsNullOrWhiteSpace($code)) { continue }
    foreach ($cmd in $fragileCmdlets) {
      if ($code -match ('(^|[^A-Za-z0-9-])' + [regex]::Escape($cmd) + '([^A-Za-z0-9-]|$)')) {
        $rel = $f.Substring($resolvedRoot.Length).TrimStart('\', '/')
        $cmdletViolations.Add(("{0}:{1}: live use of {2}" -f $rel, ($i + 1), $cmd)) | Out-Null
      }
    }
  }
}
if ($ps1Files.Count -eq 0) {
  $results.Add([pscustomobject]@{ check = 'PS5.1-fragile cmdlets (no Get-FileHash etc.)'; status = 'SKIP'; blocking = $false; evidence = 'no *.ps1 found'; next_action = '' }) | Out-Null
} else {
  $status = if ($cmdletViolations.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "ps1=$($ps1Files.Count); fragile-cmdlet-uses=$($cmdletViolations.Count)"
  if ($cmdletViolations.Count -gt 0) { $evidence += '; ' + ($cmdletViolations -join '; ') }
  $results.Add([pscustomobject]@{ check = 'PS5.1-fragile cmdlets (no Get-FileHash etc.)'; status = $status; blocking = $true; evidence = $evidence; next_action = 'Get-FileHash can be absent in the CI PowerShell 5.1 host; replace it with a raw-byte compare ([System.IO.File]::ReadAllBytes + length precheck) or another version-independent approach.' }) | Out-Null
}

# ---------------------------------------------------------------------------
# Check 2: hook command paths are forward-slash (any tracked settings.json)
# ---------------------------------------------------------------------------
$settingsFiles = @()
$gitForSettings = (Get-Command git -ErrorAction SilentlyContinue)
if ($gitForSettings) {
  $savedSettings = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $trackedSettings = & git -C $resolvedRoot -c core.quotepath=false ls-files 2>$null
    if ($LASTEXITCODE -eq 0 -and $trackedSettings) {
      $settingsFiles = @($trackedSettings |
        Where-Object { ($_ -replace '\\', '/') -match '(^|/)settings\.json$' } |
        ForEach-Object { Join-Path $resolvedRoot $_ } |
        Where-Object { Test-Path -LiteralPath $_ })
    }
  } finally {
    $ErrorActionPreference = $savedSettings
  }
}
if ($settingsFiles.Count -eq 0) {
  $results.Add([pscustomobject]@{ check = 'Hook path safety (forward-slash command paths)'; status = 'SKIP'; blocking = $false; evidence = 'no tracked settings.json'; next_action = '' }) | Out-Null
} else {
  $badPaths = [System.Collections.Generic.List[string]]::new()
  foreach ($sf in $settingsFiles) {
    $text = Get-Content -LiteralPath $sf -Raw -Encoding UTF8
    foreach ($cmd in (Get-HookCommandPaths -JsonText $text)) {
      # A literal backslash in the JSON string is "\\"; flag any command path that
      # contains a backslash separator (an absolute Windows hook path with \ ).
      if ($cmd -match '\\\\' -or $cmd -match '\\[A-Za-z0-9_.]') {
        $rel = $sf.Substring($resolvedRoot.Length).TrimStart('\', '/')
        $badPaths.Add(("{0}: {1}" -f $rel, $cmd)) | Out-Null
      }
    }
  }
  $status = if ($badPaths.Count -eq 0) { 'PASS' } else { 'FAIL' }
  $evidence = "settings=$($settingsFiles.Count); backslash_hook_paths=$($badPaths.Count)"
  if ($badPaths.Count -gt 0) { $evidence += '; ' + ($badPaths -join '; ') }
  $results.Add([pscustomobject]@{ check = 'Hook path safety (forward-slash command paths)'; status = $status; blocking = $true; evidence = $evidence; next_action = 'Rewrite hook command paths as quoted forward-slash absolute paths; backslash paths collapse and can freeze the desktop agent host.' }) | Out-Null
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$blockingFailures = @($results | Where-Object { $_.blocking -eq $true -and $_.status -eq 'FAIL' })
$overall = if ($blockingFailures.Count -gt 0) { 'FAIL' } else { 'PASS' }

Write-Output '== Windows text-safety gate =='
foreach ($r in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
}
$pass = @($results | Where-Object { $_.status -eq 'PASS' }).Count
$fail = @($results | Where-Object { $_.status -eq 'FAIL' }).Count
$skip = @($results | Where-Object { $_.status -eq 'SKIP' }).Count
Write-Output ("RESULT: {0} (pass={1} fail={2} skip={3})" -f $overall, $pass, $fail, $skip)

if ($Json) {
  [pscustomobject]@{
    gate    = 'windows-text-safety'
    root    = $resolvedRoot
    overall = $overall
    pass    = $pass
    fail    = $fail
    skip    = $skip
    results = @($results)
  } | ConvertTo-Json -Depth 5
}

if ($overall -eq 'FAIL') { exit 1 } else { exit 0 }
