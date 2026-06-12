<#
.SYNOPSIS
  Lightweight gate for the repo PowerShell Shell Contract.

.DESCRIPTION
  Read-only static checks. Runs under Windows PowerShell 5.1 and pwsh 7.
#>
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Add-Result {
  param(
    [System.Collections.Generic.List[object]]$Results,
    [string]$Check,
    [string]$Status,
    [bool]$Blocking,
    [string]$Evidence,
    [string]$NextAction
  )
  $Results.Add([pscustomobject]@{
    check = $Check
    status = $Status
    blocking = $Blocking
    evidence = $Evidence
    next_action = $NextAction
  }) | Out-Null
}

function Get-FileText {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Test-Contains {
  param([string]$Text, [string]$Pattern)
  if ($null -eq $Text) { return $false }
  return [regex]::IsMatch($Text, $Pattern)
}

function Test-NoShellAlias {
  param([string]$Path)
  $text = Get-FileText $Path
  if ($null -eq $text) { return @("missing") }
  $bad = [System.Collections.Generic.List[string]]::new()
  $lines = $text -split "`r?`n"
  $inBlockComment = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($inBlockComment) {
      if ($line -match '#>') { $inBlockComment = $false }
      continue
    }
    if ($line -match '<#') {
      if ($line -notmatch '#>') { $inBlockComment = $true }
      $line = ($line -split '<#')[0]
    }
    $code = ($line -split '#')[0]
    if ($code -match '(^|[\s;&|])(?:ls|cat|rm|curl|wget)(\s|$)') {
      $bad.Add(("{0}:{1}" -f (Split-Path -Leaf $Path), ($i + 1))) | Out-Null
    }
  }
  return @($bad)
}

function Get-CodeWithoutQuotedStrings {
  param([string]$Text)
  $withoutSingle = [regex]::Replace($Text, "'(?:''|[^'])*'", "''")
  return [regex]::Replace($withoutSingle, '"(?:""|`.|[^"])*"', '""')
}

function Get-PowerShellFiles {
  param([string]$RepoRoot)
  $files = $null
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git) {
    $saved = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $tracked = & git -C $RepoRoot -c core.quotepath=false ls-files 2>$null
      if ($LASTEXITCODE -eq 0 -and $tracked) {
        $files = foreach ($rel in $tracked) {
          $ext = [System.IO.Path]::GetExtension($rel).ToLowerInvariant()
          if ($ext -in @('.ps1', '.psm1', '.psd1')) { Join-Path $RepoRoot $rel }
        }
      }
    } finally {
      $ErrorActionPreference = $saved
    }
  }
  if ($null -eq $files) {
    $files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object {
        $_.Extension.ToLowerInvariant() -in @('.ps1', '.psm1', '.psd1') -and
        $_.FullName -notmatch '[\\/]node_modules[\\/]'
      } | ForEach-Object { $_.FullName }
  }
  return @($files | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
}

function Get-BashHeredocHits {
  param([string[]]$Paths, [string]$RepoRoot)
  $hits = [System.Collections.Generic.List[string]]::new()
  $tokenPattern = [char]60 + [char]60 + '\s*[''"]?[A-Za-z_][A-Za-z0-9_]*'
  foreach ($path in $Paths) {
    $text = Get-FileText $path
    if ($null -eq $text) { continue }
    $lines = $text -split "`r?`n"
    $inBlockComment = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]
      if ($inBlockComment) {
        if ($line -match '#>') { $inBlockComment = $false }
        continue
      }
      if ($line -match '<#') {
        if ($line -notmatch '#>') { $inBlockComment = $true }
        $line = ($line -split '<#')[0]
      }
      $code = (($line -split '#')[0])
      $code = Get-CodeWithoutQuotedStrings $code
      if ($code -match $tokenPattern) {
        $rel = $path.Substring($RepoRoot.Length).TrimStart('\', '/')
        $hits.Add(("{0}:{1}" -f $rel, ($i + 1))) | Out-Null
      }
    }
  }
  return @($hits)
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()

