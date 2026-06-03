<#
.SYNOPSIS
  Driftless agent-runtime health gate. Catches broken Codex recovery lanes before
  an agent keeps debugging a product from inside a broken agent runtime.

.DESCRIPTION
  Read-only, dependency-free, and intentionally small. It checks the repo-local
  Codex home only:

    1. Windows sandbox must not be set to elevated.
    2. .sandbox/setup_error.json must not exist.
    3. The tail of logs_2.sqlite must not contain common Codex self-error markers
       such as ResponsesApiRequest mismatch or HTTP/status 400.

  If this FAILs, the agent should stop resuming that session and start from a
  fresh or repaired isolated runtime. Do not ask a non-developer user to inspect
  these files.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CodexHome,
  [int]$RecentLogBytes = 5242880,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
if (-not $CodexHome) {
  if ($env:CODEX_HOME -and $env:CODEX_HOME.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    $CodexHome = $env:CODEX_HOME
  } else {
    $CodexHome = Join-Path $resolvedRoot '.runtime\codex-home'
  }
}

$findings = [System.Collections.Generic.List[object]]::new()
$notes = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
  param([string]$Kind, [string]$Path, [string]$Message)
  $script:findings.Add([pscustomobject]@{ kind = $Kind; path = $Path; message = $Message }) | Out-Null
}

function Add-Note {
  param([string]$Kind, [string]$Path, [string]$Message)
  $script:notes.Add([pscustomobject]@{ kind = $Kind; path = $Path; message = $Message }) | Out-Null
}

function Get-WindowsSandboxMode {
  param([string]$ConfigPath)
  if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $null }
  $inWindows = $false
  foreach ($line in Get-Content -LiteralPath $ConfigPath) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^\[(.+)\]$') {
      $inWindows = ($trimmed -eq '[windows]')
      continue
    }
    if ($inWindows -and $trimmed -match '^sandbox\s*=\s*"([^"]+)"') {
      return $matches[1]
    }
  }
  return $null
}

function Read-FileTailText {
  param([string]$Path, [int]$MaxBytes)
  $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
  try {
    $length = [int64]$stream.Length
    $count = [Math]::Min([int64][Math]::Max($MaxBytes, 1024), $length)
    $buffer = New-Object byte[] ([int]$count)
    [void]$stream.Seek(-$count, [System.IO.SeekOrigin]::End)
    [void]$stream.Read($buffer, 0, [int]$count)
    return [System.Text.Encoding]::UTF8.GetString($buffer)
  } finally {
    $stream.Dispose()
  }
}

if (-not (Test-Path -LiteralPath $CodexHome -PathType Container)) {
  Add-Note 'codex_home_missing' $CodexHome 'No repo-local Codex home exists yet. Runtime health is not applicable until Codex is installed for this repo.'
} else {
  $configPath = Join-Path $CodexHome 'config.toml'
  $mode = Get-WindowsSandboxMode -ConfigPath $configPath
  if ($mode -eq 'elevated') {
    Add-Finding 'codex_windows_sandbox_elevated' $configPath 'Codex Windows sandbox is set to elevated. This can trap Windows users in a setup/update loop.'
  } elseif ($mode -eq 'unelevated') {
    Add-Note 'codex_windows_sandbox_unelevated' $configPath 'Codex Windows sandbox is already unelevated.'
  }

  $setupError = Join-Path $CodexHome '.sandbox\setup_error.json'
  if (Test-Path -LiteralPath $setupError -PathType Leaf) {
    Add-Finding 'codex_windows_sandbox_setup_error' $setupError 'Codex sandbox setup_error.json exists. Repair or recreate the isolated runtime before continuing.'
  }

  $logDb = Join-Path $CodexHome 'logs_2.sqlite'
  if (Test-Path -LiteralPath $logDb -PathType Leaf) {
    $tail = Read-FileTailText -Path $logDb -MaxBytes $RecentLogBytes
    $patterns = @(
      "properties didn't match ResponsesApiRequest",
      'HTTP 400',
      'status 400',
      'Bad Request',
      'response.failed',
      'invalid_request'
    )
    foreach ($pattern in $patterns) {
      if ($tail.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        Add-Finding 'codex_runtime_self_error_marker' $logDb ("Codex log tail contains self-error marker: " + $pattern)
      }
    }
  }
}

$status = if ($findings.Count -gt 0) { 'FAIL' } else { 'PASS' }
$result = [pscustomobject]@{
  status = $status
  root = $resolvedRoot
  codex_home = $CodexHome
  finding_count = $findings.Count
  findings = $findings
  notes = $notes
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
} elseif ($status -eq 'PASS') {
  Write-Output 'DRIFTLESS_AGENT_RUNTIME_HEALTH_PASS'
  Write-Output 'PASS: no broken Codex runtime markers found.'
  foreach ($note in $notes) { Write-Output ("NOTE: {0}: {1}" -f $note.kind, $note.message) }
} else {
  Write-Output 'DRIFTLESS_AGENT_RUNTIME_HEALTH_FAIL'
  Write-Output 'FAIL: this agent runtime is not a safe recovery lane. Restart, repair, or recreate the isolated runtime before continuing.'
  foreach ($finding in $findings) { Write-Output ("FAIL: {0}: {1}" -f $finding.kind, $finding.message) }
}

if ($status -eq 'FAIL') { exit 1 }
exit 0
