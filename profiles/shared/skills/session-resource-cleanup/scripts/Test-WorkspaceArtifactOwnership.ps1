#requires -Version 7.2
#requires -PSEdition Core
[CmdletBinding()]
param(
  [string]$WorkspaceRoot,
  [switch]$FailOnUnmanaged,
  [switch]$SelfTest,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$protected = [regex]::new('(?i)^(key|secrets?|auth|credentials?|cookies?|sessions?|private|agent-home)$')
$unmanaged = [regex]::new('(?i)^(cc-pr-ci|pytest(?:[-_].*)?|tmp|temp|scratch|.*-finish|.*[-_. ](?:tmp|temp|artifacts?|handoff|scratch)(?:[-_. ].*|$))$')

function Invoke-Audit([string]$Root) {
  $resolved = (Resolve-Path -LiteralPath $Root).Path
  $rows = [System.Collections.Generic.List[object]]::new()
  foreach ($entry in [System.IO.Directory]::EnumerateFileSystemEntries($resolved)) {
    $name = [System.IO.Path]::GetFileName($entry)
    if ($protected.IsMatch($name)) {
      $rows.Add([pscustomobject]@{ path=$entry; kind='protected'; enumerated=$false; action='never auto-clean' }) | Out-Null
      continue
    }
    if ($unmanaged.IsMatch($name)) {
      $rows.Add([pscustomobject]@{ path=$entry; kind='unmanaged'; enumerated=$false; action='owner review and exact cleanup' }) | Out-Null
    }
  }
  $unmanagedCount = @($rows | Where-Object { $_.kind -eq 'unmanaged' }).Count
  [pscustomobject]@{
    status = $(if ($unmanagedCount -eq 0) { 'PASS' } else { 'UNMANAGED_FOUND' })
    root = $resolved
    unmanaged = $unmanagedCount
    protected = @($rows | Where-Object { $_.kind -eq 'protected' }).Count
    findings = @($rows)
  }
}

if ($SelfTest) {
  $fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('driftless-workspace-ownership-' + [guid]::NewGuid().ToString('N'))
  try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'pytest-run'), (Join-Path $fixture 'issue-12-finish'), (Join-Path $fixture 'template-project'), (Join-Path $fixture 'key') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture 'key\must-not-be-read.txt') -Value 'protected' -Encoding ASCII
    $result = Invoke-Audit -Root $fixture
    if ($result.unmanaged -ne 2 -or $result.protected -ne 1) { throw 'fixture classification failed or normal template name was misclassified' }
    if (@($result.findings | Where-Object { $_.kind -eq 'protected' -and -not $_.enumerated }).Count -ne 1) { throw 'protected root was not short-circuited' }
    Write-Output 'PASS: workspace artifact ownership self-test'
    exit 0
  } finally {
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { throw 'WorkspaceRoot is required unless -SelfTest is used.' }
$report = Invoke-Audit -Root $WorkspaceRoot
if ($Json) { $report | ConvertTo-Json -Depth 6 } else { Write-Output ("RESULT: {0} unmanaged={1} protected={2}" -f $report.status, $report.unmanaged, $report.protected) }
if ($FailOnUnmanaged -and $report.unmanaged -gt 0) { exit 2 }
exit 0