$agents = Join-Path $resolvedRoot 'AGENTS.md'
$task = Join-Path $resolvedRoot 'scripts\task.ps1'
$legacy = Join-Path $resolvedRoot 'scripts\winps51\Invoke-LegacyTask.ps1'
$docs = Join-Path $resolvedRoot 'docs\powershell-shell-contract.md'

$agentsText = Get-FileText $agents
$taskText = Get-FileText $task
$legacyText = Get-FileText $legacy

if (Test-Contains $agentsText '(?m)^## PowerShell Shell Contract\s*$') {
  Add-Result $results 'AGENTS.md shell-contract section' 'PASS' $true 'section present' 'Add a short PowerShell Shell Contract section to AGENTS.md.'
} else {
  Add-Result $results 'AGENTS.md shell-contract section' 'FAIL' $true 'section missing' 'Add a short PowerShell Shell Contract section to AGENTS.md.'
}

$defaultCommandPattern = [regex]::Escape('pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\task.ps1 <task>')
if (Test-Contains $agentsText $defaultCommandPattern) {
  Add-Result $results 'Default pwsh task command documented' 'PASS' $true 'command present' 'Document the exact default pwsh task command in AGENTS.md.'
} else {
  Add-Result $results 'Default pwsh task command documented' 'FAIL' $true 'command missing' 'Document the exact default pwsh task command in AGENTS.md.'
}

if (Test-Path -LiteralPath $task) {
  Add-Result $results 'scripts/task.ps1 exists' 'PASS' $true "path=$task" 'Create scripts/task.ps1 as the default entrypoint.'
} else {
  Add-Result $results 'scripts/task.ps1 exists' 'FAIL' $true "missing=$task" 'Create scripts/task.ps1 as the default entrypoint.'
}

if ((Test-Contains $taskText '(?m)^#Requires -Version 7\.2\s*$') -and
    (Test-Contains $taskText '\$PSVersionTable\.PSEdition') -and
    (Test-Contains $taskText "'Core'")) {
  Add-Result $results 'task.ps1 requires PowerShell Core 7.2+' 'PASS' $true 'requires version and checks Core edition' 'Make task.ps1 fail early outside pwsh/Core 7.2+.'
} else {
  Add-Result $results 'task.ps1 requires PowerShell Core 7.2+' 'FAIL' $true 'missing version or Core edition check' 'Make task.ps1 fail early outside pwsh/Core 7.2+.'
}

if ((Test-Path -LiteralPath $legacy) -and
    (Test-Contains $legacyText '(?m)^#Requires -Version 5\.1\s*$') -and
    (Test-Contains $legacyText '(?m)^#Requires -PSEdition Desktop\s*$') -and
    (Test-Contains $legacyText '\$PSVersionTable\.PSEdition')) {
  Add-Result $results 'winps51 legacy entrypoint is Desktop-only' 'PASS' $true 'requires 5.1 Desktop and checks edition' 'Add scripts/winps51/Invoke-LegacyTask.ps1 with 5.1 Desktop requirements.'
} else {
  Add-Result $results 'winps51 legacy entrypoint is Desktop-only' 'FAIL' $true 'missing or lacks 5.1 Desktop contract' 'Add scripts/winps51/Invoke-LegacyTask.ps1 with 5.1 Desktop requirements.'
}

if (Test-Path -LiteralPath $docs) {
  Add-Result $results 'Human shell-contract guide exists' 'PASS' $false "path=$docs" 'Add docs/powershell-shell-contract.md for manager-readable guidance.'
} else {
  Add-Result $results 'Human shell-contract guide exists' 'FAIL' $false "missing=$docs" 'Add docs/powershell-shell-contract.md for manager-readable guidance.'
}

