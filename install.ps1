#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Driftless installer (Windows PowerShell). Sets up an isolated home for Claude,
  Codex, or both -- a config folder that lives INSIDE this repository, so the
  agent never touches your machine's global Claude or Codex settings.

.DESCRIPTION
  You cloned or downloaded Driftless. Run this once. It materializes a repo-local
  isolated home under .runtime from the matching profile and reports which CLIs
  are installed.

  It does NOT install Claude, Codex, any MCP server, any plugin, or any
  dependency without asking you first -- and every one of those prompts defaults
  to NO. It never writes outside this repository, and it never reads or mutates
  the host-global config home.

  Idempotent: re-running re-uses the existing isolated home and only fills in
  what is missing. ASCII-only and written without a BOM so it parses identically
  on PowerShell 7.

.PARAMETER Tool
  Which profile(s) to set up: 'claude', 'codex', or 'both'. Omit for an
  interactive prompt (default 'both' when noninteractive).

.PARAMETER DryRun
  Print the plan and change nothing.

.PARAMETER Yes
  Accept the default tool choice ('both') without prompting.

.EXAMPLE
  pwsh.exe -ExecutionPolicy Bypass -File install.ps1

.EXAMPLE
  pwsh.exe -ExecutionPolicy Bypass -File install.ps1 -Tool both -DryRun
