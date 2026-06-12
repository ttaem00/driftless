#Requires -Version 5.1
#Requires -PSEdition Desktop
<#
.SYNOPSIS
  Smoke-test entrypoint for documented Windows PowerShell 5.1 work.
#>
[CmdletBinding()]
param(
  [ValidateSet('Doctor')]
  [string]$Task = 'Doctor'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -ne 'Desktop') {
  throw ("Wrong PowerShell edition: expected Desktop/Windows PowerShell 5.1, got {0} {1}." -f $PSVersionTable.PSEdition, $PSVersionTable.PSVersion)
}

switch ($Task) {
  'Doctor' {
    Write-Output 'Windows PowerShell 5.1 legacy path only.'
    Write-Output ("ps_edition={0}" -f $PSVersionTable.PSEdition)
    Write-Output ("ps_version={0}" -f $PSVersionTable.PSVersion)
    Write-Output ("repo_root={0}" -f (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path)
    Write-Output 'No destructive legacy task is configured.'
  }
}
