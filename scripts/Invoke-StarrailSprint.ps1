#requires -Version 7.0
#requires -PSEdition Core
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$TopologyPath,
  [string]$ContractPath,
  [string]$ReceiptPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$runtime = Join-Path $repoRoot 'tools\starrail-sprint\starrail_sprint.py'

function Resolve-ContainedPath {
  param([Parameter(Mandatory = $true)][string]$Path, [switch]$MustExist)
  $candidate = if ([System.IO.Path]::IsPathRooted($Path)) {
    [System.IO.Path]::GetFullPath($Path)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
  }
  $prefix = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
  if ($candidate -ne $repoRoot -and -not $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path must stay inside the Driftless repository: $Path"
  }
  if ($MustExist -and -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
    throw "Required file does not exist: $Path"
  }
  return $candidate
}

$resolvedTopology = Resolve-ContainedPath -Path $TopologyPath -MustExist
$arguments = @($runtime, '--topology', $resolvedTopology)
if ($ContractPath) { $arguments += @('--contract', (Resolve-ContainedPath -Path $ContractPath -MustExist)) }
if ($ReceiptPath) { $arguments += @('--receipt', (Resolve-ContainedPath -Path $ReceiptPath)) }
& python @arguments
exit $LASTEXITCODE