#>
[CmdletBinding()]
param(
  [ValidateSet('claude', 'codex', 'both')]
  [string]$Tool,
  [switch]$DryRun,
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve the repo root from THIS script's own location, never the working dir.
# That keeps the isolated home under this repo no matter where it is run from.
# ---------------------------------------------------------------------------
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$repoRoot = $scriptDir
try {
  $top = (& git -C $scriptDir rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -eq 0 -and $top) {
    $repoRoot = (Resolve-Path -LiteralPath ($top.Trim())).Path
  }
} catch { }

$runtimeDir = Join-Path $repoRoot '.runtime'
$profilesDir = Join-Path $repoRoot 'profiles'

$interactive = (-not $DryRun) -and (-not [System.Console]::IsInputRedirected)

# ---------------------------------------------------------------------------
# Output helpers (plain language, no jargon).
# ---------------------------------------------------------------------------
function Say  { param([string]$Text) Write-Host $Text }
function Step { param([string]$Text) Write-Host ("  " + $Text) }
function Rule { Write-Host '--------------------------------------------------------' }

# Ask-yes-no with DEFAULT NO. In dry-run or noninteractive mode the answer is the
# default (no), stated out loud, so nothing is installed behind your back.
function Confirm-YesNo {
  param([string]$Prompt)
  if ($DryRun) {
    Step ("[dry-run] would ask: " + $Prompt + " -> defaulting to NO")
    return $false
  }
  if (-not $interactive) {
    Step ("(no interactive terminal) -> defaulting to NO: " + $Prompt)
    return $false
  }
  $ans = Read-Host ("  " + $Prompt + " [y/N]")
  return ($ans -match '^(y|yes)$')
}

# ---------------------------------------------------------------------------
# Tool selection (interactive when not given on the command line).
# ---------------------------------------------------------------------------
function Select-Tool {
  if ($Tool) { return $Tool }
  if ($Yes -or -not $interactive) { return 'both' }
  Say 'Which agent do you want to set up an isolated home for?'
  Step '1) Claude'
  Step '2) Codex'
  Step '3) Both  (default)'
  $c = Read-Host '  Choose 1, 2, or 3 [3]'
  switch ($c) {
    '1' { return 'claude' }
    '2' { return 'codex' }
    default { return 'both' }
  }
}

# Report CLI presence (we never install the CLI itself).
function Get-CliState {
  param([string]$Name)
  if (Get-Command $Name -ErrorAction SilentlyContinue) { return 'installed' }
  return 'not installed'
}

# ---------------------------------------------------------------------------
# Materialize one isolated home under .runtime from the matching profile.
# The isolated home is a COPY of the profile tree (plus the shared tier) placed
# under .runtime, which is gitignored. It is created only inside this repo; the
# host-global config home is never read or written.
# ---------------------------------------------------------------------------
function Install-IsolatedHome {
  param(
    [string]$Name,
    [string]$Profile,
    [string]$HomeDir,
    [string]$EnvVar
  )

  $src = Join-Path $profilesDir $Profile
  $shared = Join-Path $profilesDir 'shared'

  if (-not (Test-Path -LiteralPath $src -PathType Container)) {
    Step ($Name + " profile folder is missing (" + $src + "); skipping.")
    return
  }

  if (Test-Path -LiteralPath $HomeDir -PathType Container) {
    Step ($Name + " isolated home already exists -- re-using it (idempotent): " + $HomeDir)
  } else {
    Step ($Name + " isolated home will be created at: " + $HomeDir)
  }

  if ($DryRun) {
    Step ("[dry-run] would create " + $HomeDir)
    Step ("[dry-run] would copy the " + $Name + " profile into the isolated home")
    if (Test-Path -LiteralPath $shared -PathType Container) {
      Step "[dry-run] would copy the shared tier (contract + safety schemas + shared skills) into the isolated home"
    }
  } else {
    if (-not (Test-Path -LiteralPath $HomeDir)) {
      New-Item -ItemType Directory -Path $HomeDir -Force | Out-Null
    }
    # Copy is idempotent: existing files are refreshed; nothing outside .runtime
    # is touched.
    Copy-Item -Path (Join-Path $src '*') -Destination $HomeDir -Recurse -Force
    if (Test-Path -LiteralPath $shared -PathType Container) {
      $sharedDest = Join-Path $HomeDir 'shared'
      if (-not (Test-Path -LiteralPath $sharedDest)) {
        New-Item -ItemType Directory -Path $sharedDest -Force | Out-Null
      }
      Copy-Item -Path (Join-Path $shared '*') -Destination $sharedDest -Recurse -Force
    }
  }

  Step ($Name + " isolation: starting the agent with " + $EnvVar + " set to this repo-local home (the command printed at the end) keeps the host-global config untouched.")
}

# ---------------------------------------------------------------------------
# Ask-before-install: optional extras (MCP servers, plugins, dependencies).
# DEFAULT IS NO for every one of these. We print the prompt and only act on an
# explicit yes. This is the load-bearing promise of the installer.
# ---------------------------------------------------------------------------
function Show-OptionalExtras {
  Rule
  Say 'Optional extras (all default to NO):'
  Step 'Driftless runs without any of these. They are offered, never assumed.'
  Say ''

  if (Confirm-YesNo 'Install optional MCP server(s) for richer tool access?') {
    Step 'You said yes. Driftless does not bundle an MCP server installer in this'
    Step 'minimal kit, so nothing was installed. Add the server yourself only if'
    Step 'you trust it; the agent reads MCP definitions from the repo-local home.'
  } else {
    Step 'Skipped MCP servers. (You can add one later by hand.)'
  }

  if (Confirm-YesNo 'Install optional plugins into the isolated home?') {
    Step 'You said yes. No plugin is bundled in this minimal kit, so nothing was'
    Step 'installed. Drop a vetted plugin into the profile and re-run to pick it up.'
  } else {
    Step 'Skipped plugins.'
  }

  if (Confirm-YesNo 'Install optional dependencies (extra command-line tools)?') {
    Step 'You said yes. This kit installs no system packages for you; install any'
    Step 'tool you want through your own package manager.'
  } else {
    Step 'Skipped dependencies. The two safety gates need only PowerShell or a'
    Step 'POSIX shell, both of which you already have.'
  }
}

# ---------------------------------------------------------------------------
# Main flow.
# ---------------------------------------------------------------------------
Rule
Say 'Driftless installer'
Rule
Step ("Repo:     " + $repoRoot)
Step ("Profiles: " + $profilesDir)
Step ("Isolated homes go under: " + $runtimeDir + "  (gitignored; never committed)")
if ($DryRun) {
  Step 'Mode:     DRY RUN -- nothing will be created or changed.'
}
Say ''

$chosen = Select-Tool
Say ("Setting up: " + $chosen)
Say ''

Step ("Claude CLI: " + (Get-CliState 'claude'))
Step ("Codex CLI : " + (Get-CliState 'codex'))
Say ''

switch ($chosen) {
  'claude' {
    Install-IsolatedHome -Name 'Claude' -Profile 'claude' -HomeDir (Join-Path $runtimeDir 'claude-home') -EnvVar 'CLAUDE_CONFIG_DIR'
  }
  'codex' {
    Install-IsolatedHome -Name 'Codex' -Profile 'codex' -HomeDir (Join-Path $runtimeDir 'codex-home') -EnvVar 'CODEX_HOME'
  }
  'both' {
    Install-IsolatedHome -Name 'Claude' -Profile 'claude' -HomeDir (Join-Path $runtimeDir 'claude-home') -EnvVar 'CLAUDE_CONFIG_DIR'
    Say ''
    Install-IsolatedHome -Name 'Codex' -Profile 'codex' -HomeDir (Join-Path $runtimeDir 'codex-home') -EnvVar 'CODEX_HOME'
  }
}

Show-OptionalExtras

Rule
if ($DryRun) {
  Say 'Dry run complete. No files were created or changed.'
  Step 'Re-run without -DryRun to apply this plan.'
} else {
  Say 'Setup complete.'
  Step 'Your isolated home(s) live under .runtime and are contained to this repo.'
  Step 'The host-global Claude/Codex config was never read or changed.'
  Say 'To start now, run from this folder (the env var points the agent at the isolated home):'
  if ($chosen -eq 'claude' -or $chosen -eq 'both') {
    Step 'Claude:  $env:CLAUDE_CONFIG_DIR="$PWD\.runtime\claude-home"; claude'
  }
  if ($chosen -eq 'codex' -or $chosen -eq 'both') {
    Step 'Codex:   $env:CODEX_HOME="$PWD\.runtime\codex-home"; codex'
  }
  Step 'Details + the macOS/Linux form: docs/en/apply-to-your-agent.md (Step 3).'
}
Rule
