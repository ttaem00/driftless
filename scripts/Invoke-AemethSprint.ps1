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
$runner = Join-Path $PSScriptRoot 'Invoke-StarrailSprint.ps1'
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $runner, '-TopologyPath', $TopologyPath)
if ($ContractPath) { $arguments += @('-ContractPath', $ContractPath) }
if ($ReceiptPath) { $arguments += @('-ReceiptPath', $ReceiptPath) }
& pwsh.exe @arguments
exit $LASTEXITCODE
