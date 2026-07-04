#requires -Version 7.0
#requires -PSEdition Core
param(
  [int]$StaleMinutes = 10,
  [switch]$Apply,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Test-AutomationBrowserProcess {
  param([object]$Process)
  if ($Process.Name -notmatch '^(chrome|msedge|whale)\.exe$') { return $false }
  $cmd = [string]$Process.CommandLine
  if (-not $cmd) { return $false }
  return ($cmd -match 'codex-(chromium|whale)|puppeteer_dev_chrome_profile|ms-playwright|remote-debugging-port')
}

function Get-AutomationProfileHint {
  param([string]$CommandLine)
  if ($CommandLine -match 'Temp\\([^ "\\]+)') { return $Matches[1] }
  if ($CommandLine -match '--user-data-dir="?([^" ]+)') { return $Matches[1] }
  return ''
}

$all = @(Get-CimInstance Win32_Process)
$automation = @($all | Where-Object { Test-AutomationBrowserProcess -Process $_ })
$automationIds = @{}
foreach ($p in $automation) { $automationIds[[int]$p.ProcessId] = $true }

$roots = @($automation | Where-Object { -not $automationIds.ContainsKey([int]$_.ParentProcessId) })
$staleCutoff = (Get-Date).AddMinutes(-1 * [Math]::Max(1, $StaleMinutes))

$targetRootIds = @{}
$rootRows = foreach ($root in $roots) {
  $gp = Get-Process -Id $root.ProcessId -ErrorAction SilentlyContinue
  $parentAlive = @($all | Where-Object { $_.ProcessId -eq $root.ParentProcessId }).Count -gt 0
  $ageMinutes = if ($gp) { [Math]::Round(((Get-Date) - $gp.StartTime).TotalMinutes, 1) } else { $null }
  $isStale = $false
  if (-not $parentAlive) { $isStale = $true }
  if ($gp -and $gp.StartTime -lt $staleCutoff) { $isStale = $true }
  if ($isStale) { $targetRootIds[[int]$root.ProcessId] = $true }
  [pscustomobject]@{
    Name = $root.Name
    ProcessId = [int]$root.ProcessId
    ParentProcessId = [int]$root.ParentProcessId
    ParentAlive = $parentAlive
    AgeMinutes = $ageMinutes
    Profile = Get-AutomationProfileHint -CommandLine ([string]$root.CommandLine)
    Eligible = $isStale
  }
}

$targetIds = @{}
foreach ($id in $targetRootIds.Keys) { $targetIds[[int]$id] = $true }

$changed = $true
while ($changed) {
  $changed = $false
  foreach ($p in $automation) {
    if ($targetIds.ContainsKey([int]$p.ParentProcessId) -and -not $targetIds.ContainsKey([int]$p.ProcessId)) {
      $targetIds[[int]$p.ProcessId] = $true
      $changed = $true
    }
  }
}

$stopped = 0
if ($Apply) {
  foreach ($id in ($targetIds.Keys | Sort-Object -Descending)) {
    $p = Get-Process -Id $id -ErrorAction SilentlyContinue
    if ($p) {
      Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
      $stopped++
    }
  }
}

$remaining = @(
  Get-CimInstance Win32_Process |
    Where-Object { Test-AutomationBrowserProcess -Process $_ }
)

$result = [pscustomobject]@{
  Apply = [bool]$Apply
  StaleMinutes = $StaleMinutes
  AutomationBrowserProcessesObserved = $automation.Count
  AutomationBrowserRootsObserved = $roots.Count
  EligibleRoots = @($rootRows | Where-Object { $_.Eligible }).Count
  EligibleProcessTreeCount = $targetIds.Count
  StoppedProcessCount = $stopped
  RemainingAutomationBrowserProcesses = $remaining.Count
  Roots = @($rootRows)
}

if ($Json) {
  $result | ConvertTo-Json -Depth 6
} else {
  $result | Format-List Apply,StaleMinutes,AutomationBrowserProcessesObserved,AutomationBrowserRootsObserved,EligibleRoots,EligibleProcessTreeCount,StoppedProcessCount,RemainingAutomationBrowserProcesses
  if ($rootRows.Count -gt 0) {
    $rootRows |
      Sort-Object @{ Expression = 'Eligible'; Descending = $true }, @{ Expression = 'AgeMinutes'; Descending = $true } |
      Format-Table -AutoSize
  }
}
