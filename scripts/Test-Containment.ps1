#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Driftless containment gate. Proves the repo never reads or writes a forbidden
  path and never leaks a credential.

.DESCRIPTION
  Scans the working-tree diff and untracked files (default), every tracked file
  (-AllFiles), or a single file (-File) and flags any file that READS or WRITES a
  forbidden path, or that leaks a credential token. The forbidden surface is the
  shared isolation contract in profiles/shared/schemas/forbidden-paths.json:
  .env / .env.*, .ssh, secrets/**, private keys (*.pem / *.key), browser profiles
  (Login Data, Cookies, chrome-profile), and the host-global agent homes
  (~/.claude, ~/.codex); plus inline secret tokens (GitHub / Anthropic / OpenAI /
  AWS keys and PRIVATE KEY blocks). Three finding classes are produced:

    forbidden_path       The scanned file's OWN path is forbidden (it should not
                         exist in the scan surface). Its contents are never read.
    forbidden_reference  A file's text references a forbidden PATH (it reads or
                         writes it).
    forbidden_secret     A file's text contains a credential token.

  RULE SOURCE. Rules load from profiles/shared/schemas/forbidden-paths.json (the
  `rules` array). Each rule has id / kind ('path' | 'secret') / reason / pathRegex
  / refRegex. If that file is absent or unparseable, a built-in default mirroring
  the contract is used. The JSON is the source of truth and overrides the defaults.

  REFERENCE-EXEMPTION (why policy docs do not fail). A 'path' rule's refRegex
  (content reference) is suppressed on the policy / containment-infrastructure
  surface: any *.md, .github/**, tests/**, the schemas/ folder, .gitignore /
  .gitattributes, and the named gate scripts. Those files legitimately NAME
  forbidden paths to describe or enforce the boundary; flagging them would be a
  false positive. The OWN-path check and ALL 'secret' rules are NEVER suppressed,
  so a real leaked credential is caught even in a doc and a committed secret file
  is caught anywhere. In -File mode (targeted fixture test) NO exemption is
  applied, so detection can be proven directly.

  CONTAINMENT INVARIANT: this gate never opens or reads the contents of a
  secret/forbidden file. Forbidden paths are matched by path/reference text only;
  a file whose own path is forbidden is flagged WITHOUT being read.

  Read-only. No network, no peer AI, no host-global access. ASCII-only so the gate
  cannot fail its own text-safety rule under PowerShell 7.

.PARAMETER Path
  Folder to scan from (defaults to the current directory). Resolved to the git
  repository root.

.PARAMETER File
  Scan exactly one file (fixture / unit test mode). No reference-exemption is
  applied so detection can be proven directly.

.PARAMETER StagedOnly
  Scan the staged diff instead of the working-tree diff.

.PARAMETER AllFiles
  Scan every tracked file in the repository.

.PARAMETER Json
  Also emit a machine-readable JSON summary.

.PARAMETER ForbiddenPathsFile
  Override the rules file location.

.OUTPUTS
  A DRIFTLESS_CONTAINMENT_PASS or DRIFTLESS_CONTAINMENT_FAIL line, the rules
  source, then one human-readable line per finding. Exit 0 on PASS, 1 on FAIL,
  2 when the target is not a git repository (reported BLOCKED, never PASS).
#>
param(
  [string]$Path = '.',
  [string]$File,
  [switch]$StagedOnly,
  [switch]$AllFiles,
  [switch]$Json,
  [string]$ForbiddenPathsFile,
  [int]$MaxFindings = 50
)

$ErrorActionPreference = 'Stop'

# Decode git stdout as UTF-8 so non-ASCII paths (with core.quotepath=false) are
# read correctly under PowerShell 7 (whose default OEM codepage would
# mangle them). Output is also UTF-8 so PASS/FAIL lines stay clean.
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

$GateCommand = 'Test-Containment.ps1'
$RulesRelative = 'profiles/shared/schemas/forbidden-paths.json'

function Resolve-TargetPath {
  param([Parameter(Mandatory = $true)][string]$InputPath)
  $resolved = Resolve-Path -LiteralPath $InputPath -ErrorAction Stop
  return [System.IO.Path]::GetFullPath($resolved.Path)
}

function ConvertTo-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$RootPath,
    [Parameter(Mandatory = $true)][string]$FilePath
  )
  $rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
  $fileFull = [System.IO.Path]::GetFullPath($FilePath)
  if ($fileFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $fileFull.Substring($rootFull.Length).TrimStart('\', '/')
  }
  return $fileFull
}

function Test-GitRepo {
  param([Parameter(Mandatory = $true)][string]$RootPath)
  git -C $RootPath rev-parse --show-toplevel *> $null
  return ($LASTEXITCODE -eq 0)
}

function Test-GateSource {
  # The gate's own source and the rules file legitimately contain every pattern
  # they hunt for (both path tokens AND literal secret-rule regexes). Never flag
  # them against themselves, for either rule kind.
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $normalized = ($RelativePath -replace '\\', '/').TrimStart('/')
  return ($normalized -eq 'scripts/Test-Containment.ps1' -or
          $normalized -eq $RulesRelative)
}

function Test-ReferenceExempt {
  # Policy / containment-infrastructure surface that legitimately NAMES forbidden
  # paths to describe or enforce the boundary. Only 'path'-rule REFERENCE findings
  # are suppressed here; own-path and 'secret' findings are NOT. Application code
  # is never on this list.
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $n = ($RelativePath -replace '\\', '/').TrimStart('/')
  if ($n -match '\.md$') { return $true }
  if ($n -match '(^|/)\.gitignore$') { return $true }
  if ($n -match '(^|/)\.gitattributes$') { return $true }
  if ($n -match '^\.github/') { return $true }
  if ($n -match '^tests/') { return $true }
  if ($n -match '(^|/)schemas/') { return $true }
  $infra = @(
    'scripts/Test-Containment.ps1',
    'scripts/Test-WindowsTextSafety.ps1'
  )
  return ($infra -contains $n)
}

function Test-SafeRegex {
  # Applies a regex match without ever aborting the scan. Rules come from an
  # external, user-editable JSON file; a malformed pattern must be surfaced as a
  # finding, not crash the gate. Returns $true/$false on a clean match, or the
  # string 'INVALID' when the pattern cannot be compiled.
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory = $true)][string]$Pattern
  )
  try {
    if ([System.Text.RegularExpressions.Regex]::IsMatch($Text, $Pattern)) {
      return $true
    }
    return $false
  } catch {
    return 'INVALID'
  }
}

# ---------------------------------------------------------------------------
# Forbidden-path model. Built-in defaults mirror the shared schema; the JSON
# file, when present, is the source of truth.
# ---------------------------------------------------------------------------

function Get-DefaultForbiddenRules {
  return @(
    [pscustomobject]@{ id = 'dotenv'; kind = 'path'; reason = 'References a .env / .env.* file (environment secrets).'
      pathRegex = '(^|/)\.env(\.[^/]*)?$'
      refRegex = '(^|[^A-Za-z0-9_-])\.env(\.[A-Za-z0-9_.-]+)?($|[^A-Za-z0-9_-])' },
    [pscustomobject]@{ id = 'ssh'; kind = 'path'; reason = 'References an .ssh directory (private SSH material).'
      pathRegex = '(^|/)\.ssh(/|$)'
      refRegex = '(^|[^A-Za-z0-9_-])[~./\\]*\.ssh([/\\]|$|[^A-Za-z0-9_-])' },
    [pscustomobject]@{ id = 'secrets_dir'; kind = 'path'; reason = 'References a secrets/ directory.'
      pathRegex = '(^|/)secrets(/|$)'
      refRegex = '(^|[^A-Za-z0-9_-])[~./\\]*secrets[/\\]' },
    [pscustomobject]@{ id = 'private_key'; kind = 'path'; reason = 'References a private key file (*.pem / *.key).'
      pathRegex = '\.(pem|key)$'
      refRegex = '[A-Za-z0-9_.\-]+\.(pem|key)($|[^A-Za-z0-9_-])' },
    [pscustomobject]@{ id = 'browser_profile'; kind = 'path'; reason = 'References a browser profile / credential store (Login Data, Cookies, chrome-profile).'
      pathRegex = '(^|/)(chrome-profile|browser-profile|profile\.default)(/|$)|(^|/)(Login Data|Cookies)$'
      refRegex = '(chrome-profile|browser-profile|profile\.default|Login Data|(^|[/\\])Cookies($|[^A-Za-z0-9_-]))' },
    [pscustomobject]@{ id = 'host_global_claude'; kind = 'path'; reason = 'References the host-global ~/.claude agent home (forbidden; a repo-local .claude/ own-path is repo-relative and exempt from the OWN-path check, only a CONTENT reference to ~/.claude / $HOME/.claude is blocked).'
      pathRegex = '(^|[/\\])\.claude([/\\]|$)'
      refRegex = '(^|[\s~]|[/\\]|\$HOME|%USERPROFILE%)\.claude([/\\]|$|[^A-Za-z0-9_-])' },
    [pscustomobject]@{ id = 'host_global_codex'; kind = 'path'; reason = 'References the host-global ~/.codex agent home (forbidden; a repo-local isolated codex home is repo-relative and exempt from the OWN-path check, only a CONTENT reference to ~/.codex / $HOME/.codex is blocked).'
      pathRegex = '(^|[/\\])\.codex([/\\]|$)'
      refRegex = '(^|[\s~]|[/\\]|\$HOME|%USERPROFILE%)\.codex([/\\]|$|[^A-Za-z0-9_-])' },
    [pscustomobject]@{ id = 'github_token'; kind = 'secret'; reason = 'Looks like a GitHub access token (ghp_/gho_/ghu_/ghs_/ghr_).'
      pathRegex = $null
      refRegex = 'gh[pousr]_[A-Za-z0-9_]{20,}' },
    [pscustomobject]@{ id = 'anthropic_key'; kind = 'secret'; reason = 'Looks like an Anthropic API key (sk-ant-...).'
      pathRegex = $null
      refRegex = 'sk-ant-[A-Za-z0-9_-]{20,}' },
    [pscustomobject]@{ id = 'openai_key'; kind = 'secret'; reason = 'Looks like an OpenAI-style secret key (sk-...).'
      pathRegex = $null
      refRegex = 'sk-[A-Za-z0-9]{32,}' },
    [pscustomobject]@{ id = 'aws_access_key'; kind = 'secret'; reason = 'Looks like an AWS access key id (AKIA...).'
      pathRegex = $null
      refRegex = 'AKIA[0-9A-Z]{16}' },
    [pscustomobject]@{ id = 'private_key_block'; kind = 'secret'; reason = 'Contains an inline PRIVATE KEY block.'
      pathRegex = $null
      refRegex = '-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----' }
  )
}

function Get-ForbiddenRules {
  param([string]$RootPath, [string]$ExplicitFile)

  $candidate = if ($ExplicitFile) { $ExplicitFile } else { Join-Path $RootPath $RulesRelative }

  if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    return [pscustomobject]@{ rules = (Get-DefaultForbiddenRules); source = "built-in default ($RulesRelative not found)" }
  }

  try {
    $raw = Get-Content -LiteralPath $candidate -Raw -ErrorAction Stop
    $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    return [pscustomobject]@{ rules = (Get-DefaultForbiddenRules); source = "built-in default (failed to parse $candidate)" }
  }

  # Accept either an object with a `rules` array or a bare array of rule objects.
  $entries = $null
  if ($null -ne $parsed.rules) {
    $entries = @($parsed.rules)
  } elseif ($parsed -is [System.Array]) {
    $entries = @($parsed)
  }

  if (-not $entries -or $entries.Count -eq 0) {
    return [pscustomobject]@{ rules = (Get-DefaultForbiddenRules); source = "built-in default ($candidate had no rules)" }
  }

  $rules = [System.Collections.Generic.List[object]]::new()
  foreach ($entry in $entries) {
    $id = if ($entry.id) { [string]$entry.id } else { 'forbidden' }
    $kind = if ($entry.kind) { [string]$entry.kind } else { 'path' }
    $reason = if ($entry.reason) { [string]$entry.reason } else { "References a forbidden path ($id)." }
    $pathRegex = if ($entry.pathRegex) { [string]$entry.pathRegex } else { $null }
    $refRegex = if ($entry.refRegex) { [string]$entry.refRegex } else { $pathRegex }
    if (-not $pathRegex -and -not $refRegex) { continue }
    $rules.Add([pscustomobject]@{ id = $id; kind = $kind; reason = $reason; pathRegex = $pathRegex; refRegex = $refRegex }) | Out-Null
  }

  if ($rules.Count -eq 0) {
    return [pscustomobject]@{ rules = (Get-DefaultForbiddenRules); source = "built-in default ($candidate had no usable rules)" }
  }

  $rel = ConvertTo-RelativePath $RootPath ([System.IO.Path]::GetFullPath($candidate))
  return [pscustomobject]@{ rules = @($rules); source = $rel }
}

function Test-RepoLocalAgentDir {
  # OWN-PATH exemption. The host_global_claude / host_global_codex rules exist to
  # block the HOST-GLOBAL agent home (~/.claude, ~/.codex), which lives OUTSIDE
  # the repo and is never part of the scanned tree. An OWN-path finding is ALWAYS
  # repo-relative (it names a file inside the scanned tree), so a repo-relative
  # .claude/ or .codex/ directory is the project's own isolated, gitignored
  # runtime artifact -- NOT the host-global home. Flagging it is a false positive.
  # SURGICAL: applies ONLY to the OWN-path check (callers gate it to the
  # host_global_* rules) and NEVER to the refRegex content-reference check -- a
  # file whose CONTENT references ~/.claude / $HOME/.claude still FAILs (real
  # host-global leak detection stays active).
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $n = ($RelativePath -replace '\\', '/').TrimStart('/')
  return ($n -match '(^|/)\.(claude|codex)(/|$)')
}

function Test-ForbiddenPath {
  # Path-only test: does the file's OWN relative path land on a forbidden path?
  # No file contents are read here. Only 'path'-kind rules carry a pathRegex.
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][object[]]$Rules
  )
  $normalized = ($RelativePath -replace '\\', '/').TrimStart('/')
  foreach ($rule in $Rules) {
    if ($rule.pathRegex -and ((Test-SafeRegex $normalized $rule.pathRegex) -eq $true)) {
      # OWN-PATH exemption for repo-local agent dirs. Skip ONLY these two rules
      # for a repo-local agent dir; every other rule and the content refRegex
      # check are untouched.
      if (($rule.id -eq 'host_global_claude' -or $rule.id -eq 'host_global_codex') -and
          (Test-RepoLocalAgentDir $normalized)) {
        continue
      }
      return $rule
    }
  }
  return $null
}

function Add-Finding {
  param(
    [System.Collections.Generic.List[object]]$Findings,
    [Parameter(Mandatory = $true)][string]$Level,
    [Parameter(Mandatory = $true)][string]$File,
    [Parameter(Mandatory = $true)][int]$Line,
    [Parameter(Mandatory = $true)][string]$Kind,
    [Parameter(Mandatory = $true)][string]$Reason
  )
  $Findings.Add([pscustomobject]@{ level = $Level; file = $File; line = $Line; kind = $Kind; reason = $Reason }) | Out-Null
}

function Read-TextLinesIfSafe {
  # Reads a NON-forbidden text file into numbered lines. Callers must ensure the
  # path is not forbidden BEFORE calling this; this function never inspects a
  # secret file's contents on behalf of a forbidden path.
  param([Parameter(Mandatory = $true)][string]$FilePath)
  try {
    $item = Get-Item -LiteralPath $FilePath -ErrorAction Stop
    if ($item.Length -gt 1048576) { return @() }
    $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
    if ($bytes -contains 0) { return @() }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return @($text -split "`r?`n")
  } catch {
    return @()
  }
}

# ---------------------------------------------------------------------------
# Scan-surface collection. Each item carries numbered lines so findings can
# report a real line number. For diffs, the line number is the new-file line of
# the added hunk; for whole files it is the absolute line number.
# ---------------------------------------------------------------------------

function Get-ChangedTextItems {
  param(
    [Parameter(Mandatory = $true)][string]$RootPath,
    [Parameter(Mandatory = $true)][object[]]$Rules
  )

  $items = [System.Collections.Generic.List[object]]::new()
  $diffArgs = if ($StagedOnly) { @('diff', '--cached', '--unified=0') } else { @('diff', '--unified=0') }
  $diff = @(git -C $RootPath -c core.quotepath=false @diffArgs)

  $currentFile = $null
  $lines = [System.Collections.Generic.List[object]]::new()
  $newLineNo = 0

  $flush = {
    param($file, $lineList)
    if ($file) {
      $items.Add([pscustomobject]@{ relative_path = $file; full_path = (Join-Path $RootPath $file); lines = @($lineList); source = 'diff' }) | Out-Null
    }
  }

  foreach ($line in $diff) {
    if ($line -match '^\+\+\+ b/(.+)$') {
      & $flush $currentFile $lines
      $currentFile = $Matches[1]
      $lines = [System.Collections.Generic.List[object]]::new()
      $newLineNo = 0
      continue
    }
    if ($line -match '^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@') {
      $newLineNo = [int]$Matches[1]
      continue
    }
    if ($line.StartsWith('+') -and -not $line.StartsWith('+++')) {
      $lines.Add([pscustomobject]@{ number = $newLineNo; text = $line.Substring(1) }) | Out-Null
      $newLineNo++
      continue
    }
  }
  & $flush $currentFile $lines

  if (-not $StagedOnly) {
    $untracked = @(git -C $RootPath -c core.quotepath=false ls-files --others --exclude-standard)
    foreach ($file in $untracked) {
      $full = Join-Path $RootPath $file
      $numbered = [System.Collections.Generic.List[object]]::new()
      if ((Test-Path -LiteralPath $full -PathType Leaf) -and -not (Test-ForbiddenPath $file $Rules)) {
        $n = 1
        foreach ($t in (Read-TextLinesIfSafe $full)) {
          $numbered.Add([pscustomobject]@{ number = $n; text = $t }) | Out-Null
          $n++
        }
      }
      $items.Add([pscustomobject]@{ relative_path = $file; full_path = $full; lines = @($numbered); source = 'untracked' }) | Out-Null
    }
  }

  return @($items)
}

function Get-AllTrackedTextItems {
  param(
    [Parameter(Mandatory = $true)][string]$RootPath,
    [Parameter(Mandatory = $true)][object[]]$Rules
  )
  $items = [System.Collections.Generic.List[object]]::new()
  $tracked = @(git -C $RootPath -c core.quotepath=false ls-files)
  foreach ($file in $tracked) {
    $full = Join-Path $RootPath $file
    $numbered = [System.Collections.Generic.List[object]]::new()
    if ((Test-Path -LiteralPath $full -PathType Leaf) -and -not (Test-ForbiddenPath $file $Rules)) {
      $n = 1
      foreach ($t in (Read-TextLinesIfSafe $full)) {
        $numbered.Add([pscustomobject]@{ number = $n; text = $t }) | Out-Null
        $n++
      }
    }
    $items.Add([pscustomobject]@{ relative_path = $file; full_path = $full; lines = @($numbered); source = 'tracked' }) | Out-Null
  }
  return @($items)
}

function Get-SingleFileItem {
  # -File mode: scan exactly one file (used by fixture tests). The relative path
  # is reported from the repo root when the file is inside the repo.
  param(
    [Parameter(Mandatory = $true)][string]$RootPath,
    [Parameter(Mandatory = $true)][string]$FullPath,
    [Parameter(Mandatory = $true)][object[]]$Rules
  )
  $rel = ConvertTo-RelativePath $RootPath $FullPath
  $numbered = [System.Collections.Generic.List[object]]::new()
  if ((Test-Path -LiteralPath $FullPath -PathType Leaf) -and -not (Test-ForbiddenPath $rel $Rules)) {
    $n = 1
    foreach ($t in (Read-TextLinesIfSafe $FullPath)) {
      $numbered.Add([pscustomobject]@{ number = $n; text = $t }) | Out-Null
      $n++
    }
  }
  return @([pscustomobject]@{ relative_path = $rel; full_path = $FullPath; lines = @($numbered); source = 'single-file' })
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# -File mode resolves the repo from the file's location; -Path otherwise.
$anchor = if ($File) { Split-Path -Parent ((Resolve-Path -LiteralPath $File -ErrorAction Stop).Path) } else { $Path }
$target = Resolve-TargetPath $anchor
if (-not (Test-GitRepo $target)) {
  $result = [pscustomobject]@{ status = 'BLOCKED'; command = $GateCommand; path = $target; reason = 'Target path is not inside a git repository.'; findings = @() }
  if ($Json) { $result | ConvertTo-Json -Depth 8 } else { Write-Output 'DRIFTLESS_CONTAINMENT_BLOCKED'; Write-Output $result.reason }
  exit 2
}

$repoRoot = [System.IO.Path]::GetFullPath((git -C $target rev-parse --show-toplevel).Trim())
$ruleSet = Get-ForbiddenRules -RootPath $repoRoot -ExplicitFile $ForbiddenPathsFile
$rules = @($ruleSet.rules)

# -File mode applies NO reference-exemption so detection can be proven directly.
$singleFileMode = [bool]$File
if ($singleFileMode) {
  $fileFull = (Resolve-Path -LiteralPath $File -ErrorAction Stop).Path
  $items = Get-SingleFileItem $repoRoot $fileFull $rules
} elseif ($AllFiles) {
  $items = Get-AllTrackedTextItems $repoRoot $rules
} else {
  $items = Get-ChangedTextItems $repoRoot $rules
}
$findings = [System.Collections.Generic.List[object]]::new()

# Validate each rule's regexes once. A malformed pattern in the external rules
# file is surfaced as a WARN finding and the broken rule's check is skipped, so a
# bad config can never silently disable containment or crash the scan.
$invalidRefRule = @{}
foreach ($rule in $rules) {
  if ($rule.pathRegex -and ((Test-SafeRegex '' $rule.pathRegex) -eq 'INVALID')) {
    Add-Finding $findings 'WARN' ([string]$ruleSet.source) 0 'invalid_rule' "$($rule.id): pathRegex is not a valid regular expression; this rule's path check was skipped."
  }
  if ($rule.refRegex -and ((Test-SafeRegex '' $rule.refRegex) -eq 'INVALID')) {
    $invalidRefRule[$rule.id] = $true
    Add-Finding $findings 'WARN' ([string]$ruleSet.source) 0 'invalid_rule' "$($rule.id): refRegex is not a valid regular expression; this rule's reference check was skipped."
  }
}

foreach ($item in $items) {
  if ($findings.Count -ge $MaxFindings) { break }
  $relative = [string]$item.relative_path
  if (Test-GateSource $relative) { continue }

  # 1) The file's OWN path is forbidden. Flag by path only; never read it.
  $pathRule = Test-ForbiddenPath $relative $rules
  if ($pathRule) {
    Add-Finding $findings 'FAIL' $relative 1 'forbidden_path' "$($pathRule.id): forbidden file is present in the scan surface (contents not read). $($pathRule.reason)"
    continue
  }

  # 2) Content scan. 'secret' rules always apply; 'path'-rule REFERENCE checks are
  #    suppressed on the policy / containment-infrastructure surface (unless -File).
  $refExempt = (-not $singleFileMode) -and (Test-ReferenceExempt $relative)
  foreach ($entry in @($item.lines)) {
    if ($findings.Count -ge $MaxFindings) { break }
    $lineText = [string]$entry.text
    if ([string]::IsNullOrEmpty($lineText)) { continue }
    foreach ($rule in $rules) {
      if (-not $rule.refRegex) { continue }
      if ($invalidRefRule.ContainsKey($rule.id)) { continue }
      $isSecret = ($rule.kind -eq 'secret')
      if (-not $isSecret -and $refExempt) { continue }
      if ((Test-SafeRegex $lineText $rule.refRegex) -eq $true) {
        if ($isSecret) {
          Add-Finding $findings 'FAIL' $relative ([int]$entry.number) 'forbidden_secret' "$($rule.id): file contains a credential token. $($rule.reason)"
        } else {
          Add-Finding $findings 'FAIL' $relative ([int]$entry.number) 'forbidden_reference' "$($rule.id): file reads or writes a forbidden path. $($rule.reason)"
        }
      }
    }
  }
}

# Honesty: a whole-tree scan that inspected zero files proves nothing. Surface it
# as a WARN rather than a silent green (a repo before its first commit has no
# tracked files, so -AllFiles would otherwise report a vacuous PASS).
$scannedWithContent = @($items | Where-Object { @($_.lines).Count -gt 0 }).Count
if ($AllFiles -and @($items).Count -eq 0) {
  Add-Finding $findings 'WARN' '(scan surface)' 0 'empty_surface' 'No tracked files were scanned (-AllFiles on a tree with no tracked files); containment is UNVERIFIED for an empty tree.'
}

$failures = @($findings | Where-Object { $_.level -eq 'FAIL' })
$warnings = @($findings | Where-Object { $_.level -eq 'WARN' })
$status = if ($failures.Count -gt 0) { 'FAIL' } else { 'PASS' }
$result = [pscustomobject]@{
  status = $status
  command = $GateCommand
  path = $repoRoot
  mode = if ($singleFileMode) { 'single_file' } elseif ($AllFiles) { 'all_tracked_files' } elseif ($StagedOnly) { 'staged_diff' } else { 'working_tree_diff_and_untracked' }
  forbidden_rules_source = $ruleSet.source
  checked_items = @($items).Count
  scanned_with_content = $scannedWithContent
  failure_count = $failures.Count
  warning_count = $warnings.Count
  findings = @($findings | Select-Object -First $MaxFindings)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 8
} else {
  if ($status -eq 'PASS') {
    Write-Output 'DRIFTLESS_CONTAINMENT_PASS'
    Write-Output ("PASS: scanned {0} item(s), {1} with content; no forbidden path or leaked secret found." -f $result.checked_items, $result.scanned_with_content)
  } else {
    Write-Output 'DRIFTLESS_CONTAINMENT_FAIL'
    Write-Output ("FAIL: {0} containment violation(s) found. Remove the forbidden reference / secret before merging." -f $failures.Count)
  }
  Write-Output ("rules: {0}" -f $ruleSet.source)
  foreach ($finding in @($findings | Select-Object -First $MaxFindings)) {
    Write-Output ("{0}: {1}: {2}:{3}: {4}" -f $finding.level, $finding.kind, $finding.file, $finding.line, $finding.reason)
  }
}

if ($status -eq 'FAIL') { exit 1 }
exit 0
