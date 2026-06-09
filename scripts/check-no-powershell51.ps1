#requires -Version 7.0
#requires -PSEdition Core
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$forbidden = @(
  ('powershell' + '.exe'),
  ('Windows' + 'PowerShell'),
  ('System32' + [char]92 + 'Windows' + 'PowerShell'),
  ('#requires' + ' -Version 5')
)
$extensions = @('.ps1', '.psm1', '.psd1', '.bat', '.cmd', '.json', '.yml', '.yaml', '.toml', '.md')
$names = @('Makefile', 'package.json', 'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock', 'pyproject.toml', 'AGENTS.md', 'README.md')
$skipDirs = @('.git', 'node_modules', '.venv', 'venv', '__pycache__')
$aliasPattern = [regex]::new("(^|[\s`"'])" + "powershell" + "\s+-", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function Get-ScanFiles {
  param([string]$Path)
  Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
    $relative = $_.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
    if ($relative -eq 'scripts/check-no-powershell51.ps1') { return $false }
    if ($relative -match '^\.runtime[\\/]') { return $false }
    $full = $_.FullName
    foreach ($dir in $skipDirs) {
      if ($full -match ('[\\/]' + [regex]::Escape($dir) + '[\\/]')) { return $false }
    }
    return ($extensions -contains $_.Extension.ToLowerInvariant()) -or ($names -contains $_.Name) -or ($relative -match '^\.githooks[\\/]')
  }
}

$hits = [System.Collections.Generic.List[object]]::new()
foreach ($file in Get-ScanFiles -Path $resolvedRoot) {
  $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
  if ($null -eq $text) { continue }
  $lines = $text -split "`r?`n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($term in $forbidden) {
      if ($lines[$i].IndexOf($term, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $hits.Add([pscustomobject]@{
          file = $file.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
          line = $i + 1
          term = $term
          text = $lines[$i].Trim()
        }) | Out-Null
      }
    }
    if ($aliasPattern.IsMatch($lines[$i])) {
      $hits.Add([pscustomobject]@{
        file = $file.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
        line = $i + 1
        term = 'powershell command alias'
        text = $lines[$i].Trim()
      }) | Out-Null
    }
    if ($lines[$i] -match '(?i)^\s*shell:\s*powershell\s*$') {
      $hits.Add([pscustomobject]@{
        file = $file.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
        line = $i + 1
        term = 'shell: powershell'
        text = $lines[$i].Trim()
      }) | Out-Null
    }
  }
}

if ($Json) {
  [pscustomobject]@{ result = if ($hits.Count -eq 0) { 'PASS' } else { 'FAIL' }; root = $resolvedRoot; hits = @($hits) } | ConvertTo-Json -Depth 5
}

if ($hits.Count -gt 0) {
  if (-not $Json) { $hits | Format-Table -AutoSize | Out-String | Write-Output }
  throw ('Forbidden Windows PowerShell launcher references found: {0}' -f $hits.Count)
}

if (-not $Json) { Write-Output 'RESULT: PASS no Windows PowerShell launcher references found' }
