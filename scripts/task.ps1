#Requires -Version 7.2
<#
.SYNOPSIS
  Default repo task entrypoint for PowerShell 7+.

.DESCRIPTION
  Keeps normal agent and manager commands on pwsh. Legacy shell execution is
  reserved for explicit compatibility tasks.
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('doctor', 'install-tools', 'lint', 'test', 'build', 'legacy-doctor', 'help')]
  [string]$Task = 'help'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Write-Section {
  param([Parameter(Mandatory = $true)][string]$Title)
  Write-Output ''
  Write-Output ("== {0} ==" -f $Title)
}

function Test-CommandExists {
  param([Parameter(Mandatory = $true)][string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-CommandSourceOrEmpty {
  param([Parameter(Mandatory = $true)][string]$Name)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
  return ''
}

function Assert-PowerShellCore {
  if ($PSVersionTable.PSEdition -ne 'Core') {
    throw ("Wrong PowerShell edition: expected Core/pwsh 7+, got {0} {1}. Run: pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 <task>" -f $PSVersionTable.PSEdition, $PSVersionTable.PSVersion)
  }
}

function Get-CurrentPowerShellPath {
  try {
    if ([System.Environment]::ProcessPath) { return [System.Environment]::ProcessPath }
  } catch { }
  try {
    return [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
  } catch { }
  return ''
}

function Invoke-Doctor {
  Write-Section 'PowerShell Shell Contract doctor'
  Write-Output ("os={0}" -f [System.Runtime.InteropServices.RuntimeInformation]::OSDescription)
  Write-Output ("current_exe={0}" -f (Get-CurrentPowerShellPath))
  Write-Output ("ps_edition={0}" -f $PSVersionTable.PSEdition)
  Write-Output ("ps_version={0}" -f $PSVersionTable.PSVersion)
  Write-Output ("pwsh_exists={0}" -f (Test-CommandExists 'pwsh.exe'))
  Write-Output ("pwsh_path={0}" -f (Get-CommandSourceOrEmpty 'pwsh.exe'))
  $legacyExe = 'power' + 'shell.exe'
  Write-Output ("legacy_shell_exists={0}" -f (Test-CommandExists $legacyExe))
  Write-Output ("legacy_shell_path={0}" -f (Get-CommandSourceOrEmpty $legacyExe))
  Write-Output ("repo_root={0}" -f $script:RepoRoot)
}

function Install-ModuleIfMissing {
  param([Parameter(Mandatory = $true)][string]$Name)
  if (Get-Module -ListAvailable -Name $Name) {
    Write-Output ("present={0}" -f $Name)
    return
  }

  Write-Output ("missing={0}; installing CurrentUser if gallery access is available" -f $Name)
  try {
    if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
      Install-PSResource -Name $Name -Scope CurrentUser -TrustRepository -ErrorAction Stop
    } elseif (Get-Command Install-Module -ErrorAction SilentlyContinue) {
      Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    } else {
      Write-Output ("manual_install={0}; no Install-PSResource or Install-Module command found" -f $Name)
      return
    }
    Write-Output ("installed={0}" -f $Name)
  } catch {
    Write-Output ("manual_install={0}; reason={1}" -f $Name, $_.Exception.Message)
  }
}

function Invoke-InstallTools {
  Write-Section 'Install or verify minimal PowerShell tools'
  Install-ModuleIfMissing 'PSScriptAnalyzer'
  Install-ModuleIfMissing 'Pester'
}

function Invoke-Lint {
  Write-Section 'Repo shell-contract lint'
  $contractScript = Join-Path $script:RepoRoot 'scripts\Test-PowerShellShellContract.ps1'
  $global:LASTEXITCODE = 0
  & $contractScript -Root $script:RepoRoot
  if ($LASTEXITCODE -ne 0) { throw ("Shell contract gate failed: exit={0}" -f $LASTEXITCODE) }

  if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Output 'PSScriptAnalyzer not installed; skipping analyzer lint. Run task install-tools to install it for CurrentUser.'
    return
  }

  Import-Module PSScriptAnalyzer -ErrorAction Stop
  $settings = Join-Path $script:RepoRoot 'PSScriptAnalyzerSettings.psd1'
  $targets = @(
    (Join-Path $script:RepoRoot 'scripts\task.ps1'),
    (Join-Path $script:RepoRoot 'scripts\Test-PowerShellShellContract.ps1'),
    (Join-Path $script:RepoRoot 'scripts\winps51\Invoke-LegacyTask.ps1')
  )
  $findings = foreach ($target in $targets) {
    if (Test-Path -LiteralPath $target) {
      Invoke-ScriptAnalyzer -Path $target -Settings $settings -ErrorAction Stop
    }
  }
  $findings = @($findings)
  if ($findings.Count -gt 0) {
    $findings | Format-Table -AutoSize | Out-String | Write-Output
    throw ("PSScriptAnalyzer findings={0}" -f $findings.Count)
  }
  Write-Output 'PSScriptAnalyzer findings=0'
}

function Invoke-Test {
  Write-Section 'Repo shell-contract tests'
  $contractScript = Join-Path $script:RepoRoot 'scripts\Test-PowerShellShellContract.ps1'
  $global:LASTEXITCODE = 0
  & $contractScript -Root $script:RepoRoot
  if ($LASTEXITCODE -ne 0) { throw ("Shell contract gate failed: exit={0}" -f $LASTEXITCODE) }

  $noActions = Join-Path $script:RepoRoot 'scripts\Test-NoGitHubActionsWorkflows.ps1'
  $global:LASTEXITCODE = 0
  & $noActions -Root $script:RepoRoot
  if ($LASTEXITCODE -ne 0) { throw ("GitHub Actions workflow gate failed: exit={0}" -f $LASTEXITCODE) }

  $textSafety = Join-Path $script:RepoRoot 'scripts\Test-WindowsTextSafety.ps1'
  if (Test-Path -LiteralPath $textSafety) {
    $global:LASTEXITCODE = 0
    & $textSafety -Root $script:RepoRoot
    if ($LASTEXITCODE -ne 0) { throw ("Windows text-safety gate failed: exit={0}" -f $LASTEXITCODE) }
  }
}

function Invoke-Build {
  Write-Section 'Build'
  Write-Output 'No repo-wide build task is defined here yet. Use task test for the shell contract and existing PR gate for full validation.'
}

function Invoke-LegacyDoctor {
  Write-Section 'Legacy shell doctor'
  $legacy = Join-Path $script:RepoRoot 'scripts\winps51\Invoke-LegacyTask.ps1'
  if (-not (Test-Path -LiteralPath $legacy)) {
    throw ("Missing legacy entrypoint: {0}" -f $legacy)
  }
  $legacyExe = 'power' + 'shell.exe'
  $ps51 = Get-Command $legacyExe -ErrorAction SilentlyContinue
  if (-not $ps51) {
    Write-Output 'legacy shell not found; legacy-doctor skipped on this host.'
    return
  }
  & $ps51.Source -NoLogo -NoProfile -ExecutionPolicy Bypass -File $legacy -Task Doctor
}

function Show-Help {
  Write-Output 'PowerShell Shell Contract default command:'
  Write-Output '  pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 <task>'
  Write-Output ''
  Write-Output 'Tasks:'
  Write-Output '  doctor         Show shell, OS, and repo-root evidence.'
  Write-Output '  install-tools  Install/verify PSScriptAnalyzer and Pester in CurrentUser scope.'
  Write-Output '  lint           Run shell-contract lint and optional PSScriptAnalyzer checks.'
  Write-Output '  test           Run shell-contract tests and Windows text-safety gate.'
  Write-Output '  build          Placeholder unless a repo-wide build is added.'
  Write-Output '  legacy-doctor  Smoke-test the documented legacy shell path.'
  Write-Output '  help           Show this help.'
}

Assert-PowerShellCore

switch ($Task) {
  'doctor' { Invoke-Doctor }
  'install-tools' { Invoke-InstallTools }
  'lint' { Invoke-Lint }
  'test' { Invoke-Test }
  'build' { Invoke-Build }
  'legacy-doctor' { Invoke-LegacyDoctor }
  'help' { Show-Help }
}
