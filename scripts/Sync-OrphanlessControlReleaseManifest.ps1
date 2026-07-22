#requires -Version 7.2
#requires -PSEdition Core
[CmdletBinding()]
param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$ManifestPath = 'profiles/shared/modules/orphanless-control/release-manifest.json',
  [switch]$Write,
  [switch]$SelfTest,
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-ToSafeRelativePath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $normalized = $Path.Replace('\', '/')
  if ([System.IO.Path]::IsPathRooted($normalized) -or $normalized -match '(^|/)\.\.(/|$)' -or $normalized.StartsWith('/')) {
    throw "Manifest path must stay repository-relative: $Path"
  }
  return $normalized
}

function Get-Sha256Hex {
  param([Parameter(Mandatory = $true)][string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  return [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Resolve-UnderRoot {
  param([Parameter(Mandatory = $true)][string]$RepoRoot, [Parameter(Mandatory = $true)][string]$RelativePath)
  $safe = Convert-ToSafeRelativePath $RelativePath
  $rootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
  $full = [System.IO.Path]::GetFullPath((Join-Path $rootFull $safe))
  if (-not ($full -eq $rootFull -or $full.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "Manifest path escapes repository root: $RelativePath"
  }
  return $full
}

function Get-DiscoveredPaths {
  param([Parameter(Mandatory = $true)][string]$RepoRoot, [Parameter(Mandatory = $true)][object]$Discovery)
  $excluded = @($Discovery.excludePaths | ForEach-Object { Convert-ToSafeRelativePath ([string]$_) })
  $paths = [System.Collections.Generic.List[string]]::new()
  foreach ($rootRel in @($Discovery.recursiveRoots)) {
    $safeRoot = Convert-ToSafeRelativePath ([string]$rootRel)
    $rootFull = Resolve-UnderRoot -RepoRoot $RepoRoot -RelativePath $safeRoot
    if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) { throw "Managed package root is missing: $safeRoot" }
    foreach ($file in @(Get-ChildItem -LiteralPath $rootFull -File -Recurse)) {
      $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName).Replace('\', '/')
      if ($excluded -notcontains $relative) { $paths.Add($relative) | Out-Null }
    }
  }
  foreach ($path in @($Discovery.explicitFiles)) { $paths.Add((Convert-ToSafeRelativePath ([string]$path))) | Out-Null }
  return @($paths | Sort-Object -Unique)
}

function New-ManifestFiles {
  param([Parameter(Mandatory = $true)][string]$RepoRoot, [Parameter(Mandatory = $true)][string[]]$Paths)
  return @($Paths | ForEach-Object {
      $full = Resolve-UnderRoot -RepoRoot $RepoRoot -RelativePath $_
      if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Managed package file is missing: $_" }
      [ordered]@{ path = $_; sha256 = Get-Sha256Hex -Path $full }
    })
}

function Test-ReleaseManifest {
  param([Parameter(Mandatory = $true)][string]$RepoRoot, [Parameter(Mandatory = $true)][string]$Path)
  $errors = [System.Collections.Generic.List[string]]::new()
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return [pscustomobject]@{ passed = $false; errors = @('manifest_missing'); files = 0 } }
  try {
    $manifest = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
    if ([string]$manifest.schemaVersion -ne 'orphanless-control.release-manifest.v1') { $errors.Add('schema_version_invalid') | Out-Null }
    if ([string]$manifest.package -ne 'orphanless-control') { $errors.Add('package_name_invalid') | Out-Null }
    if ([string]$manifest.hashAlgorithm -ne 'SHA-256') { $errors.Add('hash_algorithm_invalid') | Out-Null }
    $discovered = @(Get-DiscoveredPaths -RepoRoot $RepoRoot -Discovery $manifest.discovery)
    $declared = @($manifest.files | ForEach-Object { Convert-ToSafeRelativePath ([string]$_.path) })
    if (@($declared | Select-Object -Unique).Count -ne $declared.Count) { $errors.Add('duplicate_path') | Out-Null }
    if (($declared -join "`n") -cne ((@($declared | Sort-Object)) -join "`n")) { $errors.Add('paths_not_sorted') | Out-Null }
    foreach ($missing in @($declared | Where-Object { $discovered -notcontains $_ })) { $errors.Add("declared_but_not_discovered:$missing") | Out-Null }
    foreach ($unlisted in @($discovered | Where-Object { $declared -notcontains $_ })) { $errors.Add("unlisted_file:$unlisted") | Out-Null }
    foreach ($entry in @($manifest.files)) {
      $relative = Convert-ToSafeRelativePath ([string]$entry.path)
      $full = Resolve-UnderRoot -RepoRoot $RepoRoot -RelativePath $relative
      if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { $errors.Add("missing_file:$relative") | Out-Null }
      elseif ([string]$entry.sha256 -notmatch '^[a-f0-9]{64}$') { $errors.Add("invalid_hash:$relative") | Out-Null }
      elseif ((Get-Sha256Hex -Path $full) -cne [string]$entry.sha256) { $errors.Add("stale_hash:$relative") | Out-Null }
    }
    return [pscustomobject]@{ passed = ($errors.Count -eq 0); errors = @($errors); files = $declared.Count }
  } catch {
    $errors.Add(('manifest_error:' + $_.Exception.Message)) | Out-Null
    return [pscustomobject]@{ passed = $false; errors = @($errors); files = 0 }
  }
}

$repoRoot = (Resolve-Path -LiteralPath $Root).Path
$manifestFull = Resolve-UnderRoot -RepoRoot $repoRoot -RelativePath $ManifestPath
if ($Write) {
  if (-not (Test-Path -LiteralPath $manifestFull -PathType Leaf)) { throw "Create the reviewed manifest contract before using -Write: $ManifestPath" }
  $manifest = Get-Content -LiteralPath $manifestFull -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 20
  $paths = @(Get-DiscoveredPaths -RepoRoot $repoRoot -Discovery $manifest.discovery)
  $updated = [ordered]@{
    schemaVersion = 'orphanless-control.release-manifest.v1'; package = 'orphanless-control'; hashAlgorithm = 'SHA-256'
    discovery = [ordered]@{ recursiveRoots = @($manifest.discovery.recursiveRoots); excludePaths = @($manifest.discovery.excludePaths); explicitFiles = @($manifest.discovery.explicitFiles) }
    files = @(New-ManifestFiles -RepoRoot $repoRoot -Paths $paths)
  }
  [System.IO.File]::WriteAllText($manifestFull, (($updated | ConvertTo-Json -Depth 10) + "`n"), [System.Text.UTF8Encoding]::new($false))
}

$result = Test-ReleaseManifest -RepoRoot $repoRoot -Path $manifestFull
if ($SelfTest) {
  $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('driftless-orphanless-integrity-' + [guid]::NewGuid().ToString('N'))
  try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    foreach ($entry in @((Get-Content -LiteralPath $manifestFull -Raw | ConvertFrom-Json -Depth 20).files)) {
      $source = Resolve-UnderRoot -RepoRoot $repoRoot -RelativePath ([string]$entry.path)
      $target = Resolve-UnderRoot -RepoRoot $tempRoot -RelativePath ([string]$entry.path)
      New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($target)) -Force | Out-Null
      Copy-Item -LiteralPath $source -Destination $target
    }
    $tempManifest = Resolve-UnderRoot -RepoRoot $tempRoot -RelativePath $ManifestPath
    New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($tempManifest)) -Force | Out-Null
    Copy-Item -LiteralPath $manifestFull -Destination $tempManifest
    $positive = Test-ReleaseManifest -RepoRoot $tempRoot -Path $tempManifest
    Add-Content -LiteralPath (Resolve-UnderRoot -RepoRoot $tempRoot -RelativePath 'profiles/shared/modules/orphanless-control/README.md') -Value 'stale fixture' -Encoding utf8NoBOM
    $stale = Test-ReleaseManifest -RepoRoot $tempRoot -Path $tempManifest
    Copy-Item -LiteralPath (Resolve-UnderRoot -RepoRoot $repoRoot -RelativePath 'profiles/shared/modules/orphanless-control/README.md') -Destination (Resolve-UnderRoot -RepoRoot $tempRoot -RelativePath 'profiles/shared/modules/orphanless-control/README.md') -Force
    New-Item -ItemType File -Path (Resolve-UnderRoot -RepoRoot $tempRoot -RelativePath 'profiles/shared/modules/orphanless-control/unlisted.ps1') | Out-Null
    $unlisted = Test-ReleaseManifest -RepoRoot $tempRoot -Path $tempManifest
    $selfTestPassed = $positive.passed -and -not $stale.passed -and (@($stale.errors | Where-Object { $_ -like 'stale_hash:*' }).Count -eq 1) -and -not $unlisted.passed -and (@($unlisted.errors | Where-Object { $_ -like 'unlisted_file:*' }).Count -eq 1)
    $result | Add-Member -NotePropertyName selfTestPassed -NotePropertyValue $selfTestPassed
  } finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
  }
}
if ($Json) { $result | ConvertTo-Json -Depth 5 }
else {
  if ($result.passed) { Write-Output "ORPHANLESS_RELEASE_INTEGRITY_PASS files=$($result.files)" } else { Write-Output ('ORPHANLESS_RELEASE_INTEGRITY_FAIL ' + (@($result.errors) -join ';')) }
  if ($SelfTest) { Write-Output "ORPHANLESS_RELEASE_INTEGRITY_SELF_TEST=$($result.selfTestPassed)" }
}
if (-not $result.passed -or ($SelfTest -and -not $result.selfTestPassed)) { exit 1 }
exit 0
