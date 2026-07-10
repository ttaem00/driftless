#requires -Version 7.0
#requires -PSEdition Core
<#
.SYNOPSIS
  Generate manager and LLM views from the canonical Wuther Codemap v1 contract.

.DESCRIPTION
  Thin public adapter over the renderer-neutral Python generator. The manifest,
  schema, and output stay under Root. Clean removes only Wuther-owned artifacts
  and then regenerates them; it never recursively removes OutputPath.
#>
[CmdletBinding()]
param(
  [string]$Root = '.',
  [Parameter(Mandatory = $true)][string]$ManifestPath,
  [string]$OutputPath = '.runtime/wuther-codemap',
  [switch]$Check,
  [switch]$Clean,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Check -and $Clean) { throw '-Check and -Clean are mutually exclusive.' }

$repoRoot = (Resolve-Path -LiteralPath $Root).Path
$packageRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$generator = Join-Path $packageRoot 'tools\wuther-codemap\generate.py'
$SchemaPath = Join-Path $packageRoot 'profiles\shared\schemas\wuther-codemap-manifest.schema.json'

$argsList = @(
  $generator,
  '--root', $repoRoot,
  '--schema', $SchemaPath,
  '--manifest', $ManifestPath,
  '--output-dir', $OutputPath
)
if ($Check) { $argsList += '--check' }
if ($Clean) { $argsList += '--clean' }

$output = @(& python @argsList 2>&1)
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
  if ($Json) {
    [ordered]@{
      command = if ($Check) { 'wuther-codemap-check' } else { 'wuther-codemap-generate' }
      status = 'FAIL'
      problems = @($output | ForEach-Object { [string]$_ })
    } | ConvertTo-Json -Depth 5
  } else {
    $output | ForEach-Object { Write-Error ([string]$_) -ErrorAction Continue }
  }
  exit $exitCode
}

if ($Json) {
  $manifestFull = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
    [System.IO.Path]::GetFullPath($ManifestPath)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ManifestPath))
  }
  $manifest = Get-Content -LiteralPath $manifestFull -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
  [ordered]@{
    command = if ($Check) { 'wuther-codemap-check' } else { 'wuther-codemap-generate' }
    status = 'PASS'
    schema_version = [string]$manifest.schema_version
    files = @('manager.html', 'llm-context.json', 'llm-context.md')
    renderer = 'canonical-python'
  } | ConvertTo-Json -Depth 5
} else {
  $output
}
