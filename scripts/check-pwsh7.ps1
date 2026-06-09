#requires -Version 7.0
#requires -PSEdition Core
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7 -or $PSVersionTable.PSEdition -ne 'Core') {
  throw 'This project requires PowerShell 7+. Run with pwsh.exe.'
}

$pwsh = Get-Command pwsh.exe -ErrorAction Stop
Write-Output ('version={0}' -f $PSVersionTable.PSVersion.ToString())
Write-Output ('edition={0}' -f $PSVersionTable.PSEdition)
Write-Output ('pwsh={0}' -f $pwsh.Source)
Write-Output 'RESULT: PASS PowerShell 7 runtime available'