$taskBarePowerShell = @()
if ($taskText) {
  $lines = $taskText -split "`r?`n"
  $inBlockComment = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($inBlockComment) {
      if ($line -match '#>') { $inBlockComment = $false }
      continue
    }
    if ($line -match '<#') {
      if ($line -notmatch '#>') { $inBlockComment = $true }
      $line = ($line -split '<#')[0]
    }
    $code = (($line -split '#')[0])
    $code = Get-CodeWithoutQuotedStrings $code
    if ($code -match '(^|[\s;&|])(?:&\s*)?powershell(\s|$)') {
      $taskBarePowerShell += ("scripts/task.ps1:{0}" -f ($i + 1))
    }
  }
}
if ($taskBarePowerShell.Count -eq 0) {
  Add-Result $results 'No ambiguous bare powershell in default entrypoint' 'PASS' $true 'checked scripts/task.ps1' 'Use pwsh or powershell.exe explicitly.'
} else {
  Add-Result $results 'No ambiguous bare powershell in default entrypoint' 'FAIL' $true ($taskBarePowerShell -join ', ') 'Use pwsh or powershell.exe explicitly.'
}

$aliasHits = @()
foreach ($p in @($task, (Join-Path $resolvedRoot 'scripts\Test-PowerShellShellContract.ps1'), $legacy)) {
  if (Test-Path -LiteralPath $p) {
    $aliasHits += @(Test-NoShellAlias $p)
  }
}
if ($aliasHits.Count -eq 0) {
  Add-Result $results 'No shell aliases in shell-contract automation' 'PASS' $true 'checked task/test/legacy scripts' 'Use explicit cmdlets or explicit native commands.'
} else {
  Add-Result $results 'No shell aliases in shell-contract automation' 'FAIL' $true ($aliasHits -join '; ') 'Use explicit cmdlets or explicit native commands.'
}

$workflowRoot = Join-Path $resolvedRoot '.github\workflows'
$workflowFiles = @()
if (Test-Path -LiteralPath $workflowRoot) {
  $workflowFiles = @(Get-ChildItem -LiteralPath $workflowRoot -File -Include '*.yml', '*.yaml' -ErrorAction SilentlyContinue)
}
$workflowProblems = [System.Collections.Generic.List[string]]::new()
foreach ($wf in $workflowFiles) {
  $text = Get-FileText $wf.FullName
  $usesPowerShell = Test-Contains $text '(?i)\b(pwsh|powershell(?:\.exe)?)\b'
  $hasAnyExplicitShell = Test-Contains $text '(?mi)^\s*shell:\s*[A-Za-z0-9_.-]+\s*$'
  if ($usesPowerShell -and -not $hasAnyExplicitShell) {
    $workflowProblems.Add($wf.Name) | Out-Null
  }
}
if ($workflowProblems.Count -eq 0) {
  Add-Result $results 'GitHub Actions PowerShell steps declare shell' 'PASS' $true "workflows=$($workflowFiles.Count)" 'Add shell: pwsh or shell: powershell to PowerShell workflow steps.'
} else {
  Add-Result $results 'GitHub Actions PowerShell steps declare shell' 'FAIL' $true ($workflowProblems -join ', ') 'Add shell: pwsh or shell: powershell to PowerShell workflow steps.'
}

$psFiles = @(Get-PowerShellFiles -RepoRoot $resolvedRoot)
$heredocHits = @(Get-BashHeredocHits -Paths $psFiles -RepoRoot $resolvedRoot)
if ($heredocHits.Count -eq 0) {
  Add-Result $results 'No Bash heredoc tokens in PowerShell scripts' 'PASS' $true "ps_files=$($psFiles.Count)" 'Use PowerShell here-strings or checked-in script files instead of Bash heredoc syntax.'
} else {
  Add-Result $results 'No Bash heredoc tokens in PowerShell scripts' 'FAIL' $true ($heredocHits -join '; ') 'Use PowerShell here-strings or checked-in script files instead of Bash heredoc syntax.'
}

$blockingFailures = @($results | Where-Object { $_.blocking -and $_.status -eq 'FAIL' })
$overall = if ($blockingFailures.Count -eq 0) { 'PASS' } else { 'FAIL' }

Write-Output '== PowerShell Shell Contract gate =='
foreach ($r in $results) {
  Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
}
Write-Output ("RESULT: {0} (fail={1})" -f $overall, $blockingFailures.Count)

if ($Json) {
  [pscustomobject]@{
    gate = 'PowerShell Shell Contract'
    root = $resolvedRoot
    overall = $overall
    results = @($results)
  } | ConvertTo-Json -Depth 6
}

if ($blockingFailures.Count -gt 0) { exit 1 }
exit 0
