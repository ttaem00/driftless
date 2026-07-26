#requires -Version 7.0
#requires -PSEdition Core
[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path, [switch]$Json)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runner = Join-Path $Root 'scripts\Invoke-StarrailSprint.ps1'
$pass = Join-Path $Root 'examples\starrail-sprint\topology.pass.json'
$fail = Join-Path $Root 'examples\starrail-sprint\topology.fail.json'
$hostileStatus = Join-Path $Root 'examples\starrail-sprint\topology.hostile-status.json'
$invalidPolicy = Join-Path $Root 'examples\starrail-sprint\topology.invalid-policy.json'
$missingFeedback = Join-Path $Root 'examples\starrail-sprint\topology.missing-feedback.json'
$evidenceDisabled = Join-Path $Root 'examples\starrail-sprint\topology.evidence-disabled.json'
$notObject = Join-Path $Root 'examples\starrail-sprint\topology.not-object.json'
$nullSteps = Join-Path $Root 'examples\starrail-sprint\topology.null-steps.json'
$nonobjectStep = Join-Path $Root 'examples\starrail-sprint\topology.nonobject-step.json'
$runtime = Join-Path $Root 'tools\starrail-sprint\starrail_sprint.py'
$contract = Join-Path $Root 'profiles\shared\contract\STARRAIL_SPRINT_CONTRACT.json'
$receiptPath = Join-Path $Root '.runtime\starrail-sprint\test\receipt.json'
$failReceiptPath = Join-Path $Root '.runtime\starrail-sprint\test\blocked-receipt.json'
$installer = Join-Path $Root 'install.ps1'
$sourceSkill = Join-Path $Root 'profiles\shared\skills\starrail-sprint\SKILL.md'
$sourceRegistration = Join-Path $Root 'profiles\shared\skills\starrail-sprint\agents\openai.yaml'
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
  $installedContract = Join-Path $installedHome 'shared\contract\STARRAIL_SPRINT_CONTRACT.json'
  $installedSkill = Join-Path $installedHome 'skills\starrail-sprint\SKILL.md'
  $installedRegistration = Join-Path $installedHome 'skills\starrail-sprint\agents\openai.yaml'
  $obsoleteInstalledContract = Join-Path $installedHome 'shared\contract\STARTRAIL_SPRINT_CONTRACT.json'
  $installedReceipt = Join-Path $Root ".runtime\starrail-sprint\test\$tool-receipt.json"
  $output = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $pass -ContractPath $installedContract -ReceiptPath $installedReceipt 2>&1)
  [pscustomobject]@{
    tool = $tool
    exit = $LASTEXITCODE
    status = (($output -join "`n") | ConvertFrom-Json).status
    contract_match = ((Get-Sha256 -Path $contract) -eq (Get-Sha256 -Path $installedContract))
    skill_match = ((Get-Sha256 -Path $sourceSkill) -eq (Get-Sha256 -Path $installedSkill))
    registration_match = ((Get-Sha256 -Path $sourceRegistration) -eq (Get-Sha256 -Path $installedRegistration))
    implicit = (Get-Content -LiteralPath $installedRegistration -Raw -Encoding UTF8).Contains('allow_implicit_invocation: true')
    obsolete_absent = (-not (Test-Path -LiteralPath $obsoleteInstalledContract))
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
$expectedNodeIds = @('aemeth.contract', 'stelle.step', 'starrail.topology', 'trailblazer.executor', 'profile.recognition', 'hermes.worker.adapter')
$expectedDataIds = @('aemeth.sprint-spec', 'stelle.execution-receipt', 'starrail.topology-manifest', 'trailblazer.run-receipt', 'profile.vocabulary-contract')
$wutherSourceRef = if ($null -ne $wutherContext) { [string]$wutherContext.project.source_ref } else { '' }
$sourceRefExistsExit = 1
$sourceImplementationDiffExit = 1
if ($wutherSourceRef -match '^[0-9a-f]{40}$') {
  & git -C $Root cat-file -e ('{0}^{{commit}}' -f $wutherSourceRef) 2>$null
  $sourceRefExistsExit = $LASTEXITCODE
  if ($sourceRefExistsExit -eq 0) {
    $implementationPaths = @(
      'profiles/shared/contract/STARRAIL_SPRINT_CONTRACT.json',
      'profiles/shared/skills/starrail-sprint',
      'tools/starrail-sprint/starrail_sprint.py',
      'scripts/Invoke-StarrailSprint.ps1',
      'install.ps1',
      'install.sh',
      'examples/starrail-sprint'
    )
    & git -C $Root diff --quiet $wutherSourceRef -- @implementationPaths
    $sourceImplementationDiffExit = $LASTEXITCODE
  }
}

$passOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $pass -ContractPath $contract -ReceiptPath $receiptPath 2>&1)
$passExit = $LASTEXITCODE
$passReceipt = ($passOutput -join "`n") | ConvertFrom-Json
$failOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $fail -ReceiptPath $failReceiptPath 2>&1)
$failExit = $LASTEXITCODE
$failReceipt = ($failOutput -join "`n") | ConvertFrom-Json
$hostileOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $hostileStatus -ReceiptPath '.runtime\starrail-sprint\test\hostile-receipt.json' 2>&1)
$hostileExit = $LASTEXITCODE
$hostileReceipt = ($hostileOutput -join "`n") | ConvertFrom-Json
$invalidPolicyOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $invalidPolicy -ReceiptPath '.runtime\starrail-sprint\test\invalid-policy-receipt.json' 2>&1)
$invalidPolicyExit = $LASTEXITCODE
$invalidPolicyReceipt = ($invalidPolicyOutput -join "`n") | ConvertFrom-Json
$missingFeedbackOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $missingFeedback -ReceiptPath '.runtime\starrail-sprint\test\missing-feedback-receipt.json' 2>&1)
$missingFeedbackExit = $LASTEXITCODE
$missingFeedbackReceipt = ($missingFeedbackOutput -join "`n") | ConvertFrom-Json
$evidenceDisabledOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $evidenceDisabled 2>&1)
$evidenceDisabledExit = $LASTEXITCODE
$evidenceDisabledReceipt = ($evidenceDisabledOutput -join "`n") | ConvertFrom-Json
$notObjectOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $notObject 2>&1)
$notObjectExit = $LASTEXITCODE
$notObjectReceipt = ($notObjectOutput -join "`n") | ConvertFrom-Json
$nullStepsOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $nullSteps 2>&1)
$nullStepsExit = $LASTEXITCODE
$nullStepsReceipt = ($nullStepsOutput -join "`n") | ConvertFrom-Json
$nonobjectStepOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $nonobjectStep 2>&1)
$nonobjectStepExit = $LASTEXITCODE
$nonobjectStepReceipt = ($nonobjectStepOutput -join "`n") | ConvertFrom-Json
$outsideReceipt = Join-Path ([System.IO.Path]::GetTempPath()) ("driftless-starrail-outside-{0}.json" -f [guid]::NewGuid().ToString('N'))
$outsideOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $pass -ReceiptPath $outsideReceipt 2>&1)
$outsideExit = $LASTEXITCODE
$directOutsideReceipt = Join-Path ([System.IO.Path]::GetTempPath()) ("driftless-starrail-python-receipt-{0}.json" -f [guid]::NewGuid().ToString('N'))
$directReceiptOutput = @(& python $runtime --topology $pass --receipt $directOutsideReceipt 2>&1)
$directReceiptExit = $LASTEXITCODE
$trackedReceiptTarget = Join-Path $Root 'README.md'
$trackedReceiptBefore = Get-Sha256 -Path $trackedReceiptTarget
$wrapperTrackedOutput = @(& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $runner -TopologyPath $pass -ReceiptPath $trackedReceiptTarget 2>&1)
$wrapperTrackedExit = $LASTEXITCODE
$trackedReceiptAfterWrapper = Get-Sha256 -Path $trackedReceiptTarget
$directTrackedOutput = @(& python $runtime --topology $pass --receipt $trackedReceiptTarget 2>&1)
$directTrackedExit = $LASTEXITCODE
$trackedReceiptAfterDirect = Get-Sha256 -Path $trackedReceiptTarget
$directOutsideTopology = Join-Path ([System.IO.Path]::GetTempPath()) ("driftless-starrail-python-topology-{0}.json" -f [guid]::NewGuid().ToString('N'))
$directOutsideContract = Join-Path ([System.IO.Path]::GetTempPath()) ("driftless-starrail-python-contract-{0}.json" -f [guid]::NewGuid().ToString('N'))
Copy-Item -LiteralPath $pass -Destination $directOutsideTopology
Copy-Item -LiteralPath $contract -Destination $directOutsideContract
try {
  $directTopologyOutput = @(& python $runtime --topology $directOutsideTopology 2>&1)
  $directTopologyExit = $LASTEXITCODE
  $directContractOutput = @(& python $runtime --topology $pass --contract $directOutsideContract 2>&1)
  $directContractExit = $LASTEXITCODE
} finally {
  Remove-Item -LiteralPath $directOutsideTopology,$directOutsideContract -Force -ErrorAction SilentlyContinue
}
$runtimeText = Get-Content -LiteralPath $runtime -Raw -Encoding UTF8
$contractData = Get-Content -LiteralPath $contract -Raw -Encoding UTF8 | ConvertFrom-Json

