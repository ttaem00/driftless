#requires -Version 7.0
#requires -PSEdition Core
param([string]$Root = ".")
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath $Root).Path
$validator = Join-Path $repo "scripts\validate_manager_closeout.py"
$fixtures = Join-Path $repo "tests\fixtures\manager-closeout-skill-suite"
$policy = Join-Path $repo "profiles\shared\schemas\manager-closeout-routing-policy.json"
$valid = @(
  @{ kind = "sprint"; file = "sprint.valid.json" },
  @{ kind = "audit"; file = "audit.valid.json" },
  @{ kind = "evidence"; file = "evidence.valid.json" },
  @{ kind = "evolution"; file = "evolution.valid.json" }
)
$invalid = @(
  @{ kind = "sprint"; file = "sprint.invalid.json" },
  @{ kind = "audit"; file = "audit.invalid.json" },
  @{ kind = "evidence"; file = "evidence.invalid.json" },
  @{ kind = "evolution"; file = "evolution.invalid.json" }
)
foreach ($case in $valid) {
  & python $validator --kind $case.kind --input (Join-Path $fixtures $case.file)
  if ($LASTEXITCODE -ne 0) { throw "Valid fixture rejected: $($case.file)" }
}
foreach ($case in $invalid) {
  & python $validator --kind $case.kind --input (Join-Path $fixtures $case.file) *> $null
  if ($LASTEXITCODE -eq 0) { throw "Invalid fixture accepted: $($case.file)" }
}
& python $validator --kind route --input (Join-Path $fixtures "routing.cases.json") --policy $policy
if ($LASTEXITCODE -ne 0) { throw "Routing fixture rejected" }
Write-Output "RESULT: PASS (valid=4; invalid_rejected=4; routing_cases=7)"
