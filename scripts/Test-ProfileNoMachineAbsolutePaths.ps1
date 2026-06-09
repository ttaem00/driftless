#requires -Version 7.0
#requires -PSEdition Core
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
    [string]$Evidence,
    [string]$NextAction = ''
  )
  $Results.Add([pscustomobject]@{
      check = $Check
      status = $Status
      evidence = $Evidence
      next_action = $NextAction
    }) | Out-Null
}

function Get-TextFiles {
  param([string]$Base)
  if (-not (Test-Path -LiteralPath $Base)) { return @() }
  $extensions = @('.md', '.yaml', '.yml', '.json', '.py', '.ps1', '.toml', '.txt')
  Get-ChildItem -LiteralPath $Base -Recurse -File |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() }
}

function Get-RelativePathCompat {
  param(
    [string]$Base,
    [string]$Path
  )
  $baseFull = [System.IO.Path]::GetFullPath($Base).TrimEnd('\')
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  if ($pathFull.StartsWith($baseFull + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    return $pathFull.Substring($baseFull.Length + 1)
  }
  return $pathFull
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$results = [System.Collections.Generic.List[object]]::new()
$regex = [regex]'(?<![A-Za-z])[A-Za-z]:\\'

$files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($rel in @('AGENTS.md', 'CLAUDE.md')) {
  $path = Join-Path $resolvedRoot $rel
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    $files.Add((Get-Item -LiteralPath $path)) | Out-Null
  }
}
foreach ($file in (Get-TextFiles -Base (Join-Path $resolvedRoot 'profiles'))) {
  $files.Add($file) | Out-Null
}

$violations = [System.Collections.Generic.List[object]]::new()
foreach ($file in $files) {
  $relative = Get-RelativePathCompat -Base $resolvedRoot -Path $file.FullName
  $lineNo = 0
  foreach ($line in (Get-Content -LiteralPath $file.FullName -Encoding UTF8)) {
    $lineNo += 1
    if (-not $regex.IsMatch($line)) { continue }
    $violations.Add([pscustomobject]@{
        file = $relative
        line = $lineNo
        text = $line.Trim()
      }) | Out-Null
  }
}

Add-Result $results 'profile/hot text has no machine-specific absolute paths' ($(if ($violations.Count -eq 0) { 'PASS' } else { 'FAIL' })) "files=$($files.Count); violations=$($violations.Count)" 'Replace machine-specific paths with repo-relative paths, environment-variable resolution, or manager-provided path placeholders.'

$summary = [pscustomobject]@{
  command = 'Test-ProfileNoMachineAbsolutePaths.ps1'
  root = $resolvedRoot
  overall = $(if ($violations.Count -eq 0) { 'PASS' } else { 'FAIL' })
  pass = @($results | Where-Object status -eq 'PASS').Count
  fail = @($results | Where-Object status -eq 'FAIL').Count
  violations = @($violations)
  results = @($results)
}

if ($Json) {
  $summary | ConvertTo-Json -Depth 6
} else {
  Write-Output '== Profile no machine absolute paths gate =='
  foreach ($r in $results) {
    Write-Output ("[{0}] {1} - {2}" -f $r.status, $r.check, $r.evidence)
  }
  foreach ($v in $violations) {
    Write-Output ("[VIOLATION] {0}:{1} {2}" -f $v.file, $v.line, $v.text)
  }
  Write-Output ("RESULT: {0} (pass={1} fail={2})" -f $summary.overall, $summary.pass, $summary.fail)
}

if ($violations.Count -gt 0) { exit 1 }