$checks = @(
  [pscustomobject]@{ name = 'positive durable topology receipt'; pass = ($passExit -eq 0 -and $passReceipt.status -eq 'PASS' -and $passReceipt.steps.Count -eq 3 -and (Test-Path -LiteralPath $receiptPath)) },
  [pscustomobject]@{ name = 'failed Aemeth blocks with durable feedback receipt'; pass = ($failExit -eq 2 -and $failReceipt.status -eq 'BLOCKED' -and $failReceipt.blocked_at -eq 'verify' -and $failReceipt.steps.Count -eq 2 -and $failReceipt.feedback.to -eq 'inspect' -and (Test-Path -LiteralPath $failReceiptPath)) },
  [pscustomobject]@{ name = 'configured FAIL cannot become success'; pass = ($hostileExit -eq 1 -and $hostileReceipt.status -eq 'BLOCKED' -and $hostileReceipt.blocked_at -eq 'topology-validation' -and $hostileReceipt.problem.Contains('required_status must be PASS')) },
  [pscustomobject]@{ name = 'invalid exception policy blocks'; pass = ($invalidPolicyExit -eq 1 -and $invalidPolicyReceipt.status -eq 'BLOCKED' -and $invalidPolicyReceipt.problem.Contains('must be stop or feedback')) },
  [pscustomobject]@{ name = 'missing feedback edge blocks explicitly'; pass = ($missingFeedbackExit -eq 1 -and $missingFeedbackReceipt.status -eq 'BLOCKED' -and $missingFeedbackReceipt.problem.Contains('requires exactly one matching FAIL feedback edge')) },
  [pscustomobject]@{ name = 'evidence cannot be disabled'; pass = ($evidenceDisabledExit -eq 1 -and $evidenceDisabledReceipt.status -eq 'BLOCKED' -and $evidenceDisabledReceipt.problem.Contains('require_evidence must be true')) },
  [pscustomobject]@{ name = 'malformed topology shapes normalize to blocked receipts'; pass = ($notObjectExit -eq 1 -and $notObjectReceipt.status -eq 'BLOCKED' -and $notObjectReceipt.problem.Contains('must be a JSON object') -and $nullStepsExit -eq 1 -and $nullStepsReceipt.status -eq 'BLOCKED' -and $nullStepsReceipt.problem.Contains('steps must be an array') -and $nonobjectStepExit -eq 1 -and $nonobjectStepReceipt.status -eq 'BLOCKED' -and $nonobjectStepReceipt.problem.Contains('step must be a JSON object')) },
  [pscustomobject]@{ name = 'receipt containment negative case'; pass = ($outsideExit -ne 0 -and -not (Test-Path -LiteralPath $outsideReceipt)) },
  [pscustomobject]@{ name = 'direct Python containment negative cases'; pass = ($directReceiptExit -ne 0 -and $directTopologyExit -ne 0 -and $directContractExit -ne 0 -and -not (Test-Path -LiteralPath $directOutsideReceipt)) },
  [pscustomobject]@{ name = 'tracked source receipt targets stay unchanged'; pass = ($wrapperTrackedExit -ne 0 -and $directTrackedExit -ne 0 -and $trackedReceiptBefore -eq $trackedReceiptAfterWrapper -and $trackedReceiptBefore -eq $trackedReceiptAfterDirect -and ($wrapperTrackedOutput -join "`n").Contains('.runtime/starrail-sprint') -and ($directTrackedOutput -join "`n").Contains('.runtime/starrail-sprint')) },
  [pscustomobject]@{ name = 'canonical cross-project schema names'; pass = ($contractData.schema_version -eq 'aemeth-sprint.v1' -and $contractData.receipt_schema -eq 'trailblazer-run-receipt.v1' -and $passReceipt.schema_version -eq 'trailblazer-run-receipt.v1' -and -not (($contractData | ConvertTo-Json -Depth 20).Contains('starrail-sprint.v1')) -and -not (($passReceipt | ConvertTo-Json -Depth 20).Contains('trailblazer-receipt.v1'))) },
  [pscustomobject]@{ name = 'executable protected identifiers'; pass = @(@('class Aemeth', 'class Stelle', 'class StarrailTopology', 'def Trailblazer') | ForEach-Object { $runtimeText.Contains($_) } | Where-Object { -not $_ }).Count -eq 0 },
  [pscustomobject]@{ name = 'two profiles plus adapter fields'; pass = ($contractData.profiles.Count -eq 2 -and $contractData.profiles -contains 'claude' -and $contractData.profiles -contains 'codex' -and $contractData.compatibility.profile_required -eq $false -and $contractData.compatibility.consumers -contains 'hermes-worker') },
  [pscustomobject]@{ name = 'installed profile aliases and implicit recognition'; pass = ($installExit -eq 0 -and @($installedRuns | Where-Object { $_.exit -ne 0 -or $_.status -ne 'PASS' -or -not $_.contract_match -or -not $_.skill_match -or -not $_.registration_match -or -not $_.implicit -or -not $_.obsolete_absent -or -not $_.receipt }).Count -eq 0) },
  [pscustomobject]@{ name = 'Wuther freshness and exact ids'; pass = ($null -ne $wutherContext -and $wutherBuildExit -eq 0 -and $wutherCheckExit -eq 0 -and @($expectedNodeIds | Where-Object { $_ -notin $wutherContext.nodes.id }).Count -eq 0 -and @($expectedDataIds | Where-Object { $_ -notin $wutherContext.data_objects.id }).Count -eq 0) },
  [pscustomobject]@{ name = 'Wuther immutable implementation source ref'; pass = ($sourceRefExistsExit -eq 0 -and $sourceImplementationDiffExit -eq 0) }
)
$failed = @($checks | Where-Object { -not $_.pass })
$result = [pscustomobject]@{ gate = 'starrail-sprint'; status = if ($failed.Count) { 'FAIL' } else { 'PASS' }; checks = $checks }
if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $checks | ForEach-Object { "[{0}] {1}" -f $(if ($_.pass) { 'PASS' } else { 'FAIL' }), $_.name }; "RESULT: $($result.status)" }
if ($failed.Count) { exit 1 }
exit 0
