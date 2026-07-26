#requires -Version 7.0
#requires -PSEdition Core
[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path, [switch]$Json)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runner = Join-Path $Root 'scripts\Invoke-StarrailSprint.ps1'
$pass = Join-Path $Root 'examples\starrail-sprint\topology.pass.json'
$fail = Join-Path $Root 'examples\starrail-sprint\topology.fail.json'
$runtime = Join-Path $Root 'tools\starrail-sprint\starrail_sprint.py'
$contract = Join-Path $Root 'profiles\shared\contract\STARTRAIL_SPRINT_CONTRACT.json'
$receiptPath = Join-Path $Root '.runtime\test-starrail-sprint\receipt.json'
$failReceiptPath = Join-Path $Root '.runtime\test-starrail-sprint\blocked-receipt.json'
$installer = Join-Path $Root 'install.ps1'
$sourceSkill = Join-Path $Root 'profiles\shared\skills\starrail-sprint\SKILL.md'
$wuther = Join-Path $Root 'scripts\Invoke-WutherCodemap.ps1'
$wutherManifest = Join-Path $Root 'examples\wuther-codemap\starrail-sprint\codemap.json'
$wutherOutput = '.runtime/test-starrail-sprint/wuther'

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [System.Convert]::ToHexString($sha.ComputeHash($stream)) }
    finally { $sha.Dispose() }
  } finally { $stream.Dispose() }
}

$installOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $installer -Tool both -Yes 2>&1)
$installExit = $LASTEXITCODE
$installedRuns = foreach ($tool in @('claude', 'codex')) {
  $installedHome = Join-Path $Root ".runtime\$tool-home"
  $installedContract = Join-Path $installedHome 'shared\contract\STARTRAIL_SPRINT_CONTRACT.json'
  $installedSkill = Join-Path $installedHome 'skills\starrail-sprint\SKILL.md'
  $installedReceipt = Join-Path $Root ".runtime\test-starrail-sprint\$tool-receipt.json"
  $output = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $pass -ContractPath $installedContract -ReceiptPath $installedReceipt 2>&1)
  [pscustomobject]@{
    tool = $tool
    exit = $LASTEXITCODE
    status = (($output -join "`n") | ConvertFrom-Json).status
    contract_match = ((Get-Sha256 -Path $contract) -eq (Get-Sha256 -Path $installedContract))
    skill_match = ((Get-Sha256 -Path $sourceSkill) -eq (Get-Sha256 -Path $installedSkill))
    receipt = (Test-Path -LiteralPath $installedReceipt)
  }
}

$wutherBuild = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $wuther -Root $Root -ManifestPath $wutherManifest -OutputPath $wutherOutput -Clean 2>&1)
$wutherBuildExit = $LASTEXITCODE
$wutherContextPath = Join-Path $Root "$wutherOutput\llm-context.json"
$wutherCheckExit = 1
$wutherContext = $null
if ($wutherBuildExit -eq 0 -and (Test-Path -LiteralPath $wutherContextPath)) {
  $wutherCheck = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $wuther -Root $Root -ManifestPath $wutherManifest -OutputPath $wutherOutput -Check 2>&1)
  $wutherCheckExit = $LASTEXITCODE
  $wutherContext = Get-Content -LiteralPath $wutherContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
}
$expectedNodeIds = @('aemeth.contract', 'stelle.step', 'starrail.topology', 'trailblazer.executor', 'profile.recognition')
$expectedDataIds = @('aemeth.sprint-spec', 'stelle.execution-receipt', 'starrail.topology-manifest', 'trailblazer.run-receipt', 'profile.vocabulary-contract')

$passOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $pass -ContractPath $contract -ReceiptPath $receiptPath 2>&1)
$passExit = $LASTEXITCODE
$passReceipt = ($passOutput -join "`n") | ConvertFrom-Json
$failOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $fail -ReceiptPath $failReceiptPath 2>&1)
$failExit = $LASTEXITCODE
$failReceipt = ($failOutput -join "`n") | ConvertFrom-Json
$outsideReceipt = Join-Path ([System.IO.Path]::GetTempPath()) ("driftless-starrail-outside-{0}.json" -f [guid]::NewGuid().ToString('N'))
$outsideOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $pass -ReceiptPath $outsideReceipt 2>&1)
$outsideExit = $LASTEXITCODE
$runtimeText = Get-Content -LiteralPath $runtime -Raw -Encoding UTF8
$contractData = Get-Content -LiteralPath $contract -Raw -Encoding UTF8 | ConvertFrom-Json

$checks = @(
  [pscustomobject]@{ name = 'positive durable topology receipt'; pass = ($passExit -eq 0 -and $passReceipt.status -eq 'PASS' -and $passReceipt.steps.Count -eq 3 -and (Test-Path -LiteralPath $receiptPath)) },
  [pscustomobject]@{ name = 'failed Aemeth blocks with durable feedback receipt'; pass = ($failExit -eq 2 -and $failReceipt.status -eq 'BLOCKED' -and $failReceipt.blocked_at -eq 'verify' -and $failReceipt.steps.Count -eq 2 -and $failReceipt.feedback.to -eq 'inspect' -and (Test-Path -LiteralPath $failReceiptPath)) },
  [pscustomobject]@{ name = 'receipt containment negative case'; pass = ($outsideExit -ne 0 -and -not (Test-Path -LiteralPath $outsideReceipt)) },
  [pscustomobject]@{ name = 'executable protected identifiers'; pass = @(@('class Aemeth', 'class Stelle', 'class StarrailTopology', 'def Trailblazer') | ForEach-Object { $runtimeText.Contains($_) } | Where-Object { -not $_ }).Count -eq 0 },
  [pscustomobject]@{ name = 'two profiles plus adapter fields'; pass = ($contractData.profiles.Count -eq 2 -and $contractData.profiles -contains 'claude' -and $contractData.profiles -contains 'codex' -and $contractData.compatibility.profile_required -eq $false -and $contractData.compatibility.consumers -contains 'hermes-worker') },
  [pscustomobject]@{ name = 'installed profile normal path parity'; pass = ($installExit -eq 0 -and @($installedRuns | Where-Object { $_.exit -ne 0 -or $_.status -ne 'PASS' -or -not $_.contract_match -or -not $_.skill_match -or -not $_.receipt }).Count -eq 0) },
  [pscustomobject]@{ name = 'Wuther freshness and exact ids'; pass = ($null -ne $wutherContext -and $wutherBuildExit -eq 0 -and $wutherCheckExit -eq 0 -and @($expectedNodeIds | Where-Object { $_ -notin $wutherContext.nodes.id }).Count -eq 0 -and @($expectedDataIds | Where-Object { $_ -notin $wutherContext.data_objects.id }).Count -eq 0) }
)
$failed = @($checks | Where-Object { -not $_.pass })
$result = [pscustomobject]@{ gate = 'starrail-sprint'; status = if ($failed.Count) { 'FAIL' } else { 'PASS' }; checks = $checks }
if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $checks | ForEach-Object { "[{0}] {1}" -f $(if ($_.pass) { 'PASS' } else { 'FAIL' }), $_.name }; "RESULT: $($result.status)" }
if ($failed.Count) { exit 1 }
exit 0
